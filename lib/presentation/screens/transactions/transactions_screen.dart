import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../providers/app_providers.dart';
import '../../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _searchQuery = '';
  TransactionType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(allTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search merchant, category, reference...',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor:
                    isDark ? AppColors.darkSurface : AppColors.lightSurface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip('All', null),
                const SizedBox(width: 8),
                _filterChip('Debits', TransactionType.debit),
                const SizedBox(width: 8),
                _filterChip('Card Spends', TransactionType.purchase),
                const SizedBox(width: 8),
                _filterChip('Credits', TransactionType.credit),
                const SizedBox(width: 8),
                _filterChip('Salary', TransactionType.salary),
                const SizedBox(width: 8),
                _filterChip('UPI', TransactionType.upi),
                const SizedBox(width: 8),
                _filterChip('ATM', TransactionType.atm),
                const SizedBox(width: 8),
                _filterChip('FASTag', TransactionType.fastag),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transactions List
          Expanded(
            child: txnsAsync.when(
              data: (txns) {
                // Apply local filters
                var filtered = txns;
                if (_selectedType != null) {
                  filtered =
                      filtered.where((t) => t.type == _selectedType).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered.where((t) {
                    final title = t.displayTitle.toLowerCase();
                    final cat = t.category.toLowerCase();
                    final ref = (t.reference ?? '').toLowerCase();
                    return title.contains(_searchQuery) ||
                        cat.contains(_searchQuery) ||
                        ref.contains(_searchQuery);
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No matching transactions found',
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final txn = filtered[index];
                    return TransactionTile(
                      transaction: txn,
                      onTap: () => _showTransactionDetail(context, txn),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TransactionType? type) {
    final isSelected = _selectedType == type;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void _showTransactionDetail(BuildContext context, ParsedTransaction txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    txn.displayTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _detailRow('Type', txn.type.displayName),
              _detailRow('Bank', txn.bank.displayName),
              _detailRow('Amount', '${txn.currency} ${txn.amount}'),
              if (txn.accountLast4 != null)
                _detailRow('Account', '•••• ${txn.accountLast4}'),
              if (txn.cardLast4 != null)
                _detailRow('Card', '•••• ${txn.cardLast4}'),
              if (txn.reference != null)
                _detailRow('Reference / UPI', txn.reference!),
              if (txn.balance != null)
                _detailRow(
                    'Available Balance', '${txn.currency} ${txn.balance}'),
              if (txn.availableLimit != null)
                _detailRow(
                    'Available Limit', '${txn.currency} ${txn.availableLimit}'),
              _detailRow('Category', txn.category),
              _detailRow('Confidence', txn.confidence.displayName),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
