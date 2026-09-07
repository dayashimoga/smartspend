import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class SbiRules extends BankRule {
  @override
  Bank get targetBank => Bank.sbi;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. SBI Credit Card Bill / E-statement / Payment Due
    // "E-statement of SBI Credit Card ending XX36 dated 09/06/2025 has been mailed... Total Amt Due Rs 3595; Min Amt Due Rs 200; Payable by 29/06/2025."
    // "Payment of Rs.15,400.00 is due on your SBI Card ending 7036 by 20/09/26. Min Amt Due Rs 770."
    // "Total Amt Due on your SBI Card ending 7036 is Rs 15,400.00 by 20/09/26."
    final isBill = (normalizedBody.toLowerCase().contains('sbi card') ||
            normalizedBody.toLowerCase().contains('sbi credit card')) &&
        (normalizedBody.toLowerCase().contains('total amt due') ||
            normalizedBody.toLowerCase().contains('payment of') ||
            normalizedBody.toLowerCase().contains('e-statement') ||
            normalizedBody.toLowerCase().contains('statement') ||
            normalizedBody.toLowerCase().contains('payable by') ||
            normalizedBody.toLowerCase().contains('is due'));

    if (isBill) {
      final cardMatch = RegExp(
        r'SBI\s+(?:Credit\s+)?Card.*?(?:ending|no\.?|[Xx*]+|\s+)*?(\d{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final cardEnding = cardMatch?.group(1);

      // Total Due
      double total = 0.0;
      final totalMatch1 = RegExp(
        r'Total\s+Amt\s+Due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final totalMatch2 = RegExp(
        r'Payment\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      final totalStr = totalMatch1?.group(1) ?? totalMatch2?.group(1);
      if (totalStr != null) {
        total = AmountParser.parse(totalStr) ?? 0.0;
      }

      // Due Date
      DateTime? dueDate;
      final dueMatch = RegExp(
        r'(?:Payable\s+by|by|due\s+on|due\s+by)\s*:?\s*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (dueMatch != null) {
        dueDate = DateParser.parse(dueMatch.group(1));
      }

      // Min Due
      double minDue = 0.0;
      final minMatch = RegExp(
        r'Min\s+Amt\s+Due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

      // Statement Date
      final stmtMatch = RegExp(
        r'dated\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      final stmtDate =
          stmtMatch != null ? DateParser.parse(stmtMatch.group(1)) : null;

      if (total > 0 || dueDate != null) {
        dueDate ??= smsTimestamp.add(const Duration(days: 20));
        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.bill,
          bank: Bank.sbi,
          cardLast4: cardEnding,
          amount: total,
          currency: 'INR',
          transactionDate: stmtDate ?? smsTimestamp,
          smsReceivedAt: smsTimestamp,
          statementDate: stmtDate,
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

    // 2. SBI Credit Card Payment Received via BBPS / NEFT
    // "We have received payment of Rs.5,696.00 via BBPS & the same has been credited to your SBI Credit Card. Your available limit is Rs.372,000.27."
    final paymentMatch = RegExp(
      r'received\s+payment\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?).*?credited\s+to\s+your\s+SBI\s+Credit\s+Card',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (paymentMatch != null) {
      final amount = AmountParser.parse(paymentMatch.group(1)) ?? 0.0;

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.billPayment,
        bank: Bank.sbi,
        amount: amount,
        currency: 'INR',
        transactionDate: smsTimestamp,
        smsReceivedAt: smsTimestamp,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Payment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. SBI Credit Card Spent
    // "Rs.3,595.00 spent on your SBI Credit Card ending 7036 at Flipkart Internet Pvt on 08/06/25. Trxn. not done by you? Report at https://sbicard.com/Dispute"
    // "Rs.15,590.85 spent on your SBI Credit Card ending 7036 at AMAZONPAYINDIAPRIVA on 22/09/25."
    final spentMatch = RegExp(
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+(?:your\s+)?SBI\s+(?:Credit\s+)?Card\s+ending\s+[Xx*]*(\d{2,4})\s+at\s+(.+?)\s+on\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spentMatch != null) {
      final amount = AmountParser.parse(spentMatch.group(1)) ?? 0.0;
      final cardLast4 = spentMatch.group(2);
      final merchant = spentMatch.group(3)?.trim();
      final txnDate = DateParser.parse(spentMatch.group(4)) ?? smsTimestamp;

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.sbi,
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

    // 4. SBI Account Balance Alert
    // "Available Balance in SBI A/c XX1234 as on 06-SEP-26 is INR 12,345.00."
    // "Balance in your SBI A/c ending 1234 is Rs 12,345.00 as on 06-SEP-26."
    final balAlertMatch = RegExp(
      r'(?:Available\s+Balance|Balance|Bal)\s+in\s+(?:your\s+)?SBI\s+A/c\s+(?:ending\s+|no\.?\s*)?[Xx*]*(\d{3,4}).*?(?:is|as\s+on).*?(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
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
        bank: Bank.sbi,
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

    // 5. SBI Bank Account Debit / Credit / UPI
    // "Dear SBI User, your A/c ending 1234 debited by Rs 500 on 10Jan26..."
    // "INR 500.00 debited from SBI A/c XX1234 on 05-SEP-26 to SWIGGY. Avl Bal INR 12,000.00."
    final acctMatch = RegExp(
      r'your\s+A/c\s+(?:ending\s+|no\.?\s*)?[Xx*]*(\d{3,4})\s+(?:has\s+been\s+)?(debited|credited)\s+(?:by|for|with)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}[-/a-zA-Z0-9]{2,10})|(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+(debited|credited)\s+(?:from|to)\s+SBI\s+A/c\s+[Xx*]*(\d{3,4})\s+on\s+([0-9]{1,2}[-/a-zA-Z0-9]{2,10})',
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
        if (cand != null &&
            !cand.toLowerCase().contains('bank') &&
            !cand.toLowerCase().contains('a/c')) {
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
        bank: Bank.sbi,
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
