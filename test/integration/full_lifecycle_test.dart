import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartspend/application/review/correction_usecase.dart';
import 'package:smartspend/application/sms/ingest_sms_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/correction_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> goldenMessages;

  setUpAll(() {
    final file = File('test/fixtures/golden_sms.json');
    final fixtures = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    goldenMessages = fixtures
        .map((f) => {
              'sender': f['sender'],
              'body': f['raw_sms'],
              'timestamp': f['timestamp'],
            })
        .toList();
  });

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    try {
      await databaseFactoryFfi.deleteDatabase('test_lifecycle_vault.db');
    } catch (_) {}
  });

  group(
      'Full Fresh-Install -> Ingest -> Correct -> Restart -> Rescan Lifecycle',
      () {
    test(
        'Proves complete E2E lifecycle without regressions or overwritten corrections',
        () async {
      // Step 1: Fresh install simulation (fresh SQLite database)
      const testDbPath = 'test_lifecycle_vault.db';
      final dbHelper = DatabaseHelper(customDbPath: testDbPath);

      final smsRepo = SmsRepository(dbHelper: dbHelper);
      final txnRepo = TransactionRepository(dbHelper: dbHelper);
      final acctRepo = AccountRepository(dbHelper: dbHelper);
      final cardRepo = CardRepository(dbHelper: dbHelper);
      final billRepo = BillRepository(dbHelper: dbHelper);
      final fastagRepo = FastagRepository(dbHelper: dbHelper);
      final correctionRepo = CorrectionRepository(dbHelper: dbHelper);

      final ingestUseCase = IngestSmsUseCase(
        smsRepo: smsRepo,
        txnRepo: txnRepo,
        acctRepo: acctRepo,
        cardRepo: cardRepo,
        billRepo: billRepo,
        fastagRepo: fastagRepo,
      );

      final correctionUseCase = CorrectionUseCase(
        txnRepo: txnRepo,
        correctionRepo: correctionRepo,
      );

      // Step 2: Initial Historical SMS Synchronization
      final initialSyncResult = await ingestUseCase.execute(goldenMessages);
      expect(
          initialSyncResult.newlyIngested, equals(goldenMessages.length - 1));
      expect(initialSyncResult.duplicatesSkipped, equals(1));

      // Step 3: Check Dashboard Summary populated correctly
      final summaryBefore = await txnRepo.getFinancialSummary();
      expect(summaryBefore.totalIncome, greaterThan(0));
      expect(summaryBefore.totalExpense, greaterThan(0));

      final allTxns = await txnRepo.getAllTransactions(limit: 100);
      expect(allTxns.length, equals(goldenMessages.length - 1));

      // Pick a transaction to apply manual user edit
      final targetTxn = allTxns.firstWhere((t) => t.cardLast4 == '4000');
      final targetId = targetTxn.id;

      // Step 4: User corrects merchant in Review queue
      await correctionUseCase.updateTransactionField(
        transactionId: targetId,
        fieldName: 'merchant',
        newValue: 'Amazon Prime Video Subscription',
        reason: 'Manual precision tag',
      );

      final txnAfterEdit = await txnRepo.getTransactionById(targetId);
      expect(txnAfterEdit?.merchant, equals('Amazon Prime Video Subscription'));

      // Step 5: Simulate app process kill and reboot (close DB)
      await dbHelper.close();

      // Step 6: Reopen database on fresh app launch
      final reopenedDbHelper = DatabaseHelper(customDbPath: testDbPath);
      final reopenedTxnRepo = TransactionRepository(dbHelper: reopenedDbHelper);
      final reopenedSmsRepo = SmsRepository(dbHelper: reopenedDbHelper);
      final reopenedIngestUseCase = IngestSmsUseCase(
        smsRepo: reopenedSmsRepo,
        txnRepo: reopenedTxnRepo,
        acctRepo: AccountRepository(dbHelper: reopenedDbHelper),
        cardRepo: CardRepository(dbHelper: reopenedDbHelper),
        billRepo: BillRepository(dbHelper: reopenedDbHelper),
        fastagRepo: FastagRepository(dbHelper: reopenedDbHelper),
      );

      // Verify user correction survived reboot
      final txnAfterReboot = await reopenedTxnRepo.getTransactionById(targetId);
      expect(
          txnAfterReboot?.merchant, equals('Amazon Prime Video Subscription'));

      // Step 7: Simulate background automatic SMS inbox re-scan
      final rescanResult = await reopenedIngestUseCase.execute(goldenMessages);
      expect(rescanResult.newlyIngested, equals(0),
          reason: 'Must ingest 0 on rescan');
      expect(rescanResult.duplicatesSkipped, equals(goldenMessages.length),
          reason: 'All must be skipped');

      // Step 8: Assert manual user correction was NOT overwritten by re-ingestion
      final txnAfterRescan = await reopenedTxnRepo.getTransactionById(targetId);
      expect(
        txnAfterRescan?.merchant,
        equals('Amazon Prime Video Subscription'),
        reason: 'Rescan must never overwrite manual user corrections',
      );

      // Cleanup
      await reopenedDbHelper.close();
      try {
        File(testDbPath).deleteSync();
      } catch (_) {}
    });
  });
}
