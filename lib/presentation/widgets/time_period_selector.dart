import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/time_period.dart';

class TimePeriodSelector extends StatelessWidget {
  final TimePeriod period;
  final ValueChanged<TimePeriod> onPeriodChanged;

  const TimePeriodSelector({
    super.key,
    required this.period,
    required this.onPeriodChanged,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: DateTimeRange(
        start: period.startDate,
        end: period.endDate.isAfter(DateTime(now.year + 2, 12, 31))
            ? now
            : period.endDate,
      ),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.darkSurface,
                    onSurface: AppColors.darkTextPrimary,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    surface: AppColors.lightSurface,
                    onSurface: AppColors.lightTextPrimary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onPeriodChanged(TimePeriod.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Presets Segmented Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChip(context, 'Today', TimePeriodPreset.today),
                const SizedBox(width: 6),
                _buildChip(context, 'Week', TimePeriodPreset.week),
                const SizedBox(width: 6),
                _buildChip(context, 'Month', TimePeriodPreset.month),
                const SizedBox(width: 6),
                _buildChip(context, 'Year', TimePeriodPreset.year),
                const SizedBox(width: 6),
                _buildChip(context, 'Custom', TimePeriodPreset.custom),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Navigation Arrows and Display Label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Previous period',
                onPressed: () => onPeriodChanged(period.previous()),
              ),
              Expanded(
                child: Text(
                  period.displayLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Next period',
                onPressed: period.canGoNext
                    ? () => onPeriodChanged(period.next())
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
      BuildContext context, String label, TimePeriodPreset preset) {
    final isSelected = period.preset == preset;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (preset == TimePeriodPreset.custom) {
          _pickCustomRange(context);
        } else {
          switch (preset) {
            case TimePeriodPreset.today:
              onPeriodChanged(TimePeriod.today());
              break;
            case TimePeriodPreset.week:
              onPeriodChanged(TimePeriod.thisWeek());
              break;
            case TimePeriodPreset.month:
              onPeriodChanged(TimePeriod.thisMonth());
              break;
            case TimePeriodPreset.year:
              onPeriodChanged(TimePeriod.thisYear());
              break;
            case TimePeriodPreset.custom:
              break;
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
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
}
