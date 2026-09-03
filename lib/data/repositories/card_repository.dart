import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/enums/bank.dart';
import '../../domain/repositories/interfaces.dart';

class CardRepository implements ICardRepository {
  final DatabaseHelper _dbHelper;

  CardRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  @override
  Future<void> upsertCard(CreditCard card) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cards',
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<CreditCard>> getAllCards() async {
    final db = await _dbHelper.database;
    final res = await db.query('cards', orderBy: 'last_updated DESC');
    return res.map((m) => CreditCard.fromMap(m)).toList();
  }

  @override
  Future<CreditCard?> getCardByBankAndLast4(Bank bank, String last4) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'cards',
      where: 'bank = ? AND last4 = ?',
      whereArgs: [bank.name, last4],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return CreditCard.fromMap(res.first);
  }

  @override
  Future<List<CreditCard>> getCardsByBank(Bank bank) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'cards',
      where: 'bank = ?',
      whereArgs: [bank.name],
      orderBy: 'last_updated DESC',
    );
    return res.map((m) => CreditCard.fromMap(m)).toList();
  }

  @override
  Future<List<CreditCard>> getCardsAsOf(DateTime asOf) async {
    final db = await _dbHelper.database;
    final cards = await getAllCards();
    final asOfMs = asOf.millisecondsSinceEpoch;

    final result = <CreditCard>[];
    for (final card in cards) {
      final txRes = await db.query(
        'parsed_transactions',
        where: 'bank = ? AND card_last4 = ? AND transaction_date <= ?',
        whereArgs: [card.bank.name, card.last4, asOfMs],
        orderBy: 'transaction_date DESC',
        limit: 1,
      );

      if (txRes.isNotEmpty) {
        final avl = (txRes.first['available_limit'] as num?)?.toDouble() ??
            card.availableLimit;
        final out = (txRes.first['outstanding'] as num?)?.toDouble() ??
            card.outstanding;
        final date = DateTime.fromMillisecondsSinceEpoch(
            txRes.first['transaction_date'] as int);
        result.add(card.copyWith(
            availableLimit: avl, outstanding: out, lastUpdated: date));
      } else {
        result.add(card);
      }
    }
    return result;
  }
}
