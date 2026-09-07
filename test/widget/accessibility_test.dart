import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/dashboard/dashboard_screen.dart';

void main() {
  const sampleSummary = FinancialSummary(
    totalIncome: 75000.0,
    totalExpense: 12500.0,
    netCashFlow: 62500.0,
    totalAccountBalance: 85000.0,
    totalCardOutstanding: 12500.0,
    totalAvailableCredit: 187500.0,
    needsReviewCount: 0,
    upcomingBillsCount: 0,
    upcomingBillsTotal: 0.0,
    currency: 'INR',
  );

  group('Accessibility & TalkBack Forensic Suite', () {
    testWidgets(
        'DashboardScreen renders cleanly under 1.5x large font scaling without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value([])),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value([])),
            filteredBillsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(1.5),
              ),
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'No RenderFlex overflow under 1.5x font scaling');
      expect(find.text('Net Cashflow'), findsOneWidget);
    });

    testWidgets(
        'DashboardScreen renders cleanly under 2.0x accessibility font scaling',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value([])),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value([])),
            filteredBillsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'No RenderFlex overflow under 2.0x font scaling');
      expect(find.text('Net Cashflow'), findsOneWidget);
    });

    testWidgets(
        'Interactive action icons have >= 48x48 dp touch target semantics',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(sampleSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value([])),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value([])),
            filteredBillsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check sync button touch target size
      final syncIconFinder = find.byIcon(Icons.sync);
      final size = tester.getSize(syncIconFinder);
      expect(size.width, greaterThanOrEqualTo(20.0));
      expect(size.height, greaterThanOrEqualTo(20.0));

      // Verify IconButton parent size meets Android accessibility guidelines (48x48)
      final iconButtonFinder =
          find.ancestor(of: syncIconFinder, matching: find.byType(IconButton));
      final btnSize = tester.getSize(iconButtonFinder);
      expect(btnSize.width, greaterThanOrEqualTo(48.0));
      expect(btnSize.height, greaterThanOrEqualTo(48.0));
    });
  });
}
