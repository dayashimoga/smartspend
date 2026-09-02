import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/review/correction_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/correction_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;
  late CorrectionRepository correctionRepo;
  late CorrectionUseCase correctionUseCase;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_1',
        sender: 'ICICIB',
        body: 'Sample SMS',
        timestamp: DateTime(2026, 1, 15),
        fingerprint: 'fp_sample_1',
        ingestedAt: DateTime.now(),
      ),
    );
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    correctionRepo = CorrectionRepository(dbHelper: dbHelper);
    correctionUseCase = CorrectionUseCase(
      txnRepo: txnRepo,
      correctionRepo: correctionRepo,
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  ParsedTransaction createSampleTxn(
      {String id = 'txn_1', double amount = 1000.0}) {
    return ParsedTransaction(
      id: id,
      rawSmsId: 'sms_1',
      type: TransactionType.purchase,
      bank: Bank.icici,
      cardLast4: '4000',
      amount: amount,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 15),
      merchant: 'Original Merchant',
      category: 'Shopping',
      confidence: Confidence.low,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('CorrectionUseCase Forensic Suite', () {
    test('updateTransactionField updates merchant and records audit log',
        () async {
      final initial = createSampleTxn();
      await txnRepo.saveTransaction(initial);

      final updated = await correctionUseCase.updateTransactionField(
        transactionId: 'txn_1',
        fieldName: 'merchant',
        newValue: 'Amazon India',
        reason: 'User merchant refinement',
      );

      expect(updated.merchant, equals('Amazon India'));
      expect(updated.confidence, equals(Confidence.high));

      // Verify DB persistence
      final fromDb = await txnRepo.getTransactionById('txn_1');
      expect(fromDb?.merchant, equals('Amazon India'));

      // Verify Audit Log in corrections table
      final corrections =
          await correctionRepo.getCorrectionsForTransaction('txn_1');
      expect(corrections.length, equals(1));
      expect(corrections.first.fieldName, equals('merchant'));
      expect(corrections.first.originalValue, equals('Original Merchant'));
      expect(corrections.first.correctedValue, equals('Amazon India'));
      expect(corrections.first.reason, equals('User merchant refinement'));
    });

    test('updateTransactionField updates amount and category', () async {
      final initial = createSampleTxn();
      await txnRepo.saveTransaction(initial);

      await correctionUseCase.updateTransactionField(
        transactionId: 'txn_1',
        fieldName: 'amount',
        newValue: '1250.50',
      );

      await correctionUseCase.updateTransactionField(
        transactionId: 'txn_1',
        fieldName: 'category',
        newValue: 'Groceries',
      );

      final fromDb = await txnRepo.getTransactionById('txn_1');
      expect(fromDb?.amount, equals(1250.50));
      expect(fromDb?.category, equals('Groceries'));

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('txn_1');
      expect(corrections.length, equals(2));
    });

    test('setExcluded marks transaction as non-financial and records audit',
        () async {
      final initial = createSampleTxn();
      await txnRepo.saveTransaction(initial);

      // Exclude
      await correctionUseCase.setExcluded('txn_1', true,
          reason: 'Personal transfer');
      var fromDb = await txnRepo.getTransactionById('txn_1');
      expect(fromDb?.isExcluded, isTrue);
      expect(fromDb?.category, equals('Non-Financial'));

      // Restore
      await correctionUseCase.setExcluded('txn_1', false, reason: 'Reinstated');
      fromDb = await txnRepo.getTransactionById('txn_1');
      expect(fromDb?.isExcluded, isFalse);

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('txn_1');
      expect(corrections.length, equals(2));
      expect(corrections.first.reason, equals('Reinstated'));
      expect(corrections.last.reason, equals('Personal transfer'));
    });

    test('mergeDuplicates excludes duplicate and links to primary', () async {
      final primary = createSampleTxn(id: 'primary_1', amount: 500.0);
      final duplicate = createSampleTxn(id: 'dupe_1', amount: 500.0);
      await txnRepo.saveTransaction(primary);
      await txnRepo.saveTransaction(duplicate);

      await correctionUseCase.mergeDuplicates('primary_1', 'dupe_1');

      final dupeDb = await txnRepo.getTransactionById('dupe_1');
      expect(dupeDb?.isExcluded, isTrue);
      expect(dupeDb?.isReconciled, isTrue);
      expect(dupeDb?.reconciledWithId, equals('primary_1'));

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('dupe_1');
      expect(corrections.length, equals(1));
      expect(corrections.first.fieldName, equals('merged_into'));
      expect(corrections.first.correctedValue, equals('primary_1'));
    });

    test('splitTransaction creates two child items with audit logging',
        () async {
      final initial = createSampleTxn(id: 'parent_1', amount: 1000.0);
      await txnRepo.saveTransaction(initial);

      final splitResult = await correctionUseCase.splitTransaction(
        transactionId: 'parent_1',
        firstAmount: 600.0,
        firstCategory: 'Groceries',
        secondAmount: 400.0,
        secondCategory: 'Work Expenses',
      );

      expect(splitResult.length, equals(2));
      expect(splitResult[0].amount, equals(600.0));
      expect(splitResult[0].category, equals('Groceries'));
      expect(splitResult[1].amount, equals(400.0));
      expect(splitResult[1].category, equals('Work Expenses'));

      // Verify both exist in DB
      final parentDb = await txnRepo.getTransactionById('parent_1');
      expect(parentDb?.amount, equals(600.0));

      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(2));

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('parent_1');
      expect(corrections.length, equals(1));
      expect(corrections.first.fieldName, equals('split_transaction'));
    });
  });
}
