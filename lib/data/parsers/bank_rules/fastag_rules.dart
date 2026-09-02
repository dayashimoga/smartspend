import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class FastagRules extends BankRule {
  @override
  Bank get targetBank => Bank.unknown;

  @override
  bool canHandle(Bank bank, String body) {
    final lower = body.toLowerCase();
    return lower.contains('toll paid') ||
        lower.contains('fastag') ||
        lower.contains('netc');
  }

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. Toll Paid! Rs.65 for KA05MS4053 At Rajatadripura On 2025-07-22 21:01:40 Wallet Bal: Rs.275
    final tollMatch = RegExp(
      r'Toll\s+Paid!?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+for\s+([A-Z0-9]+)\s+At\s+(.+?)\s+On\s+([0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (tollMatch != null) {
      final amount = AmountParser.parse(tollMatch.group(1)) ?? 0.0;
      final vehicle = tollMatch.group(2);
      final plaza = tollMatch.group(3)?.trim();
      final txnDate = DateParser.parse(tollMatch.group(4)) ?? smsTimestamp;

      final walletMatch =
          RegexPatterns.walletBalance.firstMatch(normalizedBody);
      final walletBal =
          walletMatch != null ? AmountParser.parse(walletMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.fastag,
        bank: Bank.unknown,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        vehicle: vehicle,
        tollPlaza: plaza,
        walletBalance: walletBal,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Toll & FASTag',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
