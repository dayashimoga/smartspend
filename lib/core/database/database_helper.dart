import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../crypto/key_manager.dart';

class DatabaseHelper {
  static const _dbName = 'smartspend_vault_v1.db';
  static const _dbVersion = 6;

  static DatabaseHelper? _instance;
  static Database? _staticDatabase;
  Database? _instanceDatabase;
  final String? _customDbPath;

  DatabaseHelper._internal({String? customDbPath})
      : _customDbPath = customDbPath;

  factory DatabaseHelper({String? customDbPath}) {
    if (customDbPath != null) {
      return DatabaseHelper._internal(customDbPath: customDbPath);
    }
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  factory DatabaseHelper.inMemory() {
    return DatabaseHelper._internal(customDbPath: inMemoryDatabasePath);
  }

  Future<Database> get database async {
    if (_customDbPath != null) {
      if (_instanceDatabase != null && _instanceDatabase!.isOpen) {
        return _instanceDatabase!;
      }
      _instanceDatabase = await _initDatabase();
      return _instanceDatabase!;
    }

    if (_staticDatabase != null && _staticDatabase!.isOpen) {
      return _staticDatabase!;
    }
    _staticDatabase = await _initDatabase();
    return _staticDatabase!;
  }

  Future<Database> _initDatabase() async {
    // For unit tests / desktop test runner without platform channels
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (_customDbPath != null) {
      dbPath = _customDbPath;
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = join(appDocDir.path, 'SmartSpend', _dbName);
      final dir = Directory(dirname(dbPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = join(databasesPath, _dbName);
    }

    // Retrieve or generate the AES-256 encryption key
    final encryptionKey = await KeyManager.getOrCreateDatabaseKey();
    final escapedKey = encryptionKey.replaceAll("'", "''");

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (_) {}
      },
      onOpen: (db) async {
        // Enforce SQLCipher encryption key
        try {
          await db.execute("PRAGMA key = '$escapedKey'");
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (_) {}
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
      CREATE INDEX idx_raw_sms_fingerprint ON raw_sms(fingerprint);
    ''');

    await db.execute('''
      CREATE TABLE parsed_transactions (
        id TEXT PRIMARY KEY,
        raw_sms_id TEXT NOT NULL,
        type TEXT NOT NULL,
        bank TEXT NOT NULL,
        account_last4 TEXT,
        card_last4 TEXT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        transaction_date INTEGER NOT NULL,
        merchant TEXT,
        payee TEXT,
        payer TEXT,
        reference TEXT,
        rrn TEXT,
        upi_ref TEXT,
        balance REAL,
        available_limit REAL,
        outstanding REAL,
        bill_total REAL,
        bill_minimum REAL,
        bill_due_date INTEGER,
        fastag_id TEXT,
        vehicle TEXT,
        toll_plaza TEXT,
        wallet_balance REAL,
        confidence TEXT NOT NULL,
        parser_version TEXT NOT NULL,
        category TEXT NOT NULL,
        tags TEXT,
        is_excluded INTEGER NOT NULL DEFAULT 0,
        is_reconciled INTEGER NOT NULL DEFAULT 0,
        reconciled_with_id TEXT,
        transfer_account_id TEXT,
        reconciliation_notes TEXT,
        sms_received_at INTEGER,
        statement_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (raw_sms_id) REFERENCES raw_sms(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_date ON parsed_transactions(transaction_date);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_bank ON parsed_transactions(bank);
    ''');
    await db.execute('''
      CREATE INDEX idx_transactions_type ON parsed_transactions(type);
    ''');

    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        bank TEXT NOT NULL,
        last4 TEXT NOT NULL,
        account_type TEXT NOT NULL,
        current_balance REAL NOT NULL,
        currency TEXT NOT NULL,
        last_updated INTEGER NOT NULL,
        UNIQUE(bank, last4)
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
        statement_due REAL,
        current_due REAL,
        last_statement_date INTEGER,
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
        biller_name TEXT,
        account_number TEXT,
        total_amount REAL NOT NULL,
        minimum_amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        due_date INTEGER NOT NULL,
        status TEXT NOT NULL,
        currency TEXT NOT NULL,
        payment_transaction_id TEXT,
        source_date INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE fastag (
        id TEXT PRIMARY KEY,
        fastag_id TEXT,
        vehicle TEXT,
        bank TEXT,
        latest_wallet_balance REAL,
        currency TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE corrections (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        original_value TEXT,
        corrected_value TEXT,
        reason TEXT NOT NULL,
        applied_at INTEGER NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES parsed_transactions(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        currency TEXT NOT NULL,
        current_spend REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        notes TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 1,
        UNIQUE(category, month, year)
      );
    ''');

    await db.execute('''
      CREATE TABLE ingestion_checkpoint (
        id TEXT PRIMARY KEY,
        last_sms_id TEXT,
        last_timestamp INTEGER NOT NULL DEFAULT 0,
        last_fingerprint TEXT,
        parser_version TEXT NOT NULL,
        batch_offset INTEGER NOT NULL DEFAULT 0,
        stage TEXT NOT NULL DEFAULT 'idle',
        total_count INTEGER,
        scanned_count INTEGER NOT NULL DEFAULT 0,
        transactions_count INTEGER NOT NULL DEFAULT 0,
        bills_count INTEGER NOT NULL DEFAULT 0,
        accounts_count INTEGER NOT NULL DEFAULT 0,
        balances_count INTEGER NOT NULL DEFAULT 0,
        financial_count INTEGER NOT NULL DEFAULT 0,
        duplicates_count INTEGER NOT NULL DEFAULT 0,
        ignored_count INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        failed_count INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE ingestion_history (
        id TEXT PRIMARY KEY,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        status TEXT NOT NULL,
        total_scanned INTEGER NOT NULL,
        financial_count INTEGER NOT NULL,
        transactions_count INTEGER NOT NULL,
        bills_count INTEGER NOT NULL,
        balances_count INTEGER NOT NULL,
        duplicates_count INTEGER NOT NULL,
        ignored_count INTEGER NOT NULL,
        review_count INTEGER NOT NULL,
        failed_count INTEGER NOT NULL,
        parser_version TEXT NOT NULL,
        error_message TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_ingestion_history_started ON ingestion_history(started_at);
    ''');
  }

  Future<void> close() async {
    if (_instanceDatabase != null && _instanceDatabase!.isOpen) {
      await _instanceDatabase!.close();
      _instanceDatabase = null;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      await db.transaction((txn) async {
        switch (v) {
          case 2:
            await txn.execute('ALTER TABLE budgets ADD COLUMN notes TEXT');
            await txn.execute(
                'ALTER TABLE budgets ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 1');
            break;
          case 3:
            await txn.execute(
                'ALTER TABLE parsed_transactions ADD COLUMN transfer_account_id TEXT');
            await txn.execute(
                'ALTER TABLE parsed_transactions ADD COLUMN reconciliation_notes TEXT');
            break;
          case 4:
            await txn.execute(
                'ALTER TABLE parsed_transactions ADD COLUMN sms_received_at INTEGER');
            await txn.execute(
                'ALTER TABLE parsed_transactions ADD COLUMN statement_date INTEGER');
            await txn
                .execute('ALTER TABLE cards ADD COLUMN statement_due REAL');
            await txn.execute('ALTER TABLE cards ADD COLUMN current_due REAL');
            await txn.execute(
                'ALTER TABLE cards ADD COLUMN last_statement_date INTEGER');
            await txn.execute(
                'UPDATE parsed_transactions SET sms_received_at = transaction_date WHERE sms_received_at IS NULL');
            break;
          case 5:
            await txn.execute(
                'ALTER TABLE bills ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0.0');
            await txn
                .execute('ALTER TABLE bills ADD COLUMN source_date INTEGER');
            await txn.execute('ALTER TABLE bills ADD COLUMN biller_name TEXT');
            await txn
                .execute('ALTER TABLE bills ADD COLUMN account_number TEXT');
            break;
          case 6:
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS ingestion_checkpoint (
                id TEXT PRIMARY KEY,
                last_sms_id TEXT,
                last_timestamp INTEGER NOT NULL DEFAULT 0,
                last_fingerprint TEXT,
                parser_version TEXT NOT NULL,
                batch_offset INTEGER NOT NULL DEFAULT 0,
                stage TEXT NOT NULL DEFAULT 'idle',
                total_count INTEGER,
                scanned_count INTEGER NOT NULL DEFAULT 0,
                transactions_count INTEGER NOT NULL DEFAULT 0,
                bills_count INTEGER NOT NULL DEFAULT 0,
                accounts_count INTEGER NOT NULL DEFAULT 0,
                balances_count INTEGER NOT NULL DEFAULT 0,
                financial_count INTEGER NOT NULL DEFAULT 0,
                duplicates_count INTEGER NOT NULL DEFAULT 0,
                ignored_count INTEGER NOT NULL DEFAULT 0,
                review_count INTEGER NOT NULL DEFAULT 0,
                failed_count INTEGER NOT NULL DEFAULT 0,
                last_updated INTEGER NOT NULL,
                is_completed INTEGER NOT NULL DEFAULT 0
              );
            ''');
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS ingestion_history (
                id TEXT PRIMARY KEY,
                started_at INTEGER NOT NULL,
                completed_at INTEGER,
                status TEXT NOT NULL,
                total_scanned INTEGER NOT NULL,
                financial_count INTEGER NOT NULL,
                transactions_count INTEGER NOT NULL,
                bills_count INTEGER NOT NULL,
                balances_count INTEGER NOT NULL,
                duplicates_count INTEGER NOT NULL,
                ignored_count INTEGER NOT NULL,
                review_count INTEGER NOT NULL,
                failed_count INTEGER NOT NULL,
                parser_version TEXT NOT NULL,
                error_message TEXT
              );
            ''');
            await txn.execute('''
              CREATE INDEX IF NOT EXISTS idx_ingestion_history_started ON ingestion_history(started_at);
            ''');
            break;
        }
      });
    }
  }

  /// Direct migration testing helper
  @visibleForTesting
  Future<void> testOnUpgrade(
      Database db, int oldVersion, int newVersion) async {
    await _onUpgrade(db, oldVersion, newVersion);
  }

  /// Close and reset the database (for testing or user vault reset)
  static Future<void> resetDatabaseForTesting() async {
    if (_staticDatabase != null && _staticDatabase!.isOpen) {
      await _staticDatabase!.close();
      _staticDatabase = null;
    }
    _instance = null;
  }
}
