import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../providers/app_providers.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsReviewAsync = ref.watch(needsReviewTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
      ),
      body: needsReviewAsync.when(
        data: (txns) {
          if (txns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.income, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'All Caught Up!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No low-confidence or unparsed SMS in the queue',
                    style: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: txns.length,
            itemBuilder: (context, index) {
              final txn = txns[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with confidence badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              txn.confidence.displayName,
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            txn.bank.displayName,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Current Extracted Fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            txn.displayTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            AmountParser.format(txn.amount,
                                currency: txn.currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.expense),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${txn.category} • Type: ${txn.type.displayName}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Action Buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Edit Details',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () =>
                                _editTransaction(context, ref, txn),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.block, size: 14),
                            label: const Text('Non-Financial',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final useCase =
                                  ref.read(correctionUseCaseProvider);
                              await useCase.setExcluded(txn.id, true,
                                  reason: 'Marked Non-Financial');
                              ref.invalidate(needsReviewTransactionsProvider);
                              ref.invalidate(financialSummaryProvider);
                              ref.invalidate(allTransactionsProvider);
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Approve',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final useCase =
                                  ref.read(correctionUseCaseProvider);
                              await useCase.updateTransactionField(
                                transactionId: txn.id,
                                fieldName: 'category',
                                newValue: txn.category,
                                reason: 'User Approved as High Confidence',
                              );
                              ref.invalidate(needsReviewTransactionsProvider);
                              ref.invalidate(financialSummaryProvider);
                              ref.invalidate(allTransactionsProvider);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _editTransaction(
      BuildContext context, WidgetRef ref, ParsedTransaction txn) {
    final amountController = TextEditingController(text: txn.amount.toString());
    final merchantController =
        TextEditingController(text: txn.merchant ?? txn.payee ?? '');
    final categoryController = TextEditingController(text: txn.category);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: merchantController,
                  decoration:
                      const InputDecoration(labelText: 'Merchant / Payee'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final useCase = ref.read(correctionUseCaseProvider);
                if (merchantController.text.isNotEmpty) {
                  await useCase.updateTransactionField(
                    transactionId: txn.id,
                    fieldName: 'merchant',
                    newValue: merchantController.text.trim(),
                  );
                }
                if (amountController.text.isNotEmpty) {
                  await useCase.updateTransactionField(
                    transactionId: txn.id,
                    fieldName: 'amount',
                    newValue: amountController.text.trim(),
                  );
                }
                if (categoryController.text.isNotEmpty) {
                  await useCase.updateTransactionField(
                    transactionId: txn.id,
                    fieldName: 'category',
                    newValue: categoryController.text.trim(),
                  );
                }
                ref.invalidate(needsReviewTransactionsProvider);
                ref.invalidate(financialSummaryProvider);
                ref.invalidate(allTransactionsProvider);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save & Approve'),
            ),
          ],
        );
      },
    );
  }
}
