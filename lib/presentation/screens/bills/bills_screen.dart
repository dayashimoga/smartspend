import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../domain/entities/bill.dart';
import '../../providers/app_providers.dart';
import '../../widgets/time_period_selector.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  String _statusFilter =
      'All'; // 'All', 'Upcoming', 'Due Today', 'Overdue', 'Partial', 'Paid'

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedTimePeriodProvider);
    final billsAsync = ref.watch(filteredBillsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & Statements'),
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

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildStatusChip('All'),
                const SizedBox(width: 6),
                _buildStatusChip('Upcoming'),
                const SizedBox(width: 6),
                _buildStatusChip('Due Today'),
                const SizedBox(width: 6),
                _buildStatusChip('Overdue'),
                const SizedBox(width: 6),
                _buildStatusChip('Partial'),
                const SizedBox(width: 6),
                _buildStatusChip('Paid'),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Bills List
          Expanded(
            child: billsAsync.when(
              data: (bills) {
                var filtered = bills.where((bill) {
                  if (_statusFilter == 'All') return true;
                  switch (_statusFilter) {
                    case 'Upcoming':
                      return bill.effectiveStatus == BillStatus.unpaid;
                    case 'Due Today':
                      return bill.effectiveStatus == BillStatus.dueToday;
                    case 'Overdue':
                      return bill.effectiveStatus == BillStatus.overdue;
                    case 'Partial':
                      return bill.effectiveStatus == BillStatus.partial;
                    case 'Paid':
                      return bill.effectiveStatus == BillStatus.paid ||
                          bill.effectiveStatus == BillStatus.noPaymentRequired;
                    default:
                      return true;
                  }
                }).toList();

                // Sort: Overdue/Due Today first, then Upcoming, then Paid
                filtered.sort((a, b) {
                  final aPaid = a.effectiveStatus == BillStatus.paid ||
                      a.effectiveStatus == BillStatus.noPaymentRequired;
                  final bPaid = b.effectiveStatus == BillStatus.paid ||
                      b.effectiveStatus == BillStatus.noPaymentRequired;
                  if (aPaid != bPaid) return aPaid ? 1 : -1;
                  return a.dueDate.compareTo(b.dueDate);
                });

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
                          _statusFilter == 'All'
                              ? 'No bills found for this period'
                              : 'No $_statusFilter bills found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Switch time period or status filter above',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final bill = filtered[index];
                    return _buildBillCard(context, bill, isDark);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('Error loading bills: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _statusFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _statusFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Bill bill, bool isDark) {
    final status = bill.effectiveStatus;
    Color statusColor;
    Color statusBg;

    switch (status) {
      case BillStatus.overdue:
        statusColor = AppColors.danger;
        statusBg = AppColors.danger.withValues(alpha: 0.15);
        break;
      case BillStatus.dueToday:
        statusColor = Colors.deepOrange;
        statusBg = Colors.deepOrange.withValues(alpha: 0.15);
        break;
      case BillStatus.partial:
        statusColor = AppColors.warning;
        statusBg = AppColors.warning.withValues(alpha: 0.15);
        break;
      case BillStatus.paid:
      case BillStatus.noPaymentRequired:
        statusColor = AppColors.success;
        statusBg = AppColors.success.withValues(alpha: 0.15);
        break;
      case BillStatus.unpaid:
        statusColor = AppColors.info;
        statusBg = AppColors.info.withValues(alpha: 0.15);
        break;
    }

    final dueDateStr = DateFormat('dd MMM yyyy').format(bill.dueDate);
    final asOnStr = DateFormat('dd MMM yyyy, hh:mm a').format(bill.asOnDate);

    String daysBadge;
    if (status == BillStatus.paid || status == BillStatus.noPaymentRequired) {
      daysBadge = 'Paid';
    } else if (bill.daysUntilDue < 0) {
      daysBadge = '${bill.daysUntilDue.abs()} days overdue';
    } else if (bill.daysUntilDue == 0) {
      daysBadge = 'Due today!';
    } else {
      daysBadge = '${bill.daysUntilDue} days left';
    }

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
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long,
                          color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.billerDisplayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
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
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.displayName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Amounts & Due Date Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Due Date',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      dueDateStr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: bill.daysUntilDue <= 0 &&
                                status != BillStatus.paid &&
                                status != BillStatus.noPaymentRequired
                            ? AppColors.danger
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                    Text(
                      daysBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (bill.minimumAmount > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Min Due',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        AmountParser.format(bill.minimumAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Remaining Due',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      AmountParser.format(bill.remainingAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: status == BillStatus.paid ||
                                status == BillStatus.noPaymentRequired
                            ? AppColors.success
                            : AppColors.expense,
                      ),
                    ),
                    if (bill.paidAmount > 0)
                      Text(
                        'Paid: ${AmountParser.format(bill.paidAmount)} of ${AmountParser.format(bill.totalAmount)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.success),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Footer: As on date and Reminder Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'As on: $asOnStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                if (status != BillStatus.paid &&
                    status != BillStatus.noPaymentRequired)
                  TextButton.icon(
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 16),
                    label:
                        const Text('Reminder', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _showReminderDialog(context, bill),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderDialog(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set Reminder for ${bill.billerDisplayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Due: ${DateFormat('dd MMM yyyy').format(bill.dueDate)}'),
              const SizedBox(height: 12),
              const Text('Notify me before due date:'),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                title: const Text('1 day before'),
                leading: const Icon(Icons.alarm),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmReminder(1);
                },
              ),
              ListTile(
                dense: true,
                title: const Text('3 days before'),
                leading: const Icon(Icons.alarm),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmReminder(3);
                },
              ),
              ListTile(
                dense: true,
                title: const Text('5 days before'),
                leading: const Icon(Icons.alarm),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmReminder(5);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _confirmReminder(int days) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder scheduled for $days day(s) before due date'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
