import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/presentation/widgets/upcoming_bills_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpcomingBillsCard Widget Tests', () {
    final now = DateTime.now();

    testWidgets('Renders empty state cleanly when no pending bills',
        (tester) async {
      bool viewAllTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpcomingBillsCard(
              bills: const [],
              onViewAll: () => viewAllTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Bills Due'), findsOneWidget);
      expect(find.text('All credit card and detected bills are paid.'),
          findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      await tester.tap(find.text('View All'));
      await tester.pump();
      expect(viewAllTapped, isTrue);
    });

    testWidgets(
        'Renders compact stats header and bill items with status badges and countdown',
        (tester) async {
      bool viewAllTapped = false;

      final bill1 = Bill(
        id: 'b1',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 15000.0,
        minimumAmount: 1200.0,
        dueDate: now.add(const Duration(days: 3)),
        sourceDate: now.subtract(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final bill2 = Bill(
        id: 'b2',
        bank: Bank.axis,
        cardLast4: '9478',
        totalAmount: 8500.0,
        paidAmount: 2000.0,
        dueDate: now.add(const Duration(days: 10)),
        sourceDate: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpcomingBillsCard(
              bills: [bill1, bill2],
              onViewAll: () => viewAllTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Upcoming Bills'), findsOneWidget);
      expect(find.text('View All →'), findsOneWidget);

      // Check stats badge
      expect(find.textContaining('2 bills'), findsOneWidget);
      expect(find.textContaining('21,500.00 due'), findsOneWidget);
      expect(find.textContaining('Next due in 3d'), findsOneWidget);

      // Check Bill 1
      expect(find.text('HDFC Bank Card'), findsOneWidget);
      expect(find.text('•••• 9137'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('₹15,000.00'), findsOneWidget);
      expect(find.text('Min due: ₹1,200.00'), findsOneWidget);

      // Check Bill 2 (Partial)
      expect(find.text('Axis Bank Card'), findsOneWidget);
      expect(find.text('•••• 9478'), findsOneWidget);
      expect(find.text('PARTIAL'), findsOneWidget);
      expect(find.text('₹6,500.00'), findsOneWidget);
      expect(find.text('Paid: ₹2,000.00 of ₹8,500.00'), findsOneWidget);

      await tester.tap(find.text('View All →'));
      await tester.pump();
      expect(viewAllTapped, isTrue);
    });
  });
}
