import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
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
  late SmsRepository smsRepo;
  late TransactionRepository txnRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    smsRepo = SmsRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Database Schema & Cascade Forensic Suite', () {
    test(
        'Foreign key cascading deletes parsed_transactions when raw_sms is deleted',
        () async {
      final smsRecord = SmsRecord(
        id: 'sms_parent_1',
        sender: 'HDFCBK',
        body: 'Sample debit message',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_parent_1',
        ingestedAt: DateTime.now(),
      );
      await smsRepo.saveSms(smsRecord);

      final txn = ParsedTransaction(
        id: 'txn_child_1',
        rawSmsId: 'sms_parent_1',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        accountLast4: '1234',
        amount: 250.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 1),
        confidence: Confidence.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txnRepo.saveTransaction(txn);

      // Verify both exist
      expect(await smsRepo.getSmsById('sms_parent_1'), isNotNull);
      expect(await txnRepo.getTransactionById('txn_child_1'), isNotNull);

      // Delete raw_sms directly from DB
      final db = await dbHelper.database;
      await db.delete('raw_sms', where: 'id = ?', whereArgs: ['sms_parent_1']);

      // Assert that foreign key ON DELETE CASCADE deleted parsed_transactions as well!
      final childAfterCascade = await txnRepo.getTransactionById('txn_child_1');
      expect(
        childAfterCascade,
        isNull,
        reason:
            'Deleting raw_sms must cascade-delete linked parsed_transactions',
      );
    });

    test('Indexes are created on high-frequency query columns', () async {
      final db = await dbHelper.database;
      final indexes = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'");
      final indexNames = indexes.map((row) => row['name'] as String).toList();

      expect(indexNames.contains('idx_raw_sms_fingerprint'), isTrue);
      expect(indexNames.contains('idx_transactions_date'), isTrue);
      expect(indexNames.contains('idx_transactions_bank'), isTrue);
      expect(indexNames.contains('idx_transactions_type'), isTrue);
    });
  });
}
