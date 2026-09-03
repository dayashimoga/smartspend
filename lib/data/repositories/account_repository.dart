import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/account.dart';
import '../../domain/enums/bank.dart';
import '../../domain/repositories/interfaces.dart';

class AccountRepository implements IAccountRepository {
  final DatabaseHelper _dbHelper;

  AccountRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> upsertAccount(Account account) async {
    final db = await _dbHelper.database;
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Account>> getAllAccounts() async {
    final db = await _dbHelper.database;
    final res = await db.query('accounts', orderBy: 'current_balance DESC');
    return res.map((m) => Account.fromMap(m)).toList();
  }

  @override
  Future<Account?> getAccountByBankAndLast4(Bank bank, String last4) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'accounts',
      where: 'bank = ? AND last4 = ?',
      whereArgs: [bank.name, last4],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return Account.fromMap(res.first);
  }

  @override
  Future<List<Account>> getAccountsAsOf(DateTime asOf) async {
    final db = await _dbHelper.database;
    final accounts = await getAllAccounts();
    final asOfMs = asOf.millisecondsSinceEpoch;

    final result = <Account>[];
    for (final acct in accounts) {
      final txRes = await db.query(
        'parsed_transactions',
        where:
            'bank = ? AND account_last4 = ? AND balance IS NOT NULL AND transaction_date <= ?',
        whereArgs: [acct.bank.name, acct.last4, asOfMs],
        orderBy: 'transaction_date DESC',
        limit: 1,
      );

      if (txRes.isNotEmpty) {
        final bal =
            (txRes.first['balance'] as num?)?.toDouble() ?? acct.currentBalance;
        final date = DateTime.fromMillisecondsSinceEpoch(
            txRes.first['transaction_date'] as int);
        result.add(acct.copyWith(
          currentBalance: bal,
          lastUpdated: date,
          isBalanceReliable: true,
        ));
      } else {
        if (acct.lastUpdated.millisecondsSinceEpoch <= asOfMs) {
          result.add(acct.copyWith(isBalanceReliable: true));
        } else {
          result.add(acct.copyWith(isBalanceReliable: false));
        }
      }
    }
    return result;
  }
}
