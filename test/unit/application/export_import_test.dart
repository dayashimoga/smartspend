import 'dart:convert';
import 'package:crypto/crypto.dart' as import_crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/export/export_backup_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;
  late AccountRepository acctRepo;
  late CardRepository cardRepo;
  late BillRepository billRepo;
  late FastagRepository fastagRepo;
  late ExportBackupUseCase exportImportUseCase;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_1',
        sender: 'HDFCBK',
        body: 'Sample SMS',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_1',
        ingestedAt: DateTime.now(),
      ),
    );

    txnRepo = TransactionRepository(dbHelper: dbHelper);
    acctRepo = AccountRepository(dbHelper: dbHelper);
    cardRepo = CardRepository(dbHelper: dbHelper);
    billRepo = BillRepository(dbHelper: dbHelper);
    fastagRepo = FastagRepository(dbHelper: dbHelper);

    exportImportUseCase = ExportBackupUseCase(
      txnRepo: txnRepo,
      acctRepo: acctRepo,
      cardRepo: cardRepo,
      billRepo: billRepo,
      fastagRepo: fastagRepo,
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('ExportBackupUseCase Forensic Suite', () {
    test('exportToJson and exportToCsv produce well-formed checksummed output',
        () async {
      await txnRepo.saveTransaction(
        ParsedTransaction(
          id: 'txn_1',
          rawSmsId: 'sms_1',
          type: TransactionType.purchase,
          bank: Bank.hdfc,
          cardLast4: '1234',
          amount: 500.0,
          currency: 'INR',
          transactionDate: DateTime(2026, 1, 10),
          merchant: 'Bookstore',
          category: 'Shopping',
          confidence: Confidence.high,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await acctRepo.upsertAccount(
        Account(
          id: 'acct_1',
          bank: Bank.hdfc,
          last4: '5678',
          accountType: 'Savings',
          currentBalance: 25000.0,
          currency: 'INR',
          lastUpdated: DateTime(2026, 1, 10),
        ),
      );

      final jsonResult = await exportImportUseCase.exportToJson();
      final decoded = jsonDecode(jsonResult) as Map<String, dynamic>;

      expect(decoded.containsKey('checksum'), isTrue);
      expect(decoded.containsKey('payload'), isTrue);

      final payload = decoded['payload'] as Map<String, dynamic>;
      expect(payload['transactions'].length, equals(1));
      expect(payload['accounts'].length, equals(1));

      final csvResult = await exportImportUseCase.exportToCsv();
      expect(csvResult.contains('Bookstore'), isTrue);
      expect(csvResult.contains('500.00'), isTrue);
    });

    test('importFromJson restores records with valid checksum', () async {
      final backupJson = await exportImportUseCase.exportToJson();

      // Create a fresh new database instance to test restore
      final freshDbHelper = DatabaseHelper.inMemory();
      final freshSmsRepo = SmsRepository(dbHelper: freshDbHelper);
      await freshSmsRepo.saveSms(
        SmsRecord(
          id: 'sms_1',
          sender: 'HDFCBK',
          body: 'Sample SMS',
          timestamp: DateTime(2026, 1, 1),
          fingerprint: 'fp_1',
          ingestedAt: DateTime.now(),
        ),
      );

      final freshUseCase = ExportBackupUseCase(
        txnRepo: TransactionRepository(dbHelper: freshDbHelper),
        acctRepo: AccountRepository(dbHelper: freshDbHelper),
        cardRepo: CardRepository(dbHelper: freshDbHelper),
        billRepo: BillRepository(dbHelper: freshDbHelper),
        fastagRepo: FastagRepository(dbHelper: freshDbHelper),
      );

      final result = await freshUseCase.importFromJson(backupJson);
      expect(result, isNotNull);
      await freshDbHelper.close();
    });

    test('importFromJson rejects tampered backup files with SecurityException',
        () async {
      final backupJson = await exportImportUseCase.exportToJson();
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;

      // Tamper with the payload while keeping the original checksum
      final payload = decoded['payload'] as Map<String, dynamic>;
      payload['tampered_key'] = 'malicious_content';
      final tamperedJson = jsonEncode({
        'checksum': decoded['checksum'],
        'payload': payload,
      });

      expect(
        () => exportImportUseCase.importFromJson(tamperedJson),
        throwsA(isA<SecurityException>()),
      );
    });

    test(
        'importFromJson sanitizes malicious strings and rejects invalid dates/amounts',
        () async {
      // Build a crafted payload with SQL injection attempt, control characters, negative amount, and crazy date
      final maliciousPayload = {
        'version': '1.0.0',
        'exported_at': DateTime.now().toIso8601String(),
        'transactions': [
          {
            'id': 'txn_malicious_1',
            'raw_sms_id': 'sms_1',
            'type': 'purchase',
            'bank': 'hdfc',
            'card_last4': '1234',
            'amount': -999.0, // Negative amount
            'currency': 'INR',
            'transaction_date': 1768000000000,
            'merchant': "O'Reilly'; DROP TABLE parsed_transactions;--",
            'category': 'Test',
            'confidence': 'HIGH',
            'parser_version': '1.0.0',
            'is_excluded': 0,
            'is_reconciled': 0,
            'created_at': 1768000000000,
            'updated_at': 1768000000000,
          },
          {
            'id': 'txn_malicious_2',
            'raw_sms_id': 'sms_1',
            'type': 'purchase',
            'bank': 'hdfc',
            'card_last4': '9999',
            'amount': 250.0,
            'currency': 'INR',
            'transaction_date': 0, // Year 1970 (out of bounds)
            'merchant': 'Invalid Date Shop',
            'category': 'Test',
            'confidence': 'HIGH',
            'parser_version': '1.0.0',
            'is_excluded': 0,
            'is_reconciled': 0,
            'created_at': 1768000000000,
            'updated_at': 1768000000000,
          },
          {
            'id': 'txn_sanitized_3',
            'raw_sms_id': 'sms_1',
            'type': 'purchase',
            'bank': 'hdfc',
            'card_last4': '5555',
            'amount': 300.0,
            'currency': 'INR',
            'transaction_date': 1768000000000,
            'merchant': "Normal Merchant \x00\x1F With Control Chars",
            'category': 'Test',
            'confidence': 'HIGH',
            'parser_version': '1.0.0',
            'is_excluded': 0,
            'is_reconciled': 0,
            'created_at': 1768000000000,
            'updated_at': 1768000000000,
          }
        ],
        'accounts': [],
        'cards': [],
        'bills': [],
        'fastag': [],
      };

      // Compute valid SHA-256 for the crafted payload
      final jsonPayloadStr = jsonEncode(maliciousPayload);
      final validChecksum = importCryptoChecksum(jsonPayloadStr);

      final backupContent = jsonEncode({
        'checksum': validChecksum,
        'payload': maliciousPayload,
      });

      final result = await exportImportUseCase.importFromJson(backupContent);

      // txn_malicious_1 (negative amount) and txn_malicious_2 (year 1970) must be rejected
      // txn_sanitized_3 must have control chars stripped
      expect(result.transactionsImported, equals(1));

      final saved = await txnRepo.getTransactionById('txn_sanitized_3');
      expect(saved, isNotNull);
      expect(saved?.merchant, equals('Normal Merchant  With Control Chars'));
    });
  });
}

String importCryptoChecksum(String payloadStr) {
  import_crypto.Digest d =
      import_crypto.sha256.convert(utf8.encode(payloadStr));
  return d.toString();
}
