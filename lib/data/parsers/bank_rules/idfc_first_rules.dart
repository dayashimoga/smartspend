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
    // 1. Monthly Interest Credit
    // "Monthly interest of Rs.518.00 earned on your Savings A/c XX1717 has been credited to your A/C on 31/12/25. New bal: Rs.2,05,528.98. IDFC FIRST Bank"
    final interestMatch = RegExp(
      r'Monthly\s+interest\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+earned\s+on\s+your\s+(?:Savings\s+)?A/c\s+[Xx*]*(\d{4,6})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (interestMatch != null) {
      final amount = AmountParser.parse(interestMatch.group(1)) ?? 0.0;
      final digits = interestMatch.group(2)!;
      final acctLast4 =
          digits.length > 4 ? digits.substring(digits.length - 4) : digits;

      final dateMatch = RegExp(
        r'credited\s+to\s+your\s+A/[Cc]\s+on\s+([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final txnDate = dateMatch != null
          ? DateParser.parse(dateMatch.group(1)) ?? smsTimestamp
          : smsTimestamp;

      double? balance;
      final balMatch = RegExp(
        r'New\s+bal(?:ance)?\s*(?:is)?:?\s*(?:INR|Rs\.?)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (balMatch != null) {
        balance = AmountParser.parse(balMatch.group(1));
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.interest,
        bank: Bank.idfcFirst,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Interest Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. Account Credited / Deposited
    // "Your A/C XXXXX501717 is credited with INR 53,380.00 on 06/01/26 16:03. Your new balance is INR 7,08,908.98. Team IDFC FIRST Bank"
    // "Your A/c XXXXXXX1717 has been credited with Rs. 100,000.00 on 02-10-2025. Info: NEFT/HDFCH00518940931/DAYANANDA T.New bal: Rs. 280,703.14."
    final creditMatch = RegExp(
      r'A/[Cc]\s+[Xx*]*(\d{4,6})\s+(?:is|has\s+been)?\s*credited\s+(?:with|for)?\s*(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (creditMatch != null) {
      final digits = creditMatch.group(1)!;
      final acctLast4 =
          digits.length > 4 ? digits.substring(digits.length - 4) : digits;
      final amount = AmountParser.parse(creditMatch.group(2)) ?? 0.0;

      final dateMatch = RegExp(
        r'on\s+([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}(?:\s+[0-9]{2}:[0-9]{2})?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final txnDate = dateMatch != null
          ? DateParser.parse(dateMatch.group(1)) ?? smsTimestamp
          : smsTimestamp;

      double? balance;
      final balMatch = RegExp(
        r'(?:New\s+bal(?:ance)?|new\s+balance)\s*(?:is)?:?\s*(?:INR|Rs\.?)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (balMatch != null) {
        balance = AmountParser.parse(balMatch.group(1));
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.credit,
        bank: Bank.idfcFirst,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. IDFC Account Debited
    // "Your A/c XX1717 debited by Rs.30,000.00 on 21/01/26... Available balance Rs.5,38,908.98. Team IDFC FIRST Bank"
    final debitMatch = RegExp(
      r'A/c\s+[Xx*]*(\d{4,6})\s+(?:is\s+)?debited\s+(?:by|with|for)\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (debitMatch != null) {
      final digits = debitMatch.group(1)!;
      final acctLast4 =
          digits.length > 4 ? digits.substring(digits.length - 4) : digits;
      final amount = AmountParser.parse(debitMatch.group(2)) ?? 0.0;

      final dateMatch = RegExp(
        r'on\s+([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final txnDate = dateMatch != null
          ? DateParser.parse(dateMatch.group(1)) ?? smsTimestamp
          : smsTimestamp;

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
        smsReceivedAt: smsTimestamp,
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
