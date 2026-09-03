import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../providers/app_providers.dart';
import '../../widgets/time_period_selector.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  String _formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedTimePeriodProvider);
    final accountsAsync = ref.watch(filteredAccountsProvider);
    final cardsAsync = ref.watch(filteredCardsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accounts & Cards'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'Bank Accounts'),
              Tab(text: 'Credit Cards'),
            ],
          ),
        ),
        body: Column(
          children: [
            TimePeriodSelector(
              period: period,
              onPeriodChanged: (newPeriod) {
                ref.read(selectedTimePeriodProvider.notifier).state = newPeriod;
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Bank Accounts Tab
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance_outlined,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                              const SizedBox(height: 12),
                              Text('No bank accounts detected yet',
                                  style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                  'Accounts are automatically discovered from SMS',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final acct = accounts[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.account_balance,
                                            color: AppColors.primary, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acct.bank.displayName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${acct.accountType} •••• ${acct.last4}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors
                                                        .darkTextSecondary
                                                    : AppColors
                                                        .lightTextSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'As on: ${_formatDate(acct.lastUpdated)}',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? AppColors.darkTextMuted
                                                    : AppColors.lightTextMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Balance',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        acct.isBalanceReliable
                                            ? AmountParser.format(
                                                acct.currentBalance,
                                                currency: acct.currency)
                                            : 'Unavailable',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: acct.isBalanceReliable
                                                ? AppColors.income
                                                : Colors.grey),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),

                  // Credit Cards Tab
                  cardsAsync.when(
                    data: (cards) {
                      if (cards.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card_outlined,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted),
                              const SizedBox(height: 12),
                              Text('No credit cards detected yet',
                                  style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                  'Cards are automatically discovered from SMS',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          final utilization = card.utilizationPercentage;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: AppColors.expense
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.credit_card,
                                                color: AppColors.expense,
                                                size: 22),
                                          ),
                                          const SizedBox(width: 14),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${card.bank.displayName} Card',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '•••• ${card.last4}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextSecondary
                                                        : AppColors
                                                            .lightTextSecondary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'As on: ${_formatDate(card.lastUpdated)}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextMuted
                                                        : AppColors
                                                            .lightTextMuted),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (card.outstanding != null ||
                                          card.statementDue != null)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              card.statementDue != null
                                                  ? 'Statement Due'
                                                  : 'Outstanding',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              AmountParser.format(
                                                  card.statementDue ??
                                                      card.outstanding!,
                                                  currency: card.currency),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: AppColors.expense),
                                            ),
                                            if (card.currentDue != null &&
                                                card.currentDue! > 0) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Min: ${AmountParser.format(card.currentDue!, currency: card.currency)}',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkTextMuted
                                                        : AppColors
                                                            .lightTextMuted),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (card.availableLimit != null) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Available: ${AmountParser.format(card.availableLimit!, currency: card.currency)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary),
                                        ),
                                        Text(
                                          utilization != null
                                              ? '${utilization.toStringAsFixed(1)}% Used'
                                              : 'Limit: Active',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: utilization == null
                                                ? AppColors.primary
                                                : (utilization > 30
                                                    ? AppColors.warning
                                                    : AppColors.income),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (utilization != null) ...[
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: (utilization / 100.0)
                                            .clamp(0.0, 1.0),
                                        backgroundColor: isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder,
                                        color: utilization > 30
                                            ? AppColors.warning
                                            : AppColors.primary,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
