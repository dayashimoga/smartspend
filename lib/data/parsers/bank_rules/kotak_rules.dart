import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class KotakRules extends BankRule {
  @override
  Bank get targetBank => Bank.kotak;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. Kotak Credit Card Bill Statement
    final isBill = (normalizedBody.toLowerCase().contains('kotak') ||
            normalizedBody.toLowerCase().contains('card')) &&
        (normalizedBody.toLowerCase().contains('total amt due') ||
            normalizedBody.toLowerCase().contains('total due') ||
            normalizedBody.toLowerCase().contains('payment of') ||
            normalizedBody.toLowerCase().contains('statement') ||
            normalizedBody.toLowerCase().contains('payable by') ||
            normalizedBody.toLowerCase().contains('due date'));

    if (isBill) {
      final billMatch = RegExp(
        r'(?:Statement\s+for\s+(?:your\s+)?Kotak|Kotak\s+Bank\s+Credit\s+Card).*?(?:[Xx*]+|ending\s*)?(\d{4}).*?Total\s+(?:Amt\s+Due|due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?(?:Min(?:imum)?\s+(?:Amt\s+Due|due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?.*?(?:Due\s+(?:Date|by|on)|Payable\s+by)\s*:?\s*([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      final billMatchB = RegExp(
        r'Payment\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due\s+on\s+your\s+Kotak\s+Bank\s+(?:Credit\s+)?Card\s*(?:[Xx*]+|ending\s*)?(\d{4})\s+by\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      if (billMatch != null || billMatchB != null) {
        final cardLast4 = billMatch?.group(1) ?? billMatchB?.group(2);
        final total = AmountParser.parse(billMatch?.group(2) ?? billMatchB?.group(1)) ?? 0.0;
        final dueDate = DateParser.parse(billMatch?.group(4) ?? billMatchB?.group(3));

        double minDue = 0.0;
        final minMatch = RegExp(
          r'Min(?:imum)?\s+(?:Amt\s+Due|due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
          caseSensitive: false,
        ).firstMatch(normalizedBody);
        if (minMatch != null) {
          minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
        }

        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.bill,
          bank: Bank.kotak,
          cardLast4: cardLast4,
          amount: total,
          currency: 'INR',
          transactionDate: smsTimestamp,
          smsReceivedAt: smsTimestamp,
          billTotal: total,
          billMinimum: minDue,
          billDueDate: dueDate,
          confidence: Confidence.high,
          parserVersion: '1.0.0',
          category: 'Credit Card Bill',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    // 2. Kotak Credit Card Spend
    // "INR 450.00 spent on Kotak Bank Credit Card XX1234 on 15/01/26 at SWIGGY. Avl Limit: INR 85000"
    // "Spent Rs. 1,499.00 on Kotak Bank Card 5432 at Reliance Digital on 02-02-2026. Avl Limit: Rs. 88,500.00."
    final spendMatch = RegExp(
      r'(?:Spent\s+)?(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s*(?:spent\s+)?on\s+Kotak\s+(?:Bank\s+)?(?:Credit\s+)?Card\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{4})\s+(?:at|on)\s+([A-Za-z0-9\s&._-]+?)\s+on\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})|(?:Spent\s+)?(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s*(?:spent\s+)?on\s+Kotak\s+(?:Bank\s+)?(?:Credit\s+)?Card\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{4})\s+on\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})\s+at\s+([A-Za-z0-9\s&._-]+?)(?:\.|\s+Avl|$)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spendMatch != null) {
      final amount =
          AmountParser.parse(spendMatch.group(1) ?? spendMatch.group(5)) ?? 0.0;
      final cardLast4 = spendMatch.group(2) ?? spendMatch.group(6);
      final txnDate =
          DateParser.parse(spendMatch.group(4) ?? spendMatch.group(7)) ??
              smsTimestamp;
      final merchant = (spendMatch.group(3) ?? spendMatch.group(8))?.trim();

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.kotak,
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

    // 3. Kotak Account Balance Alert
    // "Bal in Kotak Bank A/c XX1234 as on 06-SEP-26 is INR 18,000.00."
    final balAlertMatch = RegExp(
      r'(?:the\s+balance|Available\s+Bal(?:ance)?|Bal)\s+in\s+Kotak\s+Bank\s+A(?:ccount|/c)\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{3,4}).*?is\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (balAlertMatch != null) {
      final acctLast4 = balAlertMatch.group(1);
      final balance = AmountParser.parse(balAlertMatch.group(2));

      DateTime txnDate = smsTimestamp;
      final asOnMatch = RegExp(
        r'as\s+on\s+(?:yesterday:)?([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (asOnMatch != null) {
        final d = DateParser.parse(asOnMatch.group(1));
        if (d != null) {
          txnDate = DateTime(d.year, d.month, d.day, 23, 59, 59);
        }
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.unknown,
        bank: Bank.kotak,
        accountLast4: acctLast4,
        amount: 0.0,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Account Balance',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 4. Kotak Bank Account Debit / Credit / UPI
    final acctMatch = RegExp(
      r'(?:Kotak\s+Bank\s+A/c|A/c)\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{3,4})\s+(?:has\s+been\s+)?(debited|credited)\s+(?:with|for)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})|(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited)\s+(?:from|to)\s+Kotak\s+Bank\s+A/c\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{3,4})\s+on\s+([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (acctMatch != null) {
      final acctLast4 = acctMatch.group(1) ?? acctMatch.group(7);
      final isDebit =
          (acctMatch.group(2) ?? acctMatch.group(6))!.toLowerCase() ==
              'debited';
      final amount =
          AmountParser.parse(acctMatch.group(3) ?? acctMatch.group(5)) ?? 0.0;
      final txnDate =
          DateParser.parse(acctMatch.group(4) ?? acctMatch.group(8)) ??
              smsTimestamp;

      final isUpi = normalizedBody.toLowerCase().contains('upi') ||
          normalizedBody.toLowerCase().contains('vpa');

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      // Extract merchant
      String? merchant;
      final merchantMatch = RegExp(
        r'(?:to|at|transfer\s+to)\s+([A-Za-z0-9\s&._-]+?)(?:\.|\s+Avl|\s+ref|\s+by\s+UPI|$)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (merchantMatch != null) {
        final cand = merchantMatch.group(1)?.trim();
        if (cand != null && !cand.toLowerCase().contains('bank') && !cand.toLowerCase().contains('a/c')) {
          merchant = cand;
        }
      }

      final refMatch = RegexPatterns.referenceNumber.firstMatch(normalizedBody);
      final ref = refMatch?.group(1);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isDebit
            ? (isUpi ? TransactionType.upi : TransactionType.debit)
            : TransactionType.credit,
        bank: Bank.kotak,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        balance: balance,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isDebit ? 'General Debit' : 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
