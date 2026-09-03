import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/models/time_period.dart';

void main() {
  group('TimePeriod Model Unit Tests', () {
    final fixedDate = DateTime(2026, 9, 3, 14, 30); // Thursday, 3 Sep 2026

    test('today factory sets 00:00:00 to 23:59:59.999', () {
      final period = TimePeriod.today(fixedDate);
      expect(period.preset, equals(TimePeriodPreset.today));
      expect(period.startDate, equals(DateTime(2026, 9, 3, 0, 0, 0)));
      expect(period.endDate, equals(DateTime(2026, 9, 3, 23, 59, 59, 999)));
      expect(period.displayLabel, contains('Sep'));
    });

    test('thisWeek factory starts on Monday and ends on Sunday', () {
      final period = TimePeriod.thisWeek(fixedDate);
      expect(period.preset, equals(TimePeriodPreset.week));
      // 3 Sep 2026 is Thursday (weekday 4). Monday is 31 Aug 2026
      expect(period.startDate, equals(DateTime(2026, 8, 31, 0, 0, 0)));
      expect(period.endDate, equals(DateTime(2026, 9, 6, 23, 59, 59, 999)));
      expect(period.displayLabel, contains('31 Aug'));
    });

    test('thisMonth factory starts on 1st and ends on last day of month', () {
      final period = TimePeriod.thisMonth(fixedDate);
      expect(period.preset, equals(TimePeriodPreset.month));
      expect(period.startDate, equals(DateTime(2026, 9, 1, 0, 0, 0)));
      expect(period.endDate, equals(DateTime(2026, 9, 30, 23, 59, 59, 999)));
      expect(period.displayLabel, equals('September 2026'));
    });

    test('thisYear factory starts on Jan 1 and ends on Dec 31', () {
      final period = TimePeriod.thisYear(fixedDate);
      expect(period.preset, equals(TimePeriodPreset.year));
      expect(period.startDate, equals(DateTime(2026, 1, 1, 0, 0, 0)));
      expect(period.endDate, equals(DateTime(2026, 12, 31, 23, 59, 59, 999)));
      expect(period.displayLabel, equals('Year 2026'));
    });

    test('custom factory sorts start and end dates', () {
      final d1 = DateTime(2026, 5, 10);
      final d2 = DateTime(2026, 5, 20);
      final period = TimePeriod.custom(d2, d1); // inverted
      expect(period.preset, equals(TimePeriodPreset.custom));
      expect(period.startDate, equals(DateTime(2026, 5, 10, 0, 0, 0)));
      expect(period.endDate, equals(DateTime(2026, 5, 20, 23, 59, 59, 999)));
    });

    test('previous and next navigate correctly across months and years', () {
      final jan = TimePeriod.thisMonth(DateTime(2026, 1, 15));
      final prev = jan.previous();
      expect(prev.startDate.month, equals(12));
      expect(prev.startDate.year, equals(2025));

      final next = prev.next();
      expect(next.startDate.month, equals(1));
      expect(next.startDate.year, equals(2026));
    });

    test('previous and next for days, weeks, and years', () {
      final today = TimePeriod.today(fixedDate);
      final yesterday = today.previous();
      expect(yesterday.startDate.day, equals(2));
      final tomorrow = yesterday.next();
      expect(tomorrow.startDate.day, equals(3));

      final week = TimePeriod.thisWeek(fixedDate);
      final prevWeek = week.previous();
      expect(prevWeek.startDate, equals(DateTime(2026, 8, 24, 0, 0, 0)));
      final nextWeek = prevWeek.next();
      expect(nextWeek.startDate, equals(week.startDate));

      final year = TimePeriod.thisYear(fixedDate);
      final prevYear = year.previous();
      expect(prevYear.startDate.year, equals(2025));
      final nextYear = prevYear.next();
      expect(nextYear.startDate.year, equals(2026));
    });

    test('previous and next for custom period shifts by duration', () {
      final custom =
          TimePeriod.custom(DateTime(2026, 6, 1), DateTime(2026, 6, 10));
      final prev = custom.previous();
      expect(prev.endDate.isBefore(custom.startDate), isTrue);
      final next = prev.next();
      expect(next.startDate.day, equals(custom.startDate.day));
    });

    test(
        'canGoNext is true for past periods and false for future/current end dates',
        () {
      final pastMonth = TimePeriod.thisMonth(DateTime(2020, 1, 1));
      expect(pastMonth.canGoNext, isTrue);

      final futureYear = TimePeriod.thisYear(DateTime(2050, 1, 1));
      expect(futureYear.canGoNext, isFalse);
    });

    test('Equatable props comparison works', () {
      final p1 = TimePeriod.thisMonth(fixedDate);
      final p2 = TimePeriod.thisMonth(fixedDate);
      expect(p1, equals(p2));
    });
  });
}
