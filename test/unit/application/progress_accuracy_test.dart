import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/sms/incremental_ingestion_service.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/ingestion_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/ingestion_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late IncrementalIngestionService service;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    service = IncrementalIngestionService(
      smsRepo: SmsRepository(dbHelper: dbHelper),
      txnRepo: TransactionRepository(dbHelper: dbHelper),
      acctRepo: AccountRepository(dbHelper: dbHelper),
      cardRepo: CardRepository(dbHelper: dbHelper),
      billRepo: BillRepository(dbHelper: dbHelper),
      fastagRepo: FastagRepository(dbHelper: dbHelper),
      ingestionRepo: IngestionRepository(dbHelper: dbHelper),
      dbHelper: dbHelper,
    );
  });

  tearDown(() async {
    service.dispose();
    await dbHelper.close();
  });

  group('Ingestion State Machine & Progress Accuracy Forensic Suite', () {
    test('Transitions through all ingestion stages in order', () async {
      final recordedStages = <IngestionStage>[];
      service.progressStream.listen((p) {
        if (recordedStages.isEmpty || recordedStages.last != p.stage) {
          recordedStages.add(p.stage);
        }
      });

      final testMessages = [
        {
          'sender': 'HDFCBK',
          'body':
              'Rs 1500.00 spent on HDFC Card 9137 at Starbucks on 12-JAN-26. Avl Lmt: 45000',
          'timestamp': DateTime(2026, 1, 12, 10, 0).millisecondsSinceEpoch,
        },
        {
          'sender': 'HDFCBK',
          'body':
              'Salary of Rs 85000 credited to A/C XX1234 on 01-JAN-26. Bal: Rs 92000',
          'timestamp': DateTime(2026, 1, 1, 9, 0).millisecondsSinceEpoch,
        },
      ];

      final finalProgress = await service.startIngestion(
        overrideMessages: testMessages,
        batchSize: 10,
      );
      await Future.delayed(Duration.zero);

      expect(finalProgress.stage, equals(IngestionStage.completed));
      expect(finalProgress.scannedCount, equals(2));
      expect(finalProgress.transactionsCount, equals(2));
      expect(finalProgress.progressPercentage, equals(100.0));

      // Verify state sequence contains key pipeline stages
      expect(recordedStages, contains(IngestionStage.discovering));
      expect(recordedStages, contains(IngestionStage.reading));
      expect(recordedStages, contains(IngestionStage.parsing));
      expect(recordedStages, contains(IngestionStage.deduping));
      expect(recordedStages, contains(IngestionStage.reconciling));
      expect(recordedStages, contains(IngestionStage.updatingEntities));
      expect(recordedStages, contains(IngestionStage.finalizing));
      expect(recordedStages, contains(IngestionStage.completed));
    });

    test('Progress percentage and displayText formatting are exact', () {
      const progress = IngestionProgress(
        stage: IngestionStage.parsing,
        scannedCount: 150,
        totalCount: 500,
        transactionsCount: 120,
        billsCount: 5,
        accountsCount: 3,
        reviewCount: 2,
      );

      expect(progress.progressPercentage, equals(30.0));
      expect(
        progress.displayText,
        equals(
            'Analyzing SMS • 150/500 • 30% • 120 txns, 5 bills, 3 accounts, 2 review'),
      );
    });

    test('Indeterminate mode displays scanned count when totalCount is null',
        () {
      const progress = IngestionProgress(
        stage: IngestionStage.discovering,
        scannedCount: 42,
        totalCount: null,
        transactionsCount: 10,
        billsCount: 1,
        accountsCount: 1,
        reviewCount: 0,
      );

      expect(progress.isIndeterminate, isTrue);
      expect(
        progress.displayText,
        equals(
            'Analyzing SMS • 42 scanned • 10 txns, 1 bills, 1 accounts, 0 review'),
      );
    });

    test('Terminal state summaryText accurately encapsulates diagnostic counts',
        () {
      const progress = IngestionProgress(
        stage: IngestionStage.completed,
        scannedCount: 200,
        financialCount: 180,
        transactionsCount: 175,
        billsCount: 12,
        accountsCount: 4,
        reviewCount: 3,
        duplicatesCount: 10,
      );

      expect(
        progress.summaryText,
        equals(
            'Scanned: 200 • Financial: 180 • Txns: 175 • Bills: 12 • Accounts: 4 • Review: 3 • Skipped: 10'),
      );
    });
  });
}
