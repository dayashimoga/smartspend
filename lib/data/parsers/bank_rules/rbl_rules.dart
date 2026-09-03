import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class RblRules extends BankRule {
  @override
  Bank get targetBank => Bank.rbl;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. RBL Credit Card Bill Statement / Payment Due
    // "Important! Your payment for RBL Bank Credit Card XXXXXXXXXXXXXXX4223 is due on 11-Aug-2022. Total Amount due is Rs. 1758.91. Please make a payment for Minimum Amount Due of Rs. 200..."
    final billMatch = RegExp(
      r'payment\s+for\s+RBL\s+Bank\s+Credit\s+Card\s+[X*x]+(\d{4})\s+is\s+due\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4}).*?Total\s+Amount\s+due\s+is\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?(?:Minimum\s+Amount\s+Due\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatch != null) {
      final cardLast4 = billMatch.group(1);
      final dueDate = DateParser.parse(billMatch.group(2));
      final total = AmountParser.parse(billMatch.group(3)) ?? 0.0;

      double minDue = 0.0;
      final minMatch = RegExp(
        r'Min(?:imum)?\s+Amount\s+Due\s+(?:of|is)\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.rbl,
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

    // 2. Generic RBL Statement
    final genericBillMatch = RegExp(
      r'(?:Statement\s+for\s+RBL\s+Credit\s+Card|RBL\s+Bank\s+Credit\s+Card).*?(?:[Xx*]+|ending\s*)?(\d{4}).*?Total\s+due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?(?:Min(?:imum)?\s+due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?.*?due\s+(?:on|by)\s*:?\s*([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (genericBillMatch != null) {
      final cardLast4 = genericBillMatch.group(1);
      final total = AmountParser.parse(genericBillMatch.group(2)) ?? 0.0;
      final dueDate = DateParser.parse(genericBillMatch.group(4));

      double minDue = 0.0;
      final minMatch = RegExp(
        r'Min(?:imum)?\s+(?:due|Amount\s+Due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.rbl,
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

    // 3. RBL Card Spend / Purchase
    // "Spent INR 1500 on RBL Bank Credit Card ending 4223 at Amazon on 10-Jan-26. Avl Limit: INR 50000"
    final spendMatch = RegExp(
      r'(?:Spent|Txn\s+of)\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+on\s+RBL\s+Bank\s+(?:Credit\s+)?Card\s+(?:ending|no\.?|[Xx*]+)?\s*(\d{4})\s+(?:at|to)\s+([A-Za-z0-9\s&._-]+?)\s+on\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spendMatch != null) {
      final amount = AmountParser.parse(spendMatch.group(1)) ?? 0.0;
      final cardLast4 = spendMatch.group(2);
      final merchant = spendMatch.group(3)?.trim();
      final txnDate = DateParser.parse(spendMatch.group(4)) ?? smsTimestamp;

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.rbl,
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

    return null;
  }
}
