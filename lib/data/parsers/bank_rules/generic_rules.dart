import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class GenericRules extends BankRule {
  @override
  Bank get targetBank => Bank.unknown;

  @override
  bool canHandle(Bank bank, String body) => true;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. Amount Extraction
    final amtMatch = RegexPatterns.amountGeneric.firstMatch(normalizedBody);
    if (amtMatch == null) return null;
    final amount = AmountParser.parse(amtMatch.group(1));
    if (amount == null || amount <= 0) return null;

    // 2. Classify Type
    final lower = normalizedBody.toLowerCase();
    TransactionType type = TransactionType.unknown;
    if (lower.contains('salary') || lower.contains('payroll')) {
      type = TransactionType.salary;
    } else if (lower.contains('atm') ||
        lower.contains('withdrawn') ||
        lower.contains('cash')) {
      type = TransactionType.atm;
    } else if (lower.contains('upi') || lower.contains('vpa')) {
      type = TransactionType.upi;
    } else if (lower.contains('toll paid') || lower.contains('fastag')) {
      type = TransactionType.fastag;
    } else if (lower.contains('debited') ||
        lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('deducted')) {
      type = TransactionType.debit;
    } else if (lower.contains('spent')) {
      type = TransactionType.purchase;
    } else if (lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('received')) {
      type = TransactionType.credit;
    } else if (lower.contains('cashback')) {
      type = TransactionType.cashback;
    } else if (lower.contains('refund')) {
      type = TransactionType.refund;
    }

    // 3. Card or Account Last 4
    final cardMatch = RegexPatterns.cardLast4.firstMatch(normalizedBody);
    final acctMatch = RegexPatterns.accountLast4.firstMatch(normalizedBody);
    final cardLast4 = cardMatch?.group(1);
    final acctLast4 = acctMatch?.group(1);

    // 4. Balances / Limits
    final balMatch = RegexPatterns.availableBalance.firstMatch(normalizedBody);
    final balance =
        balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

    final limitMatch = RegexPatterns.availableLimit.firstMatch(normalizedBody);
    final avlLimit =
        limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

    // 5. Reference
    final refMatch = RegexPatterns.referenceNumber.firstMatch(normalizedBody);
    final ref = refMatch?.group(1);

    // 6. Contextual Merchant
    String? merchant;
    final merchantMatch = RegExp(
            r'(?:at|on|to)\s+([A-Za-z0-9\s&._-]+?)(?:\s+on|\s+at|\s+Ref|\s+Bal|\.|$)',
            caseSensitive: false)
        .firstMatch(normalizedBody);
    if (merchantMatch != null) {
      final cand = merchantMatch.group(1)?.trim();
      if (cand != null &&
          cand.length >= 2 &&
          cand.length <= 40 &&
          !cand.toLowerCase().startsWith('your') &&
          !cand.toLowerCase().startsWith('the')) {
        merchant = cand;
      }
    }

    // Determine confidence
    final hasIdentifier = cardLast4 != null || acctLast4 != null;
    final hasType = type != TransactionType.unknown;
    final confidence =
        (hasIdentifier && hasType) ? Confidence.medium : Confidence.low;

    return ParsedTransaction(
      id: const Uuid().v4(),
      rawSmsId: rawSmsId,
      type: type,
      bank: Bank.unknown,
      accountLast4: acctLast4,
      cardLast4: cardLast4,
      amount: amount,
      currency: 'INR',
      transactionDate: smsTimestamp,
      merchant: merchant,
      balance: balance,
      availableLimit: avlLimit,
      reference: ref,
      confidence: confidence,
      parserVersion: '1.0.0',
      category: type.isIncome ? 'Income' : 'General',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
