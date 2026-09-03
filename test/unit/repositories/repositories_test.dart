import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/enums/bank.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late AccountRepository acctRepo;
  late CardRepository cardRepo;
  late BillRepository billRepo;
  late FastagRepository fastagRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    acctRepo = AccountRepository(dbHelper: dbHelper);
    cardRepo = CardRepository(dbHelper: dbHelper);
    billRepo = BillRepository(dbHelper: dbHelper);
    fastagRepo = FastagRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Repositories CRUD & Query Forensic Suite', () {
    test('AccountRepository upsert and query operations', () async {
      final acct = Account(
        id: 'acct_crud_1',
        bank: Bank.hdfc,
        last4: '1111',
        accountType: 'Savings',
        currentBalance: 75000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      await acctRepo.upsertAccount(acct);

      final fetched =
          await acctRepo.getAccountByBankAndLast4(Bank.hdfc, '1111');
      expect(fetched, isNotNull);
      expect(fetched?.currentBalance, equals(75000.0));

      final all = await acctRepo.getAllAccounts();
      expect(all.length, equals(1));

      // Upsert updated balance
      final updatedAcct = acct.copyWith(currentBalance: 80000.0);
      await acctRepo.upsertAccount(updatedAcct);
      final updated =
          await acctRepo.getAccountByBankAndLast4(Bank.hdfc, '1111');
      expect(updated?.currentBalance, equals(80000.0));
    });

    test('CardRepository upsert and query operations', () async {
      final card = CreditCard(
        id: 'card_crud_1',
        bank: Bank.icici,
        last4: '2222',
        availableLimit: 120000.0,
        totalLimit: 150000.0,
        outstanding: 30000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      await cardRepo.upsertCard(card);

      final fetched = await cardRepo.getCardByBankAndLast4(Bank.icici, '2222');
      expect(fetched, isNotNull);
      expect(fetched?.availableLimit, equals(120000.0));

      final all = await cardRepo.getAllCards();
      expect(all.length, equals(1));
    });

    test('BillRepository upsert and upcoming queries', () async {
      final now = DateTime.now();
      final bill = Bill(
        id: 'bill_crud_1',
        bank: Bank.axis,
        cardLast4: '3333',
        totalAmount: 5000.0,
        minimumAmount: 500.0,
        dueDate: now.add(const Duration(days: 5)),
        status: BillStatus.unpaid,
        currency: 'INR',
        createdAt: now,
      );

      await billRepo.upsertBill(bill);

      final allBills = await billRepo.getAllBills();
      expect(allBills.length, equals(1));

      final upcoming = await billRepo.getUpcomingBills();
      expect(upcoming.length, equals(1));
      expect(upcoming.first.cardLast4, equals('3333'));
    });

    test('FastagRepository upsert and vehicle query operations', () async {
      final fastag = FastagRecord(
        id: 'fastag_crud_1',
        vehicle: 'DL01XY9999',
        fastagId: 'TAG_1234',
        bank: Bank.sbi,
        latestWalletBalance: 1200.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      );

      await fastagRepo.upsertFastag(fastag);

      final fetched =
          await fastagRepo.getFastagByVehicleOrId('DL01XY9999', null);
      expect(fetched, isNotNull);
      expect(fetched?.latestWalletBalance, equals(1200.0));

      final all = await fastagRepo.getAllFastag();
      expect(all.length, equals(1));
    });
  });
}
