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
  late CorrectionUseCase useCase;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 's_corr_1',
        sender: 'HDFCBK',
        body: 'Sample SMS',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_corr_1',
        ingestedAt: DateTime.now(),
      ),
    );

    txnRepo = TransactionRepository(dbHelper: dbHelper);
    correctionRepo = CorrectionRepository(dbHelper: dbHelper);
    useCase =
        CorrectionUseCase(txnRepo: txnRepo, correctionRepo: correctionRepo);

    await txnRepo.saveTransaction(
      ParsedTransaction(
        id: 't_corr_1',
        rawSmsId: 's_corr_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        accountLast4: '1111',
        cardLast4: '2222',
        amount: 2000.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 1),
        merchant: 'Old Merchant',
        category: 'Old Category',
        confidence: Confidence.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await txnRepo.saveTransaction(
      ParsedTransaction(
        id: 't_corr_2',
        rawSmsId: 's_corr_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        amount: 2000.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 1),
        merchant: 'Duplicate Merchant',
        category: 'Old Category',
        confidence: Confidence.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('CorrectionUseCase Full Forensic Coverage Suite', () {
    test(
        'updateTransactionField updates all supported fields and records audit logs',
        () async {
      // 1. Update merchant
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'merchant',
        newValue: 'New Merchant',
      );

      // 2. Update category
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'category',
        newValue: 'Groceries',
      );

      // 3. Update amount
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'amount',
        newValue: '2500.0',
      );

      // 4. Update type
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'type',
        newValue: 'salary',
      );

      // 5. Update bank
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'bank',
        newValue: 'icici',
      );

      // 6. Update accountLast4
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'accountLast4',
        newValue: '9999',
      );

      // 7. Update cardLast4
      await useCase.updateTransactionField(
        transactionId: 't_corr_1',
        fieldName: 'cardLast4',
        newValue: '8888',
      );

      final updated = await txnRepo.getTransactionById('t_corr_1');
      expect(updated!.merchant, equals('New Merchant'));
      expect(updated.category, equals('Groceries'));
      expect(updated.amount, equals(2500.0));
      expect(updated.type, equals(TransactionType.salary));
      expect(updated.bank, equals(Bank.icici));
      expect(updated.accountLast4, equals('9999'));
      expect(updated.cardLast4, equals('8888'));
      expect(updated.confidence, equals(Confidence.high));

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('t_corr_1');
      expect(corrections.length, equals(7));
    });

    test('setExcluded marks transaction non-financial and restores', () async {
      await useCase.setExcluded('t_corr_1', true, reason: 'Test Exclusion');
      var txn = await txnRepo.getTransactionById('t_corr_1');
      expect(txn!.isExcluded, isTrue);
      expect(txn.category, equals('Non-Financial'));

      await useCase.setExcluded('t_corr_1', false);
      txn = await txnRepo.getTransactionById('t_corr_1');
      expect(txn!.isExcluded, isFalse);
    });

    test('mergeDuplicates excludes duplicate and links to primary', () async {
      await useCase.mergeDuplicates('t_corr_1', 't_corr_2');
      final duplicate = await txnRepo.getTransactionById('t_corr_2');
      expect(duplicate!.isExcluded, isTrue);
      expect(duplicate.isReconciled, isTrue);
      expect(duplicate.reconciledWithId, equals('t_corr_1'));
    });

    test('splitTransaction creates two split records', () async {
      final splitResult = await useCase.splitTransaction(
        transactionId: 't_corr_1',
        firstAmount: 1200.0,
        firstCategory: 'Groceries',
        secondAmount: 800.0,
        secondCategory: 'Household',
      );

      expect(splitResult.length, equals(2));
      expect(splitResult[0].amount, equals(1200.0));
      expect(splitResult[0].category, equals('Groceries'));
      expect(splitResult[1].amount, equals(800.0));
      expect(splitResult[1].category, equals('Household'));
    });
  });
}
