import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;
  late SmsRepository smsRepo;

  setUp(() async {
    await DatabaseHelper.resetDatabaseForTesting();
    dbHelper = DatabaseHelper.inMemory();
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    smsRepo = SmsRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Accounting Invariants Verification', () {
    test(
        '1. Invariant: Credit card repayments must NEVER be counted as expenses',
        () async {
      final now = DateTime.now();

      // Raw SMS
      final rawSms = SmsRecord(
        id: 'sms_repay_1',
        sender: 'HDFCBK',
        body:
            'Sent Rs. 15000 from A/C XX0564 for Credit Card Payment to HDFC Card 9137',
        timestamp: now,
        fingerprint: 'fp_repay_1',
        ingestedAt: now,
      );
      await smsRepo.saveSms(rawSms);

      // Card Purchase (real expense: 15,000)
      final purchaseTxn = ParsedTransaction(
        id: 'txn_purchase_1',
        rawSmsId: 'sms_repay_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        cardLast4: '9137',
        amount: 15000.0,
        transactionDate: now.subtract(const Duration(days: 5)),
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );
      await txnRepo.saveTransaction(purchaseTxn);

      // Card Repayment (internal movement, MUST be neutral!)
      final repayTxn = ParsedTransaction(
        id: 'txn_repay_1',
        rawSmsId: 'sms_repay_1',
        type: TransactionType.billPayment,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 15000.0,
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );
      await txnRepo.saveTransaction(repayTxn);

      final summary = await txnRepo.getFinancialSummary();

      // Invariant: Total expense must ONLY be the purchase (15,000), NOT double-counted with payment (30,000)!
      expect(summary.totalExpense, equals(15000.0),
          reason: 'Credit card payment must not be counted as expense');
      expect(summary.totalCardSpent, equals(15000.0));
    });

    test(
        '2. Invariant: Own-account transfers must NEVER count as expense or income',
        () async {
      final now = DateTime.now();

      final rawSms = SmsRecord(
        id: 'sms_transfer_1',
        sender: 'HDFCBK',
        body: 'Sent Rs. 50000 to IDFC A/C 1717',
        timestamp: now,
        fingerprint: 'fp_transfer_1',
        ingestedAt: now,
      );
      await smsRepo.saveSms(rawSms);

      final transferTxn = ParsedTransaction(
        id: 'txn_transfer_1',
        rawSmsId: 'sms_transfer_1',
        type: TransactionType.transfer,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 50000.0,
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );
      await txnRepo.saveTransaction(transferTxn);

      final summary = await txnRepo.getFinancialSummary();

      expect(summary.totalExpense, equals(0.0),
          reason: 'Transfers must not count as expense');
      expect(summary.totalIncome, equals(0.0),
          reason: 'Transfers must not count as income');
    });

    test(
        '3. Invariant: Investment transfers are neutral asset allocation, not consumer expense',
        () async {
      final now = DateTime.now();

      final investTxn = ParsedTransaction(
        id: 'txn_invest_1',
        rawSmsId: 'raw_dummy',
        type: TransactionType.investmentTransfer,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 30000.0,
        payee: 'MUTUAL FUNDS ICCL',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      // Verify TransactionType.isNeutral
      expect(investTxn.type.isNeutral, isTrue);
      expect(investTxn.type.isExpense, isFalse);
    });

    test(
        '4. Invariant: FASTag wallet funding is neutral transfer, not toll expense',
        () async {
      final now = DateTime.now();

      final fundingTxn = ParsedTransaction(
        id: 'txn_fastag_fund_1',
        rawSmsId: 'raw_dummy',
        type: TransactionType.fastagFunding,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 1000.0,
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      expect(fundingTxn.type.isNeutral, isTrue);
      expect(fundingTxn.type.isExpense, isFalse);
    });

    test(
        '5. Invariant: Card utilization is null (Unknown) when totalLimit is absent, NEVER false 0%',
        () {
      final cardWithoutTotalLimit = CreditCard(
        id: 'card_test_1',
        bank: Bank.sbi,
        last4: '7036',
        availableLimit: 372000.27,
        totalLimit: null, // Unknown!
        outstanding: null,
        lastUpdated: DateTime.now(),
      );

      // Must be null, never 0.0!
      expect(cardWithoutTotalLimit.utilizationPercentage, isNull,
          reason: 'Utilization must be null when total limit is unknown');

      final cardWithTotalLimit = CreditCard(
        id: 'card_test_2',
        bank: Bank.axis,
        last4: '9478',
        availableLimit: 400000.0,
        totalLimit: 500000.0,
        lastUpdated: DateTime.now(),
      );

      expect(cardWithTotalLimit.utilizationPercentage, equals(20.0));
    });
  });
}
