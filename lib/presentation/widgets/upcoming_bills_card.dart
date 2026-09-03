import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/amount_parser.dart';
import '../../domain/entities/bill.dart';

class UpcomingBillsCard extends StatelessWidget {
  final List<Bill> bills;
  final VoidCallback onViewAll;

  const UpcomingBillsCard({
    super.key,
    required this.bills,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter to active pending bills (unpaid, dueToday, partial, overdue)
    final pendingBills = bills
        .where((b) =>
            b.effectiveStatus != BillStatus.paid &&
            b.effectiveStatus != BillStatus.noPaymentRequired)
        .toList();

    // Sort by nearest due date first
    pendingBills.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (pendingBills.isEmpty) {
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Bills Due',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All credit card and detected bills are paid.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
          ],
        ),
      );
    }

    final totalDue =
        pendingBills.fold(0.0, (sum, b) => sum + b.remainingAmount);
    final nextBill = pendingBills.first;
    final nextDays = nextBill.daysUntilDue;

    String nextDueText;
    if (nextDays < 0) {
      nextDueText = '${nextDays.abs()}d overdue';
    } else if (nextDays == 0) {
      nextDueText = 'Due today';
    } else {
      nextDueText = 'Next due in ${nextDays}d';
    }

    final displayBills = pendingBills.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long,
                          color: AppColors.info, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming Bills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child:
                      const Text('View All →', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Compact Stats Badge: N bills • ₹X due • next due in Y days
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      '${pendingBills.length} bill${pendingBills.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Text('  •  ',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      '${AmountParser.format(totalDue)} due',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                    const Text('  •  ',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      nextDueText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: nextDays <= 0
                            ? AppColors.danger
                            : (nextDays <= 3
                                ? AppColors.warning
                                : AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Bills List (up to 3 items)
            ...displayBills
                .map((bill) => _buildBillItem(context, bill, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBillItem(BuildContext context, Bill bill, bool isDark) {
    final status = bill.effectiveStatus;
    Color statusColor;
    Color statusBg;

    switch (status) {
      case BillStatus.overdue:
        statusColor = AppColors.danger;
        statusBg = AppColors.danger.withValues(alpha: 0.12);
        break;
      case BillStatus.dueToday:
        statusColor = Colors.deepOrange;
        statusBg = Colors.deepOrange.withValues(alpha: 0.12);
        break;
      case BillStatus.partial:
        statusColor = AppColors.warning;
        statusBg = AppColors.warning.withValues(alpha: 0.12);
        break;
      case BillStatus.paid:
      case BillStatus.noPaymentRequired:
        statusColor = AppColors.success;
        statusBg = AppColors.success.withValues(alpha: 0.12);
        break;
      case BillStatus.unpaid:
        statusColor = AppColors.info;
        statusBg = AppColors.info.withValues(alpha: 0.12);
        break;
    }

    final dueDateStr = DateFormat('dd MMM yyyy').format(bill.dueDate);
    final asOnStr = DateFormat('dd MMM').format(bill.asOnDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.billerDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (bill.maskedTarget.isNotEmpty)
                      Text(
                        bill.maskedTarget,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getStatusBadgeText(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Amounts & Due Date Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AmountParser.format(bill.remainingAmount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (bill.paidAmount > 0)
                    Text(
                      'Paid: ${AmountParser.format(bill.paidAmount)} of ${AmountParser.format(bill.totalAmount)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.success),
                    )
                  else if (bill.minimumAmount > 0)
                    Text(
                      'Min due: ${AmountParser.format(bill.minimumAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Due: $dueDateStr',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bill.daysUntilDue <= 0
                          ? AppColors.danger
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                    ),
                  ),
                  Text(
                    'As on: $asOnStr',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusBadgeText(BillStatus status) {
    switch (status) {
      case BillStatus.unpaid:
        return 'UPCOMING';
      case BillStatus.dueToday:
        return 'DUE TODAY';
      case BillStatus.partial:
        return 'PARTIAL';
      case BillStatus.paid:
      case BillStatus.noPaymentRequired:
        return 'PAID';
      case BillStatus.overdue:
        return 'OVERDUE';
    }
  }
}
