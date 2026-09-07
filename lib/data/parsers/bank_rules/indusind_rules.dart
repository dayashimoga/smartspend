import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class IndusindRules extends BankRule {
  @override
  Bank get targetBank => Bank.indusind;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. IndusInd Reversal / Refund (Multi-Currency e.g. USD / INR)
    // "Dear Customer, txn on IndusInd Bank Credit Card ending 4351 for USD 10.00 AT Github, inc. has been reversed/credited - IndusInd Bank"
    final reverseMatch = RegExp(
      r'txn\s+on\s+IndusInd\s+Bank\s+Credit\s+Card\s+ending\s+[Xx*]*(\d{4})\s+for\s+([A-Z]{3}|Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+(?:AT|at)\s+(.+?)\s+has\s+been\s+(reversed|credited)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (reverseMatch != null) {
      final cardLast4 = reverseMatch.group(1);
      final rawCurr = reverseMatch.group(2)?.trim() ?? 'INR';
      final currency = rawCurr.startsWith('Rs') ? 'INR' : rawCurr;
      final amount = AmountParser.parse(reverseMatch.group(3)) ?? 0.0;
      final merchant = reverseMatch.group(4)?.trim();

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.reversal,
        bank: Bank.indusind,
        cardLast4: cardLast4,
        amount: amount,
        currency: currency,
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Refund & Reversal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. Regular IndusInd Card Spend
    // "INR 2,499.00 spent on IndusInd Bank Card XX7731 on 10-Jan-26 at Croma. Avl Lmt: INR 1,42,500.00"
    final spentMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+IndusInd\s+Bank\s+Card\s+XX(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\s+at\s+(.+?)(?:\.|\s+Avl\s+Lmt|$)',
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
        bank: Bank.indusind,
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
