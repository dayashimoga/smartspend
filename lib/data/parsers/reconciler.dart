import '../../domain/entities/bill.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/transaction_type.dart';

class Reconciler {
  /// Reconciles incoming transaction against historical transactions.
  /// Identifies refunds, reversals, and card repayments to avoid double counting.
  static List<ParsedTransaction> reconcileAll(List<ParsedTransaction> txns) {
    final updatedList = List<ParsedTransaction>.from(txns);

    for (int i = 0; i < updatedList.length; i++) {
      final current = updatedList[i];
      if (current.isReconciled) continue;

      // 1. Check for Refund matching a Purchase
      if (current.type == TransactionType.refund) {
        for (int j = 0; j < updatedList.length; j++) {
          if (i == j) continue;
          final other = updatedList[j];
          if (other.type == TransactionType.purchase &&
              other.cardLast4 == current.cardLast4 &&
              (other.amount - current.amount).abs() < 0.01 &&
              !other.isReconciled) {
            // Found matching purchase for refund
            updatedList[i] = current.copyWith(
              isReconciled: true,
              reconciledWithId: other.id,
            );
            updatedList[j] = other.copyWith(
              isReconciled: true,
              reconciledWithId: current.id,
            );
            break;
          }
        }
      }

      // 2. Check for Reversal matching a Debit
      if (current.type == TransactionType.reversal) {
        for (int j = 0; j < updatedList.length; j++) {
          if (i == j) continue;
          final other = updatedList[j];
          if (other.type == TransactionType.debit &&
              other.accountLast4 == current.accountLast4 &&
              (other.amount - current.amount).abs() < 0.01 &&
              !other.isReconciled) {
            updatedList[i] = current.copyWith(
              isReconciled: true,
              reconciledWithId: other.id,
            );
            updatedList[j] = other.copyWith(
              isReconciled: true,
              reconciledWithId: current.id,
            );
            break;
          }
        }
      }

      // 3. Card-payment <-> Bank-debit relationship detection
      // If a bank debit has payee or merchant matching "CRED", "CREDIT CARD", or the bank's card,
      // mark it as transfer/repayment to prevent double counting.
      if (current.type == TransactionType.debit) {
        final title = current.displayTitle.toLowerCase();
        if (title.contains('credit card') ||
            title.contains('cred') ||
            title.contains('card payment') ||
            title.contains('bill desk')) {
          updatedList[i] = current.copyWith(
            type: TransactionType.billPayment,
            category: 'Credit Card Payment',
          );
        }
      }
    }

    return updatedList;
  }

  /// Adjusts bill status for zero, negative, or no-payment-required bills.
  static Bill reconcileBill(Bill bill) {
    if (bill.totalAmount <= 0) {
      return bill.copyWith(status: BillStatus.noPaymentRequired);
    }
    return bill;
  }
}
