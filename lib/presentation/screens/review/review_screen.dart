import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/confidence.dart';
import '../../providers/app_providers.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final Set<String> _selectedIds = {};
  String _selectedFilter = 'All'; // 'All', 'Unparsed', 'Low Confidence', 'Info'

  @override
  Widget build(BuildContext context) {
    final needsReviewAsync = ref.watch(needsReviewTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        actions: [
          if (_selectedIds.isNotEmpty) ...[
            TextButton.icon(
              icon: const Icon(Icons.block, size: 16, color: Colors.orange),
              label: Text(
                'Exclude (${_selectedIds.length})',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
              onPressed: () => _bulkExclude(context),
            ),
            TextButton.icon(
              icon: const Icon(Icons.check, size: 16, color: AppColors.primary),
              label: Text(
                'Approve (${_selectedIds.length})',
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
              onPressed: () => _bulkApprove(context),
            ),
          ],
        ],
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

          final filteredTxns = txns.where((t) {
            if (_selectedFilter == 'Unparsed') {
              return t.confidence == Confidence.unparsed;
            } else if (_selectedFilter == 'Low Confidence') {
              return t.confidence == Confidence.low;
            } else if (_selectedFilter == 'Info') {
              return t.category.contains('Alert') ||
                  t.category.contains('Info');
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Filter Chips & Select All Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', txns.length),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Unparsed',
                              txns
                                  .where((t) =>
                                      t.confidence == Confidence.unparsed)
                                  .length,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              'Low Confidence',
                              txns
                                  .where((t) => t.confidence == Confidence.low)
                                  .length,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == filteredTxns.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(filteredTxns.map((t) => t.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedIds.length == filteredTxns.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTxns.length,
                  itemBuilder: (context, index) {
                    final txn = filteredTxns[index];
                    final isSelected = _selectedIds.contains(txn.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with checkbox and confidence badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedIds.add(txn.id);
                                          } else {
                                            _selectedIds.remove(txn.id);
                                          }
                                        });
                                      },
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
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
                                  ],
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
                            const SizedBox(height: 8),

                            // Current Extracted Fields
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    txn.displayTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                                    _refreshData();
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
                                      reason:
                                          'User Approved as High Confidence',
                                    );
                                    _refreshData();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = label);
      },
    );
  }

  void _refreshData() {
    ref.invalidate(needsReviewTransactionsProvider);
    ref.invalidate(financialSummaryProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(recentTransactionsProvider);
  }

  Future<void> _bulkExclude(BuildContext context) async {
    final useCase = ref.read(correctionUseCaseProvider);
    for (final id in _selectedIds) {
      await useCase.setExcluded(id, true,
          reason: 'Bulk Excluded as Non-Financial');
    }
    final count = _selectedIds.length;
    setState(() => _selectedIds.clear());
    _refreshData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excluded $count item(s)')),
      );
    }
  }

  Future<void> _bulkApprove(BuildContext context) async {
    final useCase = ref.read(correctionUseCaseProvider);
    for (final id in _selectedIds) {
      await useCase.updateTransactionField(
        transactionId: id,
        fieldName: 'category',
        newValue: 'General',
        reason: 'Bulk Approved',
      );
    }
    final count = _selectedIds.length;
    setState(() => _selectedIds.clear());
    _refreshData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved $count item(s)')),
      );
    }
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
                _refreshData();
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
