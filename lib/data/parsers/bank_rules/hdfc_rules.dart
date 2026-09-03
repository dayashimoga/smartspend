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
    final billMatchA = RegExp(
      r'Credit\s+Card\s+[Xx*]*(\d{4})\s+Statement\s*:\s*Total\s+due(?:\s+amt)?\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+Min\.?\s*due(?:\s+amt)?\s*:\s*(?:Rs\.?|INR)?\s*([\d,]+(?:\.\d+)?)\s+(?:Pay\s+by|Due\s+by)\s*:?\s*([0-9]{1,2}-[0-9]{1,2}-[0-9]{2,4})',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (billMatchA != null) {
      final cardLast4 = billMatchA.group(1);
      final total = AmountParser.parse(billMatchA.group(2)) ?? 0.0;
      final minDue = AmountParser.parse(billMatchA.group(3)) ?? 0.0;
      final dueDate = DateParser.parse(billMatchA.group(4));

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
      final dueDate = DateParser.parse(billMatchB.group(2));
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

    return null;
  }
}
