import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/interfaces.dart';

class BudgetRepository implements IBudgetRepository {
  final DatabaseHelper _dbHelper;

  BudgetRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> upsertBudget(Budget budget) async {
    final db = await _dbHelper.database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Budget>> getBudgetsForMonth(int month, int year) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'budgets',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'monthly_limit DESC',
    );
    return res.map((m) => Budget.fromMap(m)).toList();
  }
}
