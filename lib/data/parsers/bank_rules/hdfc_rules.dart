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
    // 1. HDFC Credit Card Bill Statement (Format A: Standard / Total due)
    // "HDFC Bank Credit Card XX9137 Statement: Total due: Rs.35,616.00 Min.due: Rs.1,790.00 Pay by 05-12-2025"
    // "HDFC Bank Credit Card XX9137 Statement: Total due amt: Rs.11,397.00 Min due amt: Rs.570.00 Due by:04-08-2025."
    // "Your HDFC Bank Credit Card ending 9137 statement has been generated. Total Amt Due: Rs 15,400.00, Min Amt Due: Rs 770.00, Due Date: 25-09-2026."
    // "Statement for HDFC Bank Card 9137: Total due is Rs.15,400.00. Min due Rs.770.00. Pay by 25-SEP-26"
    // "Dear Cardmember, Total Due on your HDFC Bank Card ending 9137 is Rs 15,400.00. Due on 25-09-2026."
    final billMatchA = RegExp(
      r'(?:Credit\s+Card|Card)\s+(?:no\.?\s*)?(?:ending\s+|[Xx*]*)*(\d{4}).*?Total\s+(?:due(?:\s+amt)?|amount(?:\s+due)?|amt\s+due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)(?:.*?Min\.?\s*(?:due(?:\s+amt)?|amount(?:\s+due)?|amt\s+due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?.*?(?:Pay\s+by|Due\s+by|Due\s+date|Due\s+on|Payable\s+by|on\s+or\s+before)\s*:?\s*([0-9]{1,2}[/-][a-zA-Z0-9]{2,3}[/-][0-9]{2,4}|[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchA != null) {
      final cardLast4 = billMatchA.group(1);
      final total = AmountParser.parse(billMatchA.group(2)) ?? 0.0;
      final minDue = AmountParser.parse(billMatchA.group(3)) ?? 0.0;
      final dueDate = DateParser.parse(billMatchA.group(4), referenceYear: smsTimestamp.year);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.hdfc,
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

    // 1b. HDFC E-Statement Generated (Format B)
    // "E-Statement Generated! For HDFC Bank Credit Card 1355.Due date:04/NOV/2021.Total Due:Rs.3121.Min Due:Rs.3092.For Statement: hdfcbk.io/k/DUvfZQfSl9P"
    final billMatchB = RegExp(
      r'E-Statement\s+Generated.*?For\s+HDFC\s+Bank\s+Credit\s+Card\s+[Xx*]*(\d{4}).*?Due\s+date\s*:\s*([0-9]{1,2}[/-][a-zA-Z0-9]{2,3}[/-][0-9]{2,4}).*?Total\s+Due\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?Min\s+Due\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchB != null) {
      final cardLast4 = billMatchB.group(1);
      final dueDate = DateParser.parse(billMatchB.group(2), referenceYear: smsTimestamp.year);
      final total = AmountParser.parse(billMatchB.group(3)) ?? 0.0;
      final minDue = AmountParser.parse(billMatchB.group(4)) ?? 0.0;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.hdfc,
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

    // 1c. HDFC Payment Due Notice (Format C)
    // "Payment of Rs. 15,400.00 is due on your HDFC Bank Credit Card ending 9137 by 25-SEP-26. Min Due Rs. 770.00."
    final billMatchC = RegExp(
      r'Payment\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+is\s+due\s+on.*?(?:Credit\s+Card|Card)\s+(?:no\.?\s*)?(?:ending\s+|[Xx*]*)*(\d{4}).*?(?:by|on)\s+([0-9]{1,2}[/-][a-zA-Z0-9]{2,3}[/-][0-9]{2,4}|[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})(?:.*?(?:Min\.?\s*due(?:\s+amt)?|Minimum\s+amount\s+due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchC != null) {
      final total = AmountParser.parse(billMatchC.group(1)) ?? 0.0;
      final cardLast4 = billMatchC.group(2);
      final dueDate = DateParser.parse(billMatchC.group(3), referenceYear: smsTimestamp.year);
      final minDue = AmountParser.parse(billMatchC.group(4)) ?? 0.0;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.hdfc,
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

    // 1d. HDFC Total Due / Card Statement (Format D: Total Due before Card)
    // "Total Due on your HDFC Bank Card ending 9137 is Rs 15,400.00. Due on 25-09-2026."
    // "Dear Cardmember, Total Due on your HDFC Bank Card ending 9137 is Rs 15,400.00. Due on 25-09-2026. Min due Rs 770.00"
    final billMatchD = RegExp(
      r'Total\s+(?:due(?:\s+amt)?|amount(?:\s+due)?|amt\s+due)\s+(?:on\s+your\s+)?(?:HDFC\s+Bank\s+)?(?:Credit\s+Card|Card)\s+(?:no\.?\s*)?(?:ending\s+|[Xx*.-]*)*(\d{4})\s+is\s+(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?).*?(?:Pay\s+by|Due\s+by|Due\s+date|Due\s+on|Payable\s+by|on\s+or\s+before|by)\s*:?\s*([0-9]{1,2}[/-][a-zA-Z0-9]{2,3}[/-][0-9]{2,4}|[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}|[0-9]{1,2}\s+[a-zA-Z]{3}\s+[0-9]{2,4})(?:.*?Min\.?\s*(?:due(?:\s+amt)?|amount(?:\s+due)?|amt\s+due)\s*:?\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchD != null) {
      final cardLast4 = billMatchD.group(1);
      final total = AmountParser.parse(billMatchD.group(2)) ?? 0.0;
      final dueDate = DateParser.parse(billMatchD.group(3), referenceYear: smsTimestamp.year);
      final minDue = AmountParser.parse(billMatchD.group(4)) ?? 0.0;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.bill,
        bank: Bank.hdfc,
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

    // 2. Card Payment Credited
    // "HDFC Bank Cardmember, Online Payment of Rs.11397 vide Ref# 213BAIAAAANMQXS was credited to your card ending 9137 On 01/AUG/2025_value Date 01/AUG/2025"
    final cardPaymentMatch = RegExp(
      r'Online\s+Payment\s+of\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?).*?(?:Ref#?\s*([a-zA-Z0-9]+))?.*?credited\s+to\s+your\s+card\s+ending\s+[Xx*]*(\d{4})\s+On\s+([0-9]{1,2}[/-][a-zA-Z0-9]{2,3}[/-][0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (cardPaymentMatch != null) {
      final amount = AmountParser.parse(cardPaymentMatch.group(1)) ?? 0.0;
      final ref = cardPaymentMatch.group(2);
      final cardLast4 = cardPaymentMatch.group(3);
      final txnDate =
          DateParser.parse(cardPaymentMatch.group(4)) ?? smsTimestamp;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.billPayment,
        bank: Bank.hdfc,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Credit Card Payment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 3. UPI / Credit Alert
    // "Credit Alert!Rs.20000.00 credited to HDFC Bank A/c XX0564 on 10-08-25 from VPA dayahere@sbi (UPI 100239154768)"
    final creditAlertMatch = RegExp(
      r'Credit\s+Alert\s*!\s*(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+credited\s+to\s+HDFC\s+Bank\s+A/c\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})(?:\s+from\s+VPA\s+([^\s(]+))?(?:\s*\(UPI\s*([0-9]+)\))?',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (creditAlertMatch != null) {
      final amount = AmountParser.parse(creditAlertMatch.group(1)) ?? 0.0;
      final acctLast4 = creditAlertMatch.group(2);
      final txnDate =
          DateParser.parse(creditAlertMatch.group(3)) ?? smsTimestamp;
      final vpa = creditAlertMatch.group(4);
      final upiRef = creditAlertMatch.group(5);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.credit,
        bank: Bank.hdfc,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        payer: vpa,
        upiRef: upiRef,
        reference: upiRef,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 4. Salary / Credit Deposit / ACH
    // "Update! INR 4,59,031.00 deposited in HDFC Bank A/c XX0564 on 31-DEC-25 for ACH C- HARMANCONSRCRINPLT-FFS B 2 Dec 25.Avl bal INR 5,11,120.25."
    // "Update! INR 93,807.00 deposited in HDFC Bank A/c XX0564 on 27-JUN-25 ... Salary... Avl bal INR 1,76,306.56."
    final depositMatch = RegExp(
      r'(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+deposited\s+in\s+HDFC\s+Bank\s+A/c\s+[Xx*]*(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (depositMatch != null) {
      final amount = AmountParser.parse(depositMatch.group(1)) ?? 0.0;
      final acctLast4 = depositMatch.group(2);
      final txnDate = DateParser.parse(depositMatch.group(3)) ?? smsTimestamp;

      final isSalary = normalizedBody.toLowerCase().contains('salary') ||
          normalizedBody.toLowerCase().contains('payroll') ||
          normalizedBody.toLowerCase().contains('ach c-');
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
        smsReceivedAt: smsTimestamp,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isSalary ? 'Salary' : 'Income',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 5. Sent / Transfer Debit (e.g. to Mutual Funds, ICCL)
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

      final lowerPayee = payee?.toLowerCase() ?? '';
      final isInvest = lowerPayee.contains('mutual fund') ||
          lowerPayee.contains('iccl') ||
          lowerPayee.contains('zerodha');
      final isCardPayment = lowerPayee.contains('credit card') ||
          lowerPayee.contains('card payment') ||
          lowerPayee.contains('cred');

      final type = isInvest
          ? TransactionType.investmentTransfer
          : (isCardPayment
              ? TransactionType.billPayment
              : TransactionType.debit);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: type,
        bank: Bank.hdfc,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        payee: payee,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isInvest
            ? 'Investments'
            : (isCardPayment ? 'Credit Card Payment' : 'General Debit'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 6. ATM / Card Withdrawal
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
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        balance: balance,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Cash & ATM',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 7. FASTag Alert / Added
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
        type: TransactionType.fastagFunding,
        bank: Bank.hdfc,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        fastagId: fastagId,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'FASTag Recharge',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 8. HDFC Card Transaction / RuPay UPI spend
    // "Txn Rs.124.00 On HDFC Bank Card 9137 At sbibhim.instant9284450021 by UPI 661600456771 On 07-09 Not You? Call 18002586161/SMS BLOCK CC 9137 to 7308080808"
    final cardTxnMatch = RegExp(
      r'Txn\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+On\s+HDFC\s+Bank\s+Card\s+(?:ending\s+|[Xx*]*)*(\d{4})\s+At\s+(.+?)(?:\s+by\s+UPI\s+([0-9]+))?\s+On\s+([0-9]{1,2}[-/][0-9]{1,2}(?:[-/][0-9]{2,4})?|[0-9]{1,2}-[a-zA-Z]{3}(?:-[0-9]{2,4})?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (cardTxnMatch != null) {
      final amount = AmountParser.parse(cardTxnMatch.group(1)) ?? 0.0;
      final cardLast4 = cardTxnMatch.group(2);
      var merchant = cardTxnMatch.group(3)?.trim();
      final upiRef = cardTxnMatch.group(4);
      final dateStr = cardTxnMatch.group(5);
      final txnDate = dateStr != null
          ? DateParser.parse(dateStr, referenceYear: smsTimestamp.year) ?? smsTimestamp
          : smsTimestamp;

      if (merchant != null) {
        final notYouIdx = merchant.toLowerCase().indexOf('not you');
        if (notYouIdx != -1) {
          merchant = merchant.substring(0, notYouIdx).trim();
        }
      }

      final isUpi = upiRef != null || normalizedBody.toLowerCase().contains('upi');

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: isUpi ? TransactionType.upi : TransactionType.purchase,
        bank: Bank.hdfc,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        upiRef: upiRef,
        reference: upiRef,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isUpi ? 'Digital Payments' : 'Card Spend',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 9. HDFC Account Balance Alert / Update
    // "Available Bal in HDFC Bank A/c XX0564 as on yesterday:06-SEP-26 is INR 56,473.36. Cheques are subject to clearing.For updated A/C Bal dial 18002703333."
    // "Available Bal in HDFC Bank A/c XX0564 as on 07-SEP-26 is INR 56,473.36."
    // "Avl Bal in HDFC Bank A/c XX0564 is INR 56,473.36."
    final balanceAlertMatch = RegExp(
      r'(?:Available\s+Bal|Avl\s+Bal|Balance)\s+in\s+HDFC\s+Bank\s+A/c\s+[Xx*]*(\d{4})(?:\s+as\s+on\s+(?:yesterday\s*:?\s*)?([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4}|[0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4}))?.*?is\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (balanceAlertMatch != null) {
      final acctLast4 = balanceAlertMatch.group(1);
      final dateStr = balanceAlertMatch.group(2);
      final balance = AmountParser.parse(balanceAlertMatch.group(3)) ?? 0.0;
      DateTime txnDate;
      if (dateStr != null) {
        final parsed =
            DateParser.parse(dateStr, referenceYear: smsTimestamp.year);
        // Closing balance alert for yesterday: set to end of that day (23:59:59)
        txnDate = parsed != null
            ? DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59)
            : smsTimestamp;
      } else {
        txnDate = smsTimestamp;
      }

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.unknown,
        bank: Bank.hdfc,
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

    // 10. HDFC Account Debit / UPI / Transfer
    // "INR 500.00 debited from HDFC Bank A/C XX0564 on 05-SEP-26 to SWIGGY. Avl bal INR 56,473.36."
    // "Rs. 250.00 debited from HDFC Bank A/c XX0564 on 06-09-26 towards UPI-ZEPTO-zepto@hdfcbank-123456. Avl bal: Rs 56,723.36."
    // "Update! INR 1,200.00 debited from HDFC Bank A/c XX0564 on 05-09-26 info UPI/P2M/624911.../Swiggy. Avl Bal INR 56,473.36."
    // "Debited INR 350.00 from HDFC Bank A/c XX0564 on 04-09-26 to Swiggy. Avl bal INR 57,673.36."
    // "HDFC Bank: Rs 500.00 debited from a/c **0564 on 05-09-26 towards BIL/ONL/... Avl bal Rs 56,473.36."
    final hdfcDebitMatch = RegExp(
      r'(?:(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+debited\s+from|debited\s+(?:INR|Rs\.?)\s*([\d,]+(?:\.\d+)?)\s+from)\s+(?:HDFC\s+Bank\s+)?(?:A/c|Account|a/c)\s+[Xx*.-]*(\d{4})\s+on\s+([0-9]{1,2}[-/a-zA-Z0-9\s]{2,11})(?:\s+(?:to|towards|for|info|transfer\s+to)\s+(.+?))?(?:\s+Avl\s+bal|\s+Bal\s+is|\.\s+Avl|$)',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (hdfcDebitMatch != null) {
      final amount = AmountParser.parse(
              hdfcDebitMatch.group(1) ?? hdfcDebitMatch.group(2)) ??
          0.0;
      final acctLast4 = hdfcDebitMatch.group(3);
      final dateStr = hdfcDebitMatch.group(4)?.trim();
      var rawMerchant = hdfcDebitMatch.group(5)?.trim();
      final txnDate = dateStr != null
          ? DateParser.parse(dateStr, referenceYear: smsTimestamp.year) ??
              smsTimestamp
          : smsTimestamp;

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      final upiMatch = RegExp(
              r'(?:UPI\s*Ref(?:\s*no\.?)?|(?:by\s+)?UPI)\s*[:.]?\s*([0-9]{6,20})',
              caseSensitive: false)
          .firstMatch(normalizedBody);
      final refMatch = RegExp(
              r'(?:Ref\s*(?:no\.?)?|RRN)\s*[:.]?\s*([a-zA-Z0-9]+)',
              caseSensitive: false)
          .firstMatch(normalizedBody);
      final upiRef = upiMatch?.group(1);
      final ref = refMatch?.group(1) ?? upiRef;

      var merchant = rawMerchant;
      if (merchant != null) {
        final upiPrefixMatch = RegExp(
                r'UPI[-/](?:P2[MP][-/])?(?:[0-9]+[-/])?([A-Za-z0-9\s&._-]+)',
                caseSensitive: false)
            .firstMatch(merchant);
        if (upiPrefixMatch != null) {
          merchant = upiPrefixMatch.group(1);
        }
        final notYouIdx = merchant?.toLowerCase().indexOf('not you') ?? -1;
        if (notYouIdx != -1) {
          merchant = merchant?.substring(0, notYouIdx).trim();
        }
      }

      final isUpi = upiRef != null ||
          normalizedBody.toLowerCase().contains('upi') ||
          (merchant?.toLowerCase().contains('upi') ?? false);
      final isCardPayment =
          merchant?.toLowerCase().contains('credit card') ?? false;

      final type = isCardPayment
          ? TransactionType.billPayment
          : (isUpi ? TransactionType.upi : TransactionType.debit);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: type,
        bank: Bank.hdfc,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        balance: balance,
        upiRef: upiRef,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: isCardPayment
            ? 'Credit Card Payment'
            : (isUpi ? 'Digital Payments' : 'General Debit'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // 11. HDFC Card Spend (POS / E-com / Alert)
    // "Spent Rs.450.00 on HDFC Bank Card 9137 on 05-09-2026 at Amazon. Avl lmt: Rs 1,50,000."
    // "Alert: You have spent Rs 150.00 on your HDFC Bank Credit Card ending 9137 on 04-Sep-2026 at RELIANCE RETAIL. Avl Lmt: Rs 1,49,850.00."
    // "Txn of Rs. 200.00 done on HDFC Bank Card 9137 at Uber on 05-09-26."
    final hdfcCardSpendMatch = RegExp(
      r'(?:(?:Spent|have\s+spent|Txn\s+of)\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)|(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+spent)\s+(?:on|done\s+on|using)?\s*(?:your\s+)?HDFC\s+Bank\s+(?:Credit\s+)?Card\s+(?:ending\s+|no\.?\s*|[Xx*.-]*)*(\d{4})\s+(?:at\s+(.+?)\s+on\s+([0-9]{1,2}[-/a-zA-Z0-9\s]{2,11})|on\s+([0-9]{1,2}[-/a-zA-Z0-9\s]{2,11})\s+at\s+(.+?)(?:\.|\s+Avl|$))',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (hdfcCardSpendMatch != null) {
      final amount = AmountParser.parse(
              hdfcCardSpendMatch.group(1) ?? hdfcCardSpendMatch.group(2)) ??
          0.0;
      final cardLast4 = hdfcCardSpendMatch.group(3);
      final merchant =
          (hdfcCardSpendMatch.group(4) ?? hdfcCardSpendMatch.group(7))?.trim();
      final dateStr =
          (hdfcCardSpendMatch.group(5) ?? hdfcCardSpendMatch.group(6))?.trim();
      final txnDate = dateStr != null
          ? DateParser.parse(dateStr, referenceYear: smsTimestamp.year) ??
              smsTimestamp
          : smsTimestamp;

      final limitMatch =
          RegexPatterns.availableLimit.firstMatch(normalizedBody);
      final avlLimit =
          limitMatch != null ? AmountParser.parse(limitMatch.group(1)) : null;

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        cardLast4: cardLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        smsReceivedAt: smsTimestamp,
        merchant: merchant,
        availableLimit: avlLimit,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Card Spend',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
