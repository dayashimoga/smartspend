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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late IncrementalIngestionService service;
  late IngestionRepository ingestionRepo;
  late TransactionRepository txnRepo;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    ingestionRepo = IngestionRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    service = IncrementalIngestionService(
      smsRepo: SmsRepository(dbHelper: dbHelper),
      txnRepo: txnRepo,
      acctRepo: AccountRepository(dbHelper: dbHelper),
      cardRepo: CardRepository(dbHelper: dbHelper),
      billRepo: BillRepository(dbHelper: dbHelper),
      fastagRepo: FastagRepository(dbHelper: dbHelper),
      ingestionRepo: ingestionRepo,
      dbHelper: dbHelper,
    );
  });

  tearDown(() async {
    service.dispose();
    await dbHelper.close();
  });

  group('Parser-Version Reprocessing & Re-analyze Forensic Suite', () {
    test(
        'Historical SMS are re-analyzed from database when reanalyze is requested',
        () async {
      final initialMessages = [
        {
          'id': 'sms_re_1',
          'sender': 'HDFCBK',
          'body': 'Rs 2500.00 spent on Card 9137 on 10-JAN-26',
          'timestamp': DateTime(2026, 1, 10, 10, 0).millisecondsSinceEpoch,
        },
        {
          'id': 'sms_re_2',
          'sender': 'SBIINB',
          'body': 'A/C 1234 credited by Rs 10000 on 11-JAN-26. Bal: 15000',
          'timestamp': DateTime(2026, 1, 11, 11, 0).millisecondsSinceEpoch,
        },
      ];

      // Initial import
      await service.startIngestion(overrideMessages: initialMessages);
      final initialTxns = await txnRepo.getAllTransactions();
      expect(initialTxns.length, equals(2));

      // Trigger re-analyze of historical records from DB
      final reanalyzeProgress = await service.startIngestion(reanalyze: true);

      expect(reanalyzeProgress.isCompleted, isTrue);
      expect(reanalyzeProgress.scannedCount, equals(2));
      expect(reanalyzeProgress.transactionsCount, equals(2));

      // Checkpoint reflects current parser version
      final cp = await ingestionRepo.getCheckpoint();
      expect(cp!.parserVersion,
          equals(IncrementalIngestionService.currentParserVersion));
      expect(cp.isCompleted, isTrue);
    });

    test(
        'shouldReprocessHistorical detects outdated parser version in checkpoint',
        () async {
      // Simulate older checkpoint version
      final oldCheckpoint = IngestionCheckpoint(
        id: 'primary',
        parserVersion: '0.9.0',
        lastUpdated: DateTime.now(),
        isCompleted: true,
      );
      await ingestionRepo.saveCheckpoint(oldCheckpoint);

      final shouldReprocess = await service.shouldReprocessHistorical();
      expect(shouldReprocess, isTrue,
          reason:
              'Must flag reprocess when stored version 0.9.0 != current version 1.0.0');
    });
  });
}
