import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../crypto/key_manager.dart';

class DatabaseHelper {
  static const _dbName = 'smartspend_vault_v1.db';
  static const _dbVersion = 1;

  static DatabaseHelper? _instance;
  static Database? _database;
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
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onOpen: (db) async {
        // Enforce SQLCipher encryption key and foreign keys
        try {
          await db.execute("PRAGMA key = '$encryptionKey'");
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
        payment_transaction_id TEXT,
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
        UNIQUE(category, month, year)
      );
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic for future versions
  }

  /// Close and reset the database (for testing or user vault reset)
  static Future<void> resetDatabaseForTesting() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
