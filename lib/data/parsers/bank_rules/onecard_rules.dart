import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class OnecardRules extends BankRule {
  @override
  Bank get targetBank => Bank.onecard;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // "INR 1,840.00 spent on your SIB OneCard ending 9012 at BookMyShow on 02-Feb-26. Avl Limit: INR 88,160.00."
    final spentMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+your\s+(?:SIB\s+)?OneCard\s+ending\s+(\d{4})\s+at\s+(.+?)\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spentMatch != null) {
      final amount = AmountParser.parse(spentMatch.group(1)) ?? 0.0;
      final cardLast4 = spentMatch.group(2);
      final merchant = spentMatch.group(3)?.trim();
      final txnDate = DateParser.parse(spentMatch.group(4)) ?? smsTimestamp;

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.onecard,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        merchant: merchant,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Entertainment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
