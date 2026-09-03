import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/dashboard/dashboard_screen.dart';

void main() {
  final now = DateTime.now();

  final sampleTxns = [
    ParsedTransaction(
      id: 'txn_dash_1',
      rawSmsId: 'sms_1',
      type: TransactionType.purchase,
      bank: Bank.hdfc,
      amount: 2500.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 5),
      merchant: 'Nature Basket',
      category: 'Groceries',
      confidence: Confidence.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ParsedTransaction(
      id: 'txn_dash_2',
      rawSmsId: 'sms_1',
      type: TransactionType.salary,
      bank: Bank.hdfc,
      amount: 85000.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 1),
      merchant: 'Employer Corp',
      category: 'Salary',
      confidence: Confidence.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final sampleBills = [
    Bill(
      id: 'bill_dash_1',
      bank: Bank.hdfc,
      cardLast4: '9137',
      totalAmount: 3494.78,
      dueDate: now.add(const Duration(days: 5)),
      createdAt: now,
    ),
  ];

  const fullSummary = FinancialSummary(
    totalIncome: 85000.0,
    totalExpense: 2500.0,
    netCashFlow: 82500.0,
    totalAccountBalance: 82500.0,
    totalCardOutstanding: 15000.0,
    totalAvailableCredit: 185000.0,
    needsReviewCount: 2,
    upcomingBillsCount: 1,
    upcomingBillsTotal: 3494.78,
    currency: 'INR',
  );

  final emptySummary = FinancialSummary.empty();

  group('DashboardScreen Comprehensive UI Test Suite', () {
    testWidgets(
        'Renders all summary metrics, banners, upcoming bills, and recent transactions in Dark Mode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith((ref) => ThemeMode.dark),
            financialSummaryProvider
                .overrideWith((ref) => Future.value(fullSummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(fullSummary)),
            recentTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
            filteredBillsProvider
                .overrideWith((ref) => Future.value(sampleBills)),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SmartSpend'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);

      // Verify TimePeriodSelector presets
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Verify Hero Summary and Cards
      expect(find.text('Net Cashflow'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Bank Balances'), findsOneWidget);
      expect(find.text('Card Spent'), findsOneWidget);

      // Verify Unresolved Warning Banner
      expect(find.text('2 unresolved transaction(s) excluded from totals'),
          findsOneWidget);

      // Verify Prominent Upcoming Bills Section
      expect(find.text('Upcoming Bills'), findsOneWidget);
      expect(find.text('HDFC Bank Card'), findsOneWidget);
      expect(find.text('•••• 9137'), findsOneWidget);

      // Verify Recent Transactions Section
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Nature Basket'), findsOneWidget);
      expect(find.text('Employer Corp'), findsOneWidget);

      // Tap sync button
      await tester.tap(find.byIcon(Icons.sync));
      await tester.pump();
    });

    testWidgets(
        'Renders in Light Mode and displays empty state when no transactions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith((ref) => ThemeMode.light),
            financialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
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

      expect(find.text('SmartSpend'), findsOneWidget);
      expect(find.text('Net Cashflow'), findsOneWidget);
      expect(find.text('No transactions in this period'), findsOneWidget);
      expect(find.text('2 unresolved transaction(s) excluded from totals'),
          findsNothing);
    });

    testWidgets('Renders loading spinner when isSyncing is active',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSyncingProvider.overrideWith((ref) => true),
            financialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'Tapping on a recent transaction opens detail modal and closes it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.value(fullSummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(fullSummary)),
            recentTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
            filteredBillsProvider
                .overrideWith((ref) => Future.value(sampleBills)),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Nature Basket'));
      await tester.pumpAndSettle();

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Confidence'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Confidence'), findsNothing);
    });
  });
}
