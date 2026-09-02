import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/sms_datasource.dart';
import '../../providers/app_providers.dart';
import '../../widgets/summary_cards.dart';
import '../../widgets/transaction_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final recentAsync = ref.watch(recentTransactionsProvider);
    final isSyncing = ref.watch(isSyncingProvider);
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
            const Text('SmartSpend'),
          ],
        ),
        actions: [
          IconButton(
            icon: isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync SMS',
            onPressed: isSyncing
                ? null
                : () async {
                    ref.read(isSyncingProvider.notifier).state = true;
                    try {
                      final hasPerm = await SmsDatasource.hasPermissions();
                      if (!hasPerm) {
                        await SmsDatasource.requestPermissions();
                      }
                      final messages = await SmsDatasource.readInboxSms();
                      if (messages.isNotEmpty) {
                        final useCase = ref.read(ingestSmsUseCaseProvider);
                        await useCase.execute(messages);
                      }
                      // Refresh providers
                      ref.invalidate(financialSummaryProvider);
                      ref.invalidate(recentTransactionsProvider);
                      ref.invalidate(allTransactionsProvider);
                      ref.invalidate(accountsProvider);
                      ref.invalidate(cardsProvider);
                      ref.invalidate(billsProvider);
                      ref.invalidate(needsReviewTransactionsProvider);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Sync completed successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sync notice: $e')),
                        );
                      }
                    } finally {
                      ref.read(isSyncingProvider.notifier).state = false;
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Financial Summary
            summaryAsync.when(
              data: (summary) => Column(
                children: [
                  SummaryCards(summary: summary),

                  // Needs Review alert banner if applicable
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
                                  '${summary.needsReviewCount} transaction(s) need your review',
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

                  // Upcoming Bills alert banner if applicable
                  if (summary.upcomingBillsCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/bills'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long,
                                  color: AppColors.info, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${summary.upcomingBillsCount} upcoming credit card bills due',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.info),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.info, size: 18),
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

            // Recent Transactions Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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

            // Recent Transactions List
            recentAsync.when(
              data: (txns) {
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
                            'No transactions ingested yet',
                            style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Sync SMS" above or rescan in settings',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txns.length,
                  itemBuilder: (context, index) {
                    final txn = txns[index];
                    return TransactionTile(
                      transaction: txn,
                      onTap: () {
                        _showTransactionDetail(context, txn);
                      },
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
