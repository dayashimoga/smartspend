import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../domain/repositories/interfaces.dart';

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

  /// Exports full financial database into an encrypted or plain JSON format.
  Future<String> exportToJson() async {
    final txns =
        await _txnRepo.getAllTransactions(limit: 50000, includeExcluded: true);
    final accts = await _acctRepo.getAllAccounts();
    final cards = await _cardRepo.getAllCards();
    final bills = await _billRepo.getAllBills();
    final fastags = await _fastagRepo.getAllFastag();

    final data = {
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'transactions': txns.map((t) => t.toMap()).toList(),
      'accounts': accts.map((a) => a.toMap()).toList(),
      'cards': cards.map((c) => c.toMap()).toList(),
      'bills': bills.map((b) => b.toMap()).toList(),
      'fastag': fastags.map((f) => f.toMap()).toList(),
    };

    final jsonString = jsonEncode(data);
    final checksum = sha256.convert(utf8.encode(jsonString)).toString();

    return jsonEncode({
      'checksum': checksum,
      'payload': data,
    });
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
