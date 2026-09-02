import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/correction.dart';
import '../../domain/repositories/interfaces.dart';

class CorrectionRepository implements ICorrectionRepository {
  final DatabaseHelper _dbHelper;

  CorrectionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> saveCorrection(Correction correction) async {
    final db = await _dbHelper.database;
    await db.insert(
      'corrections',
      correction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<Correction>> getCorrectionsForTransaction(
      String transactionId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'corrections',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'applied_at DESC',
    );
    return res.map((m) => Correction.fromMap(m)).toList();
  }

  @override
  Future<void> deleteCorrection(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'corrections',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
