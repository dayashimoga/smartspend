import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/bank_rules/kotak_rules.dart';
import 'package:smartspend/data/parsers/bank_rules/rbl_rules.dart';
import 'package:smartspend/data/parsers/merchant_normalizer.dart';
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
}
