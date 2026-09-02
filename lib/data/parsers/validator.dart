import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/confidence.dart';
import '../../domain/enums/transaction_type.dart';

class Validator {
  /// Cross-field validation to ensure sanity of parsed records before persistence.
  static ParsedTransaction validate(ParsedTransaction txn) {
    var issuesFound = false;

    // 1. Amount validation
    if (txn.type != TransactionType.bill && txn.amount <= 0) {
      issuesFound = true;
    }

    // 2. Date sanity check
    final now = DateTime.now();
    final oneYearFromNow = now.add(const Duration(days: 366));
    final tenYearsAgo = now.subtract(const Duration(days: 3650));

    if (txn.transactionDate.isAfter(oneYearFromNow) ||
        txn.transactionDate.isBefore(tenYearsAgo)) {
      issuesFound = true;
    }

    if (txn.billDueDate != null) {
      if (txn.billDueDate!.isBefore(tenYearsAgo) ||
          txn.billDueDate!.isAfter(oneYearFromNow)) {
        issuesFound = true;
      }
    }

    // 3. Balance sanity check (balances shouldn't be astronomically large)
    if (txn.balance != null && txn.balance! > 1000000000) {
      issuesFound = true;
    }

    if (issuesFound && txn.confidence == Confidence.high) {
      return txn.copyWith(confidence: Confidence.medium);
    }

    return txn;
  }
}
