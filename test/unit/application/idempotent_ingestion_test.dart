import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/sms/ingest_sms_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late IngestSmsUseCase ingestUseCase;
  late SmsRepository smsRepo;
  late TransactionRepository txnRepo;
  late List<Map<String, dynamic>> testSmsMessages;

  setUpAll(() {
    final file = File('test/fixtures/golden_sms.json');
    final fixtures = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    testSmsMessages = fixtures
        .map((f) => {
              'sender': f['sender'],
              'body': f['raw_sms'],
              'timestamp': f['timestamp'],
            })
        .toList();
  });

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    smsRepo = SmsRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    ingestUseCase = IngestSmsUseCase(
      smsRepo: smsRepo,
      txnRepo: txnRepo,
      acctRepo: AccountRepository(dbHelper: dbHelper),
      cardRepo: CardRepository(dbHelper: dbHelper),
      billRepo: BillRepository(dbHelper: dbHelper),
      fastagRepo: FastagRepository(dbHelper: dbHelper),
    );
  });

  group('Idempotent Ingestion Quality Gate', () {
    test('Repeated rescans create exactly ZERO duplicate records', () async {
      final totalMessages = testSmsMessages.length;
      expect(totalMessages, greaterThan(10));

      // Pass 1: Initial Ingestion (contains 1 whitespace duplicate fixture)
      final pass1 = await ingestUseCase.execute(testSmsMessages);
      expect(pass1.newlyIngested, equals(totalMessages - 1));
      expect(pass1.duplicatesSkipped, equals(1));

      // Verify DB count
      final countAfterPass1 = await smsRepo.getSmsCount();
      expect(countAfterPass1, equals(totalMessages - 1));

      // Pass 2: Re-scan exact same inbox
      final pass2 = await ingestUseCase.execute(testSmsMessages);
      expect(pass2.newlyIngested, equals(0),
          reason: 'Pass 2 must ingest 0 new records');
      expect(pass2.duplicatesSkipped, equals(totalMessages),
          reason: 'Pass 2 must skip all duplicates');

      // Verify DB count has NOT increased
      final countAfterPass2 = await smsRepo.getSmsCount();
      expect(countAfterPass2, equals(totalMessages - 1),
          reason: 'DB count must remain unchanged');

      // Pass 3: Another restart/re-scan simulation
      final pass3 = await ingestUseCase.execute(testSmsMessages);
      expect(pass3.newlyIngested, equals(0),
          reason: 'Pass 3 must ingest 0 new records');
      expect(pass3.duplicatesSkipped, equals(totalMessages),
          reason: 'Pass 3 must skip all duplicates');

      final countAfterPass3 = await smsRepo.getSmsCount();
      expect(countAfterPass3, equals(totalMessages - 1),
          reason: 'DB count must remain unchanged');
    });
  });
}
