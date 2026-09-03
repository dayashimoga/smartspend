import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/ingestion_state.dart';
import 'package:smartspend/presentation/widgets/ingestion_progress_banner.dart';

void main() {
  group('Ingestion UI & Diagnostics Widget Test Suite', () {
    testWidgets(
        'Renders progress banner in active state with accurate percentage and controls',
        (tester) async {
      bool pauseCalled = false;
      const progress = IngestionProgress(
        stage: IngestionStage.parsing,
        scannedCount: 200,
        totalCount: 400,
        transactionsCount: 150,
        billsCount: 8,
        accountsCount: 3,
        reviewCount: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngestionProgressBanner(
              progress: progress,
              onPause: () => pauseCalled = true,
            ),
          ),
        ),
      );

      // Verify text
      expect(
        find.text(
            'Analyzing SMS • 200/400 • 50% • 150 txns, 8 bills, 3 accounts, 2 review'),
        findsOneWidget,
      );

      // Verify progress bar exists
      expect(find.byKey(const Key('ingestion_progress_bar')), findsOneWidget);

      // Verify View Details button
      expect(find.text('View Details'), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byTooltip('Pause'));
      expect(pauseCalled, isTrue);
    });

    testWidgets('Renders indeterminate progress bar when totalCount is null',
        (tester) async {
      const progress = IngestionProgress(
        stage: IngestionStage.discovering,
        scannedCount: 75,
        totalCount: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IngestionProgressBanner(
              progress: progress,
            ),
          ),
        ),
      );

      expect(
          find.text(
              'Analyzing SMS • 75 scanned • 0 txns, 0 bills, 0 accounts, 0 review'),
          findsOneWidget);
      expect(
          find.byKey(const Key('ingestion_indeterminate_bar')), findsOneWidget);
    });

    testWidgets(
        'Tapping View Details opens IngestionDiagnosticsModal bottom sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const progress = IngestionProgress(
        stage: IngestionStage.reading,
        scannedCount: 100,
        totalCount: 200,
        financialCount: 85,
        transactionsCount: 80,
        billsCount: 4,
        accountsCount: 2,
        reviewCount: 1,
        duplicatesCount: 5,
        ignoredCount: 15,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IngestionProgressBanner(
              progress: progress,
            ),
          ),
        ),
      );

      await tester.tap(find.text('View Details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Import Diagnostics'), findsOneWidget);
      expect(find.text('Total Scanned'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Financial SMS'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text('Duplicates Skipped'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets(
        'Completion banner shows summary and Dismiss button triggers callback',
        (tester) async {
      bool dismissCalled = false;
      const progress = IngestionProgress(
        stage: IngestionStage.completed,
        scannedCount: 500,
        totalCount: 500,
        transactionsCount: 420,
        billsCount: 15,
        accountsCount: 4,
        reviewCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngestionProgressBanner(
              progress: progress,
              onDismiss: () => dismissCalled = true,
            ),
          ),
        ),
      );

      expect(
          find.text(
              'Sync Complete • 500 scanned • 420 txns, 15 bills, 4 accounts, 3 review'),
          findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      expect(dismissCalled, isTrue);
    });
  });
}
