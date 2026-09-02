import 'package:uuid/uuid.dart';
import '../../../core/constants/regex_patterns.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/date_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';
import '../../../domain/enums/confidence.dart';
import '../../../domain/enums/transaction_type.dart';
import 'bank_rule.dart';

class YesBankRules extends BankRule {
  @override
  Bank get targetBank => Bank.yesBank;

  @override
  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  }) {
    // "Rs. 1,250.00 debited from YES BANK A/c XX8812 on 14-FEB-26 via UPI: Swiggy. Avl Bal: Rs. 45,210.00. Ref 392019482910."
    final upiMatch = RegExp(
      r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d+)?)\s+debited\s+from\s+YES\s+BANK\s+A/c\s+XX(\d{4})\s+on\s+([0-9]{1,2}-[a-zA-Z]{3}-[0-9]{2,4})\s+via\s+UPI:\s*(.+?)\.\s+Avl\s+Bal',
      caseSensitive: false,
    ).firstMatch(normalizedBody);

    if (upiMatch != null) {
      final amount = AmountParser.parse(upiMatch.group(1)) ?? 0.0;
      final acctLast4 = upiMatch.group(2);
      final txnDate = DateParser.parse(upiMatch.group(3)) ?? smsTimestamp;
      final merchant = upiMatch.group(4)?.trim();

      final balMatch =
          RegexPatterns.availableBalance.firstMatch(normalizedBody);
      final balance =
          balMatch != null ? AmountParser.parse(balMatch.group(1)) : null;

      final refMatch = RegexPatterns.referenceNumber.firstMatch(normalizedBody);
      final ref = refMatch?.group(1);

      return ParsedTransaction(
        id: const Uuid().v4(),
        rawSmsId: rawSmsId,
        type: TransactionType.upi,
        bank: Bank.yesBank,
        accountLast4: acctLast4,
        amount: amount,
        currency: 'INR',
        transactionDate: txnDate,
        merchant: merchant,
        balance: balance,
        reference: ref,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Food & Dining',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
