import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../providers/app_providers.dart';
import '../../widgets/budget_card.dart';
import '../../widgets/ingestion_progress_banner.dart';
import '../../widgets/summary_cards.dart';
import '../../widgets/time_period_selector.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/upcoming_bills_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _recentPeriod = 'Daily'; // 'Daily', 'Weekly', 'Monthly', 'Yearly'

  double _calculatePeriodTotal(List<ParsedTransaction> txns, String period) {
    final now = DateTime.now();
    double total = 0.0;
    for (final t in txns) {
      if (!t.type.isExpense || t.isExcluded) continue;
      final d = t.transactionDate;
      if (period == 'Daily') {
        if (d.year == now.year && d.month == now.month && d.day == now.day) {
          total += t.amount;
        }
      } else if (period == 'Weekly') {
        if (now.difference(d).inDays < 7 && !d.isAfter(now)) {
          total += t.amount;
        }
      } else if (period == 'Monthly') {
        if (d.year == now.year && d.month == now.month) {
          total += t.amount;
        }
      } else if (period == 'Yearly') {
        if (d.year == now.year) {
          total += t.amount;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedTimePeriodProvider);
    final summaryAsync = ref.watch(filteredFinancialSummaryProvider);
    final txnsAsync = ref.watch(filteredTransactionsProvider);
    final billsAsync = ref.watch(filteredBillsProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final ingestionProgress = ref.watch(ingestionControllerProvider);
    final ingestionNotifier = ref.read(ingestionControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SmartSpend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: isSyncing || ingestionProgress.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync SMS',
            onPressed: isSyncing || ingestionProgress.isBusy
                ? null
                : () async {
                    ref.read(isSyncingProvider.notifier).state = true;
                    try {
                      final service =
                          ref.read(incrementalIngestionServiceProvider);
                      await service.startIngestion();
                    } finally {
                      ref.read(isSyncingProvider.notifier).state = false;
                      ref.invalidate(filteredFinancialSummaryProvider);
                      ref.invalidate(filteredTransactionsProvider);
                      ref.invalidate(recentTransactionsProvider);
                      ref.invalidate(allTransactionsProvider);
                      ref.invalidate(filteredBillsProvider);
                      ref.invalidate(filteredAccountsProvider);
                      ref.invalidate(filteredCardsProvider);
                      ref.invalidate(monthlyBudgetProvider);
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ingestion Progress Banner
            IngestionProgressBanner(
              progress: ingestionProgress,
              onPause: ingestionNotifier.pause,
              onResume: ingestionNotifier.resume,
              onCancel: ingestionNotifier.cancel,
              onRetry: ingestionNotifier.retry,
            ),

            // Time Period Selector
            TimePeriodSelector(
              period: period,
              onPeriodChanged: (newPeriod) {
                ref.read(selectedTimePeriodProvider.notifier).state = newPeriod;
              },
            ),

            // Financial Summary
            summaryAsync.when(
              data: (summary) => Column(
                children: [
                  SummaryCards(
                    summary: summary,
                    isUpdating: ingestionProgress.isBusy || isSyncing,
                  ),
                  if (summary.needsReviewCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.go('/review'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppColors.warning, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${summary.needsReviewCount} unresolved transaction(s) excluded from totals',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.warning),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.warning, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading summary: $err'),
              ),
            ),

            // Monthly Budget Card
            const BudgetCard(),

            // Prominent Upcoming Bills Section before Recent Transactions
            billsAsync.when(
              data: (bills) => UpcomingBillsCard(
                bills: bills,
                onViewAll: () => context.push('/bills'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Recent Transactions Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),

            // Period Total Badges & Timeframe Switcher
            txnsAsync.when(
              data: (allTxns) {
                final deduplicated = TransactionRepository.deduplicate(allTxns);
                final periodTotal =
                    _calculatePeriodTotal(deduplicated, _recentPeriod);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Timeframe selector chips
                        ...['Daily', 'Weekly', 'Monthly', 'Yearly'].map((p) {
                          final isSelected = _recentPeriod == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(p,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  )),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 0),
                              onSelected: (_) {
                                setState(() {
                                  _recentPeriod = p;
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 8),

                        // Period Total Display
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.expense.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '$_recentPeriod Total: ${AmountParser.format(periodTotal, currency: 'INR')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Recent Transactions List (Grouped by Day)
            txnsAsync.when(
              data: (allTxns) {
                final deduplicated = TransactionRepository.deduplicate(allTxns);
                final txns = deduplicated.take(15).toList();
                if (txns.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions in this period',
                            style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group transactions by calendar day
                final now = DateTime.now();
                final grouped = <String, List<ParsedTransaction>>{};
                for (final t in txns) {
                  final key =
                      DateFormat('yyyy-MM-dd').format(t.transactionDate);
                  grouped.putIfAbsent(key, () => []).add(t);
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grouped.length,
                  itemBuilder: (context, groupIndex) {
                    final dateKey = grouped.keys.elementAt(groupIndex);
                    final dayTxns = grouped[dateKey]!;
                    final firstDate = dayTxns.first.transactionDate;

                    final isToday = firstDate.year == now.year &&
                        firstDate.month == now.month &&
                        firstDate.day == now.day;
                    final isYesterday = firstDate.year == now.year &&
                        firstDate.month == now.month &&
                        firstDate.day == now.day - 1;

                    final dateLabel = isToday
                        ? 'Today, ${DateFormat('dd MMM').format(firstDate)}'
                        : (isYesterday
                            ? 'Yesterday, ${DateFormat('dd MMM').format(firstDate)}'
                            : DateFormat('EEE, dd MMM yyyy').format(firstDate));

                    // Day expense total
                    final dayTotal = dayTxns
                        .where((t) => t.type.isExpense && !t.isExcluded)
                        .fold(0.0, (sum, t) => sum + t.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Day Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              if (dayTotal > 0)
                                Text(
                                  'Day Total: ${AmountParser.format(dayTotal, currency: 'INR')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...dayTxns.map((txn) => TransactionTile(
                              transaction: txn,
                              onTap: () => _showTransactionDetail(context, txn),
                            )),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading transactions: $err'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, dynamic txn) {
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
