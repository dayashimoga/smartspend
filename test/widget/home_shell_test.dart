import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/app.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/accounts/accounts_screen.dart';
import 'package:smartspend/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:smartspend/presentation/screens/insights/insights_screen.dart';
import 'package:smartspend/presentation/screens/review/review_screen.dart';
import 'package:smartspend/presentation/screens/transactions/transactions_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('HomeShell Bottom Navigation Forensic Suite', () {
    testWidgets('Switches tabs across all bottom navigation items',
        (tester) async {
      const summary = FinancialSummary(
        totalIncome: 10000.0,
        totalExpense: 2000.0,
        netCashFlow: 8000.0,
        totalAccountBalance: 50000.0,
        totalCardOutstanding: 5000.0,
        totalAvailableCredit: 95000.0,
        needsReviewCount: 1,
        upcomingBillsCount: 0,
        upcomingBillsTotal: 0.0,
        currency: 'INR',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
            financialSummaryProvider
                .overrideWith((ref) => Future.value(summary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(summary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value([])),
            allTransactionsProvider.overrideWith((ref) => Future.value([])),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value([])),
            accountsProvider.overrideWith((ref) => Future.value([])),
            filteredAccountsProvider.overrideWith((ref) => Future.value([])),
            cardsProvider.overrideWith((ref) => Future.value([])),
            filteredCardsProvider.overrideWith((ref) => Future.value([])),
            billsProvider.overrideWith((ref) => Future.value([])),
            filteredBillsProvider.overrideWith((ref) => Future.value([])),
            needsReviewTransactionsProvider
                .overrideWith((ref) => Future.value([])),
          ],
          child: const SmartSpendApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initial tab: Dashboard
      expect(find.text('SmartSpend'), findsOneWidget);

      // Tap Transactions
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionsScreen), findsOneWidget);

      // Tap Accounts
      await tester.tap(find.text('Accounts').last);
      await tester.pumpAndSettle();
      expect(find.byType(AccountsScreen), findsOneWidget);

      // Tap Insights
      await tester.tap(find.text('Insights').last);
      await tester.pumpAndSettle();
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Tap Review
      await tester.tap(find.text('Review').last);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewScreen), findsOneWidget);

      // Tap back to Dashboard
      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });
}
