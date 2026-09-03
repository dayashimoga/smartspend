import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/ingestion_state.dart';
import 'ingestion_diagnostics_modal.dart';

class IngestionProgressBanner extends StatelessWidget {
  final IngestionProgress progress;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const IngestionProgressBanner({
    super.key,
    required this.progress,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Only display when active or completed/failed/paused (not idle)
    if (progress.stage == IngestionStage.idle) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = progress.stage == IngestionStage.completed;
    final isFailed = progress.stage == IngestionStage.failed;
    final isPaused = progress.stage == IngestionStage.paused;

    final bannerBg = isCompleted
        ? AppColors.income.withValues(alpha: 0.12)
        : (isFailed
            ? AppColors.expense.withValues(alpha: 0.12)
            : (isPaused
                ? AppColors.warning.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.12)));

    final borderColor = isCompleted
        ? AppColors.income.withValues(alpha: 0.3)
        : (isFailed
            ? AppColors.expense.withValues(alpha: 0.3)
            : (isPaused
                ? AppColors.warning.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.3)));

    final accentColor = isCompleted
        ? AppColors.income
        : (isFailed
            ? AppColors.expense
            : (isPaused ? AppColors.warning : AppColors.primary));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Status icon + Description text + Dismiss/Close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_outline
                      : (isFailed
                          ? Icons.error_outline
                          : (isPaused
                              ? Icons.pause_circle_outline
                              : Icons.sync)),
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.displayText,
                      key: const Key('ingestion_progress_text'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 2),
                      Text(
                        'All records up to date. Tap Dismiss to close.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCompleted && onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          // Progress bar (when active or paused)
          if (!isCompleted && !isFailed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: progress.isIndeterminate && progress.isBusy
                  ? const LinearProgressIndicator(
                      minHeight: 4,
                      key: Key('ingestion_indeterminate_bar'),
                    )
                  : LinearProgressIndicator(
                      key: const Key('ingestion_progress_bar'),
                      value: progress.progressPercentage / 100.0,
                      minHeight: 4,
                      backgroundColor: accentColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
            ),
          ],

          const SizedBox(height: 10),

          // Actions Row: View Details + Pause/Resume/Cancel/Retry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  IngestionDiagnosticsModal.show(
                    context,
                    progress: progress,
                    onPause: onPause,
                    onResume: onResume,
                    onCancel: onCancel,
                    onRetry: onRetry,
                  );
                },
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text('View Details',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (progress.canPause && onPause != null)
                    IconButton(
                      icon: const Icon(Icons.pause, size: 18),
                      tooltip: 'Pause',
                      onPressed: onPause,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  if (progress.canResume && onResume != null)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      tooltip: 'Resume',
                      onPressed: onResume,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  if (progress.canCancel && onCancel != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.stop, size: 18),
                      tooltip: 'Cancel',
                      onPressed: onCancel,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  if (progress.canRetry && onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 14),
                      label:
                          const Text('Retry', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (isCompleted && onDismiss != null)
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('Dismiss',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
