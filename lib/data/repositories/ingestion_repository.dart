import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/ingestion_checkpoint.dart';
import '../../domain/repositories/interfaces.dart';

class IngestionRepository implements IIngestionRepository {
  final DatabaseHelper _dbHelper;

  IngestionRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<IngestionCheckpoint?> getCheckpoint({String id = 'primary'}) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'ingestion_checkpoint',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return IngestionCheckpoint.fromMap(res.first);
  }

  @override
  Future<void> saveCheckpoint(IngestionCheckpoint checkpoint) async {
    final db = await _dbHelper.database;
    await db.insert(
      'ingestion_checkpoint',
      checkpoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clearCheckpoint({String id = 'primary'}) async {
    final db = await _dbHelper.database;
    await db.delete(
      'ingestion_checkpoint',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> saveHistory(IngestionHistoryRecord record) async {
    final db = await _dbHelper.database;
    await db.insert(
      'ingestion_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<IngestionHistoryRecord>> getHistory({int limit = 50}) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'ingestion_history',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return res.map((m) => IngestionHistoryRecord.fromMap(m)).toList();
  }

  @override
  Future<void> deleteHistory(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'ingestion_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
