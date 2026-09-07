import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/bank_rules/axis_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/generic_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/hdfc_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/icici_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/kotak_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/rbl_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/sbi_rules.dart';
import 'package:smartspend/data/parsers/merchant_normalizer.dart';
import 'package:smartspend/data/parsers/parser_pipeline.dart';
import 'package:smartspend/data/parsers/reconciler.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  group('KotakRules Unit Tests', () {
    final rule = KotakRules();
    final now = DateTime(2026, 2, 1);

    test('canHandle detects Kotak Bank', () {
      expect(rule.canHandle(Bank.kotak, 'Kotak Bank SMS'), isTrue);
      expect(rule.canHandle(Bank.hdfc, 'Kotak Bank SMS'), isFalse);
    });

    test('Parses Kotak credit card bill statement', () {
      const sms =
          'Statement for your Kotak Credit Card ending 5432. Total Due: Rs. 12,450.00, Min Due: Rs. 620.00, Due Date: 15-02-2026.';
      final parsed = rule.parse(
        rawSmsId: 'sms_kotak_bill',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.kotak));
      expect(parsed.cardLast4, equals('5432'));
      expect(parsed.amount, equals(12450.0));
      expect(parsed.billTotal, equals(12450.0));
      expect(parsed.billMinimum, equals(620.0));
    });

    test('Parses Kotak credit card spend', () {
      const sms =
          'Spent Rs. 1,499.00 on Kotak Bank Card 5432 at Reliance Digital on 02-02-2026. Avl Limit: Rs. 88,500.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_kotak_spend',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.purchase));
      expect(parsed.bank, equals(Bank.kotak));
      expect(parsed.cardLast4, equals('5432'));
      expect(parsed.amount, equals(1499.0));
      expect(parsed.merchant, equals('Reliance Digital'));
      expect(parsed.availableLimit, equals(88500.0));
    });

    test('Parses Kotak bank account debit', () {
      const sms =
          'Rs. 2,000.00 debited from Kotak Bank A/c 9876 on 03-02-2026. Bal Rs. 45,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_kotak_debit',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.debit));
      expect(parsed.bank, equals(Bank.kotak));
      expect(parsed.accountLast4, equals('9876'));
      expect(parsed.amount, equals(2000.0));
      expect(parsed.balance, equals(45000.0));
    });

    test('Returns null for unrelated text', () {
      final parsed = rule.parse(
        rawSmsId: 'sms_none',
        rawBody: 'Welcome to Kotak Bank promo',
        normalizedBody: 'Welcome to Kotak Bank promo',
        smsTimestamp: now,
      );
      expect(parsed, isNull);
    });
  });

  group('RblRules Unit Tests', () {
    final rule = RblRules();
    final now = DateTime(2026, 2, 1);

    test('canHandle detects RBL Bank', () {
      expect(rule.canHandle(Bank.rbl, 'RBL Bank SMS'), isTrue);
      expect(rule.canHandle(Bank.axis, 'RBL Bank SMS'), isFalse);
    });

    test('Parses generic RBL statement', () {
      const sms =
          'Statement for RBL Credit Card ending 4223. Total due Rs. 3,500.00, Min due Rs. 250.00 due on 15-08-2022.';
      final parsed = rule.parse(
        rawSmsId: 'sms_rbl_gen_bill',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.rbl));
      expect(parsed.cardLast4, equals('4223'));
      expect(parsed.amount, equals(3500.0));
      expect(parsed.billMinimum, equals(250.0));
    });

    test('Parses RBL card spend', () {
      const sms =
          'Spent Rs. 850.00 on RBL Bank Card ending 4223 at Dominos on 05-08-2022. Avl Limit: Rs. 45,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_rbl_spend',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.purchase));
      expect(parsed.bank, equals(Bank.rbl));
      expect(parsed.cardLast4, equals('4223'));
      expect(parsed.amount, equals(850.0));
      expect(parsed.merchant, equals('Dominos'));
      expect(parsed.availableLimit, equals(45000.0));
    });
  });

  group('MerchantNormalizer Unit Tests', () {
    test('Canonicalizes various merchant spellings and assigns categories', () {
      final now = DateTime.now();
      final txnAmazon = ParsedTransaction(
        id: '1',
        rawSmsId: 'raw_1',
        type: TransactionType.purchase,
        bank: Bank.icici,
        amount: 500.0,
        merchant: 'AMAZON PAY IN E COMMERC',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final normalized = MerchantNormalizer.normalize(txnAmazon);
      expect(normalized.category, equals('Shopping'));

      final txnFood = ParsedTransaction(
        id: '2',
        rawSmsId: 'raw_2',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        amount: 350.0,
        merchant: 'SWIGGY BANGALORE',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final normFood = MerchantNormalizer.normalize(txnFood);
      expect(normFood.category, equals('Food & Dining'));
    });
  });

  group('Reconciler Extended Suite', () {
    test('reconcileSingle detects FASTag wallet funding and investment SIPs',
        () {
      final now = DateTime.now();

      final fastagDebit = ParsedTransaction(
        id: 'fastag_1',
        rawSmsId: 'raw_fastag',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        amount: 500.0,
        merchant: 'NETC FASTAG RECHARGE',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final resFastag = Reconciler.reconcileSingle(fastagDebit, []);
      expect(
          resFastag.updatedCurrent.type, equals(TransactionType.fastagFunding));

      final sipDebit = ParsedTransaction(
        id: 'sip_1',
        rawSmsId: 'raw_sip',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        amount: 5000.0,
        payee: 'GROWW MUTUAL FUND SIP',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final resSip = Reconciler.reconcileSingle(sipDebit, []);
      expect(resSip.updatedCurrent.type,
          equals(TransactionType.investmentTransfer));
    });

    test('reconcileBill marks bills noPaymentRequired when amount <= 0', () {
      final zeroBill = Bill(
        id: 'b1',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 0.0,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        status: BillStatus.unpaid,
        createdAt: DateTime.now(),
      );

      final reconciled = Reconciler.reconcileBill(zeroBill);
      expect(reconciled.status, equals(BillStatus.noPaymentRequired));
    });
  });

  group('HdfcRules Unit Tests', () {
    final rule = HdfcRules();
    final now = DateTime(2026, 9, 7, 10, 0);

    test('Parses HDFC RuPay / Card UPI spend transaction', () {
      const sms = '''Txn Rs.124.00
On HDFC Bank Card 9137
At sbibhim.instant9284450021 
by UPI 661600456771
On 07-09
Not You?
Call 18002586161/SMS BLOCK CC 9137 to 7308080808''';

      final parsed = rule.parse(
        rawSmsId: 'sms_hdfc_card_upi',
        rawBody: sms,
        normalizedBody:
            'Txn Rs.124.00 On HDFC Bank Card 9137 At sbibhim.instant9284450021 by UPI 661600456771 On 07-09 Not You? Call 18002586161/SMS BLOCK CC 9137 to 7308080808',
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.hdfc));
      expect(parsed.cardLast4, equals('9137'));
      expect(parsed.amount, equals(124.0));
      expect(parsed.merchant, equals('sbibhim.instant9284450021'));
      expect(parsed.upiRef, equals('661600456771'));
      expect(parsed.transactionDate.year, equals(2026));
      expect(parsed.transactionDate.month, equals(9));
      expect(parsed.transactionDate.day, equals(7));
      expect(parsed.type.isExpense, isTrue);
      expect(parsed.confidence, equals(Confidence.high));
    });

    test('Parses HDFC Account balance notification', () {
      const sms =
          'Available Bal in HDFC Bank A/c XX0564 as on yesterday:06-SEP-26 is INR 56,473.36. Cheques are subject to clearing.For updated A/C Bal dial 18002703333.';

      final parsed = rule.parse(
        rawSmsId: 'sms_hdfc_balance',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.hdfc));
      expect(parsed.accountLast4, equals('0564'));
      expect(parsed.balance, equals(56473.36));
      expect(parsed.amount, equals(0.0));
      expect(parsed.transactionDate.year, equals(2026));
      expect(parsed.transactionDate.month, equals(9));
      expect(parsed.transactionDate.day, equals(6));
      expect(parsed.confidence, equals(Confidence.high));
      expect(parsed.category, equals('Account Balance'));
    });

    test('Parses HDFC credit card statement with text month and ending 9137',
        () {
      const sms =
          'Statement for your HDFC Bank Credit Card ending 9137 has been generated. Total Amt Due: Rs 15,400.00, Min Amt Due: Rs 770.00, Due Date: 25-SEP-26.';

      final parsed = rule.parse(
        rawSmsId: 'sms_hdfc_bill_sep',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.hdfc));
      expect(parsed.cardLast4, equals('9137'));
      expect(parsed.billTotal, equals(15400.0));
      expect(parsed.billMinimum, equals(770.0));
      expect(parsed.billDueDate, isNotNull);
      expect(parsed.billDueDate!.month, equals(9));
      expect(parsed.billDueDate!.day, equals(25));
    });

    test('Parses HDFC payment due notice format', () {
      const sms =
          'Payment of Rs. 15,400.00 is due on your HDFC Bank Credit Card ending 9137 by 25-SEP-26. Min Due Rs. 770.00.';

      final parsed = rule.parse(
        rawSmsId: 'sms_hdfc_bill_notice',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.hdfc));
      expect(parsed.cardLast4, equals('9137'));
      expect(parsed.billTotal, equals(15400.0));
      expect(parsed.billDueDate, isNotNull);
    });

    test('ParserPipeline handles full end-to-end HDFC SMS parsing', () {
      final pipeline = ParserPipeline();

      // Test 1: Today's transaction
      const txnSms = '''Txn Rs.124.00
On HDFC Bank Card 9137
At sbibhim.instant9284450021 
by UPI 661600456771
On 07-09
Not You?
Call 18002586161/SMS BLOCK CC 9137 to 7308080808''';

      final parsedTxn = pipeline.parseSms(
        rawSmsId: 'sms_1',
        sender: 'AD-HDFCBK',
        rawBody: txnSms,
        timestamp: now,
      );

      expect(parsedTxn.bank, equals(Bank.hdfc));
      expect(parsedTxn.cardLast4, equals('9137'));
      expect(parsedTxn.amount, equals(124.0));
      expect(parsedTxn.type.isExpense, isTrue);

      // Test 2: Today's balance
      const balSms =
          'Available Bal in HDFC Bank A/c XX0564 as on yesterday:06-SEP-26 is INR 56,473.36. Cheques are subject to clearing.For updated A/C Bal dial 18002703333.';

      final parsedBal = pipeline.parseSms(
        rawSmsId: 'sms_2',
        sender: 'AD-HDFCBK',
        rawBody: balSms,
        timestamp: now,
      );

      expect(parsedBal.bank, equals(Bank.hdfc));
      expect(parsedBal.accountLast4, equals('0564'));
      expect(parsedBal.balance, equals(56473.36));
      expect(parsedBal.confidence, equals(Confidence.high));
    });
  });

  group('GenericRules Unit Tests', () {
    final rule = GenericRules();
    final now = DateTime(2026, 9, 7, 10, 0);

    test('Parses generic credit card statement into TransactionType.bill', () {
      const sms =
          'Statement for your Credit Card ending 1234: Total Due Rs 8,500.00, Min Due Rs 425.00, Due Date 22-09-2026.';

      final parsed = rule.parse(
        rawSmsId: 'sms_gen_bill',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.cardLast4, equals('1234'));
      expect(parsed.billTotal, equals(8500.0));
      expect(parsed.billMinimum, equals(425.0));
      expect(parsed.billDueDate, isNotNull);
      expect(parsed.confidence, equals(Confidence.high));
    });

    test('Parses generic pure balance alert with account and balance', () {
      const sms =
          'Available balance in A/c XX9988 as on 07-09-2026 is INR 34,250.50.';

      final parsed = rule.parse(
        rawSmsId: 'sms_gen_bal',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.accountLast4, equals('9988'));
      expect(parsed.balance, equals(34250.50));
      expect(parsed.amount, equals(0.0));
      expect(parsed.confidence, equals(Confidence.high));
    });
  });

  group('IciciRules Multi-Format Tests', () {
    final rule = IciciRules();
    final now = DateTime(2026, 9, 7, 10, 0);

    test('Parses ICICI credit card bill statement format B', () {
      const sms =
          'Total amount due on your ICICI Bank Credit Card XX4000 is Rs 3,494.78 payable by 05-FEB-26. Min due Rs 180.';
      final parsed = rule.parse(
        rawSmsId: 'sms_icici_bill',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.icici));
      expect(parsed.cardLast4, equals('4000'));
      expect(parsed.billTotal, equals(3494.78));
      expect(parsed.billMinimum, equals(180.0));
    });

    test('Parses ICICI account debit with merchant & balance', () {
      const sms =
          'Dear Customer, ICICI Bank Account XX1234 has been debited for Rs 1,500.00 on 05-Sep-26. Info: UPI/321948/Swiggy. Avl Bal: INR 25,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_icici_debit',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.icici));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.amount, equals(1500.0));
      expect(parsed.balance, equals(25000.0));
      expect(parsed.merchant, contains('Swiggy'));
    });

    test('Parses ICICI account balance alert', () {
      const sms =
          'Dear Customer, the balance in your ICICI Bank Account XX1234 as on 06-SEP-26 is INR 45,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_icici_bal',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.unknown));
      expect(parsed.bank, equals(Bank.icici));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.balance, equals(45000.0));
      expect(parsed.amount, equals(0.0));
    });
  });

  group('SbiRules Multi-Format Tests', () {
    final rule = SbiRules();
    final now = DateTime(2026, 9, 7, 10, 0);

    test('Parses SBI Card bill reminder format', () {
      const sms =
          'Payment of Rs.15,400.00 is due on your SBI Card ending 7036 by 20/09/26. Min Amt Due Rs 770.';
      final parsed = rule.parse(
        rawSmsId: 'sms_sbi_bill',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(TransactionType.bill));
      expect(parsed.bank, equals(Bank.sbi));
      expect(parsed.cardLast4, equals('7036'));
      expect(parsed.billTotal, equals(15400.0));
      expect(parsed.billMinimum, equals(770.0));
    });

    test('Parses SBI account balance alert', () {
      const sms =
          'Available Balance in SBI A/c XX1234 as on 06-SEP-26 is INR 12,345.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_sbi_bal',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.sbi));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.balance, equals(12345.0));
      expect(parsed.amount, equals(0.0));
    });

    test('Parses SBI account debit with merchant & balance', () {
      const sms =
          'INR 500.00 debited from SBI A/c XX1234 on 05-SEP-26 to SWIGGY. Avl Bal INR 12,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_sbi_debit',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.sbi));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.amount, equals(500.0));
      expect(parsed.balance, equals(12000.0));
      expect(parsed.merchant, contains('SWIGGY'));
    });
  });

  group('AxisRules Multi-Format Tests', () {
    final rule = AxisRules();
    final now = DateTime(2026, 9, 7, 10, 0);

    test('Parses Axis account balance alert', () {
      const sms =
          'Bal in Axis Bank A/c no. XX1234 as on 06-SEP-26 is INR 15,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_axis_bal',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.axis));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.balance, equals(15000.0));
      expect(parsed.amount, equals(0.0));
    });

    test('Parses Axis account debit with merchant & balance', () {
      const sms =
          'INR 500.00 debited from Axis Bank A/c no. XX1234 on 05-09-26 to SWIGGY. Avl Bal INR 15,000.00.';
      final parsed = rule.parse(
        rawSmsId: 'sms_axis_debit',
        rawBody: sms,
        normalizedBody: sms,
        smsTimestamp: now,
      );

      expect(parsed, isNotNull);
      expect(parsed!.bank, equals(Bank.axis));
      expect(parsed.accountLast4, equals('1234'));
      expect(parsed.amount, equals(500.0));
      expect(parsed.balance, equals(15000.0));
      expect(parsed.merchant, contains('SWIGGY'));
    });
  });
}
