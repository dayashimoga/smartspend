import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/models/time_period.dart';
import 'package:smartspend/presentation/widgets/time_period_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimePeriodSelector Widget Tests', () {
    final testDate = DateTime(2026, 9, 3);

    testWidgets('Renders all presets and navigation buttons', (tester) async {
      final period = TimePeriod.thisMonth(testDate);
      TimePeriod? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimePeriodSelector(
              period: period,
              onPeriodChanged: (p) => selected = p,
            ),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap 'Today' chip
      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(selected, isNotNull);
      expect(selected!.preset, equals(TimePeriodPreset.today));

      // Tap 'Week' chip
      await tester.tap(find.text('Week'));
      await tester.pump();
      expect(selected!.preset, equals(TimePeriodPreset.week));

      // Tap 'Year' chip
      await tester.tap(find.text('Year'));
      await tester.pump();
      expect(selected!.preset, equals(TimePeriodPreset.year));

      // Tap previous arrow
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(selected, isNotNull);
    });

    testWidgets('Tapping Custom opens DateRangePicker dialog', (tester) async {
      final period = TimePeriod.thisMonth(testDate);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimePeriodSelector(
              period: period,
              onPeriodChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // DateRangePicker should appear with 'Save' or close icon
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });
  });
}
