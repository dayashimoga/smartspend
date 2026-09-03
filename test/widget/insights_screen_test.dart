import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/insights/insights_screen.dart';

void main() {
  final sampleTxns = [
    ParsedTransaction(
      id: 'txn_1',
      rawSmsId: 'sms_1',
      type: TransactionType.purchase,
      bank: Bank.hdfc,
      amount: 3500.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 10),
      merchant: 'FreshMart',
      category: 'Groceries',
      confidence: Confidence.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ParsedTransaction(
      id: 'txn_2',
      rawSmsId: 'sms_2',
      type: TransactionType.purchase,
      bank: Bank.icici,
      amount: 1500.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 12),
      merchant: 'Fuel Station',
      category: 'Fuel',
      confidence: Confidence.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  const fullSummary = FinancialSummary(
    totalIncome: 65000.0,
    totalExpense: 5000.0,
    netCashFlow: 60000.0,
    totalAccountBalance: 75000.0,
    totalCardOutstanding: 5000.0,
    totalAvailableCredit: 195000.0,
    needsReviewCount: 0,
    upcomingBillsCount: 0,
    upcomingBillsTotal: 0.0,
    currency: 'INR',
  );

  final emptySummary = FinancialSummary.empty();

  group('InsightsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders charts, ratios, time filter, and category breakdowns',
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
            allTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
          ],
          child: const MaterialApp(
            home: InsightsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Financial Insights'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.textContaining('Income vs Spend Ratio'), findsOneWidget);
      expect(find.textContaining('Spending by Category'), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('Fuel'), findsWidgets);

      // Tap on Groceries category
      await tester.tap(find.text('Groceries').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FreshMart'), findsOneWidget);
    });

    testWidgets('Renders cleanly when no expenses recorded', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.value(emptySummary)),
            allTransactionsProvider.overrideWith((ref) => Future.value([])),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: InsightsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Financial Insights'), findsOneWidget);
      expect(find.textContaining('Income vs Spend Ratio'), findsOneWidget);
      expect(find.textContaining('Spending by Category'), findsNothing);
    });

    testWidgets('Renders error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financialSummaryProvider
                .overrideWith((ref) => Future.error('DB_ERROR')),
            filteredFinancialSummaryProvider
                .overrideWith((ref) => Future.error('DB_ERROR')),
            allTransactionsProvider
                .overrideWith((ref) => Future.error('DB_ERROR')),
            filteredTransactionsProvider
                .overrideWith((ref) => Future.error('DB_ERROR')),
          ],
          child: const MaterialApp(
            home: InsightsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_ERROR'), findsWidgets);
    });
  });
}
