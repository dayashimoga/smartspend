import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import '../institution_detector.dart';
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
    final detectedBank = InstitutionDetector.detect('', normalizedBody);

    // A. Generic Credit Card Bill / Statement Extraction
    final isBillCandidate = lower.contains('statement') ||
        lower.contains('total due') ||
        lower.contains('amt due') ||
        lower.contains('amount due') ||
        (lower.contains('card') &&
            (lower.contains('due by') ||
                lower.contains('due on') ||
                lower.contains('due date') ||
                lower.contains('payable by') ||
                lower.contains('pay before') ||
                lower.contains('pay by') ||
                lower.contains('payment of') ||
                lower.contains('bill')));

    if (isBillCandidate) {
      final cardMatch = RegexPatterns.cardLast4.firstMatch(normalizedBody);
      final cardLast4 = cardMatch?.group(1);

      // Attempt multiple total due extractors
      double total = 0.0;
      final totalMatch1 = RegexPatterns.billTotalDue.firstMatch(normalizedBody);
      final totalMatch2 = RegExp(
              r'(?:Total\s+(?:due(?:\s+amt)?|amount(?:\s+due)?|amt\s+due)|Total\s+Due).*?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
              caseSensitive: false)
          .firstMatch(normalizedBody);
      final totalMatch3 = RegExp(
              r'Payment\s+of\s+(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)\s+is\s+due',
              caseSensitive: false)
          .firstMatch(normalizedBody);
      final totalMatch4 = RegExp(
              r'bill\s+(?:of\s+)?(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d+)?)',
              caseSensitive: false)
          .firstMatch(normalizedBody);

      final totalStr = totalMatch1?.group(1) ??
          totalMatch2?.group(1) ??
          totalMatch3?.group(1) ??
          totalMatch4?.group(1);
      if (totalStr != null) {
        total = AmountParser.parse(totalStr) ?? 0.0;
      }

      final minMatch = RegexPatterns.billMinDue.firstMatch(normalizedBody);
      final minDue =
          minMatch != null ? AmountParser.parse(minMatch.group(1)) ?? 0.0 : 0.0;

      final dueMatch = RegexPatterns.billDueDate.firstMatch(normalizedBody);
      DateTime? dueDate;
      if (dueMatch != null) {
        dueDate = DateParser.parse(dueMatch.group(1),
            referenceYear: smsTimestamp.year);
      }

      if (total > 0 || dueDate != null) {
        dueDate ??= smsTimestamp.add(const Duration(days: 20));
        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.bill,
          bank: detectedBank,
          cardLast4: cardLast4,
          amount: total,
          currency: 'INR',
          transactionDate: smsTimestamp,
          smsReceivedAt: smsTimestamp,
          billTotal: total,
          billMinimum: minDue,
          billDueDate: dueDate,
          confidence: total > 0 ? Confidence.high : Confidence.medium,
          parserVersion: '1.0.0',
          category: 'Credit Card Bill',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      // If text explicitly mentions credit card bill/statement, NEVER let it fall through to spend/debit
      if (lower.contains('card') &&
          (lower.contains('statement') ||
              lower.contains('bill') ||
              lower.contains('due'))) {
        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.bill,
          bank: detectedBank,
          cardLast4: cardLast4,
          amount: total,
          currency: 'INR',
          transactionDate: smsTimestamp,
          smsReceivedAt: smsTimestamp,
          billTotal: total,
          billMinimum: minDue,
          billDueDate: smsTimestamp.add(const Duration(days: 20)),
          confidence: Confidence.medium,
          parserVersion: '1.0.0',
          category: 'Credit Card Bill',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    // B. Pure Balance Alerts, Limit Updates, or Statements with no transaction event
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
        lower.contains('toll') ||
        lower.contains('txn') ||
        lower.contains('transaction');

    final isPureBalanceOrStatement = !hasTxnKeyword &&
        (lower.contains('bal') ||
            lower.contains('balance') ||
            lower.contains('limit') ||
            lower.contains('statement'));

    if (isPureBalanceOrStatement) {
      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final acctMatch = RegexPatterns.accountLast4.firstMatch(normalizedBody);
      final balance = balMatch != null
          ? AmountParser.parse(balMatch.group(1) ?? balMatch.group(2))
          : null;
      final acctLast4 = acctMatch?.group(1);

      if (balance != null) {
        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.unknown,
          bank: detectedBank,
          accountLast4: acctLast4,
          amount: 0.0,
          currency: 'INR',
          transactionDate: smsTimestamp,
          smsReceivedAt: smsTimestamp,
          balance: balance,
          confidence: acctLast4 != null ? Confidence.high : Confidence.medium,
          parserVersion: '1.0.0',
          category: 'Account Balance',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      // Return unparsed/informational record so non-financial balance/limit is NEVER counted as a spend transaction
      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.unknown,
        bank: detectedBank,
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
    final upiRefMatch =
        RegExp(r'(?:by\s+)?UPI\s*[:.]?\s*([0-9]{6,20})', caseSensitive: false)
            .firstMatch(normalizedBody);
    final ref = refMatch?.group(1) ?? upiRefMatch?.group(1);

    // 6. Contextual Merchant / Payee
    String? merchant;
    final merchantMatches = RegExp(
            r'(?:at|to|from|towards|info)\s+([A-Za-z0-9\s&._-]+?)(?:\s+on\s+|\s+at\s+|\s+from\s+|\s+by\s+UPI|\s+Ref|\s+Bal|\.\s+|\.$|$)',
            caseSensitive: false)
        .allMatches(normalizedBody);
    for (final m in merchantMatches) {
      final cand = m.group(1)?.trim();
      if (cand != null &&
          cand.length >= 2 &&
          cand.length <= 40 &&
          !cand.toLowerCase().startsWith('your') &&
          !cand.toLowerCase().startsWith('the') &&
          !cand.toLowerCase().contains('bank') &&
          !cand.toLowerCase().contains('a/c') &&
          !cand.toLowerCase().contains('account') &&
          !cand.toLowerCase().contains('card')) {
        merchant = cand;
        break;
      }
    }

    // 7. Date extraction from text if available
    DateTime txnDate = smsTimestamp;
    final dateMatch = RegExp(
      r'\b([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{1,2}[-/\s]?[a-zA-Z]{3}[-/\s]?[0-9]{2,4}|[0-9]{1,2}[-/\s]?[a-zA-Z]{3}|[0-9]{1,2}[/-][0-9]{1,2})\b',
      caseSensitive: false,
    ).firstMatch(normalizedBody);
    if (dateMatch != null) {
      final parsedDate = DateParser.parse(dateMatch.group(1),
          referenceYear: smsTimestamp.year);
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
      bank: detectedBank,
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
