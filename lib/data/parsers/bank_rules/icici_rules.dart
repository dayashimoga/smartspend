import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class IciciRules extends BankRule {
  @override
  Bank get targetBank => Bank.icici;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. ICICI Card Credited / Refunded
    // "ICICI Bank Credit Card XX4000 credited/refunded with Rs 190.30 on 16-JUL-25. To transfer, call Customer Care..."
    // "ICICI Bank Credit Card XX4000 credited/refunded with Rs 1,137.50 on 15-AUG-25."
    final refundMatch = RegExp(
      r'ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4})\s+credited/refunded\s+with\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (refundMatch != null) {
      final cardLast4 = refundMatch.group(1);
      final amount = AmountParser.parse(refundMatch.group(2)) ?? 0.0;
      final txnDate = DateParser.parse(refundMatch.group(3)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.refund,
        bank: Bank.icici,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Refund',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. Merchant Specific Card Refund
    // "AMAZON PAY IN E COMMERC refund of Rs 1,493.89 credited to ICICI Bank Credit Card XX4000 on 01-NOV-25. Revised total due Rs 0, minimum due Rs .00"
    final merchantRefundMatch = RegExp(
      r'(.+?)\s+refund\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+credited\s+to\s+ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})(?:.*?Revised\s+total\s+due\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (merchantRefundMatch != null) {
      final merchant = merchantRefundMatch.group(1)?.trim();
      final amount = AmountParser.parse(merchantRefundMatch.group(2)) ?? 0.0;
      final cardLast4 = merchantRefundMatch.group(3);
      final txnDate =
          DateParser.parse(merchantRefundMatch.group(4)) ?? smsTimestamp;
      final revisedTotal = AmountParser.parse(merchantRefundMatch.group(5));

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.refund,
        bank: Bank.icici,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        billTotal: revisedTotal,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Refund',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. Card Payment Received (BBPS / Direct)
    // "Payment of Rs 6,306.02 has been received on your ICICI Bank Credit Card XX4000 through Bharat Bill Payment System on 28-NOV-25."
    final paymentMatch = RegExp(
      r'Payment\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+received\s+on\s+your\s+ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4}).*?on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
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
        bank: Bank.icici,
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

    // 4. ICICI Card Purchase
    // "INR 483.40 spent using ICICI Bank Card XX4000 on 18-Jan-26 on AMAZON PAY IN E. Avl Limit: INR 1,96,021.82."
    final spentMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+spent\s+(?:using\s+)?ICICI\s+Bank\s+Card\s+XX(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\s+(?:on|at)\s+(.+?)(?:\.|\s+Avl\s+Limit|$)',
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
        bank: Bank.icici,
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

    // 5. ICICI Credit Card Bill Statement
    // "ICICI Bank Credit Card XX4000... Total of Rs 3,494.78 or minimum of Rs 180.00 is due by 05-FEB-26."
    final billMatch = RegExp(
      r'Credit\s+Card\s+XX(\d{4}).*?Total\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+or\s+minimum\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due\s+by\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatch != null) {
      final cardLast4 = billMatch.group(1);
      final total = AmountParser.parse(billMatch.group(2)) ?? 0.0;
      final minDue = AmountParser.parse(billMatch.group(3)) ?? 0.0;
      final dueDate = DateParser.parse(billMatch.group(4));

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.icici,
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

    return null;
  }
}
