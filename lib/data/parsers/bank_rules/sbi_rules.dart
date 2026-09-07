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
    // 1. SBI Credit Card E-statement Bill
    // "E-statement of SBI Credit Card ending XX36 dated 09/06/2025 has been mailed... Total Amt Due Rs 3595; Min Amt Due Rs 200; Payable by 29/06/2025."
    final billMatch = RegExp(
      r'(?:E-statement|Statement)\s+of\s+SBI\s+Credit\s+Card\s+ending\s+[Xx*]*(\d{2,4}).*?(?:dated\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4}))?.*?Total\s+Amt\s+Due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?Payable\s+by\s*:?\s*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatch != null) {
      final cardEnding = billMatch.group(1);
      final stmtDate = DateParser.parse(billMatch.group(2));
      final total = AmountParser.parse(billMatch.group(3)) ?? 0.0;
      final dueDate = DateParser.parse(billMatch.group(4));

      double minDue = 0.0;
      final minMatch = RegExp(
        r'Min\s+Amt\s+Due\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(normalizedBody);
      if (minMatch != null) {
        minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
      }

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
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+your\s+SBI\s+Credit\s+Card\s+ending\s+[Xx*]*(\d{2,4})\s+at\s+(.+?)\s+on\s+([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})',
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

    // 4. SBI Bank Account Debit / Credit
    // "Dear SBI User, your A/c ending 1234 debited by Rs 500 on 10Jan26..."
    final acctMatch = RegExp(
      r'your\s+A/c\s+(?:ending\s+|no\.?\s*)?[Xx*]*(\d{3,4})\s+(?:has\s+been\s+)?(debited|credited)\s+(?:by|for|with)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}[-/a-zA-Z0-9]{2,10})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (acctMatch != null) {
      final acctLast4 = acctMatch.group(1);
      final isDebit = acctMatch.group(2)!.toLowerCase() == 'debited';
      final amount = AmountParser.parse(acctMatch.group(3)) ?? 0.0;
      final txnDate = DateParser.parse(acctMatch.group(4)) ?? smsTimestamp;

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isDebit ? TransactionType.debit : TransactionType.credit,
        bank: Bank.sbi,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        balance: balance,
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
