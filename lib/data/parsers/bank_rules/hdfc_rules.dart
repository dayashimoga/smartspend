import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class HdfcRules extends BankRule {
  @override
  Bank get targetBank => Bank.hdfc;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. HDFC Credit Card Bill Statement
    // "HDFC Bank Credit Card XX9137 Statement: Total due amt: Rs.11,397.00 Min due amt: Rs.570.00 Due by:04-08-2025."
    final billMatch = RegExp(
      r'Credit\s+Card\s+XX(\d{4})\s+Statement\s*:\s*Total\s+due\s+amt\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+Min\s+due\s+amt\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+Due\s+by\s*:\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
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
        bank: Bank.hdfc,
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

    // 2. Salary / Credit Deposit
    // "Update! INR 93,807.00 deposited in HDFC Bank A/c XX0564 on 27-JUN-25 ... Salary... Avl bal INR 1,76,306.56."
    final depositMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+deposited\s+in\s+HDFC\s+Bank\s+A/c\s+XX(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (depositMatch != null) {
      final amount = AmountParser.parse(depositMatch.group(1)) ?? 0.0;
      final acctLast4 = depositMatch.group(2);
      final txnDate = DateParser.parse(depositMatch.group(3)) ?? smsTimestamp;

      final isSalary = normalizedBody.toLowerCase().contains('salary');
      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isSalary ? TransactionType.salary : TransactionType.credit,
        bank: Bank.hdfc,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isSalary ? 'Salary' : 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. Sent / Transfer Debit
    // "Sent Rs.30000.00 From HDFC Bank A/C *0564 To MUTUAL FUNDS ICCL On 21/01/26 Ref 638798306591"
    final sentMatch = RegExp(
      r'Sent\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+From\s+HDFC\s+Bank\s+A/C\s+\*?(\d{4})\s+To\s+(.+?)\s+On\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})\s+Ref\s+([a-zA-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (sentMatch != null) {
      final amount = AmountParser.parse(sentMatch.group(1)) ?? 0.0;
      final acctLast4 = sentMatch.group(2);
      final payee = sentMatch.group(3)?.trim();
      final txnDate = DateParser.parse(sentMatch.group(4)) ?? smsTimestamp;
      final ref = sentMatch.group(5);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.debit,
        bank: Bank.hdfc,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        payee: payee,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Investments',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 4. ATM / Card Withdrawal
    // "Withdrawn Rs.3000 From HDFC Bank Card x4617 At INDUSIND BANK LIMITED On 2026-01-04:22:44:25 Bal Rs.40643.25"
    final atmMatch = RegExp(
      r'Withdrawn\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+From\s+HDFC\s+Bank\s+Card\s+x?(\d{4})\s+At\s+(.+?)\s+On\s+([0-9]{4}-[0-9]{2}-[0-9]{2}:[0-9]{2}:[0-9]{2}:[0-9]{2})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (atmMatch != null) {
      final amount = AmountParser.parse(atmMatch.group(1)) ?? 0.0;
      final cardLast4 = atmMatch.group(2);
      final merchant = atmMatch.group(3)?.trim();
      final txnDate = DateParser.parse(atmMatch.group(4)) ?? smsTimestamp;

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.atm,
        bank: Bank.hdfc,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        merchant: merchant,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Cash & ATM',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 5. FASTag Alert / Added
    // "FASTag Alert Rs.100 added to HDFC Bank NETC FASTag 19000011559872 on 22-07-2025 19:42:12."
    final fastagMatch = RegExp(
      r'FASTag\s+Alert\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+added\s+to\s+HDFC\s+Bank\s+NETC\s+FASTag\s+([0-9]+)\s+on\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}\s+[0-9]{2}:[0-9]{2}:[0-9]{2})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (fastagMatch != null) {
      final amount = AmountParser.parse(fastagMatch.group(1)) ?? 0.0;
      final fastagId = fastagMatch.group(2);
      final txnDate = DateParser.parse(fastagMatch.group(3)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.fastag,
        bank: Bank.hdfc,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        fastagId: fastagId,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Transportation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
