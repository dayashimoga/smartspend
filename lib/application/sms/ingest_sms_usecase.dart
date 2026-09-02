import 'package:uuid/uuid.dart';
import '../../data/parsers/parser_pipeline.dart';
import '../../data/parsers/reconciler.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/fastag_record.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/entities/sms_record.dart';
import '../../domain/enums/bank.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/interfaces.dart';

class IngestionResult {
  final int totalScanned;
  final int newlyIngested;
  final int duplicatesSkipped;
  final int needsReviewCount;

  const IngestionResult({
    required this.totalScanned,
    required this.newlyIngested,
    required this.duplicatesSkipped,
    required this.needsReviewCount,
  });

  @override
  String toString() =>
      'IngestionResult(scanned: $totalScanned, ingested: $newlyIngested, skipped: $duplicatesSkipped, needsReview: $needsReviewCount)';
}

class IngestSmsUseCase {
  final ISmsRepository _smsRepo;
  final ITransactionRepository _txnRepo;
  final IAccountRepository _acctRepo;
  final ICardRepository _cardRepo;
  final IBillRepository _billRepo;
  final IFastagRepository _fastagRepo;
  final ParserPipeline _pipeline;

  IngestSmsUseCase({
    required ISmsRepository smsRepo,
    required ITransactionRepository txnRepo,
    required IAccountRepository acctRepo,
    required ICardRepository cardRepo,
    required IBillRepository billRepo,
    required IFastagRepository fastagRepo,
    ParserPipeline? pipeline,
  })  : _smsRepo = smsRepo,
        _txnRepo = txnRepo,
        _acctRepo = acctRepo,
        _cardRepo = cardRepo,
        _billRepo = billRepo,
        _fastagRepo = fastagRepo,
        _pipeline = pipeline ?? ParserPipeline();

  /// Ingests a list of SMS messages idempotently.
  /// Repeated calls with the same messages produce zero duplicate transactions.
  Future<IngestionResult> execute(
      List<Map<String, dynamic>> rawMessages) async {
    int newlyIngested = 0;
    int duplicatesSkipped = 0;
    int needsReviewCount = 0;

    for (final msg in rawMessages) {
      final sender = (msg['sender'] as String?)?.trim() ?? 'UNKNOWN';
      final body = (msg['body'] as String?)?.trim() ?? '';
      if (body.isEmpty) continue;

      final dynamic rawTime = msg['timestamp'];
      DateTime timestamp;
      if (rawTime is DateTime) {
        timestamp = rawTime;
      } else if (rawTime is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(rawTime);
      } else if (rawTime is String) {
        timestamp = DateTime.tryParse(rawTime) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }

      // Step 1: Generate deterministic SHA-256 fingerprint
      final fingerprint =
          SmsRecord.generateFingerprint(sender, body, timestamp);

      // Step 2: Check for existing fingerprint (Idempotent ingestion guarantee)
      final exists = await _smsRepo.existsByFingerprint(fingerprint);
      if (exists) {
        duplicatesSkipped++;
        continue;
      }

      // Step 3: Persist immutable raw SMS record
      final rawSmsId = const Uuid().v4();
      final smsRecord = SmsRecord(
        id: rawSmsId,
        sender: sender,
        body: body,
        timestamp: timestamp,
        fingerprint: fingerprint,
        ingestedAt: DateTime.now(),
      );
      await _smsRepo.saveSms(smsRecord);

      // Step 4: Parse SMS through pipeline
      var parsed = _pipeline.parseSms(
        rawSmsId: rawSmsId,
        sender: sender,
        rawBody: body,
        timestamp: timestamp,
      );

      // Step 5: Real-time reconciliation against historical transactions
      final historicalCandidates = await _txnRepo.getAllTransactions(
        limit: 100,
        bank: parsed.bank != Bank.unknown ? parsed.bank : null,
      );
      final match = Reconciler.reconcileSingle(parsed, historicalCandidates);
      parsed = match.updatedCurrent;

      if (match.matchedOther != null) {
        await _txnRepo.updateTransaction(match.matchedOther!);
      }

      // Step 6: Save parsed transaction
      await _txnRepo.saveTransaction(parsed);
      newlyIngested++;

      if (parsed.confidence.needsReview) {
        needsReviewCount++;
      }

      // Step 7: Update Associated Entities
      await _updateAssociatedEntities(parsed);
    }

    return IngestionResult(
      totalScanned: rawMessages.length,
      newlyIngested: newlyIngested,
      duplicatesSkipped: duplicatesSkipped,
      needsReviewCount: needsReviewCount,
    );
  }

  Future<void> _updateAssociatedEntities(ParsedTransaction txn) async {
    // 1. Update Bank Account balance if applicable
    if (txn.accountLast4 != null && txn.bank != Bank.unknown) {
      final existing =
          await _acctRepo.getAccountByBankAndLast4(txn.bank, txn.accountLast4!);
      final newBalance = txn.balance ?? existing?.currentBalance ?? 0.0;

      await _acctRepo.upsertAccount(
        Account(
          id: existing?.id ?? const Uuid().v4(),
          bank: txn.bank,
          last4: txn.accountLast4!,
          accountType:
              txn.type == TransactionType.salary ? 'Salary' : 'Savings',
          currentBalance: newBalance,
          currency: txn.currency,
          lastUpdated: txn.transactionDate,
        ),
      );
    }

    // 2. Update Credit Card if applicable
    if (txn.cardLast4 != null && txn.bank != Bank.unknown) {
      final existing =
          await _cardRepo.getCardByBankAndLast4(txn.bank, txn.cardLast4!);
      await _cardRepo.upsertCard(
        CreditCard(
          id: existing?.id ?? const Uuid().v4(),
          bank: txn.bank,
          last4: txn.cardLast4!,
          availableLimit: txn.availableLimit ?? existing?.availableLimit,
          totalLimit: existing?.totalLimit,
          outstanding: txn.outstanding ?? existing?.outstanding,
          currency: txn.currency,
          lastUpdated: txn.transactionDate,
        ),
      );
    }

    // 3. Update Bill if applicable
    if (txn.type == TransactionType.bill &&
        txn.cardLast4 != null &&
        txn.billDueDate != null) {
      final bill = Bill(
        id: const Uuid().v4(),
        bank: txn.bank,
        cardLast4: txn.cardLast4!,
        totalAmount: txn.billTotal ?? txn.amount,
        minimumAmount: txn.billMinimum ?? 0.0,
        dueDate: txn.billDueDate!,
        currency: txn.currency,
        createdAt: DateTime.now(),
      );
      await _billRepo.upsertBill(Reconciler.reconcileBill(bill));
    }

    // 4. Update FASTag if applicable
    if (txn.type == TransactionType.fastag) {
      final existing =
          await _fastagRepo.getFastagByVehicleOrId(txn.vehicle, txn.fastagId);
      await _fastagRepo.upsertFastag(
        FastagRecord(
          id: existing?.id ?? const Uuid().v4(),
          fastagId: txn.fastagId ?? existing?.fastagId,
          vehicle: txn.vehicle ?? existing?.vehicle,
          bank: txn.bank != Bank.unknown ? txn.bank : existing?.bank,
          latestWalletBalance:
              txn.walletBalance ?? existing?.latestWalletBalance,
          currency: txn.currency,
          lastUpdated: txn.transactionDate,
        ),
      );
    }
  }
}
