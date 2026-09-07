import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/entities/parsed_transaction.dart';
import '../../providers/app_providers.dart';
import '../../widgets/budget_card.dart';
import '../../widgets/time_period_selector.dart';
import '../../widgets/transaction_tile.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String? _selectedDrillCategory;
  String _chartTimeframe =
      'Day-wise'; // 'Day-wise', 'Week-wise', 'Month-wise', 'Year-wise'

  Map<String, double> _buildTimeframeSpend(
      List<ParsedTransaction> txns, String timeframe) {
    final now = DateTime.now();
    final expenseTxns =
        txns.where((t) => t.type.isExpense && !t.isExcluded).toList();
    final map = <String, double>{};

    if (timeframe == 'Day-wise') {
      final recentDays = <DateTime>[];
      for (int i = 6; i >= 0; i--) {
        recentDays.add(now.subtract(Duration(days: i)));
      }
      for (final d in recentDays) {
        final label = DateFormat('dd MMM').format(d);
        map[label] = 0.0;
      }
      for (final t in expenseTxns) {
        final label = DateFormat('dd MMM').format(t.transactionDate);
        if (map.containsKey(label)) {
          map[label] = map[label]! + t.amount;
        } else {
          final isSameMonth = t.transactionDate.month == now.month &&
              t.transactionDate.year == now.year;
          if (isSameMonth) {
            map[label] = (map[label] ?? 0.0) + t.amount;
          }
        }
      }
    } else if (timeframe == 'Week-wise') {
      map['W1'] = 0.0;
      map['W2'] = 0.0;
      map['W3'] = 0.0;
      map['W4'] = 0.0;
      map['W5'] = 0.0;
      for (final t in expenseTxns) {
        final day = t.transactionDate.day;
        final weekIdx = ((day - 1) ~/ 7) + 1;
        final key = 'W${weekIdx.clamp(1, 5)}';
        map[key] = (map[key] ?? 0.0) + t.amount;
      }
    } else if (timeframe == 'Month-wise') {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final maxMonth = now.month;
      for (int i = 0; i < maxMonth; i++) {
        map[months[i]] = 0.0;
      }
      for (final t in expenseTxns) {
        if (t.transactionDate.year == now.year) {
          final mIndex = t.transactionDate.month - 1;
          if (mIndex >= 0 && mIndex < months.length) {
            final key = months[mIndex];
            map[key] = (map[key] ?? 0.0) + t.amount;
          }
        }
      }
    } else if (timeframe == 'Year-wise') {
      map['${now.year - 1}'] = 0.0;
      map['${now.year}'] = 0.0;
      for (final t in expenseTxns) {
        final yStr = '${t.transactionDate.year}';
        map[yStr] = (map[yStr] ?? 0.0) + t.amount;
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedTimePeriodProvider);
    final summaryAsync = ref.watch(filteredFinancialSummaryProvider);
    final txnsAsync = ref.watch(filteredTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Time Period Selector
          TimePeriodSelector(
            period: period,
            onPeriodChanged: (newPeriod) {
              ref.read(selectedTimePeriodProvider.notifier).state = newPeriod;
            },
          ),
          const SizedBox(height: 8),

          // Income vs Expense Comparison Bar
          summaryAsync.when(
            data: (summary) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Income vs Spend Ratio (${period.displayLabel})',
                            style: const TextStyle(
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
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
          const SizedBox(height: 12),

          // Multi-Timeframe Spend Breakdown Bar Chart
          txnsAsync.when(
            data: (txns) {
              final spendMap = _buildTimeframeSpend(txns, _chartTimeframe);
              final maxSpend = spendMap.values.isEmpty
                  ? 100.0
                  : spendMap.values.fold(0.0, (a, b) => a > b ? a : b);
              final totalChartSpend =
                  spendMap.values.fold(0.0, (sum, val) => sum + val);

              final barGroups = <BarChartGroupData>[];
              int idx = 0;
              for (final entry in spendMap.entries) {
                barGroups.add(
                  BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: AppColors.expense,
                        width: spendMap.length > 7 ? 16 : 28,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                );
                idx++;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spend Totals ($_chartTimeframe)',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              AmountParser.format(totalChartSpend,
                                  currency: 'INR'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Timeframe switcher chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Day-wise',
                              'Week-wise',
                              'Month-wise',
                              'Year-wise'
                            ].map((tf) {
                              final isSelected = _chartTimeframe == tf;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(
                                    tf,
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
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (_) {
                                    setState(() {
                                      _chartTimeframe = tf;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (maxSpend * 1.25) + 100,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                    final label = spendMap.keys
                                        .elementAt(group.x.toInt());
                                    return BarTooltipItem(
                                      '$label\n${AmountParser.format(rod.toY, currency: 'INR')}',
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
                                      final index = val.toInt();
                                      if (index >= 0 &&
                                          index < spendMap.length) {
                                        final label =
                                            spendMap.keys.elementAt(index);
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: barGroups,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Monthly Budget Card
          const BudgetCard(),
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

                final showTitle = pct >= 5.0;
                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: showTitle ? '${pct.toStringAsFixed(0)}%' : '',
                  showTitle: showTitle,
                  radius: isSelected ? 65 : 55,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
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
