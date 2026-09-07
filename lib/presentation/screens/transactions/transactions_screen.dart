import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/transaction_type.dart';
import '../../providers/app_providers.dart';
import '../../widgets/time_period_selector.dart';
import '../../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _searchQuery = '';
  String _instrumentView =
      'All Accounts'; // 'All Accounts', 'Bank Accounts', 'Credit Cards'
  TransactionType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedTimePeriodProvider);
    final txnsAsync = ref.watch(filteredTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: Column(
        children: [
          // Time Period Selector
          TimePeriodSelector(
            period: period,
            onPeriodChanged: (newPeriod) {
              ref.read(selectedTimePeriodProvider.notifier).state = newPeriod;
            },
          ),

          // Instrument View Switcher (All vs Bank Accounts vs Credit Cards)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: ['All Accounts', 'Bank Accounts', 'Credit Cards']
                    .map((view) {
                  final isSelected = _instrumentView == view;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _instrumentView = view;
                          _selectedType = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          view,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

          // Filter Chips tailored to current view
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _filterChip('All', null),
                const SizedBox(width: 8),
                if (_instrumentView != 'Credit Cards') ...[
                  _filterChip('Debits', TransactionType.debit),
                  const SizedBox(width: 8),
                ],
                if (_instrumentView != 'Bank Accounts') ...[
                  _filterChip('Card Spends', TransactionType.purchase),
                  const SizedBox(width: 8),
                ],
                _filterChip('Credits', TransactionType.credit),
                const SizedBox(width: 8),
                if (_instrumentView != 'Credit Cards') ...[
                  _filterChip('Salary', TransactionType.salary),
                  const SizedBox(width: 8),
                  _filterChip('UPI', TransactionType.upi),
                  const SizedBox(width: 8),
                  _filterChip('ATM', TransactionType.atm),
                  const SizedBox(width: 8),
                  _filterChip('FASTag', TransactionType.fastag),
                ],
                if (_instrumentView == 'Credit Cards') ...[
                  _filterChip('Refunds', TransactionType.refund),
                  const SizedBox(width: 8),
                  _filterChip('Payments', TransactionType.billPayment),
                ],
              ],
            ),
          ),

          // Transactions List & Summary Totals
          Expanded(
            child: txnsAsync.when(
              data: (rawTxns) {
                // Deduplicate items
                final txns = TransactionRepository.deduplicate(rawTxns);

                // Apply Instrument View Filter
                var filtered = txns;
                if (_instrumentView == 'Bank Accounts') {
                  filtered = filtered.where((t) {
                    final isCard = t.type == TransactionType.purchase ||
                        (t.cardLast4 != null && t.cardLast4!.isNotEmpty);
                    return !isCard;
                  }).toList();
                } else if (_instrumentView == 'Credit Cards') {
                  filtered = filtered.where((t) {
                    final isCard = t.type == TransactionType.purchase ||
                        (t.cardLast4 != null && t.cardLast4!.isNotEmpty);
                    return isCard;
                  }).toList();
                }

                // Apply type filter
                if (_selectedType != null) {
                  if (_selectedType == TransactionType.purchase) {
                    filtered = filtered
                        .where((t) =>
                            t.type == TransactionType.purchase ||
                            (t.cardLast4 != null &&
                                t.cardLast4!.isNotEmpty &&
                                t.type.isExpense))
                        .toList();
                  } else {
                    filtered =
                        filtered.where((t) => t.type == _selectedType).toList();
                  }
                }

                // Apply search query
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

                // Calculate Totals for this unique filtered set
                final totalSpent = filtered
                    .where((t) => t.type.isExpense && !t.isExcluded)
                    .fold(0.0, (sum, t) => sum + t.amount);
                final totalIncome = filtered
                    .where((t) => t.type.isIncome && !t.isExcluded)
                    .fold(0.0, (sum, t) => sum + t.amount);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
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

                return Column(
                  children: [
                    // Summary Total Bar for Current Filtered Set
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} Unique items',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Spent: ${AmountParser.format(totalSpent, currency: 'INR')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expense,
                                ),
                              ),
                              if (totalIncome > 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'Credits: ${AmountParser.format(totalIncome, currency: 'INR')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // List of Transactions
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final txn = filtered[index];
                          return TransactionTile(
                            transaction: txn,
                            onTap: () {
                              _showTransactionDetail(context, txn);
                            },
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
