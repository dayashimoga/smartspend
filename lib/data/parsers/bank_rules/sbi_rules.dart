import 'package:uuid/uuid.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class SbiRules extends BankRule {
  @override
  Bank get targetBank => Bank.sbi;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. SBI Credit Card Spent
    // "Rs.3,676.00 spent on your SBI Credit Card ending 7036 at FlipkartInternetPvt on 30/11/25."
    final spentMatch = RegExp(
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+your\s+SBI\s+Credit\s+Card\s+ending\s+(\d{4})\s+at\s+(.+?)\s+on\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spentMatch != null) {
      final amount = AmountParser.parse(spentMatch.group(1)) ?? 0.0;
      final cardLast4 = spentMatch.group(2);
      final merchant = spentMatch.group(3)?.trim();
      final txnDate = DateParser.parse(spentMatch.group(4)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.sbi,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        merchant: merchant,
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
