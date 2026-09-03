import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/bill.dart';
import '../../domain/enums/bank.dart';
import '../../domain/repositories/interfaces.dart';

class BillRepository implements IBillRepository {
  final DatabaseHelper _dbHelper;

  BillRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> upsertBill(Bill bill) async {
    final db = await _dbHelper.database;
    await db.insert(
      'bills',
      bill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Bill>> getAllBills() async {
    final db = await _dbHelper.database;
    final res = await db.query('bills', orderBy: 'due_date ASC');
    return res.map((m) => Bill.fromMap(m)).toList();
  }

  @override
  Future<List<Bill>> getBillsByCard(Bank bank, String cardLast4) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'bills',
      where: 'bank = ? AND card_last4 = ?',
      whereArgs: [bank.name, cardLast4],
      orderBy: 'due_date DESC',
    );
    return res.map((m) => Bill.fromMap(m)).toList();
  }

  @override
  Future<List<Bill>> getUpcomingBills({int days = 30}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final futureLimit = now.add(Duration(days: days)).millisecondsSinceEpoch;

    final res = await db.query(
      'bills',
      where: 'due_date <= ? AND status != ?',
      whereArgs: [futureLimit, BillStatus.paid.name],
      orderBy: 'due_date ASC',
    );
    return res.map((m) => Bill.fromMap(m)).toList();
  }
}
