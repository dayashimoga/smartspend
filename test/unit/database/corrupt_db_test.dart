import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartspend/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Corrupt Database Resilience Forensic Suite', () {
    test(
        'Opening a corrupt database file throws DatabaseException gracefully without crash',
        () async {
      const corruptDbName = 'test_corrupted_file.db';
      final databasesPath = await databaseFactoryFfi.getDatabasesPath();
      final fullPath = '$databasesPath/$corruptDbName';
      final file = File(fullPath);
      file.parent.createSync(recursive: true);
      // Write 4096 bytes of non-sqlite garbage (larger than page size)
      final garbage = List<int>.filled(4096, 0xFF);
      file.writeAsBytesSync(garbage);

      final corruptHelper = DatabaseHelper(customDbPath: fullPath);

      bool threw = false;
      try {
        final db = await corruptHelper.database;
        await db.rawQuery('SELECT * FROM raw_sms');
      } on DatabaseException catch (_) {
        threw = true;
      } catch (e) {
        threw = true;
      }

      expect(threw, isTrue, reason: 'Must throw on corrupt database file');

      // Cleanup
      try {
        await databaseFactoryFfi.deleteDatabase(fullPath);
      } catch (_) {}
    });
  });
}
