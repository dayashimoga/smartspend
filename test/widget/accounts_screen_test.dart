import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/accounts/accounts_screen.dart';

void main() {
  final sampleAccounts = [
    Account(
      id: 'acct_1',
      bank: Bank.hdfc,
      last4: '1234',
      accountType: 'Savings',
      currentBalance: 45000.0,
      currency: 'INR',
      lastUpdated: DateTime(2026, 1, 15),
    ),
    Account(
      id: 'acct_2',
      bank: Bank.icici,
      last4: '5678',
      accountType: 'Salary',
      currentBalance: 85000.0,
      currency: 'INR',
      lastUpdated: DateTime(2026, 1, 16),
    ),
  ];

  final sampleCards = [
    CreditCard(
      id: 'card_1',
      bank: Bank.icici,
      last4: '4000',
      availableLimit: 175000.0,
      totalLimit: 200000.0,
      outstanding: 25000.0,
      currency: 'INR',
      lastUpdated: DateTime(2026, 1, 18),
    ),
  ];

  group('AccountsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders bank accounts and credit cards across tabs',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider
                .overrideWith((ref) => Future.value(sampleAccounts)),
            cardsProvider.overrideWith((ref) => Future.value(sampleCards)),
          ],
          child: const MaterialApp(
            home: AccountsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Accounts & Cards'), findsOneWidget);
      expect(find.text('Bank Accounts'), findsOneWidget);
      expect(find.text('Credit Cards'), findsOneWidget);

      // Verify Bank Accounts Tab
      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('ICICI Bank'), findsOneWidget);

      // Switch to Credit Cards Tab
      await tester.tap(find.text('Credit Cards'));
      await tester.pumpAndSettle();

      // Verify Credit Cards Tab
      expect(find.text('•••• 4000'), findsOneWidget);
    });

    testWidgets('Renders empty states when no accounts or cards exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.value([])),
            cardsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: AccountsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No bank accounts detected yet'), findsOneWidget);

      // Switch to Cards tab
      await tester.tap(find.text('Credit Cards'));
      await tester.pumpAndSettle();

      expect(find.text('No credit cards detected yet'), findsOneWidget);
    });

    testWidgets('Renders error states gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsProvider.overrideWith((ref) => Future.error('DB_ERROR')),
            cardsProvider.overrideWith((ref) => Future.error('DB_ERROR')),
          ],
          child: const MaterialApp(
            home: AccountsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_ERROR'), findsOneWidget);
    });
  });
}
