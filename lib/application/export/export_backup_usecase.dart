import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/utils/crypto_utils.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/fastag_record.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/repositories/interfaces.dart';

class ImportResult {
  final int transactionsImported;
  final int accountsImported;
  final int cardsImported;
  final int billsImported;
  final int fastagsImported;

  const ImportResult({
    required this.transactionsImported,
    required this.accountsImported,
    required this.cardsImported,
    required this.billsImported,
    required this.fastagsImported,
  });

  int get totalImported =>
      transactionsImported +
      accountsImported +
      cardsImported +
      billsImported +
      fastagsImported;
}

class ExportBackupUseCase {
  final ITransactionRepository _txnRepo;
  final IAccountRepository _acctRepo;
  final ICardRepository _cardRepo;
  final IBillRepository _billRepo;
  final IFastagRepository _fastagRepo;

  ExportBackupUseCase({
    required ITransactionRepository txnRepo,
    required IAccountRepository acctRepo,
    required ICardRepository cardRepo,
    required IBillRepository billRepo,
    required IFastagRepository fastagRepo,
  })  : _txnRepo = txnRepo,
        _acctRepo = acctRepo,
        _cardRepo = cardRepo,
        _billRepo = billRepo,
        _fastagRepo = fastagRepo;

  /// Exports full financial database into an authenticated JSON format.
  /// If [passphrase] is supplied, protects the backup with PBKDF2-derived HMAC-SHA256 authentication.
  Future<String> exportToJson({String? passphrase}) async {
    final txns =
        await _txnRepo.getAllTransactions(limit: 50000, includeExcluded: true);
    final accts = await _acctRepo.getAllAccounts();
    final cards = await _cardRepo.getAllCards();
    final bills = await _billRepo.getAllBills();
    final fastags = await _fastagRepo.getAllFastag();

    final data = {
      'version': '1.1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'transactions': txns.map((t) => t.toMap()).toList(),
      'accounts': accts.map((a) => a.toMap()).toList(),
      'cards': cards.map((c) => c.toMap()).toList(),
      'bills': bills.map((b) => b.toMap()).toList(),
      'fastag': fastags.map((f) => f.toMap()).toList(),
    };

    final payloadBytes = utf8.encode(jsonEncode(data));

    if (passphrase != null && passphrase.isNotEmpty) {
      final saltBytes = CryptoUtils.generateRandomBytes(16);
      final saltHex =
          saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final key = CryptoUtils.pbkdf2HmacSha256(
        passphrase: passphrase,
        salt: saltBytes,
        iterations: 10000,
        keyLength: 32,
      );
      final authTag = CryptoUtils.computeHmacHex(key, payloadBytes);

      return jsonEncode({
        'format': 'smartspend-auth-v2',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'salt': saltHex,
        'iterations': 10000,
        'auth_tag': authTag,
        'payload': data,
      });
    }

    final checksum = sha256.convert(payloadBytes).toString();
    return jsonEncode({
      'checksum': checksum,
      'payload': data,
    });
  }

