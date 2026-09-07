import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class AxisRules extends BankRule {
  @override
  Bank get targetBank => Bank.axis;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. Axis Credit Card Statement (Format A: "Statement for your Axis Bank Credit Card XX9478 of INR 9732.47 has been generated with due date 05-07-25... Minimum amount due is INR 195.")
    final billMatchA = RegExp(
      r'Statement\s+for\s+your\s+Axis\s+Bank\s+Credit\s+Card\s+(?:no\.?\s*)?[Xx*]*(\d{4})\s+of\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+generated\s+with\s+due\s+date\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}).*?(?:Minimum\s+amount\s+due\s+is\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchA != null) {
      final cardLast4 = billMatchA.group(1);
      final total = AmountParser.parse(billMatchA.group(2)) ?? 0.0;
      final dueDate = DateParser.parse(billMatchA.group(3));

      double minDue = 0.0;
      final minMatch = RegExp(
        r'(?:Min(?:imum)?\s+(?:amt\s+due|amount\s+due|due\s+amt|due))\s*(?:is|:)?\s*(?:INR|Rs\.?)?\s*(?:Dr\.?|Cr\.?)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.axis,
        cardLast4: cardLast4,
        amount: total,
        currency: 'INR',
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        billTotal: total,
        billMinimum: minDue,
        billDueDate: dueDate,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Bill',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 1b. Axis Credit Card Statement (Format B: "Statement for your Axis Bank Credit Card no. XX3345 has been generated. Due on: 03-10-25 Total amt: INR Dr. 1180.00 Min amt due: INR Dr. 1180.00")
    final billMatchB = RegExp(
      r'Statement\s+for\s+your\s+Axis\s+Bank\s+Credit\s+Card\s+no\.?\s+[Xx*]*(\d{4})\s+has\s+been\s+generated.*?(?:Due\s+on|Due\s+date)\s*:?\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}).*?Total\s+amt\s*:?\s*(?:INR|Rs\.?)?\s*(?:Dr\.?|Cr\.?)?\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchB != null) {
      final cardLast4 = billMatchB.group(1);
      final dueDate = DateParser.parse(billMatchB.group(2));
      final total = AmountParser.parse(billMatchB.group(3)) ?? 0.0;

      double minDue = 0.0;
      final minMatch = RegExp(
        r'(?:Min(?:imum)?\s+(?:amt\s+due|amount\s+due|due\s+amt|due))\s*(?:is|:)?\s*(?:INR|Rs\.?)?\s*(?:Dr\.?|Cr\.?)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.axis,
        cardLast4: cardLast4,
        amount: total,
        currency: 'INR',
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        billTotal: total,
        billMinimum: minDue,
        billDueDate: dueDate,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Bill',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. Axis Credit Card Payment Received
    // "Payment of INR 62194 has been received towards your Axis Bank Credit Card XX9478 on 29-10-25 - Axis Bank"
    final paymentMatch = RegExp(
      r'Payment\s+of\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+received\s+towards\s+your\s+Axis\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (paymentMatch != null) {
      final amount = AmountParser.parse(paymentMatch.group(1)) ?? 0.0;
      final cardLast4 = paymentMatch.group(2);
      final txnDate = DateParser.parse(paymentMatch.group(3)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.billPayment,
        bank: Bank.axis,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Payment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. Axis Cashback Credited
    // "Congratulations! Cashback of INR 295 has been credited to your Axis Bank Flipkart Credit Card XX9478 towards your last month spends - Axis Bank"
    final cashbackMatch = RegExp(
      r'Cashback\s+of\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+credited\s+to\s+your\s+Axis\s+Bank.*?Credit\s+Card\s+[Xx*]*(\d{4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (cashbackMatch != null) {
      final amount = AmountParser.parse(cashbackMatch.group(1)) ?? 0.0;
      final cardLast4 = cashbackMatch.group(2);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.cashback,
        bank: Bank.axis,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Cashback & Rewards',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 4. Axis Card Spent
    // "Spent INR 320 Axis Bank Card no. XX9478 08-09-25 09:55:45 IST Reliance Re Avl Limit: INR 495864.75"
    // "Spent INR 560.2 Axis Bank Card no. XX0449 27-09-25 19:54:30 IST ZOMATO Avl Limit: INR 434142.32"
    final spentMatch = RegExp(
      r'Spent\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+Axis\s+Bank\s+Card\s+no\.?\s+XX(\d{4})\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\s+[0-9]{2}:[0-9]{2}:[0-9]{2})(?:\s+IST)?\s+(.+?)(?:\s+Avl\s+Limit|$)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spentMatch != null) {
      final amount = AmountParser.parse(spentMatch.group(1)) ?? 0.0;
      final cardLast4 = spentMatch.group(2);
      final txnDate = DateParser.parse(spentMatch.group(3)) ?? smsTimestamp;
      final merchant = spentMatch.group(4)?.trim();

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.axis,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Shopping',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 5. Axis Bank Account Debit / Card Payment
    // "Rs. 3,000.00 debited from Axis Bank A/c no. XX1234 on 16-01-26 for Card Payment Ref 222222."
    final debitMatch = RegExp(
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+debited\s+from\s+Axis\s+Bank\s+A/c\s*(?:no\.?\s*)?[Xx*]*(\d{4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (debitMatch != null) {
      final amount = AmountParser.parse(debitMatch.group(1)) ?? 0.0;
      final acctLast4 = debitMatch.group(2);

      final dateMatch = RegExp(r'on\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
              caseSensitive: false)
          .firstMatch(normalizedBody);
      final txnDate = dateMatch != null
          ? DateParser.parse(dateMatch.group(1)) ?? smsTimestamp
          : smsTimestamp;

      final isCardPayment =
          normalizedBody.toLowerCase().contains('card payment') ||
              normalizedBody.toLowerCase().contains('credit card') ||
              normalizedBody.toLowerCase().contains('cred');

      final refMatch = RegexPatterns.referenceNumber.firstMatch(normalizedBody);
      final ref = refMatch?.group(1);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type:
            isCardPayment ? TransactionType.billPayment : TransactionType.debit,
        bank: Bank.axis,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isCardPayment ? 'Credit Card Payment' : 'General Debit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
