import 'package:uuid/uuid.dart';
import '../../domain/entities/correction.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/bank.dart';
import '../../domain/enums/confidence.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/interfaces.dart';

class CorrectionUseCase {
  final ITransactionRepository _txnRepo;
  final ICorrectionRepository _correctionRepo;

  CorrectionUseCase({
    required ITransactionRepository txnRepo,
    required ICorrectionRepository correctionRepo,
  })  : _txnRepo = txnRepo,
        _correctionRepo = correctionRepo;

  /// Modifies fields on a transaction while recording an immutable audit log in corrections.
  Future<ParsedTransaction> updateTransactionField({
    required String transactionId,
    required String fieldName,
    required String newValue,
    String reason = 'User Edit',
  }) async {
    final txn = await _txnRepo.getTransactionById(transactionId);
    if (txn == null) throw Exception('Transaction not found: $transactionId');

    String? originalValue;
    ParsedTransaction updated = txn;

    switch (fieldName) {
      case 'merchant':
        originalValue = txn.merchant;
        updated = txn.copyWith(merchant: newValue, confidence: Confidence.high);
        break;
      case 'category':
        originalValue = txn.category;
        updated = txn.copyWith(category: newValue, confidence: Confidence.high);
        break;
      case 'amount':
        originalValue = txn.amount.toString();
        final amt = double.tryParse(newValue) ?? txn.amount;
        updated = txn.copyWith(amount: amt, confidence: Confidence.high);
        break;
      case 'type':
        originalValue = txn.type.name;
        final newType = TransactionType.values.firstWhere(
          (t) => t.name == newValue,
          orElse: () => txn.type,
        );
        updated = txn.copyWith(type: newType, confidence: Confidence.high);
        break;
      case 'bank':
        originalValue = txn.bank.name;
        final newBank = Bank.values.firstWhere(
          (b) => b.name == newValue,
          orElse: () => txn.bank,
        );
        updated = txn.copyWith(bank: newBank, confidence: Confidence.high);
        break;
      case 'accountLast4':
        originalValue = txn.accountLast4;
        updated =
            txn.copyWith(accountLast4: newValue, confidence: Confidence.high);
        break;
      case 'cardLast4':
        originalValue = txn.cardLast4;
        updated =
            txn.copyWith(cardLast4: newValue, confidence: Confidence.high);
        break;
    }

    // Save correction record
    final correction = Correction(
      id: const Uuid().v4(),
      transactionId: transactionId,
      fieldName: fieldName,
      originalValue: originalValue,
      correctedValue: newValue,
      reason: reason,
      appliedAt: DateTime.now(),
    );
    await _correctionRepo.saveCorrection(correction);

    // Save updated transaction
    await _txnRepo.updateTransaction(updated);
    return updated;
  }

  /// Toggles exclusion state (or marks as non-financial)
  Future<void> setExcluded(String transactionId, bool isExcluded,
      {String? reason}) async {
    final txn = await _txnRepo.getTransactionById(transactionId);
    if (txn == null) return;

    final updated = txn.copyWith(
      isExcluded: isExcluded,
      category: isExcluded ? 'Non-Financial' : txn.category,
      confidence: Confidence.high,
    );

    await _correctionRepo.saveCorrection(
      Correction(
        id: const Uuid().v4(),
        transactionId: transactionId,
        fieldName: 'is_excluded',
        originalValue: txn.isExcluded.toString(),
        correctedValue: isExcluded.toString(),
        reason: reason ??
            (isExcluded ? 'Marked Non-Financial / Excluded' : 'Restored'),
        appliedAt: DateTime.now(),
      ),
    );

    await _txnRepo.updateTransaction(updated);
  }

  /// Merges duplicate transactions by excluding the duplicate and linking it to the primary.
  Future<void> mergeDuplicates(String primaryId, String duplicateId) async {
    final primary = await _txnRepo.getTransactionById(primaryId);
    final duplicate = await _txnRepo.getTransactionById(duplicateId);
    if (primary == null || duplicate == null) return;

    final updatedDuplicate = duplicate.copyWith(
      isExcluded: true,
      isReconciled: true,
      reconciledWithId: primary.id,
      category: 'Duplicate Excluded',
    );

    await _txnRepo.updateTransaction(updatedDuplicate);

    await _correctionRepo.saveCorrection(
      Correction(
        id: const Uuid().v4(),
        transactionId: duplicateId,
        fieldName: 'merged_into',
        originalValue: null,
        correctedValue: primary.id,
        reason: 'User merged duplicate into ${primary.id}',
        appliedAt: DateTime.now(),
      ),
    );
  }

  /// Splits a transaction into two smaller transactions (e.g. personal + business split)
  Future<List<ParsedTransaction>> splitTransaction({
    required String transactionId,
    required double firstAmount,
    required String firstCategory,
    required double secondAmount,
    required String secondCategory,
  }) async {
    final txn = await _txnRepo.getTransactionById(transactionId);
    if (txn == null) throw Exception('Transaction not found: $transactionId');

    // Update original transaction with first amount
    final updatedFirst = txn.copyWith(
      amount: firstAmount,
      category: firstCategory,
      confidence: Confidence.high,
    );
    await _txnRepo.updateTransaction(updatedFirst);

    // Create new split child transaction
    final secondTxn = txn.copyWith(
      id: const Uuid().v4(),
      amount: secondAmount,
      category: secondCategory,
      confidence: Confidence.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _txnRepo.saveTransaction(secondTxn);

    await _correctionRepo.saveCorrection(
      Correction(
        id: const Uuid().v4(),
        transactionId: transactionId,
        fieldName: 'split_transaction',
        originalValue: txn.amount.toString(),
        correctedValue: '$firstAmount & $secondAmount',
        reason: 'Split transaction into 2 items',
        appliedAt: DateTime.now(),
      ),
    );

    return [updatedFirst, secondTxn];
  }
}
