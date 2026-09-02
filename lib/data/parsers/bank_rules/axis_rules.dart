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
    // 1. Axis Card Spent
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
        merchant: merchant,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Food & Dining',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
