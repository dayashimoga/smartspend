import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/enums/bank.dart';

void main() {
  group('Bill Enhancements & Status Unit Tests', () {
    final now = DateTime.now();

    test(
        'effectiveStatus calculates dueToday, overdue, partial, and paid dynamically',
        () {
      final today = DateTime(now.year, now.month, now.day);

      // 1. Due Today
      final dueTodayBill = Bill(
        id: 'b_today',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 5000.0,
        dueDate: today,
        createdAt: now.subtract(const Duration(days: 15)),
      );
      expect(dueTodayBill.daysUntilDue, equals(0));
      expect(dueTodayBill.effectiveStatus, equals(BillStatus.dueToday));
      expect(dueTodayBill.effectiveStatus.displayName, equals('Due Today'));

      // 2. Overdue
      final overdueBill = Bill(
        id: 'b_overdue',
        bank: Bank.axis,
        cardLast4: '9478',
        totalAmount: 3000.0,
        dueDate: today.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 20)),
      );
      expect(overdueBill.daysUntilDue, equals(-3));
      expect(overdueBill.isOverdue, isTrue);
      expect(overdueBill.effectiveStatus, equals(BillStatus.overdue));
      expect(overdueBill.effectiveStatus.displayName, equals('Overdue'));

      // 3. Partial Payment
      final partialBill = Bill(
        id: 'b_partial',
        bank: Bank.icici,
        cardLast4: '4000',
        totalAmount: 10000.0,
        paidAmount: 4000.0,
        dueDate: today.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 10)),
      );
      expect(partialBill.effectiveStatus, equals(BillStatus.partial));
      expect(partialBill.effectiveStatus.displayName, equals('Partial'));
      expect(partialBill.remainingAmount, equals(6000.0));

      // 4. Fully Paid
      final paidBill = Bill(
        id: 'b_paid',
        bank: Bank.sbi,
        cardLast4: '7036',
        totalAmount: 8000.0,
        paidAmount: 8000.0,
        dueDate: today.add(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 5)),
      );
      expect(paidBill.effectiveStatus, equals(BillStatus.paid));
      expect(paidBill.remainingAmount, equals(0.0));

      // 5. Zero or negative bill
      final zeroBill = Bill(
        id: 'b_zero',
        bank: Bank.rbl,
        cardLast4: '4223',
        totalAmount: 0.0,
        dueDate: today.add(const Duration(days: 2)),
        createdAt: now,
      );
      expect(zeroBill.effectiveStatus, equals(BillStatus.noPaymentRequired));
      expect(
          zeroBill.effectiveStatus.displayName, equals('No Payment Required'));
    });

    test('billerDisplayName and maskedTarget formatting', () {
      final cardBill = Bill(
        id: 'b1',
        bank: Bank.hdfc,
        cardLast4: '1355',
        totalAmount: 2500.0,
        dueDate: now.add(const Duration(days: 4)),
        createdAt: now,
      );
      expect(cardBill.billerDisplayName, equals('HDFC Bank Card'));
      expect(cardBill.maskedTarget, equals('•••• 1355'));

      final customBill = Bill(
        id: 'b2',
        bank: Bank.unknown,
        cardLast4: '',
        billerName: 'BESCOM Electricity',
        accountNumber: '1234567890',
        totalAmount: 1200.0,
        dueDate: now.add(const Duration(days: 8)),
        createdAt: now,
      );
      expect(customBill.billerDisplayName, equals('BESCOM Electricity'));
      expect(customBill.maskedTarget, equals('•••• 7890'));
    });

    test('toMap and fromMap serialization roundtrip', () {
      final original = Bill(
        id: 'b_roundtrip',
        bank: Bank.axis,
        cardLast4: '3345',
        billerName: 'Axis Credit Card',
        accountNumber: '9876',
        totalAmount: 1180.0,
        minimumAmount: 100.0,
        paidAmount: 500.0,
        dueDate: DateTime(2026, 7, 5),
        status: BillStatus.partial,
        currency: 'INR',
        paymentTransactionId: 'txn_payment_1',
        sourceDate: DateTime(2026, 6, 20, 10, 0),
        createdAt: DateTime(2026, 6, 20, 10, 5),
      );

      final map = original.toMap();
      final restored = Bill.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.bank, equals(original.bank));
      expect(restored.cardLast4, equals(original.cardLast4));
      expect(restored.totalAmount, equals(original.totalAmount));
      expect(restored.paidAmount, equals(original.paidAmount));
      expect(restored.effectiveStatus, equals(BillStatus.partial));
      expect(restored.sourceDate, equals(original.sourceDate));
      expect(
          restored.paymentTransactionId, equals(original.paymentTransactionId));
    });
  });
}
