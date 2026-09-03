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
  late IncrementalIngestionService service;
  late SmsRepository smsRepo;
  late TransactionRepository txnRepo;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    smsRepo = SmsRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    service = IncrementalIngestionService(
      smsRepo: smsRepo,
      txnRepo: txnRepo,
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

  group('Incremental Ingestion & Duplicate Prevention Forensic Suite', () {
    test(
        'Pass 1 ingests initial batch; Pass 2 with new SMS processes ONLY new SMS',
        () async {
      final initialMessages = [
        {
          'sender': 'HDFCBK',
          'body': 'Rs 1200.00 spent on Card 9137 on 05-JAN-26',
          'timestamp': DateTime(2026, 1, 5, 12, 0).millisecondsSinceEpoch,
        },
        {
          'sender': 'HDFCBK',
          'body': 'Rs 3400.00 debited from A/C XX1234 on 06-JAN-26. Bal: 45000',
          'timestamp': DateTime(2026, 1, 6, 14, 0).millisecondsSinceEpoch,
        },
      ];

      // Pass 1: Initial import
      final pass1 = await service.startIngestion(
        overrideMessages: initialMessages,
      );
      expect(pass1.transactionsCount, equals(2));
      expect(pass1.duplicatesCount, equals(0));

      final countPass1 = await smsRepo.getSmsCount();
      expect(countPass1, equals(2));

      // Pass 2: Inbox now contains the original 2 + 1 new SMS
      final secondBatch = [
        ...initialMessages,
        {
          'sender': 'ICICIB',
          'body': 'INR 550.00 paid towards Swiggy on 10-JAN-26 using UPI',
          'timestamp': DateTime(2026, 1, 10, 19, 0).millisecondsSinceEpoch,
        },
      ];

      final pass2 = await service.startIngestion(
        overrideMessages: secondBatch,
      );

      // Verify that the duplicate 2 are skipped and only the 1 new SMS is ingested
      expect(pass2.duplicatesCount, equals(2));
      expect(pass2.transactionsCount, equals(1));

      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(3),
          reason:
              'Total transactions in DB must be exactly 3 (2 initial + 1 new)');
    });
  });
}
