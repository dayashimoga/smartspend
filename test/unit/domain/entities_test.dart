import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/budget.dart';
import 'package:smartspend/domain/entities/correction.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  group('Domain Entities Serialization & CopyWith Suite', () {
    test('Account serialization and copyWith', () {
      final now = DateTime(2026, 1, 15);
      final acct = Account(
        id: 'acct_1',
        bank: Bank.hdfc,
        last4: '1234',
        accountType: 'Savings',
        currentBalance: 50000.0,
        currency: 'INR',
        lastUpdated: now,
      );

      final map = acct.toMap();
      final restored = Account.fromMap(map);

      expect(restored.id, equals(acct.id));
      expect(restored.bank, equals(acct.bank));
      expect(restored.last4, equals(acct.last4));
      expect(restored.currentBalance, equals(50000.0));

      final updated = acct.copyWith(currentBalance: 55000.0);
      expect(updated.currentBalance, equals(55000.0));
      expect(updated.last4, equals('1234'));
    });

    test('Bill serialization and copyWith', () {
      final now = DateTime(2026, 1, 15);
      final bill = Bill(
        id: 'bill_1',
        bank: Bank.icici,
        cardLast4: '4000',
        totalAmount: 12500.0,
        minimumAmount: 1250.0,
        dueDate: now.add(const Duration(days: 15)),
        status: BillStatus.unpaid,
        currency: 'INR',
        createdAt: now,
      );

      final map = bill.toMap();
      final restored = Bill.fromMap(map);

      expect(restored.id, equals(bill.id));
      expect(restored.totalAmount, equals(12500.0));
      expect(restored.status, equals(BillStatus.unpaid));

      final paid = bill.copyWith(status: BillStatus.paid);
      expect(paid.status, equals(BillStatus.paid));
    });

    test('CreditCard serialization and copyWith', () {
      final now = DateTime(2026, 1, 15);
      final card = CreditCard(
        id: 'card_1',
        bank: Bank.axis,
        last4: '9999',
        availableLimit: 85000.0,
        totalLimit: 100000.0,
        outstanding: 15000.0,
        currency: 'INR',
        lastUpdated: now,
      );

      final map = card.toMap();
      final restored = CreditCard.fromMap(map);

      expect(restored.id, equals(card.id));
      expect(restored.availableLimit, equals(85000.0));
      expect(restored.utilizationPercentage, closeTo(15.0, 0.1));

      final updated = card.copyWith(outstanding: 20000.0);
      expect(updated.outstanding, equals(20000.0));
    });

    test('FastagRecord serialization and copyWith', () {
      final now = DateTime(2026, 1, 15);
      final fastag = FastagRecord(
        id: 'fastag_1',
        vehicle: 'MH12AB1234',
        fastagId: 'TAG_998877',
        bank: Bank.sbi,
        latestWalletBalance: 850.0,
        currency: 'INR',
        lastUpdated: now,
      );

      final map = fastag.toMap();
      final restored = FastagRecord.fromMap(map);

      expect(restored.id, equals(fastag.id));
      expect(restored.vehicle, equals('MH12AB1234'));
      expect(restored.latestWalletBalance, equals(850.0));
      expect(restored.fastagId, equals('TAG_998877'));

      final updated = fastag.copyWith(latestWalletBalance: 650.0);
      expect(updated.latestWalletBalance, equals(650.0));
    });

    test('Budget serialization and copyWith', () {
      const budget = Budget(
        id: 'budget_1',
        category: 'Dining',
        monthlyLimit: 10000.0,
        currency: 'INR',
        currentSpend: 4200.0,
        month: 1,
        year: 2026,
      );

      final map = budget.toMap();
      final restored = Budget.fromMap(map);

      expect(restored.id, equals(budget.id));
      expect(restored.category, equals('Dining'));
      expect(restored.monthlyLimit, equals(10000.0));
      expect(restored.remainingAmount, equals(5800.0));
      expect(restored.progressPercentage, closeTo(42.0, 0.1));

      final updated = budget.copyWith(currentSpend: 5000.0);
      expect(updated.currentSpend, equals(5000.0));
      expect(updated.remainingAmount, equals(5000.0));
    });

    test('Correction serialization', () {
      final now = DateTime(2026, 1, 15);
      final correction = Correction(
        id: 'corr_1',
        transactionId: 'txn_1',
        fieldName: 'category',
        originalValue: 'Uncategorized',
        correctedValue: 'Groceries',
        reason: 'Manual reclassification',
        appliedAt: now,
      );

      final map = correction.toMap();
      final restored = Correction.fromMap(map);

      expect(restored.id, equals(correction.id));
      expect(restored.fieldName, equals('category'));
      expect(restored.originalValue, equals('Uncategorized'));
      expect(restored.correctedValue, equals('Groceries'));
    });

    test('SmsRecord serialization and copyWith', () {
      final now = DateTime(2026, 1, 15);
      final sms = SmsRecord(
        id: 'sms_test_1',
        sender: 'HDFCBK',
        body: 'Rs 500 spent',
        timestamp: now,
        fingerprint: 'fp_abc_123',
        ingestedAt: now,
      );

      final map = sms.toMap();
      final restored = SmsRecord.fromMap(map);

      expect(restored.id, equals(sms.id));
      expect(restored.sender, equals('HDFCBK'));
      expect(restored.fingerprint, equals('fp_abc_123'));
    });

    test('Enums display names and helpers', () {
      expect(Bank.hdfc.displayName, contains('HDFC'));
      expect(Bank.icici.displayName, contains('ICICI'));
      expect(Bank.axis.displayName, contains('Axis'));
      expect(Bank.sbi.displayName, contains('State Bank of India'));
      expect(Bank.hsbc.displayName, contains('HSBC'));
      expect(Bank.yesBank.displayName, contains('YES BANK'));
      expect(Bank.idfcFirst.displayName, contains('IDFC FIRST'));
      expect(Bank.indusind.displayName, contains('IndusInd'));
      expect(Bank.ujjivan.displayName, contains('Ujjivan'));
      expect(Bank.onecard.displayName, contains('OneCard'));
      expect(Bank.sib.displayName, contains('South Indian'));
      expect(Bank.unknown.displayName, equals('General / Other'));

      expect(TransactionType.purchase.name, equals('purchase'));
      expect(TransactionType.debit.name, equals('debit'));
      expect(TransactionType.credit.name, equals('credit'));
      expect(TransactionType.refund.name, equals('refund'));
      expect(TransactionType.billPayment.name, equals('billPayment'));

      expect(Confidence.high.needsReview, isFalse);
      expect(Confidence.medium.needsReview, isFalse);
      expect(Confidence.low.needsReview, isTrue);
      expect(Confidence.unparsed.needsReview, isTrue);
    });
  });
}
