import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class IciciRules extends BankRule {
  @override
  Bank get targetBank => Bank.icici;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // 1. ICICI Card Credited / Refunded
    // "ICICI Bank Credit Card XX4000 credited/refunded with Rs 190.30 on 16-JUL-25. To transfer, call Customer Care..."
    // "ICICI Bank Credit Card XX4000 credited/refunded with Rs 1,137.50 on 15-AUG-25."
    final refundMatch = RegExp(
      r'ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4})\s+credited/refunded\s+with\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (refundMatch != null) {
      final cardLast4 = refundMatch.group(1);
      final amount = AmountParser.parse(refundMatch.group(2)) ?? 0.0;
      final txnDate = DateParser.parse(refundMatch.group(3)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.refund,
        bank: Bank.icici,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Refund',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 2. Merchant Specific Card Refund
    // "AMAZON PAY IN E COMMERC refund of Rs 1,493.89 credited to ICICI Bank Credit Card XX4000 on 01-NOV-25. Revised total due Rs 0, minimum due Rs .00"
    final merchantRefundMatch = RegExp(
      r'(.+?)\s+refund\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+credited\s+to\s+ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})(?:.*?Revised\s+total\s+due\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (merchantRefundMatch != null) {
      final merchant = merchantRefundMatch.group(1)?.trim();
      final amount = AmountParser.parse(merchantRefundMatch.group(2)) ?? 0.0;
      final cardLast4 = merchantRefundMatch.group(3);
      final txnDate =
          DateParser.parse(merchantRefundMatch.group(4)) ?? smsTimestamp;
      final revisedTotal = AmountParser.parse(merchantRefundMatch.group(5));

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.refund,
        bank: Bank.icici,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        billTotal: revisedTotal,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Refund',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. Card Payment Received (BBPS / Direct)
    // "Payment of Rs 6,306.02 has been received on your ICICI Bank Credit Card XX4000 through Bharat Bill Payment System on 28-NOV-25."
    final paymentMatch = RegExp(
      r'Payment\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+has\s+been\s+received\s+on\s+your\s+ICICI\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4}).*?on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (paymentMatch != null) {
      final amount = AmountParser.parse(paymentMatch.group(1)) ?? 0.0;
      final cardLast4 = paymentMatch.group(2);
      final txnDate = DateParser.parse(paymentMatch.group(3)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.billPayment,
        bank: Bank.icici,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Payment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 4. ICICI Credit Card Bill Statement (Multi-format)
    // Format A: "ICICI Bank Credit Card XX4000... Total of Rs 3,494.78 or minimum of Rs 180.00 is due by 05-FEB-26."
    // Format B: "Total amount due on your ICICI Bank Credit Card XX4000 is Rs 3,494.78 payable by 05-FEB-26. Min due Rs 180."
    // Format C: "Payment of Rs 3,494.78 is due on your ICICI Bank Card XX4000 by 05-FEB-26."
    final isBill = (normalizedBody.toLowerCase().contains('credit card') ||
            (normalizedBody.toLowerCase().contains('card') &&
                (normalizedBody.toLowerCase().contains('due') ||
                    normalizedBody.toLowerCase().contains('statement')))) &&
        (normalizedBody.toLowerCase().contains('total') ||
            normalizedBody.toLowerCase().contains('minimum') ||
            normalizedBody.toLowerCase().contains('statement') ||
            normalizedBody.toLowerCase().contains('due by') ||
            normalizedBody.toLowerCase().contains('payable by') ||
            normalizedBody.toLowerCase().contains('is due'));

    if (isBill) {
      final cardMatch = RegExp(
        r'(?:Credit\s+)?Card\s*(?:no\.?|[Xx*]+|ending\s*)?\s*(\d{4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      final billMatchA = RegExp(
        r'Total\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+or\s+minimum\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due\s+by\s+([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      final billMatchB = RegExp(
        r'Total\s+(?:amount\s+)?due.*?(?:is\s*(?:Rs\.?|INR|₹)?|(?:Rs\.?|INR|₹))\s*([\d,]+(?:\.\d+)?).*?(?:payable\s+by|due\s+by|due\s+on)\s*:?\s*([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      final billMatchC = RegExp(
        r'Payment\s+of\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+is\s+due.*?(?:by|on)\s+([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})',
        caseSensitive: false,
      ).firstMatch(normalizedBody);

      if (billMatchA != null || billMatchB != null || billMatchC != null) {
        final cardLast4 = cardMatch?.group(1);
        final totalStr = billMatchA?.group(1) ??
            billMatchB?.group(1) ??
            billMatchC?.group(1);
        final total = AmountParser.parse(totalStr) ?? 0.0;

        final dueDateStr = billMatchA?.group(3) ??
            billMatchB?.group(2) ??
            billMatchC?.group(2);
        final dueDate = DateParser.parse(dueDateStr);

        double minDue = 0.0;
        if (billMatchA != null) {
          minDue = AmountParser.parse(billMatchA.group(2)) ?? 0.0;
        } else {
          final minMatch = RegExp(
            r'min(?:imum)?\s+(?:due|amt|amount)\s*(?:is|:)?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
            caseSensitive: false,
          ).firstMatch(normalizedBody);
          if (minMatch != null) {
            minDue = AmountParser.parse(minMatch.group(1)) ?? 0.0;
          }
        }

        return ParsedTransaction(
          id: const Uuid().v4(),
          rawSmsId: rawSmsId,
          type: TransactionType.bill,
          bank: Bank.icici,
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

    // 5. ICICI Account Balance Alert
    // "Dear Customer, the balance in your ICICI Bank Account XX1234 as on 06-SEP-26 is INR 45,000.00."
    // "Available Bal in ICICI Bank A/c XX1234 as on 06-SEP-26 is INR 45,000.00."
    final balAlertMatch = RegExp(
      r'(?:the\s+balance|Available\s+Bal(?:ance)?)\s+in\s+(?:your\s+)?ICICI\s+Bank\s+A(?:ccount|/c)\s+[Xx*]*(\d{4}).*?is\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
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
        bank: Bank.icici,
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

    // 6. ICICI Card Purchase / Spend
    // "INR 483.40 spent using ICICI Bank Card XX4000 on 18-Jan-26 on AMAZON PAY IN E. Avl Limit: INR 1,96,021.82."
    // "Spent INR 450.00 on ICICI Bank Card XX4000 on 18-Jan-26 at Swiggy. Avl Limit: ..."
    final spentMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+spent\s+(?:using\s+)?ICICI\s+Bank\s+Card\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\s+(?:on|at)\s+(.+?)(?:\.|\s+Avl\s+Limit|$)|(?:Spent\s+)(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+on\s+ICICI\s+Bank\s+Card\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\s+(?:at|on)\s+(.+?)(?:\.|\s+Avl\s+Limit|$)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (spentMatch != null) {
      final amount =
          AmountParser.parse(spentMatch.group(1) ?? spentMatch.group(5)) ?? 0.0;
      final cardLast4 = spentMatch.group(2) ?? spentMatch.group(6);
      final txnDate =
          DateParser.parse(spentMatch.group(3) ?? spentMatch.group(7)) ??
              smsTimestamp;
      final merchant = (spentMatch.group(4) ?? spentMatch.group(8))?.trim();

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.icici,
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

    // 7. ICICI Bank Account Debited / Transfer / UPI
    // "Dear Customer, ICICI Bank Account XX1234 has been debited for Rs 1,500.00 on 05-Sep-26. Info: UPI/321.../Swiggy. Avl Bal: INR 25,000.00."
    // "INR 500.00 debited from ICICI Bank A/C XX1234 on 05-SEP-26 to ZOMATO. Avl bal INR 24,500.00."
    // "Your A/c ending XX1234 has been debited with INR 500.00 on 05-Sep-26 by UPI to SWIGGY. Avl Bal INR 25,000."
    final debitMatch = RegExp(
      r'(?:ICICI\s+Bank\s+Account|A/[Cc]\s+(?:ending\s+)?)\s*[Xx*]*(\d{4})\s+(?:has\s+been\s+)?debited\s+(?:for|with|by)\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})|(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+debited\s+from\s+ICICI\s+Bank\s+A/[Cc]\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (debitMatch != null) {
      final acctLast4 = debitMatch.group(1) ?? debitMatch.group(5);
      final amount =
          AmountParser.parse(debitMatch.group(2) ?? debitMatch.group(4)) ?? 0.0;
      final txnDate =
          DateParser.parse(debitMatch.group(3) ?? debitMatch.group(6)) ??
              smsTimestamp;

      final isUpi = normalizedBody.toLowerCase().contains('upi') ||
          normalizedBody.toLowerCase().contains('vpa');

      final isCardPayment =
          normalizedBody.toLowerCase().contains('card payment') ||
              normalizedBody.toLowerCase().contains('credit card') ||
              normalizedBody.toLowerCase().contains('cred');

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      // Extract merchant
      String? merchant;
      final merchantMatch = RegExp(
        r'(?:to|at|info:?\s*(?:upi/[0-9]+/)?)\s*([A-Za-z0-9\s&._-]+?)(?:\.|\s+Avl|\s+ref|$)',
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
        type: isCardPayment
            ? TransactionType.billPayment
            : (isUpi ? TransactionType.upi : TransactionType.debit),
        bank: Bank.icici,
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
        category: isCardPayment ? 'Credit Card Payment' : 'General Debit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 8. ICICI Bank Account Credited
    // "Dear Customer, ICICI Bank Account XX1234 has been credited for Rs 5,000.00 on 05-Sep-26. Info: NEFT/... Avl Bal: INR 30,000.00."
    final creditMatch = RegExp(
      r'(?:ICICI\s+Bank\s+Account|A/[Cc]\s+(?:ending\s+)?)\s*[Xx*]*(\d{4})\s+(?:has\s+been\s+)?credited\s+(?:for|with|by)\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+on\s+([0-9]{1,2}-[a-zA-Z0-9]{2,3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (creditMatch != null) {
      final acctLast4 = creditMatch.group(1);
      final amount = AmountParser.parse(creditMatch.group(2)) ?? 0.0;
      final txnDate = DateParser.parse(creditMatch.group(3)) ?? smsTimestamp;

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      final isSalary = normalizedBody.toLowerCase().contains('salary') ||
          normalizedBody.toLowerCase().contains('payroll');

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isSalary ? TransactionType.salary : TransactionType.credit,
        bank: Bank.icici,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isSalary ? 'Salary' : 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
