import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/ingestion_state.dart';

class IngestionDiagnosticsModal extends StatelessWidget {
  final IngestionProgress progress;
  final VoidCallback? onRetry;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const IngestionDiagnosticsModal({
    super.key,
    required this.progress,
    this.onRetry,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  static void show(
    BuildContext context, {
    required IngestionProgress progress,
    VoidCallback? onRetry,
    VoidCallback? onPause,
    VoidCallback? onResume,
    VoidCallback? onCancel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IngestionDiagnosticsModal(
        progress: progress,
        onRetry: onRetry,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not yet';
    return DateFormat('dd MMM yyyy, hh:mm:ss a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131B2E) : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Import Diagnostics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Status & Progress indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _statusIcon(progress.stage),
                        const SizedBox(width: 8),
                        Text(
                          progress.stage.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _statusColor(progress.stage),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      progress.isIndeterminate
                          ? '${progress.scannedCount} scanned'
                          : '${progress.progressPercentage.toStringAsFixed(0)}% (${progress.scannedCount}/${progress.totalCount})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: progress.isIndeterminate && progress.isBusy
                      ? const LinearProgressIndicator(minHeight: 6)
                      : LinearProgressIndicator(
                          value: progress.progressPercentage / 100.0,
                          minHeight: 6,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Diagnostics Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              children: [
                _metricTile('Total Scanned', '${progress.scannedCount}',
                    Icons.filter_list_outlined, isDark),
                _metricTile('Financial SMS', '${progress.financialCount}',
                    Icons.attach_money, isDark,
                    color: AppColors.income),
                _metricTile('Transactions', '${progress.transactionsCount}',
                    Icons.receipt_long_outlined, isDark),
                _metricTile('Bills Detected', '${progress.billsCount}',
                    Icons.calendar_today_outlined, isDark),
                _metricTile('Balances Updated', '${progress.balancesCount}',
                    Icons.account_balance_wallet_outlined, isDark),
                _metricTile('Duplicates Skipped', '${progress.duplicatesCount}',
                    Icons.copy_outlined, isDark,
                    color: Colors.grey),
                _metricTile('Ignored (OTP/Promo)', '${progress.ignoredCount}',
                    Icons.block_outlined, isDark,
                    color: Colors.grey),
                _metricTile('Needs Review', '${progress.reviewCount}',
                    Icons.warning_amber_rounded, isDark,
                    color: AppColors.warning),
              ],
            ),
          ),

          // Last Updated footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Last updated: ${_formatTime(progress.lastUpdated)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Error Banner if failed
          if (progress.errorMessage != null &&
              progress.stage == IngestionStage.failed) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.expense, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.errorMessage!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.expense),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons (Pause / Resume / Cancel / Retry)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (progress.canPause && onPause != null)
                OutlinedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pause'),
                ),
              if (progress.canResume && onResume != null)
                ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Resume'),
                ),
              if (progress.canCancel && onCancel != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel'),
                ),
              ],
              if (progress.canRetry && onRetry != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Failed'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, IconData icon, bool isDark,
      {Color? color}) {
    final effectiveColor = color ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: effectiveColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(IngestionStage stage) {
    switch (stage) {
      case IngestionStage.completed:
        return const Icon(Icons.check_circle,
            color: AppColors.income, size: 16);
      case IngestionStage.failed:
        return const Icon(Icons.error, color: AppColors.expense, size: 16);
      case IngestionStage.paused:
        return const Icon(Icons.pause_circle_filled,
            color: AppColors.warning, size: 16);
      default:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary),
        );
    }
  }

  Color _statusColor(IngestionStage stage) {
    switch (stage) {
      case IngestionStage.completed:
        return AppColors.income;
      case IngestionStage.failed:
        return AppColors.expense;
      case IngestionStage.paused:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}
