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
    // 1. ICICI Card Purchase
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
        merchant: merchant,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Shopping',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. ICICI Credit Card Bill Statement
    // "ICICI Bank Credit Card XX4000... Total of Rs 3,494.78 or minimum of Rs 180.00 is due by 05-FEB-26."
    final billMatch = RegExp(
      r'Credit\s+Card\s+XX(\d{4})\s+Total\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+or\s+minimum\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due\s+by\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
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
        billTotal: total,
        billMinimum: minDue,
        billDueDate: dueDate,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Bills & Utilities',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
