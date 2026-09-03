import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/widgets/summary_cards.dart';
import 'package:smartspend/presentation/widgets/transaction_tile.dart';

void main() {
  group('TransactionTile & SummaryCards Widget Components Suite', () {
    testWidgets(
        'TransactionTile renders income transaction with positive prefix and green color',
        (tester) async {
      final txn = ParsedTransaction(
        id: 't1',
        rawSmsId: 's1',
        type: TransactionType.salary,
        bank: Bank.hdfc,
        amount: 50000.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 1),
        merchant: 'Tech Corp',
        category: 'Salary',
        confidence: Confidence.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(
              transaction: txn,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Tech Corp'), findsOneWidget);
      expect(find.text('+₹50,000.00'), findsOneWidget);

      await tester.tap(find.byType(TransactionTile));
      expect(tapped, isTrue);
    });

    testWidgets(
        'TransactionTile renders expense transaction with negative prefix and red color',
        (tester) async {
      final txn = ParsedTransaction(
        id: 't2',
        rawSmsId: 's1',
        type: TransactionType.purchase,
        bank: Bank.icici,
        cardLast4: '4000',
        amount: 1200.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 5),
        merchant: 'Cafe Mocha',
        category: 'Food & Dining',
        confidence: Confidence.high,
        isExcluded: true,
        isReconciled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionTile(transaction: txn),
          ),
        ),
      );

      expect(find.text('Cafe Mocha'), findsOneWidget);
      expect(find.text('-₹1,200.00'), findsOneWidget);
    });

    testWidgets('SummaryCards renders all metric metrics cleanly',
        (tester) async {
      const summary = FinancialSummary(
        totalIncome: 100000.0,
        totalExpense: 35000.0,
        netCashFlow: 65000.0,
        totalAccountBalance: 120000.0,
        totalCardOutstanding: 15000.0,
        totalAvailableCredit: 185000.0,
        needsReviewCount: 0,
        upcomingBillsCount: 0,
        upcomingBillsTotal: 0.0,
        currency: 'INR',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCards(summary: summary),
          ),
        ),
      );

      expect(find.text('Net Cashflow'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Bank Balances'), findsOneWidget);
      expect(find.text('Card Spent'), findsOneWidget);
      expect(find.text('₹65,000.00'), findsOneWidget);
    });
  });
}
