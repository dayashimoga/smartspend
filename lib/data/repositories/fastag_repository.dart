import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/fastag_record.dart';
import '../../domain/repositories/interfaces.dart';

class FastagRepository implements IFastagRepository {
  final DatabaseHelper _dbHelper;

  FastagRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> upsertFastag(FastagRecord record) async {
    final db = await _dbHelper.database;
    await db.insert(
      'fastag',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<FastagRecord>> getAllFastag() async {
    final db = await _dbHelper.database;
    final res = await db.query('fastag', orderBy: 'last_updated DESC');
    return res.map((m) => FastagRecord.fromMap(m)).toList();
  }

  @override
  Future<FastagRecord?> getFastagByVehicleOrId(
      String? vehicle, String? fastagId) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (vehicle != null && vehicle.isNotEmpty) {
      whereClauses.add('vehicle = ?');
      whereArgs.add(vehicle);
    }
    if (fastagId != null && fastagId.isNotEmpty) {
      whereClauses.add('fastag_id = ?');
      whereArgs.add(fastagId);
    }

    if (whereClauses.isEmpty) return null;

    final res = await db.query(
      'fastag',
      where: whereClauses.join(' OR '),
      whereArgs: whereArgs,
      limit: 1,
    );
    if (res.isEmpty) return null;
    return FastagRecord.fromMap(res.first);
  }
}
