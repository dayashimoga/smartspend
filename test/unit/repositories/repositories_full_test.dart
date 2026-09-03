import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/budget_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/correction_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/budget.dart';
import 'package:smartspend/domain/entities/correction.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late AccountRepository accountRepo;
  late CardRepository cardRepo;
  late BillRepository billRepo;
  late FastagRepository fastagRepo;
  late BudgetRepository budgetRepo;
  late CorrectionRepository correctionRepo;
  late SmsRepository smsRepo;
  late TransactionRepository txnRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    accountRepo = AccountRepository(dbHelper: dbHelper);
    cardRepo = CardRepository(dbHelper: dbHelper);
    billRepo = BillRepository(dbHelper: dbHelper);
    fastagRepo = FastagRepository(dbHelper: dbHelper);
    budgetRepo = BudgetRepository(dbHelper: dbHelper);
    correctionRepo = CorrectionRepository(dbHelper: dbHelper);
    smsRepo = SmsRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Full Repositories CRUD & Query Forensic Suite', () {
    test('AccountRepository upsert, query, and balance updates', () async {
      final acct = Account(
        id: 'acct_1',
        bank: Bank.hdfc,
        last4: '1234',
        accountType: 'Savings',
        currentBalance: 50000.0,
        currency: 'INR',
        lastUpdated: DateTime(2026, 1, 1),
      );

      await accountRepo.upsertAccount(acct);
      var all = await accountRepo.getAllAccounts();
      expect(all.length, equals(1));
      expect(all.first.currentBalance, equals(50000.0));

      final updated = acct.copyWith(currentBalance: 55000.0);
      await accountRepo.upsertAccount(updated);
      all = await accountRepo.getAllAccounts();
      expect(all.length, equals(1));
      expect(all.first.currentBalance, equals(55000.0));

      final byBankLast4 =
          await accountRepo.getAccountByBankAndLast4(Bank.hdfc, '1234');
      expect(byBankLast4, isNotNull);
      expect(byBankLast4!.currentBalance, equals(55000.0));
    });

    test('CardRepository upsert, query, and limit updates', () async {
      final card = CreditCard(
        id: 'card_1',
        bank: Bank.icici,
        last4: '4000',
        availableLimit: 180000.0,
        totalLimit: 200000.0,
        outstanding: 20000.0,
        currency: 'INR',
        lastUpdated: DateTime(2026, 1, 1),
      );

      await cardRepo.upsertCard(card);
      var all = await cardRepo.getAllCards();
      expect(all.length, equals(1));
      expect(all.first.availableLimit, equals(180000.0));

      final fetched = await cardRepo.getCardByBankAndLast4(Bank.icici, '4000');
      expect(fetched, isNotNull);
      expect(fetched!.outstanding, equals(20000.0));
    });

    test('BillRepository upsert, query, and upcoming bills', () async {
      final bill = Bill(
        id: 'bill_1',
        bank: Bank.axis,
        cardLast4: '5555',
        totalAmount: 12000.0,
        minimumAmount: 600.0,
        dueDate: DateTime.now().add(const Duration(days: 3)),
        status: BillStatus.unpaid,
        currency: 'INR',
        createdAt: DateTime.now(),
      );

      await billRepo.upsertBill(bill);
      var all = await billRepo.getAllBills();
      expect(all.length, equals(1));
      expect(all.first.totalAmount, equals(12000.0));

      final upcoming = await billRepo.getUpcomingBills(days: 5);
      expect(upcoming.length, equals(1));
    });

    test('FastagRepository upsert, query by vehicle, and balance tracking',
        () async {
      final ft = FastagRecord(
        id: 'ft_1',
        vehicle: 'KA05MN9999',
        bank: Bank.sbi,
        latestWalletBalance: 1200.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      await fastagRepo.upsertFastag(ft);
      var all = await fastagRepo.getAllFastag();
      expect(all.length, equals(1));
      expect(all.first.latestWalletBalance, equals(1200.0));

      final byVehicle =
          await fastagRepo.getFastagByVehicleOrId('KA05MN9999', null);
      expect(byVehicle, isNotNull);
      expect(byVehicle!.bank, equals(Bank.sbi));
    });

    test('BudgetRepository upsert and month-year query', () async {
      const b = Budget(
        id: 'b_1',
        category: 'Shopping',
        monthlyLimit: 20000.0,
        currency: 'INR',
        currentSpend: 4500.0,
        month: 1,
        year: 2026,
      );

      await budgetRepo.upsertBudget(b);
      var budgets = await budgetRepo.getBudgetsForMonth(1, 2026);
      expect(budgets.length, equals(1));
      expect(budgets.first.monthlyLimit, equals(20000.0));
    });

    test('CorrectionRepository and TransactionRepository full lifecycle',
        () async {
      final sms = SmsRecord(
        id: 's_full_1',
        sender: 'HDFCBK',
        body: 'Rs 1500 debited for dinner',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_full_1',
        ingestedAt: DateTime.now(),
      );
      await smsRepo.saveSms(sms);

      final txn = ParsedTransaction(
        id: 't_full_1',
        rawSmsId: 's_full_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        amount: 1500.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 1),
        merchant: 'Dinner Cafe',
        category: 'Food',
        confidence: Confidence.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await txnRepo.saveTransaction(txn);

      // Add a correction
      final corr = Correction(
        id: 'c_1',
        transactionId: 't_full_1',
        fieldName: 'category',
        originalValue: 'Food',
        correctedValue: 'Dining Out',
        reason: 'User preference',
        appliedAt: DateTime.now(),
      );
      await correctionRepo.saveCorrection(corr);

      final corrections =
          await correctionRepo.getCorrectionsForTransaction('t_full_1');
      expect(corrections.length, equals(1));
      expect(corrections.first.correctedValue, equals('Dining Out'));

      // Update transaction
      final updatedTxn = txn.copyWith(category: 'Dining Out', isExcluded: true);
      await txnRepo.updateTransaction(updatedTxn);

      final fetched = await txnRepo.getTransactionById('t_full_1');
      expect(fetched!.category, equals('Dining Out'));
      expect(fetched.isExcluded, isTrue);

      // Search
      final searchResults = await txnRepo.searchTransactions('Dinner');
      expect(searchResults.length, equals(1));

      // Delete
      await txnRepo.deleteTransaction('t_full_1');
      final deleted = await txnRepo.getTransactionById('t_full_1');
      expect(deleted, isNull);
    });

    test(
        'SmsRepository full operations (bulk, fingerprint, count, getAll, getById)',
        () async {
      final records = [
        SmsRecord(
          id: 's_bulk_1',
          sender: 'HDFCBK',
          body: 'SMS 1',
          timestamp: DateTime(2026, 1, 1),
          fingerprint: 'fp_bulk_1',
          ingestedAt: DateTime.now(),
        ),
        SmsRecord(
          id: 's_bulk_2',
          sender: 'ICICIB',
          body: 'SMS 2',
          timestamp: DateTime(2026, 1, 2),
          fingerprint: 'fp_bulk_2',
          ingestedAt: DateTime.now(),
        ),
      ];

      // saveBulkSms empty guard
      await smsRepo.saveBulkSms([]);

      // saveBulkSms populated
      await smsRepo.saveBulkSms(records);

      final count = await smsRepo.getSmsCount();
      expect(count, equals(2));

      final byFp = await smsRepo.getSmsByFingerprint('fp_bulk_1');
      expect(byFp, isNotNull);
      expect(byFp!.sender, equals('HDFCBK'));

      final nonExistentFp = await smsRepo.getSmsByFingerprint('non_existent');
      expect(nonExistentFp, isNull);

      final exists = await smsRepo.existsByFingerprint('fp_bulk_2');
      expect(exists, isTrue);

      final notExists = await smsRepo.existsByFingerprint('no_fp');
      expect(notExists, isFalse);

      final all = await smsRepo.getAllSms(limit: 10, offset: 0);
      expect(all.length, equals(2));

      final byId = await smsRepo.getSmsById('s_bulk_1');
      expect(byId, isNotNull);
      expect(byId!.id, equals('s_bulk_1'));

      final missingId = await smsRepo.getSmsById('missing');
      expect(missingId, isNull);
    });
  });
}
