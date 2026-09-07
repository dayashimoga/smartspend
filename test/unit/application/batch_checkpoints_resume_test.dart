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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late IngestionRepository ingestionRepo;
  late SmsRepository smsRepo;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    ingestionRepo = IngestionRepository(dbHelper: dbHelper);
    smsRepo = SmsRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Batch Checkpoints & Kill/Restart Resume Forensic Suite', () {
    test('Resumes after process termination without restarting from batch 0',
        () async {
      final messages = List.generate(
        6,
        (i) => {
          'id': 'sms_batch_$i',
          'sender': 'HDFCBK',
          'body': 'Rs ${100 + i}.00 spent on Card 9137 on ${i + 1}-JAN-26',
          'timestamp': DateTime(2026, 1, i + 1, 10, 0).millisecondsSinceEpoch,
        },
      );

      // --- RUN 1: Process batch 1 (size 2), then simulate process kill ---
      final service1 = IncrementalIngestionService(
        smsRepo: smsRepo,
        txnRepo: TransactionRepository(dbHelper: dbHelper),
        acctRepo: AccountRepository(dbHelper: dbHelper),
        cardRepo: CardRepository(dbHelper: dbHelper),
        billRepo: BillRepository(dbHelper: dbHelper),
        fastagRepo: FastagRepository(dbHelper: dbHelper),
        ingestionRepo: ingestionRepo,
        dbHelper: dbHelper,
      );

      int batchesCommitted = 0;
      service1.onBatchCommitted = () async {
        batchesCommitted++;
        if (batchesCommitted == 1) {
          // Pause service to simulate kill after first batch commit (offset 2)
          await service1.pause();
        }
      };

      await service1.startIngestion(
        overrideMessages: messages,
        batchSize: 2,
      );

      // Verify checkpoint after Batch 1 commit
      final cp1 = await ingestionRepo.getCheckpoint();
      expect(cp1, isNotNull);
      expect(cp1!.batchOffset, equals(2),
          reason: 'Checkpoint must be saved at batch 1 boundary');
      expect(cp1.isCompleted, isFalse);
      expect(cp1.scannedCount, equals(2));

      // Dispose service 1 (simulating process termination)
      service1.dispose();

      // --- RUN 2: Cold start with fresh service instance connected to same DB ---
      final service2 = IncrementalIngestionService(
        smsRepo: smsRepo,
        txnRepo: TransactionRepository(dbHelper: dbHelper),
        acctRepo: AccountRepository(dbHelper: dbHelper),
        cardRepo: CardRepository(dbHelper: dbHelper),
        billRepo: BillRepository(dbHelper: dbHelper),
        fastagRepo: FastagRepository(dbHelper: dbHelper),
        ingestionRepo: ingestionRepo,
        dbHelper: dbHelper,
      );

      // Resume ingestion
      final finalProgress = await service2.startIngestion(
        overrideMessages: messages,
        batchSize: 2,
      );

      expect(finalProgress.isCompleted, isTrue);
      expect(finalProgress.scannedCount, equals(6));
      expect(finalProgress.transactionsCount, equals(6));

      // Verify final checkpoint
      final cp2 = await ingestionRepo.getCheckpoint();
      expect(cp2, isNotNull);
      expect(cp2!.batchOffset, equals(6));
      expect(cp2.isCompleted, isTrue);

      // Confirm raw_sms in DB has exactly 6 unique records (no duplicates from resumption)
      final count = await smsRepo.getSmsCount();
      expect(count, equals(6));

      service2.dispose();
    });
  });
}
