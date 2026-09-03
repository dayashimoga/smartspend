import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/transactions/transactions_screen.dart';

void main() {
  final sampleTxns = [
    ParsedTransaction(
      id: 'txn_1',
      rawSmsId: 'sms_1',
      type: TransactionType.purchase,
      bank: Bank.icici,
      cardLast4: '4000',
      amount: 499.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 10),
      merchant: 'Amazon Shopping',
      category: 'Shopping',
      confidence: Confidence.high,
      reference: 'UPI123456',
      balance: 15000.0,
      availableLimit: 195000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ParsedTransaction(
      id: 'txn_2',
      rawSmsId: 'sms_2',
      type: TransactionType.salary,
      bank: Bank.hdfc,
      accountLast4: '0564',
      amount: 90000.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 1),
      merchant: 'Corporate Salary',
      category: 'Salary',
      confidence: Confidence.high,
      reference: 'NEFT999',
      balance: 95000.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    ParsedTransaction(
      id: 'txn_3',
      rawSmsId: 'sms_3',
      type: TransactionType.fastag,
      bank: Bank.sbi,
      amount: 150.0,
      currency: 'INR',
      transactionDate: DateTime(2026, 1, 12),
      merchant: 'KIAL Toll Plaza',
      category: 'Travel & Toll',
      confidence: Confidence.medium,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  group('TransactionsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders transaction list and opens detail modal on tap',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Amazon Shopping'), findsOneWidget);
      expect(find.text('Corporate Salary'), findsOneWidget);
      expect(find.text('KIAL Toll Plaza'), findsOneWidget);

      // Tap on Amazon Shopping tile to open detail bottom sheet
      await tester.tap(find.text('Amazon Shopping'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify detail sheet content
      expect(find.text('Reference / UPI'), findsOneWidget);
      expect(find.text('UPI123456'), findsOneWidget);
      expect(find.text('Available Limit'), findsOneWidget);
      expect(find.text('•••• 4000'), findsWidgets);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Reference / UPI'), findsNothing);
    });

    testWidgets(
        'Filters list by search query and shows empty state when none match',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Amazon');
      await tester.pump();

      expect(find.text('Amazon Shopping'), findsOneWidget);
      expect(find.text('Corporate Salary'), findsNothing);
      expect(find.text('KIAL Toll Plaza'), findsNothing);

      // Enter query with zero matches
      await tester.enterText(find.byType(TextField), 'NonExistentMerchantXYZ');
      await tester.pump();

      expect(find.text('No matching transactions found'), findsOneWidget);
    });

    testWidgets('Filters list using filter chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsProvider
                .overrideWith((ref) => Future.value(sampleTxns)),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Salary' chip
      await tester.tap(find.text('Salary').first);
      await tester.pump();

      expect(find.text('Corporate Salary'), findsOneWidget);
      expect(find.text('Amazon Shopping'), findsNothing);

      // Tap 'All' chip to reset
      await tester.tap(find.text('All'));
      await tester.pump();

      expect(find.text('Amazon Shopping'), findsOneWidget);
      expect(find.text('Corporate Salary'), findsOneWidget);
    });

    testWidgets('Renders error state on failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allTransactionsProvider
                .overrideWith((ref) => Future.error('DB_READ_ERROR')),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_READ_ERROR'), findsOneWidget);
    });
  });
}