  /// Restores financial records from JSON string after validating authenticated integrity and sanitizing inputs.
  Future<ImportResult> importFromJson(String rawJson,
      {String? passphrase}) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid JSON backup file.');
    }

    if (!decoded.containsKey('payload')) {
      throw const FormatException('Corrupt backup structure: missing payload.');
    }

    final payload = decoded['payload'] as Map<String, dynamic>;
    final payloadBytes = utf8.encode(jsonEncode(payload));

    // 1. Authenticated v2 format check
    if (decoded['format'] == 'smartspend-auth-v2') {
      if (passphrase == null || passphrase.isEmpty) {
        throw const SecurityException(
            'Authentication required: Passphrase is required to restore this authenticated backup.');
      }

      final claimedTag = decoded['auth_tag'] as String? ?? '';
      final saltHex = decoded['salt'] as String? ?? '';
      final iterations = decoded['iterations'] as int? ?? 10000;

      final saltBytes = <int>[];
      for (int i = 0; i < saltHex.length; i += 2) {
        saltBytes.add(int.parse(saltHex.substring(i, i + 2), radix: 16));
      }

      final key = CryptoUtils.pbkdf2HmacSha256(
        passphrase: passphrase,
        salt: saltBytes,
        iterations: iterations,
        keyLength: 32,
      );

      final recomputedTag = CryptoUtils.computeHmacHex(key, payloadBytes);
      if (!CryptoUtils.constantTimeHexEquals(claimedTag, recomputedTag)) {
        throw const SecurityException(
            'Backup authentication failure: Invalid passphrase or tampered backup payload.');
      }
    } else if (decoded.containsKey('checksum')) {
      // Legacy v1 checksum verification
      final claimedChecksum = decoded['checksum'] as String;
      final recomputedChecksum = sha256.convert(payloadBytes).toString();
      if (claimedChecksum != recomputedChecksum) {
        throw const SecurityException(
            'Backup integrity failure: Checksum mismatch. The file may have been modified or corrupted.');
      }
    } else {
      throw const FormatException(
          'Unrecognized backup format: missing auth_tag or checksum.');
    }

    int txnsCount = 0;
    int acctsCount = 0;
    int cardsCount = 0;
    int billsCount = 0;
    int fastagCount = 0;

    // 2. Import & Validate Transactions
    if (payload.containsKey('transactions')) {
      final txnsList = payload['transactions'] as List<dynamic>;
      for (final raw in txnsList) {
        if (raw is! Map<String, dynamic>) continue;
        final sanitized = _sanitizeTransactionMap(raw);
        if (sanitized != null) {
          try {
            await _txnRepo
                .saveTransaction(ParsedTransaction.fromMap(sanitized));
            txnsCount++;
          } catch (_) {}
        }
      }
    }

    // 3. Import & Validate Accounts
    if (payload.containsKey('accounts')) {
      final acctsList = payload['accounts'] as List<dynamic>;
      for (final raw in acctsList) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          await _acctRepo.upsertAccount(Account.fromMap(raw));
          acctsCount++;
        } catch (_) {}
      }
    }

    // 4. Import & Validate Cards
    if (payload.containsKey('cards')) {
      final cardsList = payload['cards'] as List<dynamic>;
      for (final raw in cardsList) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          await _cardRepo.upsertCard(CreditCard.fromMap(raw));
          cardsCount++;
        } catch (_) {}
      }
    }

    // 5. Import & Validate Bills
    if (payload.containsKey('bills')) {
      final billsList = payload['bills'] as List<dynamic>;
      for (final raw in billsList) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          await _billRepo.upsertBill(Bill.fromMap(raw));
          billsCount++;
        } catch (_) {}
      }
    }

    // 6. Import & Validate FASTag
    if (payload.containsKey('fastag')) {
      final fastagsList = payload['fastag'] as List<dynamic>;
      for (final raw in fastagsList) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          await _fastagRepo.upsertFastag(FastagRecord.fromMap(raw));
          fastagCount++;
        } catch (_) {}
      }
    }

    return ImportResult(
      transactionsImported: txnsCount,
      accountsImported: acctsCount,
      cardsImported: cardsCount,
      billsImported: billsCount,
      fastagsImported: fastagCount,
    );
  }

  Map<String, dynamic>? _sanitizeTransactionMap(Map<String, dynamic> raw) {
    // Basic bounds validation
    final amountNum = raw['amount'];
    if (amountNum is! num || amountNum.isNaN || amountNum.isInfinite) {
      return null;
    }
    final amount = amountNum.toDouble();
    if (amount < 0 || amount > 1000000000) {
      return null;
    }

    final dateNum = raw['transaction_date'];
    if (dateNum is! int) return null;
    // Check reasonable date bounds (year 2000 to 2100 in ms)
    if (dateNum < 946684800000 || dateNum > 4102444800000) {
      return null;
    }

    // Sanitize strings & length limits to prevent overflow / injection
    final sanitized = Map<String, dynamic>.from(raw);
    sanitized['merchant'] = _sanitizeString(raw['merchant'], 120);
    sanitized['payee'] = _sanitizeString(raw['payee'], 120);
    sanitized['payer'] = _sanitizeString(raw['payer'], 120);
    sanitized['category'] =
        _sanitizeString(raw['category'], 60) ?? 'Uncategorized';
    sanitized['reference'] = _sanitizeString(raw['reference'], 60);
    sanitized['card_last4'] = _sanitizeLast4(raw['card_last4']);
    sanitized['account_last4'] = _sanitizeLast4(raw['account_last4']);

    return sanitized;
  }

  String? _sanitizeString(dynamic val, int maxLength) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    final cleaned = str.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }

  String? _sanitizeLast4(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (RegExp(r'^\d{3,4}$').hasMatch(str)) {
      return str;
    }
    return null;
  }

  /// Exports transactions to CSV string for spreadsheets.
  Future<String> exportToCsv() async {
    final txns =
        await _txnRepo.getAllTransactions(limit: 50000, includeExcluded: true);
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln(
        'Date,Type,Bank,Amount,Currency,Merchant,Category,Account,Card,Reference,Status');

    for (final t in txns) {
      final dateStr = t.transactionDate.toIso8601String().split('T').first;
      final typeStr = t.type.name;
      final bankStr = t.bank.displayName;
      final amt = t.amount.toStringAsFixed(2);
      final curr = t.currency;
      final merchant =
          '"${(t.merchant ?? t.payee ?? '').replaceAll('"', '""')}"';
      final category = '"${t.category.replaceAll('"', '""')}"';
      final acct = t.accountLast4 ?? '';
      final card = t.cardLast4 ?? '';
      final ref = t.reference ?? '';
      final status = t.isExcluded ? 'Excluded' : 'Active';

      buffer.writeln(
          '$dateStr,$typeStr,$bankStr,$amt,$curr,$merchant,$category,$acct,$card,$ref,$status');
    }

    return buffer.toString();
  }
}

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
