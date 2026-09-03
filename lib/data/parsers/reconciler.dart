import '../../domain/entities/bill.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/transaction_type.dart';

class ReconciliationMatch {
  final ParsedTransaction updatedCurrent;
  final ParsedTransaction? matchedOther;

  const ReconciliationMatch({
    required this.updatedCurrent,
    this.matchedOther,
  });
}

class Reconciler {
  /// Reconciles an incoming transaction against historical candidates.
  static ReconciliationMatch reconcileSingle(
    ParsedTransaction incoming,
    List<ParsedTransaction> historicalCandidates,
  ) {
    var current = incoming;

    // 1. Detect Credit Card repayments from Bank Debits (Partial or Full)
    if (current.type == TransactionType.debit) {
      final title = current.displayTitle.toLowerCase();
      final body = current.merchant?.toLowerCase() ?? '';
      if (title.contains('credit card') ||
          title.contains('cred') ||
          title.contains('cheq') ||
          title.contains('card payment') ||
          title.contains('bill desk') ||
          title.contains('billdesk') ||
          body.contains('card payment') ||
          body.contains('credit card')) {
        current = current.copyWith(
          type: TransactionType.billPayment,
          category: 'Credit Card Payment',
        );
      }
    }

    // 2. Detect Card Credit from payment arrival (reconciles card statement with bank debit)
    if (current.type == TransactionType.credit) {
      final title = current.displayTitle.toLowerCase();
      if (title.contains('payment received') ||
          title.contains('card payment') ||
          title.contains('autopay received')) {
        current = current.copyWith(
          type: TransactionType.billPayment,
          category: 'Credit Card Payment',
        );
      }
    }

    // 3. Own-Account Transfer Detection (e.g. transfer between user's accounts within 4 hours)
    if (current.type == TransactionType.debit ||
        current.type == TransactionType.credit) {
      final isDebit = current.type == TransactionType.debit;
      final oppositeType =
          isDebit ? TransactionType.credit : TransactionType.debit;

      ParsedTransaction? transferCandidate;
      int bestTransferDiff = 4 * 3600 * 1000; // 4 hours in ms

      for (final other in historicalCandidates) {
        if (other.type == oppositeType &&
            (other.amount - current.amount).abs() < 0.01 &&
            !other.isReconciled &&
            (other.accountLast4 != current.accountLast4 ||
                other.bank != current.bank)) {
          final diff = (other.transactionDate.millisecondsSinceEpoch -
                  current.transactionDate.millisecondsSinceEpoch)
              .abs();
          if (diff < bestTransferDiff) {
            bestTransferDiff = diff;
            transferCandidate = other;
          }
        }
      }

      if (transferCandidate != null) {
        return ReconciliationMatch(
          updatedCurrent: current.copyWith(
            type: TransactionType.transfer,
            category: 'Transfer',
            isReconciled: true,
            reconciledWithId: transferCandidate.id,
          ),
          matchedOther: transferCandidate.copyWith(
            type: TransactionType.transfer,
            category: 'Transfer',
            isReconciled: true,
            reconciledWithId: current.id,
          ),
        );
      }
    }

    // 4. Refund Matching with Ambiguity Resolution (Exact ref > Merchant match > Timestamp proximity)
    if (current.type == TransactionType.refund && !current.isReconciled) {
      final bestPurchase = _findBestMatch(
        target: current,
        candidates: historicalCandidates,
        targetType: TransactionType.purchase,
        allowPartial: true,
      );

      if (bestPurchase != null) {
        return ReconciliationMatch(
          updatedCurrent: current.copyWith(
            isReconciled: true,
            reconciledWithId: bestPurchase.id,
          ),
          matchedOther: bestPurchase.copyWith(
            isReconciled: true,
            reconciledWithId: current.id,
          ),
        );
      }
    }

    // 5. Purchase Matching if refund arrived prior
    if (current.type == TransactionType.purchase && !current.isReconciled) {
      final bestRefund = _findBestMatch(
        target: current,
        candidates: historicalCandidates,
        targetType: TransactionType.refund,
        allowPartial: false,
      );

      if (bestRefund != null) {
        return ReconciliationMatch(
          updatedCurrent: current.copyWith(
            isReconciled: true,
            reconciledWithId: bestRefund.id,
          ),
          matchedOther: bestRefund.copyWith(
            isReconciled: true,
            reconciledWithId: current.id,
          ),
        );
      }
    }

    // 6. Reversal Matching (Failed ATM / UPI debit reversal)
    if (current.type == TransactionType.reversal && !current.isReconciled) {
      final bestDebit = _findBestMatch(
        target: current,
        candidates: historicalCandidates,
        targetType: TransactionType.debit,
        allowPartial: false,
      );

      if (bestDebit != null) {
        return ReconciliationMatch(
          updatedCurrent: current.copyWith(
            isReconciled: true,
            reconciledWithId: bestDebit.id,
          ),
          matchedOther: bestDebit.copyWith(
            isReconciled: true,
            reconciledWithId: current.id,
          ),
        );
      }
    }

    return ReconciliationMatch(updatedCurrent: current);
  }

