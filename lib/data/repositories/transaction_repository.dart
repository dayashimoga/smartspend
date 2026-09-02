import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/bank.dart';
import '../../domain/enums/confidence.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/interfaces.dart';

class TransactionRepository implements ITransactionRepository {
  final DatabaseHelper _dbHelper;

  TransactionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> saveTransaction(ParsedTransaction transaction) async {
    final db = await _dbHelper.database;
    await db.insert(
      'parsed_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveBulkTransactions(
      List<ParsedTransaction> transactions) async {
    if (transactions.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert(
        'parsed_transactions',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateTransaction(ParsedTransaction transaction) async {
    final db = await _dbHelper.database;
    await db.update(
      'parsed_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'parsed_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<ParsedTransaction?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'parsed_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return ParsedTransaction.fromMap(res.first);
  }

  @override
  Future<List<ParsedTransaction>> getAllTransactions({
    int limit = 100,
    int offset = 0,
    TransactionType? type,
    Bank? bank,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    bool includeExcluded = false,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeExcluded) {
      whereClauses.add('is_excluded = 0');
    }
    if (type != null) {
      whereClauses.add('type = ?');
      whereArgs.add(type.name);
    }
    if (bank != null) {
      whereClauses.add('bank = ?');
      whereArgs.add(bank.name);
    }
    if (category != null && category.isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (startDate != null) {
      whereClauses.add('transaction_date >= ?');
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      whereClauses.add('transaction_date <= ?');
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final res = await db.query(
      'parsed_transactions',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'transaction_date DESC',
      limit: limit,
      offset: offset,
    );

    return res.map((m) => ParsedTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<ParsedTransaction>> getNeedsReviewTransactions() async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'parsed_transactions',
      where: 'confidence IN (?, ?)',
      whereArgs: [Confidence.low.name, Confidence.unparsed.name],
      orderBy: 'transaction_date DESC',
    );
    return res.map((m) => ParsedTransaction.fromMap(m)).toList();
  }

  @override
  Future<List<ParsedTransaction>> getRecentTransactions(
      {int limit = 10}) async {
    return getAllTransactions(limit: limit, offset: 0);
  }

  @override
  Future<List<ParsedTransaction>> searchTransactions(String query) async {
    final db = await _dbHelper.database;
    final q = '%$query%';
    final res = await db.query(
      'parsed_transactions',
      where:
          '(merchant LIKE ? OR payee LIKE ? OR payer LIKE ? OR category LIKE ? OR reference LIKE ?)',
      whereArgs: [q, q, q, q, q],
      orderBy: 'transaction_date DESC',
      limit: 50,
    );
    return res.map((m) => ParsedTransaction.fromMap(m)).toList();
  }

  @override
  Future<FinancialSummary> getFinancialSummary(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await _dbHelper.database;
    final txns = await getAllTransactions(
      limit: 10000,
      startDate: startDate,
      endDate: endDate,
    );

    double totalIncome = 0.0;
    double totalExpense = 0.0;

    for (final t in txns) {
      if (t.isExcluded) continue;
      // Prevent double counting billPayment (card repayment from bank debit)
      if (t.type == TransactionType.billPayment) continue;

      if (t.type.isIncome) {
        totalIncome += t.amount;
      } else if (t.type.isExpense) {
        totalExpense += t.amount;
      }
    }

    // Accounts balance sum
    final acctRes =
        await db.rawQuery('SELECT SUM(current_balance) as total FROM accounts');
    final totalAcctBal = (acctRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // Cards limits & outstanding
    final cardRes = await db.rawQuery(
        'SELECT SUM(outstanding) as out_total, SUM(available_limit) as avl_total FROM cards');
    final totalCardOut =
        (cardRes.first['out_total'] as num?)?.toDouble() ?? 0.0;
    final totalCardAvl =
        (cardRes.first['avl_total'] as num?)?.toDouble() ?? 0.0;

    // Upcoming bills
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final billRes = await db.rawQuery(
      "SELECT COUNT(*) as count, SUM(total_amount) as total FROM bills WHERE status = 'unpaid' AND due_date >= ?",
      [nowMs],
    );
    final upcomingCount = (billRes.first['count'] as int?) ?? 0;
    final upcomingTotal = (billRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // Review count
    final reviewTxns = await getNeedsReviewTransactions();

    return FinancialSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: totalIncome - totalExpense,
      totalAccountBalance: totalAcctBal,
      totalCardOutstanding: totalCardOut,
      totalAvailableCredit: totalCardAvl,
      upcomingBillsCount: upcomingCount,
      upcomingBillsTotal: upcomingTotal,
      needsReviewCount: reviewTxns.length,
      currency: 'INR',
    );
  }
}
