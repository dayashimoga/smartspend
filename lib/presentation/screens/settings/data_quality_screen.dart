import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

class DataQualityScreen extends ConsumerWidget {
  const DataQualityScreen({super.key});

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkpointAsync = ref.watch(ingestionCheckpointProvider);
    final historyAsync = ref.watch(ingestionHistoryProvider);
    final ingestionProgress = ref.watch(ingestionControllerProvider);
    final ingestionNotifier = ref.read(ingestionControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Quality & Ingestion'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Parser Health Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.verified_outlined,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parser Engine',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Rule Pipeline v1.0.0',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'OPTIMAL',
                          style: TextStyle(
                            color: AppColors.income,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  checkpointAsync.when(
                    data: (cp) {
                      if (cp == null) {
                        return const Text(
                          'No ingestion runs recorded yet. Sync SMS from Dashboard to populate diagnostics.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        );
                      }
                      return Column(
                        children: [
                          _diagnosticRow(
                              'Total Scanned SMS', '${cp.scannedCount}'),
                          _diagnosticRow(
                              'Financial SMS', '${cp.financialCount}'),
                          _diagnosticRow(
                              'Transactions Parsed', '${cp.transactionsCount}'),
                          _diagnosticRow(
                              'Bills Discovered', '${cp.billsCount}'),
                          _diagnosticRow(
                              'Balances Updated', '${cp.balancesCount}'),
                          _diagnosticRow(
                              'Duplicates Skipped', '${cp.duplicatesCount}'),
                          _diagnosticRow(
                              'Ignored (OTP/Promo)', '${cp.ignoredCount}'),
                          _diagnosticRow(
                              'Flagged for Review', '${cp.reviewCount}'),
                          _diagnosticRow(
                              'Failed / Unparsed', '${cp.failedCount}'),
                          _diagnosticRow(
                              'Last Watermark Date',
                              cp.lastTimestamp > 0
                                  ? _formatDateTime(
                                      DateTime.fromMillisecondsSinceEpoch(
                                          cp.lastTimestamp))
                                  : 'Initial'),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error: $err'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          ElevatedButton.icon(
            onPressed: ingestionProgress.isBusy
                ? null
                : () => _confirmReanalyze(context, ingestionNotifier),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Re-analyze Historical SMS'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Ingestion History Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingestion History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh History',
                onPressed: () => ref.invalidate(ingestionHistoryProvider),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ingestion History List
          historyAsync.when(
            data: (history) {
              if (history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history,
                            size: 40,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No historical runs logged yet',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final record = history[index];
                  final isSuccess = record.status == 'completed';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isSuccess
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                    size: 16,
                                    color: isSuccess
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDateTime(record.startedAt),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isSuccess
                                          ? AppColors.income
                                          : AppColors.expense)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  record.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSuccess
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scanned: ${record.totalScanned} • Txns: ${record.transactionsCount} • Bills: ${record.billsCount} • Review: ${record.reviewCount} • Skipped: ${record.duplicatesCount}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          if (record.errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Error: ${record.errorMessage}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.expense),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
            error: (err, _) => Text('Error loading history: $err'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _diagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmReanalyze(BuildContext context, IngestionNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-analyze Historical SMS?'),
        content: const Text(
          'This will re-parse all saved SMS records using the latest rules and re-evaluate balances and bills. Existing user manual corrections are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.reanalyze();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Re-analysis started in background')),
              );
            },
            child: const Text('Re-analyze'),
          ),
        ],
      ),
    );
  }
}
