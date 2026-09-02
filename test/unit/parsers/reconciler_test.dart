import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/reconciler.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  group('Reconciler Unit Tests', () {
    test('Reconciles refund with originating card purchase', () {
      final purchase = ParsedTransaction(
        id: 'txn_purchase_1',
        rawSmsId: 'sms_1',
        type: TransactionType.purchase,
        bank: Bank.icici,
        cardLast4: '4000',
        amount: 483.40,
        transactionDate: DateTime(2026, 1, 18),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final refund = ParsedTransaction(
        id: 'txn_refund_1',
        rawSmsId: 'sms_2',
        type: TransactionType.refund,
        bank: Bank.icici,
        cardLast4: '4000',
        amount: 483.40,
        transactionDate: DateTime(2026, 1, 19),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = Reconciler.reconcileAll([purchase, refund]);
      expect(result[0].isReconciled, isTrue);
      expect(result[0].reconciledWithId, equals('txn_refund_1'));
      expect(result[1].isReconciled, isTrue);
      expect(result[1].reconciledWithId, equals('txn_purchase_1'));
    });

    test(
        'Prevents double-counting by reclassifying credit card payments from bank debits',
        () {
      final cardRepayment = ParsedTransaction(
        id: 'txn_debit_1',
        rawSmsId: 'sms_3',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        accountLast4: '0564',
        amount: 15000.0,
        payee: 'CRED Credit Card Payment',
        transactionDate: DateTime(2026, 1, 20),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = Reconciler.reconcileAll([cardRepayment]);
      expect(result[0].type, equals(TransactionType.billPayment));
      expect(result[0].category, equals('Credit Card Payment'));
    });

    test('Reconciles zero or negative bills to noPaymentRequired', () {
      final billZero = Bill(
        id: 'bill_1',
        bank: Bank.hdfc,
        cardLast4: '9137',
        totalAmount: 0.0,
        minimumAmount: 0.0,
        dueDate: DateTime(2026, 2, 10),
        status: BillStatus.unpaid,
        createdAt: DateTime.now(),
      );

      final reconciled = Reconciler.reconcileBill(billZero);
      expect(reconciled.status, equals(BillStatus.noPaymentRequired));
    });
  });
}
