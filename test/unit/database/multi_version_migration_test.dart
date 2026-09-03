import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartspend/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const testDbName1 = 'test_migration_v1_v3.db';
  const testDbName2 = 'test_migration_rollback.db';
  const testDbName3 = 'test_migration_v1_v5.db';

  setUp(() async {
    await databaseFactory.deleteDatabase(testDbName1);
    await databaseFactory.deleteDatabase(testDbName2);
    await databaseFactory.deleteDatabase(testDbName3);
  });

  tearDown(() async {
    await databaseFactory.deleteDatabase(testDbName1);
    await databaseFactory.deleteDatabase(testDbName2);
    await databaseFactory.deleteDatabase(testDbName3);
  });

  group('Multi-Version Database Migration & Rollback Forensic Suite', () {
    test('Migrate v1 -> v2 -> v3 preserves existing data and adds new columns',
        () async {
      // 1. Create v1 schema and write to file
      var db = await openDatabase(
        testDbName1,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE budgets (
              id TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              monthly_limit REAL NOT NULL,
              currency TEXT NOT NULL,
              current_spend REAL NOT NULL,
              month INTEGER NOT NULL,
              year INTEGER NOT NULL,
              UNIQUE(category, month, year)
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
              reconciled_with_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      );

      // Insert seed data into v1
      await db.insert('budgets', {
        'id': 'b1',
        'category': 'Groceries',
        'monthly_limit': 15000.0,
        'currency': 'INR',
        'current_spend': 5000.0,
        'month': 1,
        'year': 2026,
      });

      await db.insert('parsed_transactions', {
        'id': 't1',
        'raw_sms_id': 'sms1',
        'type': 'debit',
        'bank': 'hdfc',
        'amount': 2500.0,
        'currency': 'INR',
        'transaction_date': 1768000000000,
        'confidence': 'HIGH',
        'parser_version': '1.0.0',
        'category': 'Shopping',
        'is_excluded': 0,
        'is_reconciled': 0,
        'created_at': 1768000000000,
        'updated_at': 1768000000000,
      });

      await db.close();

      // 2. Re-open with version 3 and run migration
      db = await openDatabase(
        testDbName1,
        version: 3,
        onUpgrade: (db, oldVersion, newVersion) async {
          for (int v = oldVersion + 1; v <= newVersion; v++) {
            await db.transaction((txn) async {
              switch (v) {
                case 2:
                  await txn
                      .execute('ALTER TABLE budgets ADD COLUMN notes TEXT');
                  await txn.execute(
                      'ALTER TABLE budgets ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 1');
                  break;
                case 3:
                  await txn.execute(
                      'ALTER TABLE parsed_transactions ADD COLUMN transfer_account_id TEXT');
                  await txn.execute(
                      'ALTER TABLE parsed_transactions ADD COLUMN reconciliation_notes TEXT');
                  break;
              }
            });
          }
        },
      );

      // 3. Verify original data is preserved
      final budgets = await db.query('budgets');
      expect(budgets.length, equals(1));
      expect(budgets.first['category'], equals('Groceries'));
      expect(budgets.first['monthly_limit'], equals(15000.0));
      expect(budgets.first['is_recurring'], equals(1)); // Default applied

      final txns = await db.query('parsed_transactions');
      expect(txns.length, equals(1));
      expect(txns.first['amount'], equals(2500.0));

      // 4. Update new columns
      await db.update('budgets', {'notes': 'Monthly grocery cap'},
          where: 'id = ?', whereArgs: ['b1']);
      final updatedBudget =
          await db.query('budgets', where: 'id = ?', whereArgs: ['b1']);
      expect(updatedBudget.first['notes'], equals('Monthly grocery cap'));

      await db.update(
          'parsed_transactions',
          {
            'transfer_account_id': 'acct_target_99',
            'reconciliation_notes': 'Verified own-account transfer',
          },
          where: 'id = ?',
          whereArgs: ['t1']);
      final updatedTxn = await db
          .query('parsed_transactions', where: 'id = ?', whereArgs: ['t1']);
      expect(updatedTxn.first['transfer_account_id'], equals('acct_target_99'));
      expect(updatedTxn.first['reconciliation_notes'],
          equals('Verified own-account transfer'));

      await db.close();
    });

    test('Migration transaction rollback safety on failure', () async {
      var db = await openDatabase(
        testDbName2,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE test_table (id TEXT PRIMARY KEY, val TEXT)');
        },
      );
      await db.insert('test_table', {'id': '1', 'val': 'original'});
      await db.close();

      // Trigger failing migration inside transaction
      bool caughtError = false;
      try {
        db = await openDatabase(
          testDbName2,
          version: 2,
          onUpgrade: (db, oldVersion, newVersion) async {
            await db.transaction((txn) async {
              await txn.execute('ALTER TABLE test_table ADD COLUMN col2 TEXT');
              // Intentionally bad SQL syntax to trigger error
              await txn.execute('INVALID SQL SYNTAX HERE THAT MUST FAIL');
            });
          },
        );
      } catch (_) {
        caughtError = true;
      }

      expect(caughtError, isTrue);

      // Reopen at version 1 - database should not be corrupted and original data intact
      db = await openDatabase(testDbName2, version: 1);
      final rows = await db.query('test_table');
      expect(rows.length, equals(1));
      expect(rows.first['val'], equals('original'));
      await db.close();
    });

    test(
        'DatabaseHelper testOnUpgrade successfully migrates all steps from v1 to v5',
        () async {
      var db = await openDatabase(
        testDbName3,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE budgets (
              id TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              monthly_limit REAL NOT NULL,
              currency TEXT NOT NULL,
              current_spend REAL NOT NULL,
              month INTEGER NOT NULL,
              year INTEGER NOT NULL,
              UNIQUE(category, month, year)
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
              reconciled_with_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE cards (
              id TEXT PRIMARY KEY,
              bank TEXT NOT NULL,
              last4 TEXT NOT NULL,
              available_limit REAL,
              total_limit REAL,
              outstanding REAL,
              currency TEXT NOT NULL,
              last_updated INTEGER NOT NULL,
              UNIQUE(bank, last4)
            );
          ''');
          await db.execute('''
            CREATE TABLE bills (
              id TEXT PRIMARY KEY,
              bank TEXT NOT NULL,
              card_last4 TEXT NOT NULL,
              total_amount REAL NOT NULL,
              minimum_amount REAL NOT NULL,
              due_date INTEGER NOT NULL,
              status TEXT NOT NULL,
              currency TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');
        },
      );

      final helper = DatabaseHelper.inMemory();
      await helper.testOnUpgrade(db, 1, 5);

      // Verify v2 columns on budgets
      final budgetCols = await db.rawQuery('PRAGMA table_info(budgets)');
      final budgetNames = budgetCols.map((c) => c['name'] as String).toList();
      expect(budgetNames.contains('notes'), isTrue);
      expect(budgetNames.contains('is_recurring'), isTrue);

      // Verify v3 and v4 columns on parsed_transactions
      final txnCols =
          await db.rawQuery('PRAGMA table_info(parsed_transactions)');
      final txnNames = txnCols.map((c) => c['name'] as String).toList();
      expect(txnNames.contains('transfer_account_id'), isTrue);
      expect(txnNames.contains('reconciliation_notes'), isTrue);
      expect(txnNames.contains('sms_received_at'), isTrue);
      expect(txnNames.contains('statement_date'), isTrue);

      // Verify v4 columns on cards
      final cardCols = await db.rawQuery('PRAGMA table_info(cards)');
      final cardNames = cardCols.map((c) => c['name'] as String).toList();
      expect(cardNames.contains('statement_due'), isTrue);
      expect(cardNames.contains('current_due'), isTrue);
      expect(cardNames.contains('last_statement_date'), isTrue);

      // Verify v5 columns on bills
      final billCols = await db.rawQuery('PRAGMA table_info(bills)');
      final billNames = billCols.map((c) => c['name'] as String).toList();
      expect(billNames.contains('paid_amount'), isTrue);
      expect(billNames.contains('source_date'), isTrue);
      expect(billNames.contains('biller_name'), isTrue);
      expect(billNames.contains('account_number'), isTrue);

      await db.close();
      await helper.close();
    });
  });
}
