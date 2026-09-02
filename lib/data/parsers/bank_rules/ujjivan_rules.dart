import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class UjjivanRules extends BankRule {
  @override
  Bank get targetBank => Bank.ujjivan;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // "Dear Customer, INR 5,000.00 credited to your Ujjivan SFB A/c XX3344 on 05-01-2026 towards Interest. Avl Bal: INR 85,320.00"
    final creditMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+credited\s+to\s+your\s+Ujjivan\s+(?:SFB\s+)?A/c\s+XX(\d{4})\s+on\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (creditMatch != null) {
      final amount = AmountParser.parse(creditMatch.group(1)) ?? 0.0;
      final acctLast4 = creditMatch.group(2);
      final txnDate = DateParser.parse(creditMatch.group(3)) ?? smsTimestamp;

      final isInterest = normalizedBody.toLowerCase().contains('interest');
      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isInterest ? TransactionType.interest : TransactionType.credit,
        bank: Bank.ujjivan,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isInterest ? 'Interest' : 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
