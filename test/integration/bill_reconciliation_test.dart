import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/reconciler.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  group('Bill Reconciliation Integration Tests', () {
    final now = DateTime(2026, 3, 15);

    test('Partial payment sets status to partial and updates paidAmount', () {
      final bill = Bill(
        id: 'bill_1',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 10000.0,
        minimumAmount: 500.0,
        dueDate: DateTime(2026, 3, 25),
        sourceDate: DateTime(2026, 3, 5),
        createdAt: DateTime(2026, 3, 5),
      );

      final payment = ParsedTransaction(
        id: 'pay_1',
        rawSmsId: 'sms_p1',
        type: TransactionType.billPayment,
        bank: Bank.hdfc,
        cardLast4: '9137',
        amount: 3000.0,
        transactionDate: DateTime(2026, 3, 10),
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final reconciled =
          Reconciler.reconcileBillsWithPayments([bill], [payment]);
      expect(reconciled.length, equals(1));
      expect(reconciled.first.paidAmount, equals(3000.0));
      expect(reconciled.first.remainingAmount, equals(7000.0));
      expect(reconciled.first.effectiveStatus, equals(BillStatus.partial));
      expect(reconciled.first.paymentTransactionId, equals('pay_1'));
    });

    test('Multiple partial payments accumulate to mark bill paid', () {
      final bill = Bill(
        id: 'bill_multi',
        bank: Bank.axis,
        cardLast4: '9478',
        totalAmount: 5000.0,
        dueDate: DateTime(2026, 3, 20),
        sourceDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
      );

      final pay1 = ParsedTransaction(
        id: 'pay_1',
        rawSmsId: 'sms_1',
        type: TransactionType.billPayment,
        bank: Bank.axis,
        cardLast4: '9478',
        amount: 2000.0,
        transactionDate: DateTime(2026, 3, 5),
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final pay2 = ParsedTransaction(
        id: 'pay_2',
        rawSmsId: 'sms_2',
        type: TransactionType.billPayment,
        bank: Bank.axis,
        cardLast4: '9478',
        amount: 3000.0,
        transactionDate: DateTime(2026, 3, 12),
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final reconciled =
          Reconciler.reconcileBillsWithPayments([bill], [pay1, pay2]);
      expect(reconciled.first.paidAmount, equals(5000.0));
      expect(reconciled.first.remainingAmount, equals(0.0));
      expect(reconciled.first.effectiveStatus, equals(BillStatus.paid));
    });

    test('Duplicate statements in same billing cycle keep latest statement',
        () {
      final stmtEarlier = Bill(
        id: 'stmt_v1',
        bank: Bank.sbi,
        cardLast4: '7036',
        totalAmount: 5696.0,
        dueDate: DateTime(2026, 3, 22),
        createdAt: DateTime(2026, 3, 1, 10, 0),
      );

      final stmtLater = Bill(
        id: 'stmt_v2',
        bank: Bank.sbi,
        cardLast4: '7036',
        totalAmount: 5696.0,
        dueDate: DateTime(2026, 3, 22),
        createdAt: DateTime(2026, 3, 2, 14, 0), // newer timestamp
      );

      final reconciled =
          Reconciler.reconcileBillsWithPayments([stmtEarlier, stmtLater], []);
      expect(reconciled.length, equals(1));
      expect(reconciled.first.id, equals('stmt_v2'));
    });

    test(
        'reconcileBillsWithPayments handles non-card billerName and bank fallback',
        () {
      final bill = Bill(
        id: 'bill_biller',
        bank: Bank.hdfc,
        cardLast4: '',
        billerName: 'BESCOM Power',
        totalAmount: 1450.0,
        dueDate: DateTime(2026, 3, 20),
        sourceDate: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
      );

      final pay = ParsedTransaction(
        id: 'pay_bescom',
        rawSmsId: 's_bescom',
        type: TransactionType.billPayment,
        bank: Bank.hdfc,
        cardLast4: '',
        merchant: 'BESCOM Power',
        amount: 1450.0,
        transactionDate: DateTime(2026, 3, 10),
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final reconciled = Reconciler.reconcileBillsWithPayments([bill], [pay]);
      expect(reconciled.first.paidAmount, equals(1450.0));
      expect(reconciled.first.effectiveStatus, equals(BillStatus.paid));
    });

    test('reconcileBillsWithPayments ignores payments outside 45-day window',
        () {
      final bill = Bill(
        id: 'bill_window',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 5000.0,
        dueDate: DateTime.now().add(const Duration(days: 20)),
        sourceDate: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      final oldPay = ParsedTransaction(
        id: 'pay_old',
        rawSmsId: 's_old',
        type: TransactionType.billPayment,
        bank: Bank.hdfc,
        cardLast4: '9137',
        amount: 5000.0,
        transactionDate: DateTime(2025, 12, 1), // > 45 days prior
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );

      final reconciled =
          Reconciler.reconcileBillsWithPayments([bill], [oldPay]);
      expect(reconciled.first.paidAmount, equals(0.0));
      expect(reconciled.first.effectiveStatus, equals(BillStatus.unpaid));
    });
  });
}
