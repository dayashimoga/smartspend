import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/application/export/export_backup_usecase.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;
  late ExportBackupUseCase exportUseCase;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_pii_1',
        sender: 'HDFCBK',
        body: 'Sample message for card 4000',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_pii_1',
        ingestedAt: DateTime.now(),
      ),
    );

    txnRepo = TransactionRepository(dbHelper: dbHelper);
    exportUseCase = ExportBackupUseCase(
      txnRepo: txnRepo,
      acctRepo: AccountRepository(dbHelper: dbHelper),
      cardRepo: CardRepository(dbHelper: dbHelper),
      billRepo: BillRepository(dbHelper: dbHelper),
      fastagRepo: FastagRepository(dbHelper: dbHelper),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('PII Leakage & Data Masking Forensic Suite', () {
    test('Masked display strings only reveal last 4 digits (•••• 4000)', () {
      final txnWithCard = ParsedTransaction(
        id: 'txn_card',
        rawSmsId: 'sms_pii_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        cardLast4: '4000',
        amount: 500.0,
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final txnWithAcct = ParsedTransaction(
        id: 'txn_acct',
        rawSmsId: 'sms_pii_1',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 1500.0,
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(txnWithCard.maskedAccountOrCard, equals('•••• 4000'));
      expect(txnWithAcct.maskedAccountOrCard, equals('•••• 0564'));

      // Ensure no 16-digit or full account numbers are stored in last4 fields
      expect(txnWithCard.cardLast4!.length, lessThanOrEqualTo(4));
      expect(txnWithAcct.accountLast4!.length, lessThanOrEqualTo(4));
    });

    test(
        'Exported JSON and CSV records do not contain unmasked 16-digit account numbers',
        () async {
      final txn = ParsedTransaction(
        id: 'txn_export_test',
        rawSmsId: 'sms_pii_1',
        type: TransactionType.purchase,
        bank: Bank.icici,
        cardLast4: '7890',
        amount: 1200.0,
        merchant: 'Flipkart',
        category: 'Shopping',
        confidence: Confidence.high,
        transactionDate: DateTime(2026, 1, 15),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txnRepo.saveTransaction(txn);

      // JSON export check
      final jsonStr = await exportUseCase.exportToJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final payload = decoded['payload'] as Map<String, dynamic>;
      final exportedTxn = payload['transactions'].first as Map<String, dynamic>;

      expect(exportedTxn['card_last4'], equals('7890'));
      expect(exportedTxn.containsKey('full_card_number'), isFalse);
      expect(exportedTxn.containsKey('pan'), isFalse);

      // Regex scan whole exported JSON for 16-digit credit card patterns
      final creditCardPattern = RegExp(
          r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13})\b');
      expect(creditCardPattern.hasMatch(jsonStr), isFalse,
          reason: 'Exported JSON must NOT contain full PAN numbers');

      // CSV export check
      final csvStr = await exportUseCase.exportToCsv();
      expect(creditCardPattern.hasMatch(csvStr), isFalse,
          reason: 'Exported CSV must NOT contain full PAN numbers');
    });
  });
}
