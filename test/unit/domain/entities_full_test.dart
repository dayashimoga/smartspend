import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/budget.dart';
import 'package:smartspend/domain/entities/correction.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  group('Domain Entities Full Forensic Coverage Suite', () {
    test(
        'ParsedTransaction methods, display titles, getters, and serialization',
        () {
      final now = DateTime.now();
      final txn = ParsedTransaction(
        id: 'txn_full',
        rawSmsId: 'sms_full',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        accountLast4: '1234',
        cardLast4: '5678',
        amount: 1500.0,
        currency: 'INR',
        transactionDate: now,
        merchant: 'Grocers Inc',
        payee: 'Payee Person',
        payer: 'Payer Person',
        reference: 'REF123',
        rrn: 'RRN456',
        upiRef: 'UPI789',
        balance: 10000.0,
        availableLimit: 50000.0,
        outstanding: 12000.0,
        billTotal: 12000.0,
        billMinimum: 600.0,
        billDueDate: now.add(const Duration(days: 15)),
        fastagId: 'FT123',
        vehicle: 'KA01AB1234',
        tollPlaza: 'Attibele',
        walletBalance: 850.0,
        confidence: Confidence.high,
        parserVersion: '1.0.0',
        category: 'Groceries',
        tags: const ['food', 'essential'],
        isExcluded: false,
        isReconciled: false,
        reconciledWithId: null,
        createdAt: now,
        updatedAt: now,
      );

      // Display title with merchant
      expect(txn.displayTitle, equals('Grocers Inc'));
      expect(txn.maskedAccountOrCard, equals('•••• 5678'));

      // Display title without merchant, with payee
      final txnPayee = txn.copyWith(merchant: '');
      expect(txnPayee.displayTitle, equals('Payee Person'));

      // Display title without payee, with vehicle
      final txnVehicle = txnPayee.copyWith(payee: '');
      expect(txnVehicle.displayTitle, equals('Toll: KA01AB1234'));

      // Display title without vehicle, with tollPlaza
      final txnPlaza = txnVehicle.copyWith(vehicle: '');
      expect(txnPlaza.displayTitle, equals('Toll at Attibele'));

      // Display title without tollPlaza, with payer
      final txnPayer = txnPlaza.copyWith(tollPlaza: '');
      expect(txnPayer.displayTitle, equals('Payer Person'));

      // Default fallback display title
      final txnDefault = txnPayer.copyWith(payer: '');
      expect(txnDefault.displayTitle, equals('HDFC Card Purchase'));

      // Account masked fallback
      final txnAcctOnly = ParsedTransaction(
        id: 't_acct',
        rawSmsId: 's',
        type: TransactionType.debit,
        bank: Bank.hdfc,
        accountLast4: '1234',
        amount: 100.0,
        currency: 'INR',
        transactionDate: now,
        confidence: Confidence.high,
        createdAt: now,
        updatedAt: now,
      );
      expect(txnAcctOnly.maskedAccountOrCard, equals('•••• 1234'));

      final txnNone = txnAcctOnly.copyWith(accountLast4: '');
      expect(txnNone.maskedAccountOrCard, equals(''));

      // toMap & fromMap
      final map = txn.toMap();
      final restored = ParsedTransaction.fromMap(map);
      expect(restored.id, equals(txn.id));
      expect(restored.amount, equals(1500.0));
      expect(restored.props.length, equals(txn.props.length));
    });

    test('Bill methods, isDueSoon, isOverdue, and serialization', () {
      final now = DateTime.now();
      final dueSoonBill = Bill(
        id: 'bill_soon',
        bank: Bank.icici,
        cardLast4: '4000',
        totalAmount: 5000.0,
        minimumAmount: 250.0,
        dueDate: now.add(const Duration(days: 2)),
        status: BillStatus.unpaid,
        currency: 'INR',
        createdAt: now,
      );

      expect(dueSoonBill.isDueSoon, isTrue);
      expect(dueSoonBill.isOverdue, isFalse);

      final overdueBill = dueSoonBill.copyWith(
        dueDate: now.subtract(const Duration(days: 2)),
      );
      expect(overdueBill.isOverdue, isTrue);
      expect(overdueBill.isDueSoon, isFalse);

      final map = dueSoonBill.toMap();
      final restored = Bill.fromMap(map);
      expect(restored.id, equals(dueSoonBill.id));
      expect(restored.totalAmount, equals(5000.0));
      expect(restored.props.length, equals(dueSoonBill.props.length));

      expect(BillStatus.unpaid.displayName, equals('Due'));
      expect(BillStatus.paid.displayName, equals('Paid'));
      expect(BillStatus.overdue.displayName, equals('Overdue'));
      expect(BillStatus.noPaymentRequired.displayName,
          equals('No Payment Required'));
    });

    test('Account methods and serialization', () {
      final acct = Account(
        id: 'acct_1',
        bank: Bank.hdfc,
        last4: '9999',
        accountType: 'Savings',
        currentBalance: 32000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      final map = acct.toMap();
      final restored = Account.fromMap(map);
      expect(restored.id, equals(acct.id));
      expect(restored.currentBalance, equals(32000.0));
      expect(restored.props.length, equals(acct.props.length));
    });

    test('CreditCard methods and serialization', () {
      final card = CreditCard(
        id: 'card_1',
        bank: Bank.icici,
        last4: '4000',
        availableLimit: 150000.0,
        totalLimit: 200000.0,
        outstanding: 50000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      expect(card.utilizationPercentage, equals(25.0));

      final map = card.toMap();
      final restored = CreditCard.fromMap(map);
      expect(restored.id, equals(card.id));
      expect(restored.outstanding, equals(50000.0));
      expect(restored.props.length, equals(card.props.length));
    });

    test('FastagRecord methods and serialization', () {
      final ft = FastagRecord(
        id: 'ft_1',
        vehicle: 'KA01CD1234',
        bank: Bank.sbi,
        latestWalletBalance: 500.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      final map = ft.toMap();
      final restored = FastagRecord.fromMap(map);
      expect(restored.id, equals(ft.id));
      expect(restored.latestWalletBalance, equals(500.0));
      expect(restored.props.length, equals(ft.props.length));
    });

    test('Budget methods, remaining, percentage, and serialization', () {
      const b = Budget(
        id: 'b_1',
        category: 'Food',
        monthlyLimit: 10000.0,
        currency: 'INR',
        currentSpend: 8000.0,
        month: 1,
        year: 2026,
      );

      expect(b.remainingAmount, equals(2000.0));
      expect(b.progressPercentage, equals(80.0));
      expect(b.isExceeded, isFalse);

      final over = b.copyWith(currentSpend: 12000.0);
      expect(over.isExceeded, isTrue);
      expect(over.remainingAmount, equals(0.0));

      final map = b.toMap();
      final restored = Budget.fromMap(map);
      expect(restored.id, equals(b.id));
      expect(restored.monthlyLimit, equals(10000.0));
      expect(restored.props.length, equals(b.props.length));
    });

    test('Correction methods and serialization', () {
      final corr = Correction(
        id: 'c_1',
        transactionId: 't_1',
        fieldName: 'category',
        originalValue: 'General',
        correctedValue: 'Groceries',
        reason: 'Manual adjustment',
        appliedAt: DateTime.now(),
      );

      final map = corr.toMap();
      final restored = Correction.fromMap(map);
      expect(restored.id, equals(corr.id));
      expect(restored.correctedValue, equals('Groceries'));
      expect(restored.props.length, equals(corr.props.length));
    });

    test('FinancialSummary utilization and empty constructor', () {
      const summary = FinancialSummary(
        totalIncome: 10000.0,
        totalExpense: 2000.0,
        netCashFlow: 8000.0,
        totalAccountBalance: 50000.0,
        totalCardOutstanding: 20000.0,
        totalAvailableCredit: 80000.0,
        upcomingBillsCount: 1,
        upcomingBillsTotal: 2500.0,
        needsReviewCount: 0,
        currency: 'INR',
      );

      expect(summary.cardUtilizationPercentage, equals(20.0));

      final empty = FinancialSummary.empty();
      expect(empty.totalIncome, equals(0.0));
      expect(empty.cardUtilizationPercentage, isNull);
      expect(empty.props.length, equals(11));
    });

    test('Exhaustive coverage for TransactionType, Bank, and Confidence enums',
        () {
      for (final t in TransactionType.values) {
        expect(t.displayName.isNotEmpty, isTrue);
        expect(t.isExpense, isA<bool>());
        expect(t.isIncome, isA<bool>());
      }

      for (final b in Bank.values) {
        expect(b.displayName.isNotEmpty, isTrue);
        expect(b.shortName.isNotEmpty, isTrue);
      }

      for (final c in Confidence.values) {
        expect(c.displayName.isNotEmpty, isTrue);
        expect(c.needsReview, isA<bool>());
      }
    });
  });
}
