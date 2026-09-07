import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/amount_parser.dart';
import '../../domain/entities/budget.dart';
import '../providers/app_providers.dart';

class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetAsync = ref.watch(monthlyBudgetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return budgetAsync.when(
      data: (budget) => _buildCard(context, ref, budget, isDark),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(
      BuildContext context, WidgetRef ref, Budget? budget, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.track_changes_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Budget',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showBudgetDialog(context, ref, budget),
                icon: Icon(
                  budget != null
                      ? Icons.edit_outlined
                      : Icons.add_circle_outline,
                  size: 16,
                ),
                label: Text(budget != null ? 'Edit' : 'Set Budget'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          if (budget == null) ...[
            const SizedBox(height: 10),
            Text(
              'No budget set for this month. Set a spending limit to stay in control.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _showBudgetDialog(context, ref, null),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Set Monthly Budget'),
            ),
          ] else ...[
            const SizedBox(height: 12),
            // Spent vs Limit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spent This Month',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AmountParser.format(budget.currentSpend,
                          currency: budget.currency),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Budget Limit',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AmountParser.format(budget.monthlyLimit,
                          currency: budget.currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:
                    (budget.currentSpend / budget.monthlyLimit).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  budget.isExceeded
                      ? AppColors.expense
                      : (budget.progressPercentage > 80
                          ? AppColors.warning
                          : AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Room to spend / Exceeded Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: budget.isExceeded
                    ? AppColors.expense.withValues(alpha: 0.12)
                    : AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    budget.isExceeded
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                    size: 15,
                    color: budget.isExceeded
                        ? AppColors.expense
                        : AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    budget.isExceeded
                        ? 'Budget crossed by ${AmountParser.format(budget.currentSpend - budget.monthlyLimit, currency: budget.currency)}!'
                        : '${AmountParser.format(budget.remainingAmount, currency: budget.currency)} room left to spend',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: budget.isExceeded
                          ? AppColors.expense
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref, Budget? budget) {
    final controller = TextEditingController(
      text: budget != null ? budget.monthlyLimit.toStringAsFixed(0) : '50000',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    budget != null
                        ? 'Edit Monthly Budget'
                        : 'Set Monthly Budget',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your total monthly spending target for all expenses.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Monthly Budget Limit',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [20000, 30000, 50000, 75000, 100000].map((preset) {
                  return ActionChip(
                    label: Text('₹${preset ~/ 1000}k'),
                    onPressed: () {
                      controller.text = preset.toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(controller.text.trim());
                    if (val != null && val > 0) {
                      await ref
                          .read(budgetControllerProvider.notifier)
                          .setBudget(val);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                      }
                    }
                  },
                  child: const Text('Save Budget',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
