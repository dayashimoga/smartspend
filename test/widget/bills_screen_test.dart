import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/bills/bills_screen.dart';

void main() {
  final now = DateTime.now();
  final sampleBills = [
    Bill(
      id: 'bill_1',
      bank: Bank.icici,
      cardLast4: '4000',
      totalAmount: 3494.78,
      minimumAmount: 180.0,
      dueDate: now.add(const Duration(days: 4)),
      status: BillStatus.unpaid,
      currency: 'INR',
      createdAt: now,
    ),
    Bill(
      id: 'bill_2',
      bank: Bank.hdfc,
      cardLast4: '9999',
      totalAmount: 12500.0,
      minimumAmount: 650.0,
      paidAmount: 12500.0,
      dueDate: now.subtract(const Duration(days: 10)),
      status: BillStatus.paid,
      currency: 'INR',
      createdAt: now.subtract(const Duration(days: 20)),
    ),
  ];

  group('BillsScreen Comprehensive UI Test Suite', () {
    testWidgets('Renders bills list with status chips, reminders, and filters',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredBillsProvider
                .overrideWith((ref) => Future.value(sampleBills)),
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

      // Check filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget); // chip
      expect(find.text('Due'), findsOneWidget); // bill 1 badge
      expect(find.text('Paid'), findsWidgets);

      // Tap 'Upcoming' status chip
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      // Tap 'Reminder' button on bill 1
      expect(find.text('Reminder'), findsOneWidget);
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();

      // Check reminder dialog appears
      expect(find.textContaining('Set Reminder for ICICI Bank Card'),
          findsOneWidget);
      expect(find.text('3 days before'), findsOneWidget);

      // Select reminder
      await tester.tap(find.text('3 days before'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reminder scheduled for 3 day(s)'),
          findsOneWidget);
    });

    testWidgets('Renders empty state when no bills exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredBillsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No bills found for this period'), findsOneWidget);
    });

    testWidgets('Renders error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredBillsProvider
                .overrideWith((ref) => Future.error('DB_READ_ERROR')),
          ],
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error loading bills: DB_READ_ERROR'),
          findsOneWidget);
    });
  });
}
