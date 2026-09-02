import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class IdfcFirstRules extends BankRule {
  @override
  Bank get targetBank => Bank.idfcFirst;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. IDFC Account Debited
    // "Your A/c XX1717 debited by Rs.30,000.00 on 21/01/26... Available balance Rs.5,38,908.98. Team IDFC FIRST Bank"
    final debitMatch = RegExp(
      r'A/c\s+XX(\d{4})\s+debited\s+by\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (debitMatch != null) {
      final acctLast4 = debitMatch.group(1);
      final amount = AmountParser.parse(debitMatch.group(2)) ?? 0.0;
      final txnDate = DateParser.parse(debitMatch.group(3)) ?? smsTimestamp;

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.debit,
        bank: Bank.idfcFirst,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Transfers & Payments',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
