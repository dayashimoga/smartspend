import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
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
    final lower = normalizedBody.toLowerCase();

    // Guard: Pure Balance Alerts, Limit Updates, or Statements with no transaction event
    final hasTxnKeyword = lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('spent') ||
        lower.contains('withdrawn') ||
        lower.contains('deposited') ||
        lower.contains('sent') ||
        lower.contains('received') ||
        lower.contains('paid') ||
        lower.contains('deducted') ||
        lower.contains('cashback') ||
        lower.contains('refund') ||
        lower.contains('reversal') ||
        lower.contains('toll');

    final isPureBalanceOrStatement = !hasTxnKeyword &&
        (lower.contains('bal') ||
            lower.contains('balance') ||
            lower.contains('limit') ||
            lower.contains('statement'));

    if (isPureBalanceOrStatement) {
      // Return unparsed/informational record so balance/limit is NEVER counted as a spend transaction
      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.unknown,
        bank: Bank.unknown,
        amount: 0.0,
        currency: 'INR',
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.unparsed,
        parserVersion: '1.0.0',
        category: 'Informational Alert',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 1. Transaction Amount Extraction (Specifically avoiding balance/limit amounts)
    double? amount;
    String currency = 'INR';

    // Check for foreign currency transactions (e.g. USD 10.00, EUR 50)
    final foreignMatch = RegExp(
      r'\b(USD|EUR|GBP|AED|CAD|SGD|AUD)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (foreignMatch != null) {
      currency = foreignMatch.group(1)!.toUpperCase();
      amount = AmountParser.parse(foreignMatch.group(2));
    }

    if (amount == null || amount <= 0) {
      // Try targeted transaction amount regexes first
      final targetedMatches = [
        // "debited by/for/with Rs. X" or "credited with/by Rs. X"
        RegExp(
            r'(?:debited|credited|spent|withdrawn|sent|paid|refunded|cashback|deposited)\s+(?:by|for|with|of)?\s*(?:(?:Rs\.?|INR|₹)\s*|\b(?:INR|Rs\.?)\s*)([\d,]+(?:\.\d{1,2})?)',
            caseSensitive: false),
        // "INR X spent/debited/credited/paid"
        RegExp(
            r'(?:(?:Rs\.?|INR|₹)\s*|\b(?:INR|Rs\.?)\s*)([\d,]+(?:\.\d{1,2})?)\s+(?:spent|debited|credited|deposited|withdrawn|paid|deducted)',
            caseSensitive: false),
        // "Payment of Rs. X"
        RegExp(
            r'(?:Payment|Txn|Transaction)\s+(?:of\s+)?(?:(?:Rs\.?|INR|₹)\s*|\b(?:INR|Rs\.?)\s*)([\d,]+(?:\.\d{1,2})?)',
            caseSensitive: false),
        // Generic amount fallback
        RegexPatterns.amountGeneric,
      ];

      for (final r in targetedMatches) {
        final m = r.firstMatch(normalizedBody);
        if (m != null) {
          final cand = AmountParser.parse(m.group(1));
          if (cand != null && cand > 0) {
            amount = cand;
            break;
          }
        }
      }
    }

    if (amount == null || amount <= 0) return null;

    // 2. Classify Type
    TransactionType type = TransactionType.unknown;
    if (lower.contains('salary') || lower.contains('payroll')) {
      type = TransactionType.salary;
    } else if (lower.contains('interest') && lower.contains('credit')) {
      type = TransactionType.interest;
    } else if (lower.contains('atm') ||
        lower.contains('withdrawn') ||
        lower.contains('cash withdrawal')) {
      type = TransactionType.atm;
    } else if (lower.contains('toll paid') || lower.contains('fastag toll')) {
      type = TransactionType.fastag;
    } else if (lower.contains('cashback')) {
      type = TransactionType.cashback;
    } else if (lower.contains('refund') || lower.contains('reversed')) {
      type = TransactionType.refund;
    } else if (lower.contains('spent')) {
      type = TransactionType.purchase;
    } else if (lower.contains('debited') ||
        lower.contains('sent') ||
        lower.contains('paid') ||
        lower.contains('deducted')) {
      if (lower.contains('card payment') ||
          lower.contains('credit card payment') ||
          lower.contains('cred') ||
          lower.contains('cc payment')) {
        type = TransactionType.billPayment;
      } else {
        type = TransactionType.debit;
      }
    } else if (lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('received')) {
      type = TransactionType.credit;
    } else if (lower.contains('upi') || lower.contains('vpa')) {
      type = TransactionType.upi;
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

    // Critical Guard: If extracted amount is exactly identical to the balance and amount is large, reject misclassification
    if (balance != null &&
        (amount - balance).abs() < 0.01 &&
        !lower.contains('debited') &&
        !lower.contains('credited')) {
      return null;
    }

    // 5. Reference / UPI Ref
    final refMatch = RegexPatterns.referenceNumber.firstMatch(normalizedBody);
    final ref = refMatch?.group(1);

    // 6. Contextual Merchant / Payee
    String? merchant;
    final merchantMatch = RegExp(
            r'(?:at|to|from)\s+([A-Za-z0-9\s&._-]+?)(?:\s+on|\s+at|\s+from|\s+Ref|\s+Bal|\.|$)',
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

    // 7. Date extraction from text if available
    DateTime txnDate = smsTimestamp;
    final dateMatch = RegExp(
      r'\b([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\b',
    ).firstMatch(normalizedBody);
    if (dateMatch != null) {
      final parsedDate = DateParser.parse(dateMatch.group(1));
      if (parsedDate != null) {
        txnDate = parsedDate;
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
      currency: currency,
      transactionDate: txnDate,
      smsReceivedAt: smsTimestamp,
      merchant: merchant,
      balance: balance,
      availableLimit: avlLimit,
      reference: ref,
      confidence: confidence,
      parserVersion: '1.0.0',
      category: type.isIncome ? 'Income' : 'General Debit',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
