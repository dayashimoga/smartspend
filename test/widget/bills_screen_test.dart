import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/bills/bills_screen.dart';

void main() {
  final sampleBills = [
    Bill(
      id: 'bill_1',
      bank: Bank.icici,
      cardLast4: '4000',
      totalAmount: 3494.78,
      minimumAmount: 180.0,
      dueDate: DateTime(2026, 2, 5),
      status: BillStatus.unpaid,
      currency: 'INR',
      createdAt: DateTime.now(),
    ),
    Bill(
      id: 'bill_2',
      bank: Bank.hdfc,
      cardLast4: '9999',
      totalAmount: 12500.0,
      minimumAmount: 650.0,
      dueDate: DateTime(2026, 1, 20),
      status: BillStatus.paid,
      currency: 'INR',
      createdAt: DateTime.now(),
    ),
  ];

  group('BillsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders bills list with status chips and due dates',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billsProvider.overrideWith((ref) => Future.value(sampleBills)),
          ],
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bills & Statements'), findsOneWidget);
      expect(find.text('ICICI Bank Card'), findsOneWidget);
      expect(find.text('HDFC Bank Card'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('Renders empty state when no bills exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No credit card bills detected'), findsOneWidget);
      expect(find.text('Bill statements will automatically appear here'),
          findsOneWidget);
    });

    testWidgets('Renders error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billsProvider.overrideWith((ref) => Future.error('DB_READ_ERROR')),
          ],
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_READ_ERROR'), findsOneWidget);
    });
  });
}
