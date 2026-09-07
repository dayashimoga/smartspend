import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:smartspend/domain/entities/ingestion_checkpoint.dart';
import 'package:smartspend/domain/entities/ingestion_state.dart';
import 'package:smartspend/domain/repositories/interfaces.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Ingestion Coverage Booster Suite', () {
    test('IngestionCheckpoint toMap, fromMap, copyWith, props', () {
      final now = DateTime.now();
      final cp1 = IngestionCheckpoint(
        id: 'cp_1',
        lastSmsId: 'sms_99',
        lastTimestamp: 1768000000000,
        lastFingerprint: 'fp_99',
        parserVersion: '1.0.0',
        batchOffset: 50,
        stage: IngestionStage.parsing,
        totalCount: 100,
        scannedCount: 50,
        transactionsCount: 40,
        billsCount: 3,
        accountsCount: 2,
        balancesCount: 10,
        financialCount: 45,
        duplicatesCount: 2,
        ignoredCount: 3,
        reviewCount: 1,
        failedCount: 0,
        lastUpdated: now,
        isCompleted: false,
      );

      final map = cp1.toMap();
      expect(map['id'], equals('cp_1'));
      expect(map['is_completed'], equals(0));

      final cpFromMap = IngestionCheckpoint.fromMap(map);
      expect(cpFromMap.id, equals('cp_1'));
      expect(cpFromMap.scannedCount, equals(50));
      expect(cpFromMap.stage, equals(IngestionStage.parsing));

      final cp2 = cp1.copyWith(
        id: 'cp_2',
        isCompleted: true,
        scannedCount: 100,
        transactionsCount: 80,
      );
      expect(cp2.id, equals('cp_2'));
      expect(cp2.isCompleted, isTrue);
      expect(cp2.scannedCount, equals(100));
      expect(cp2.transactionsCount, equals(80));
      expect(cp2.billsCount, equals(3)); // preserved

      expect(cp1.props.length, equals(20));
    });

    test('IngestionHistoryRecord toMap, fromMap, props', () {
      final now = DateTime.now();
      final hist1 = IngestionHistoryRecord(
        id: 'h_1',
        startedAt: now,
        completedAt: now.add(const Duration(minutes: 1)),
        status: 'completed',
        totalScanned: 100,
        financialCount: 80,
        transactionsCount: 75,
        billsCount: 5,
        balancesCount: 20,
        duplicatesCount: 5,
        ignoredCount: 15,
        reviewCount: 2,
        failedCount: 0,
        parserVersion: '1.0.0',
        errorMessage: null,
      );

      final map = hist1.toMap();
      expect(map['status'], equals('completed'));

      final fromMap = IngestionHistoryRecord.fromMap(map);
      expect(fromMap.id, equals('h_1'));
      expect(fromMap.totalScanned, equals(100));
      expect(fromMap.status, equals('completed'));
      expect(hist1.props.length, equals(15));
    });

    test('IngestionProgress copyWith, display text, and stage names', () {
      for (final stage in IngestionStage.values) {
        expect(stage.displayName.isNotEmpty, isTrue);
      }

      var prog = const IngestionProgress(
        stage: IngestionStage.failed,
        scannedCount: 10,
        totalCount: 20,
        errorMessage: 'Connection timed out',
      );
      expect(prog.isFailed, isTrue);
      expect(prog.displayText, contains('Sync Failed • 10 scanned'));
      expect(prog.canRetry, isTrue);

      prog = const IngestionProgress(
        stage: IngestionStage.paused,
        scannedCount: 15,
        totalCount: 30,
        transactionsCount: 10,
        billsCount: 1,
        accountsCount: 1,
        reviewCount: 0,
      );
      expect(prog.isPaused, isTrue);
      expect(prog.displayText, contains('Sync Paused • 15/30'));
      expect(prog.canResume, isTrue);
      expect(prog.canCancel, isTrue);

      final copied = prog.copyWith(
        stage: IngestionStage.cancelled,
        scannedCount: 16,
        totalCount: 32,
        currentBatch: 2,
        totalBatches: 4,
        transactionsCount: 11,
        billsCount: 2,
        accountsCount: 2,
        balancesCount: 5,
        financialCount: 15,
        duplicatesCount: 1,
        ignoredCount: 2,
        reviewCount: 1,
        failedCount: 1,
        errorMessage: 'Cancelled by user',
      );
      expect(copied.isCancelled, isTrue);
      expect(copied.currentBatch, equals(2));
      expect(copied.props.length, equals(16));
    });

    test('IngestionRepository clearCheckpoint, deleteHistory and getHistory',
        () async {
      final repo = IngestionRepository(dbHelper: dbHelper);
      await repo.saveCheckpoint(IngestionCheckpoint(
        id: 'primary',
        lastSmsId: 'sms_1',
        lastTimestamp: 1000,
        parserVersion: '1.0.0',
        lastUpdated: DateTime.now(),
        isCompleted: true,
      ));
      await repo.saveHistory(IngestionHistoryRecord(
        id: 'hist_1',
        startedAt: DateTime.now(),
        status: 'completed',
        totalScanned: 10,
        financialCount: 8,
        transactionsCount: 7,
        billsCount: 1,
        balancesCount: 2,
        duplicatesCount: 0,
        ignoredCount: 2,
        reviewCount: 0,
        failedCount: 0,
        parserVersion: '1.0.0',
      ));

      final hist = await repo.getHistory(limit: 5);
      expect(hist.length, equals(1));

      await repo.clearCheckpoint();
      final cpAfterClear = await repo.getCheckpoint();
      expect(cpAfterClear, isNull);

      await repo.deleteHistory('hist_1');
      final histAfterClear = await repo.getHistory();
      expect(histAfterClear, isEmpty);
    });

    test(
        'IncrementalIngestionService processes bills, cards, Fastag, and ignored non-financial SMS',
        () async {
      final service = IncrementalIngestionService(
        smsRepo: SmsRepository(dbHelper: dbHelper),
        txnRepo: TransactionRepository(dbHelper: dbHelper),
        acctRepo: AccountRepository(dbHelper: dbHelper),
        cardRepo: CardRepository(dbHelper: dbHelper),
        billRepo: BillRepository(dbHelper: dbHelper),
        fastagRepo: FastagRepository(dbHelper: dbHelper),
        ingestionRepo: IngestionRepository(dbHelper: dbHelper),
        dbHelper: dbHelper,
      );

      final mixedSms = [
        // 1. Bill SMS
        {
          'sender': 'HDFCBK',
          'body':
              'HDFC Bank Credit Card XX9137 Statement: Total due amt: Rs.11,397.00 Min due amt: Rs.570.00 Due by:04-08-2025.',
          'timestamp': DateTime(2025, 7, 20).millisecondsSinceEpoch,
        },
        // 2. Card Spent SMS
        {
          'sender': 'HDFCBK',
          'body':
              'Rs 3200.00 spent on Card 9137 at Reliance Retail on 06-FEB-26. Avl Lmt: 41800',
          'timestamp': DateTime(2026, 2, 6).millisecondsSinceEpoch,
        },
        // 3. Fastag SMS
        {
          'sender': 'NETC',
          'body':
              'FASTag toll payment of Rs 85.00 at KIAL Toll for KA01MJ1234. Bal: Rs 420.00',
          'timestamp': DateTime(2026, 2, 7).millisecondsSinceEpoch,
        },
        // 4. Ignored OTP SMS
        {
          'sender': 'HDFCBK',
          'body': 'Your OTP for login is 482910. Do not share with anyone.',
          'timestamp': DateTime(2026, 2, 8).millisecondsSinceEpoch,
        },
      ];

      final res = await service.startIngestion(
        overrideMessages: mixedSms,
        batchSize: 10,
      );

      expect(res.isCompleted, isTrue);
      expect(res.scannedCount, equals(4));
      expect(res.ignoredCount, equals(1)); // The promo SMS
      expect(res.billsCount, greaterThanOrEqualTo(1));
      expect(res.transactionsCount, greaterThanOrEqualTo(2));

      service.dispose();
    });

    test('IncrementalIngestionService inactive controls and retry no-ops',
        () async {
      final service = IncrementalIngestionService(
        smsRepo: SmsRepository(dbHelper: dbHelper),
        txnRepo: TransactionRepository(dbHelper: dbHelper),
        acctRepo: AccountRepository(dbHelper: dbHelper),
        cardRepo: CardRepository(dbHelper: dbHelper),
        billRepo: BillRepository(dbHelper: dbHelper),
        fastagRepo: FastagRepository(dbHelper: dbHelper),
        ingestionRepo: IngestionRepository(dbHelper: dbHelper),
        dbHelper: dbHelper,
      );

      // Call pause/resume/retry when idle
      await service.pause();
      expect(service.currentProgress.stage, equals(IngestionStage.idle));

      await service.resume();
      expect(service.currentProgress.stage, equals(IngestionStage.idle));

      await service.retry();
      expect(service.currentProgress.stage, equals(IngestionStage.idle));

      // Test cancel with existing checkpoint
      await IngestionRepository(dbHelper: dbHelper).saveCheckpoint(
        IngestionCheckpoint(
          id: 'primary',
          lastSmsId: 'sms_1',
          lastTimestamp: 1000,
          parserVersion: '1.0.0',
          lastUpdated: DateTime.now(),
          isCompleted: false,
        ),
      );
      await service.cancel();
      expect(service.currentProgress.stage, equals(IngestionStage.cancelled));

      service.dispose();
    });

    test(
        'IncrementalIngestionService handles unexpected errors and transitions to failed state',
        () async {
      final failingRepo = _FailingIngestionRepo();
      final service = IncrementalIngestionService(
        smsRepo: SmsRepository(dbHelper: dbHelper),
        txnRepo: TransactionRepository(dbHelper: dbHelper),
        acctRepo: AccountRepository(dbHelper: dbHelper),
        cardRepo: CardRepository(dbHelper: dbHelper),
        billRepo: BillRepository(dbHelper: dbHelper),
        fastagRepo: FastagRepository(dbHelper: dbHelper),
        ingestionRepo: failingRepo,
        dbHelper: dbHelper,
      );

      final res = await service.startIngestion(
        overrideMessages: [
          {
            'sender': 'HDFCBK',
            'body': 'Rs 100 spent',
            'timestamp': 1000,
          }
        ],
      );

      expect(res.stage, equals(IngestionStage.failed));
      expect(res.errorMessage, contains('Simulated DB failure'));
      expect(res.canRetry, isTrue);

      service.dispose();
    });

    test('Riverpod IngestionNotifier controls and providers work seamlessly',
        () async {
      final freshDb = DatabaseHelper.inMemory();
      addTearDown(freshDb.close);

      final container = ProviderContainer(
        overrides: [
          dbHelperProvider.overrideWithValue(freshDb),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(ingestionControllerProvider.notifier);
      expect(notifier.state.stage, equals(IngestionStage.idle));

      // Test startSync
      await notifier.startSync(
        overrideMessages: [
          {
            'sender': 'HDFCBK',
            'body': 'Rs 250 spent on Card 9137 on 15-JAN-26',
            'timestamp': 1768000000000,
          }
        ],
      );
      await Future.delayed(Duration.zero);
      expect(notifier.state.isCompleted, isTrue);

      // Test controls
      await notifier.pause();
      await notifier.resume();
      await notifier.cancel();
      await notifier.retry();
      await notifier.reanalyze();

      // Test dismiss
      notifier.dismiss();
      expect(notifier.state.stage, equals(IngestionStage.idle));

      // Test providers
      final cp = await container.read(ingestionCheckpointProvider.future);
      expect(cp, isNotNull);
      expect(cp!.isCompleted, isTrue);

      final hist = await container.read(ingestionHistoryProvider.future);
      expect(hist, isNotEmpty);

      final accounts = await container.read(filteredAccountsProvider.future);
      expect(accounts, isEmpty);

      final cards = await container.read(filteredCardsProvider.future);
      expect(cards, isEmpty);
    });
  });
}

class _FailingIngestionRepo implements IIngestionRepository {
  @override
  Future<void> clearCheckpoint({String id = 'primary'}) async {}
  @override
  Future<void> deleteHistory(String id) async {}
  @override
  Future<IngestionCheckpoint?> getCheckpoint({String id = 'primary'}) =>
      throw Exception('Simulated DB failure');
  @override
  Future<List<IngestionHistoryRecord>> getHistory({int limit = 50}) async => [];
  @override
  Future<void> saveCheckpoint(IngestionCheckpoint checkpoint) async =>
      throw Exception('Simulated DB failure');
  @override
  Future<void> saveHistory(IngestionHistoryRecord record) async =>
      throw Exception('Simulated DB failure');
}
