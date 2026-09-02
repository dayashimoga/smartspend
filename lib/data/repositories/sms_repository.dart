import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/sms_record.dart';
import '../../domain/repositories/interfaces.dart';

class SmsRepository implements ISmsRepository {
  final DatabaseHelper _dbHelper;

  SmsRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> saveSms(SmsRecord record) async {
    final db = await _dbHelper.database;
    await db.insert(
      'raw_sms',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> saveBulkSms(List<SmsRecord> records) async {
    if (records.isEmpty) return;
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final r in records) {
      batch.insert(
        'raw_sms',
        r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<SmsRecord?> getSmsByFingerprint(String fingerprint) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'raw_sms',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return SmsRecord.fromMap(res.first);
  }

  @override
  Future<bool> existsByFingerprint(String fingerprint) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT 1 FROM raw_sms WHERE fingerprint = ? LIMIT 1',
      [fingerprint],
    );
    return res.isNotEmpty;
  }

  @override
  Future<List<SmsRecord>> getAllSms({int limit = 100, int offset = 0}) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'raw_sms',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return res.map((m) => SmsRecord.fromMap(m)).toList();
  }

  @override
  Future<SmsRecord?> getSmsById(String id) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'raw_sms',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return SmsRecord.fromMap(res.first);
  }

  @override
  Future<int> getSmsCount() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM raw_sms');
    return (res.first['count'] as int?) ?? 0;
  }
}
