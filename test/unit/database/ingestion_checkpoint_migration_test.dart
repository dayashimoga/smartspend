import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartspend/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testDbName = 'test_migration_v5_v6.db';

  setUp(() async {
    await databaseFactory.deleteDatabase(testDbName);
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(testDbName);
  });

  group('Database Schema Migration v5 -> v6 Forensic Suite', () {
    test(
        'Migrates from v5 to v6 creating ingestion_checkpoint and ingestion_history tables',
        () async {
      // 1. Create v5 schema
      var db = await openDatabase(
        testDbName,
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE raw_sms (
              id TEXT PRIMARY KEY,
              sender TEXT NOT NULL,
              body TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              fingerprint TEXT NOT NULL UNIQUE,
              ingested_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE parsed_transactions (
              id TEXT PRIMARY KEY,
              raw_sms_id TEXT NOT NULL,
              type TEXT NOT NULL,
              bank TEXT NOT NULL,
              amount REAL NOT NULL,
              currency TEXT NOT NULL,
              transaction_date INTEGER NOT NULL,
              confidence TEXT NOT NULL,
              parser_version TEXT NOT NULL,
              category TEXT NOT NULL,
              is_excluded INTEGER NOT NULL DEFAULT 0,
              is_reconciled INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      );

      // Insert pre-existing v5 record
      await db.insert('raw_sms', {
        'id': 'sms_pre_v6',
        'sender': 'HDFCBK',
        'body': 'Rs 500 spent on card 9137',
        'timestamp': 1768000000000,
        'fingerprint': 'fp_pre_v6',
        'ingested_at': 1768000000000,
      });
      await db.close();

      // 2. Perform upgrade to v6 using DatabaseHelper
      final helper = DatabaseHelper.inMemory();
      db = await openDatabase(testDbName, version: 6);
      await helper.testOnUpgrade(db, 5, 6);

      // 3. Verify original data preserved
      final smsRows = await db.query('raw_sms');
      expect(smsRows.length, equals(1));
      expect(smsRows.first['id'], equals('sms_pre_v6'));

      // 4. Verify ingestion_checkpoint table exists and accepts writes
      await db.insert('ingestion_checkpoint', {
        'id': 'primary',
        'last_sms_id': 'sms_pre_v6',
        'last_timestamp': 1768000000000,
        'parser_version': '1.0.0',
        'batch_offset': 1,
        'stage': 'completed',
        'scanned_count': 1,
        'transactions_count': 1,
        'bills_count': 0,
        'accounts_count': 0,
        'balances_count': 0,
        'financial_count': 1,
        'duplicates_count': 0,
        'ignored_count': 0,
        'review_count': 0,
        'failed_count': 0,
        'last_updated': 1768000000000,
        'is_completed': 1,
      });

      final cpRows = await db.query('ingestion_checkpoint');
      expect(cpRows.length, equals(1));
      expect(cpRows.first['parser_version'], equals('1.0.0'));

      // 5. Verify ingestion_history table exists and accepts writes
      await db.insert('ingestion_history', {
        'id': 'hist_1',
        'started_at': 1768000000000,
        'completed_at': 1768000001000,
        'status': 'completed',
        'total_scanned': 1,
        'financial_count': 1,
        'transactions_count': 1,
        'bills_count': 0,
        'balances_count': 0,
        'duplicates_count': 0,
        'ignored_count': 0,
        'review_count': 0,
        'failed_count': 0,
        'parser_version': '1.0.0',
      });

      final histRows = await db.query('ingestion_history');
      expect(histRows.length, equals(1));

      await db.close();
      await helper.close();
    });
  });
}
