import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/budget.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/widgets/budget_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BudgetCard Comprehensive UI Test Suite', () {
    final now = DateTime.now();

    testWidgets('Renders empty budget state and opens set budget modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyBudgetProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BudgetCard(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Monthly Budget'), findsOneWidget);
      expect(find.text('Set Budget'), findsOneWidget);
      expect(
          find.text(
              'No budget set for this month. Set a spending limit to stay in control.'),
          findsOneWidget);
      expect(find.text('Set Monthly Budget'), findsOneWidget);

      // Open set budget modal
      await tester.tap(find.text('Set Budget'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
          find.text(
              'Enter your total monthly spending target for all expenses.'),
          findsOneWidget);
      expect(find.text('₹20k'), findsOneWidget);
      expect(find.text('₹50k'), findsOneWidget);
      expect(find.text('Save Budget'), findsOneWidget);

      // Tap preset chip
      await tester.tap(find.text('₹30k'));
      await tester.pump();

      // Tap Save
      await tester.tap(find.text('Save Budget'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Renders active budget within limit with room to spend',
        (tester) async {
      final budget = Budget(
        id: 'b1',
        category: 'Overall',
        month: now.month,
        year: now.year,
        monthlyLimit: 50000.0,
        currentSpend: 32000.0,
        currency: 'INR',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyBudgetProvider.overrideWith((ref) => Future.value(budget)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BudgetCard(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Monthly Budget'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Spent This Month'), findsOneWidget);
      expect(find.text('₹32,000.00'), findsOneWidget);
      expect(find.text('Budget Limit'), findsOneWidget);
      expect(find.text('₹50,000.00'), findsOneWidget);
      expect(
          find.textContaining('18,000.00 room left to spend'), findsOneWidget);

      // Tap Edit button
      await tester.tap(find.text('Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Monthly Budget'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit Monthly Budget'), findsNothing);
    });

    testWidgets('Renders exceeded budget alert when spending exceeds limit',
        (tester) async {
      final exceededBudget = Budget(
        id: 'b2',
        category: 'Overall',
        month: now.month,
        year: now.year,
        monthlyLimit: 40000.0,
        currentSpend: 47500.0,
        currency: 'INR',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyBudgetProvider
                .overrideWith((ref) => Future.value(exceededBudget)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BudgetCard(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('₹47,500.00'), findsOneWidget);
      expect(find.text('₹40,000.00'), findsOneWidget);
      expect(
          find.textContaining('Budget crossed by ₹7,500.00!'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
