import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

enum TimePeriodPreset {
  today,
  week,
  month,
  year,
  custom,
}

class TimePeriod extends Equatable {
  final DateTime startDate;
  final DateTime endDate;
  final TimePeriodPreset preset;

  const TimePeriod({
    required this.startDate,
    required this.endDate,
    required this.preset,
  });

  factory TimePeriod.today([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return TimePeriod(
      startDate: start,
      endDate: end,
      preset: TimePeriodPreset.today,
    );
  }

  factory TimePeriod.thisWeek([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    // Monday is 1, Sunday is 7
    final daysFromMonday = now.weekday - 1;
    final monday = now.subtract(Duration(days: daysFromMonday));
    final start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
    final sunday = start.add(const Duration(days: 6));
    final end =
        DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999);
    return TimePeriod(
      startDate: start,
      endDate: end,
      preset: TimePeriodPreset.week,
    );
  }

  factory TimePeriod.thisMonth([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final start = DateTime(now.year, now.month, 1, 0, 0, 0);
    // Last day of month is day 0 of next month
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final end = DateTime(now.year, now.month, lastDay.day, 23, 59, 59, 999);
    return TimePeriod(
      startDate: start,
      endDate: end,
      preset: TimePeriodPreset.month,
    );
  }

  factory TimePeriod.thisYear([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final start = DateTime(now.year, 1, 1, 0, 0, 0);
    final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    return TimePeriod(
      startDate: start,
      endDate: end,
      preset: TimePeriodPreset.year,
    );
  }

  factory TimePeriod.custom(DateTime start, DateTime end) {
    final earliest = start.isBefore(end) ? start : end;
    final latest = start.isBefore(end) ? end : start;
    final s = DateTime(earliest.year, earliest.month, earliest.day, 0, 0, 0);
    final e = DateTime(latest.year, latest.month, latest.day, 23, 59, 59, 999);
    return TimePeriod(
      startDate: s,
      endDate: e,
      preset: TimePeriodPreset.custom,
    );
  }

  TimePeriod previous() {
    switch (preset) {
      case TimePeriodPreset.today:
        final prevDay = startDate.subtract(const Duration(days: 1));
        return TimePeriod.today(prevDay);
      case TimePeriodPreset.week:
        final prevWeek = startDate.subtract(const Duration(days: 7));
        return TimePeriod.thisWeek(prevWeek);
      case TimePeriodPreset.month:
        final prevMonth = DateTime(startDate.year, startDate.month - 1, 1);
        return TimePeriod.thisMonth(prevMonth);
      case TimePeriodPreset.year:
        final prevYear = DateTime(startDate.year - 1, 1, 1);
        return TimePeriod.thisYear(prevYear);
      case TimePeriodPreset.custom:
        final diff = endDate.difference(startDate);
        final newEnd = startDate.subtract(const Duration(milliseconds: 1));
        final newStart = newEnd.subtract(diff);
        return TimePeriod.custom(newStart, newEnd);
    }
  }

  TimePeriod next() {
    switch (preset) {
      case TimePeriodPreset.today:
        final nextDay = startDate.add(const Duration(days: 1));
        return TimePeriod.today(nextDay);
      case TimePeriodPreset.week:
        final nextWeek = startDate.add(const Duration(days: 7));
        return TimePeriod.thisWeek(nextWeek);
      case TimePeriodPreset.month:
        final nextMonth = DateTime(startDate.year, startDate.month + 1, 1);
        return TimePeriod.thisMonth(nextMonth);
      case TimePeriodPreset.year:
        final nextYear = DateTime(startDate.year + 1, 1, 1);
        return TimePeriod.thisYear(nextYear);
      case TimePeriodPreset.custom:
        final diff = endDate.difference(startDate);
        final newStart = endDate.add(const Duration(milliseconds: 1));
        final newEnd = newStart.add(diff);
        return TimePeriod.custom(newStart, newEnd);
    }
  }

  bool get canGoNext {
    final now = DateTime.now();
    return endDate.isBefore(now);
  }

  String get displayLabel {
    switch (preset) {
      case TimePeriodPreset.today:
        final now = DateTime.now();
        if (startDate.year == now.year &&
            startDate.month == now.month &&
            startDate.day == now.day) {
          return 'Today (${DateFormat('dd MMM').format(startDate)})';
        }
        return DateFormat('dd MMM yyyy').format(startDate);
      case TimePeriodPreset.week:
        return '${DateFormat('dd MMM').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
      case TimePeriodPreset.month:
        return DateFormat('MMMM yyyy').format(startDate);
      case TimePeriodPreset.year:
        return 'Year ${startDate.year}';
      case TimePeriodPreset.custom:
        return '${DateFormat('dd MMM yy').format(startDate)} - ${DateFormat('dd MMM yy').format(endDate)}';
    }
  }

  @override
  List<Object?> get props => [startDate, endDate, preset];
}
