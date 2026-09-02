import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class HsbcRules extends BankRule {
  @override
  Bank get targetBank => Bank.hsbc;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. HSBC Credit Card Bill statement
    // Example: "HSBC Credit Card ending 0741 : Total amount is 955.9 and minimum amount is 100 ; payable by 30-Jan-26."
    final billMatch = RegExp(
      r'HSBC\s+Credit\s+Card\s+ending\s+(\d{4})\s*:\s*Total\s+amount\s+is\s+([\d,]+(?:\.\d+)?)\s+and\s+minimum\s+amount\s+is\s+([\d,]+(?:\.\d+)?)\s*;\s*payable\s+by\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
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
        bank: Bank.hsbc,
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

    // 2. Generic HSBC card purchase / debit
    final cardMatch = RegexPatterns.cardLast4.firstMatch(normalizedBody);
    final amtMatch = RegexPatterns.amountPrefix.firstMatch(normalizedBody);
    if (amtMatch != null) {
      final amt = AmountParser.parse(amtMatch.group(1)) ?? 0.0;
      final cardLast4 = cardMatch?.group(1);
      final isDebit = RegexPatterns.debitKeywords.hasMatch(normalizedBody);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isDebit ? TransactionType.purchase : TransactionType.credit,
        bank: Bank.hsbc,
        cardLast4: cardLast4,
        amount: amt,
        transactionDate: smsTimestamp,
        confidence: Confidence.medium,
        parserVersion: '1.0.0',
        category: 'Shopping',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
