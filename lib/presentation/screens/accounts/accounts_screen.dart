import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../providers/app_providers.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final cardsAsync = ref.watch(cardsProvider);
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
        body: TabBarView(
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
                        Text('Accounts are automatically discovered from SMS',
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_balance,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
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
                                        fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  AmountParser.format(acct.currentBalance,
                                      currency: acct.currency),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.income),
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
                        Text('Cards are automatically discovered from SMS',
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.expense.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.credit_card,
                                          color: AppColors.expense, size: 22),
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
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors
                                                      .lightTextSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (card.outstanding != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Outstanding',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                        AmountParser.format(card.outstanding!,
                                            currency: card.currency),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.expense),
                                      ),
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
                                    'Available Limit: ${AmountParser.format(card.availableLimit!, currency: card.currency)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                  Text(
                                    '${card.utilizationPercentage.toStringAsFixed(1)}% Used',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: card.utilizationPercentage > 30
                                          ? AppColors.warning
                                          : AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: (card.utilizationPercentage / 100.0)
                                    .clamp(0.0, 1.0),
                                backgroundColor: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                                color: card.utilizationPercentage > 30
                                    ? AppColors.warning
                                    : AppColors.primary,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
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
          ],
        ),
      ),
    );
  }
}
