import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../providers/app_providers.dart';
import '../../widgets/transaction_tile.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String? _selectedDrillCategory;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final txnsAsync = ref.watch(allTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Income vs Expense Comparison Bar
          summaryAsync.when(
            data: (summary) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Income vs Spend Ratio',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (summary.totalIncome > summary.totalExpense
                                        ? summary.totalIncome
                                        : summary.totalExpense) *
                                    1.2 +
                                100,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                  final label =
                                      groupIndex == 0 ? 'Income' : 'Spend';
                                  return BarTooltipItem(
                                    '$label\n${AmountParser.format(rod.toY, currency: summary.currency)}',
                                    const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    return Text(
                                      val == 0 ? 'Income' : 'Spend',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: summary.totalIncome,
                                    color: AppColors.income,
                                    width: 38,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [
                                  BarChartRodData(
                                    toY: summary.totalExpense,
                                    color: AppColors.expense,
                                    width: 38,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
          const SizedBox(height: 16),

          // Category Breakdown
          txnsAsync.when(
            data: (txns) {
              // Group spending by category
              final Map<String, double> categorySpend = {};
              for (final t in txns) {
                if (t.type.isExpense && !t.isExcluded) {
                  categorySpend[t.category] =
                      (categorySpend[t.category] ?? 0.0) + t.amount;
                }
              }

              if (categorySpend.isEmpty) {
                return const SizedBox.shrink();
              }

              final totalSpend =
                  categorySpend.values.fold(0.0, (a, b) => a + b);
              final colors = [
                AppColors.primary,
                AppColors.accent,
                AppColors.warning,
                AppColors.expense,
                const Color(0xFF8B5CF6),
                const Color(0xFFEC4899),
                const Color(0xFF14B8A6),
              ];

              int colorIdx = 0;
              final sections = categorySpend.entries.map((entry) {
                final pct =
                    totalSpend > 0 ? (entry.value / totalSpend) * 100.0 : 0.0;
                final color = colors[colorIdx++ % colors.length];
                final isSelected = _selectedDrillCategory == entry.key;

                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: isSelected ? 65 : 55,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                );
              }).toList();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spending by Category (Tap to Drill Down)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, pieTouchResponse) {
                                if (event is FlTapUpEvent &&
                                    pieTouchResponse?.touchedSection != null) {
                                  final touchedIndex = pieTouchResponse!
                                      .touchedSection!.touchedSectionIndex;
                                  if (touchedIndex >= 0 &&
                                      touchedIndex <
                                          categorySpend.keys.length) {
                                    final catKey = categorySpend.keys
                                        .elementAt(touchedIndex);
                                    setState(() {
                                      _selectedDrillCategory =
                                          (_selectedDrillCategory == catKey)
                                              ? null
                                              : catKey;
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Legend
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: categorySpend.entries.map((e) {
                          final isSelected = _selectedDrillCategory == e.key;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDrillCategory =
                                    isSelected ? null : e.key;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${AmountParser.format(e.value)})',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),

          // Drill down transactions list
          if (_selectedDrillCategory != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions in "$_selectedDrillCategory"',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDrillCategory = null;
                    });
                  },
                  child: const Text('Clear Filter'),
                ),
              ],
            ),
            txnsAsync.when(
              data: (txns) {
                final filtered = txns
                    .where((t) => t.category == _selectedDrillCategory)
                    .toList();
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    return TransactionTile(transaction: filtered[idx]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ],
      ),
    );
  }
}