  /// Finds best matching transaction resolving ambiguity among same-value transactions.
  static ParsedTransaction? _findBestMatch({
    required ParsedTransaction target,
    required List<ParsedTransaction> candidates,
    required TransactionType targetType,
    required bool allowPartial,
  }) {
    ParsedTransaction? bestCandidate;
    int highestScore = -1;

    for (final other in candidates) {
      if (other.isReconciled) continue;
      if (other.type != targetType) continue;

      // Card / Account must match if specified
      if (target.cardLast4 != null &&
          other.cardLast4 != null &&
          target.cardLast4 != other.cardLast4) {
        continue;
      }
      if (target.accountLast4 != null &&
          other.accountLast4 != null &&
          target.accountLast4 != other.accountLast4) {
        continue;
      }

      final amountDiff = (other.amount - target.amount).abs();
      final isExactAmount = amountDiff < 0.01;
      final isPartialRefund = allowPartial && target.amount <= other.amount;

      if (!isExactAmount && !isPartialRefund) continue;

      int score = 0;
      if (isExactAmount) score += 100;

      // Exact reference / RRN / UPI ref match
      if (target.reference != null &&
          other.reference != null &&
          target.reference!.isNotEmpty &&
          target.reference == other.reference) {
        score += 200;
      }
      if (target.rrn != null &&
          other.rrn != null &&
          target.rrn!.isNotEmpty &&
          target.rrn == other.rrn) {
        score += 200;
      }

      // Merchant match
      if (target.merchant != null &&
          other.merchant != null &&
          target.merchant!.isNotEmpty &&
          other.merchant!
              .toLowerCase()
              .contains(target.merchant!.toLowerCase())) {
        score += 50;
      }

      // Proximity score (within 30 days)
      final daysDiff =
          (target.transactionDate.difference(other.transactionDate).inHours)
                  .abs() /
              24.0;
      if (daysDiff <= 30) {
        score += (30 - daysDiff).toInt();
      }

      if (score > highestScore) {
        highestScore = score;
        bestCandidate = other;
      }
    }

    return bestCandidate;
  }

  /// Reconciles batch list of transactions.
  static List<ParsedTransaction> reconcileAll(List<ParsedTransaction> txns) {
    var result = List<ParsedTransaction>.from(txns);
    for (int i = 0; i < result.length; i++) {
      final current = result[i];
      final others = [
        for (int j = 0; j < result.length; j++)
          if (i != j) result[j]
      ];
      final match = reconcileSingle(current, others);
      result[i] = match.updatedCurrent;
      if (match.matchedOther != null) {
        final otherIdx =
            result.indexWhere((t) => t.id == match.matchedOther!.id);
        if (otherIdx >= 0) {
          result[otherIdx] = match.matchedOther!;
        }
      }
    }
    return result;
  }

  /// Adjusts bill status for zero, negative, or no-payment-required bills.
  static Bill reconcileBill(Bill bill) {
    if (bill.totalAmount <= 0) {
      return bill.copyWith(status: BillStatus.noPaymentRequired);
    }
    return bill;
  }
}
