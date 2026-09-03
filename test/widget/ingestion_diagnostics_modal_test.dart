import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/ingestion_state.dart';
import 'package:smartspend/presentation/widgets/ingestion_diagnostics_modal.dart';

void main() {
  group('IngestionDiagnosticsModal Comprehensive Widget Tests', () {
    testWidgets(
        'Renders paused state, error banner, and invokes pause/resume/cancel/retry callbacks',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool pauseCalled = false;
      bool resumeCalled = false;
      bool cancelCalled = false;
      bool retryCalled = false;

      // 1. Paused state with resume & cancel
      final pausedProgress = IngestionProgress(
        stage: IngestionStage.paused,
        scannedCount: 40,
        totalCount: 100,
        transactionsCount: 30,
        billsCount: 2,
        accountsCount: 1,
        lastUpdated: DateTime(2026, 1, 15, 10, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngestionDiagnosticsModal(
              progress: pausedProgress,
              onResume: () => resumeCalled = true,
              onCancel: () => cancelCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      expect(resumeCalled, isTrue);

      await tester.tap(find.text('Cancel'));
      expect(cancelCalled, isTrue);

      // 2. Failed state with error banner and retry button
      final failedProgress = IngestionProgress(
        stage: IngestionStage.failed,
        scannedCount: 20,
        totalCount: 100,
        errorMessage: 'Database lock acquisition failed',
        lastUpdated: DateTime(2026, 1, 15, 10, 35),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngestionDiagnosticsModal(
              progress: failedProgress,
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Database lock acquisition failed'), findsOneWidget);
      expect(find.text('Retry Failed'), findsOneWidget);

      await tester.tap(find.text('Retry Failed'));
      expect(retryCalled, isTrue);

      // 3. Active state with pause button
      const activeProgress = IngestionProgress(
        stage: IngestionStage.parsing,
        scannedCount: 60,
        totalCount: 100,
        transactionsCount: 45,
        lastUpdated: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IngestionDiagnosticsModal(
              progress: activeProgress,
              onPause: () => pauseCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Last updated: Not yet'),
          findsOneWidget); // lastUpdated == null branch
      expect(find.text('Pause'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      expect(pauseCalled, isTrue);
    });
  });
}
