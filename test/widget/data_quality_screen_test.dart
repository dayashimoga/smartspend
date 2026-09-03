import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/ingestion_checkpoint.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/settings/data_quality_screen.dart';

void main() {
  final testCheckpoint = IngestionCheckpoint(
    id: 'primary',
    lastSmsId: 'sms_100',
    lastTimestamp: DateTime(2026, 1, 15).millisecondsSinceEpoch,
    parserVersion: '1.0.0',
    batchOffset: 250,
    scannedCount: 250,
    financialCount: 230,
    transactionsCount: 220,
    billsCount: 10,
    accountsCount: 3,
    balancesCount: 45,
    duplicatesCount: 15,
    ignoredCount: 5,
    reviewCount: 2,
    failedCount: 0,
    lastUpdated: DateTime(2026, 1, 15),
    isCompleted: true,
  );

  final testHistory = [
    IngestionHistoryRecord(
      id: 'hist_1',
      startedAt: DateTime(2026, 1, 15, 10, 0),
      completedAt: DateTime(2026, 1, 15, 10, 2),
      status: 'completed',
      totalScanned: 250,
      financialCount: 230,
      transactionsCount: 220,
      billsCount: 10,
      balancesCount: 45,
      duplicatesCount: 15,
      ignoredCount: 5,
      reviewCount: 2,
      failedCount: 0,
      parserVersion: '1.0.0',
    ),
    IngestionHistoryRecord(
      id: 'hist_failed',
      startedAt: DateTime(2026, 1, 10, 9, 0),
      completedAt: DateTime(2026, 1, 10, 9, 1),
      status: 'failed',
      totalScanned: 50,
      financialCount: 40,
      transactionsCount: 35,
      billsCount: 2,
      balancesCount: 5,
      duplicatesCount: 0,
      ignoredCount: 10,
      reviewCount: 0,
      failedCount: 1,
      parserVersion: '1.0.0',
      errorMessage: 'Simulated inbox timeout',
    ),
  ];

  group('DataQualityScreen Widget Test Suite', () {
    testWidgets(
        'Renders engine health, checkpoint stats, history items and re-analyze modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ingestionCheckpointProvider
                .overrideWith((ref) => Future.value(testCheckpoint)),
            ingestionHistoryProvider
                .overrideWith((ref) => Future.value(testHistory)),
          ],
          child: const MaterialApp(
            home: DataQualityScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Data Quality & Ingestion'), findsOneWidget);
      expect(find.text('Parser Engine'), findsOneWidget);
      expect(find.text('Rule Pipeline v1.0.0'), findsOneWidget);
      expect(find.text('OPTIMAL'), findsOneWidget);

      // Verify diagnostics metrics
      expect(find.text('Total Scanned SMS'), findsOneWidget);
      expect(find.text('250'), findsWidgets);
      expect(find.text('Financial SMS'), findsOneWidget);
      expect(find.text('230'), findsOneWidget);
      expect(find.text('Transactions Parsed'), findsOneWidget);
      expect(find.text('220'), findsOneWidget);

      // Verify historical runs rendered
      expect(find.text('Ingestion History'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('Error: Simulated inbox timeout'), findsOneWidget);

      // Tap Re-analyze button
      await tester.tap(find.text('Re-analyze Historical SMS'));
      await tester.pumpAndSettle();

      expect(find.text('Re-analyze Historical SMS?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Re-analyze'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Re-analyze Historical SMS?'), findsNothing);
    });
  });
}
