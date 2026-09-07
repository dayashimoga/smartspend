import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/database_helper.dart';
import '../../data/datasources/sms_datasource.dart';
import '../../data/parsers/parser_pipeline.dart';
import '../../data/parsers/reconciler.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/fastag_record.dart';
import '../../domain/entities/ingestion_checkpoint.dart';
import '../../domain/entities/ingestion_state.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/entities/sms_record.dart';
import '../../domain/enums/bank.dart';
import '../../domain/enums/confidence.dart';
import '../../domain/enums/transaction_type.dart';
import '../../domain/repositories/interfaces.dart';

typedef BatchCommittedCallback = Future<void> Function();

class IncrementalIngestionService {
  static const String currentParserVersion = '1.0.0';
  static const int defaultBatchSize = 50;

  final ISmsRepository _smsRepo;
  final ITransactionRepository _txnRepo;
  final IAccountRepository? acctRepo;
  final ICardRepository? cardRepo;
  final IBillRepository? billRepo;
  final IFastagRepository? fastagRepo;
  final IIngestionRepository _ingestionRepo;
  final DatabaseHelper _dbHelper;
  final ParserPipeline _pipeline;

  final StreamController<IngestionProgress> _progressController =
      StreamController<IngestionProgress>.broadcast();

  IngestionProgress _currentProgress = const IngestionProgress();
  bool _isPaused = false;
  bool _isCancelled = false;
  bool _isRunning = false;
  List<Map<String, dynamic>>? _cachedMessages;

  BatchCommittedCallback? onBatchCommitted;

  IncrementalIngestionService({
    required ISmsRepository smsRepo,
    required ITransactionRepository txnRepo,
    this.acctRepo,
    this.cardRepo,
    this.billRepo,
    this.fastagRepo,
    required IIngestionRepository ingestionRepo,
    DatabaseHelper? dbHelper,
    ParserPipeline? pipeline,
  })  : _smsRepo = smsRepo,
        _txnRepo = txnRepo,
        _ingestionRepo = ingestionRepo,
        _dbHelper = dbHelper ?? DatabaseHelper(),
        _pipeline = pipeline ?? ParserPipeline();

  Stream<IngestionProgress> get progressStream => _progressController.stream;
  IngestionProgress get currentProgress => _currentProgress;
  bool get isRunning => _isRunning;

  void _emit(IngestionProgress progress) {
    _currentProgress = progress;
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Checks if historical SMS should be reanalyzed due to parser version upgrade.
  Future<bool> shouldReprocessHistorical() async {
    final cp = await _ingestionRepo.getCheckpoint();
    if (cp == null || !cp.isCompleted) return false;
    return cp.parserVersion != currentParserVersion;
  }

  /// Pauses active ingestion at current batch boundary.
  Future<void> pause() async {
    if (!_isRunning || _isPaused) return;
    _isPaused = true;
    _emit(_currentProgress.copyWith(stage: IngestionStage.paused));
    final cp = await _ingestionRepo.getCheckpoint();
    if (cp != null) {
      await _ingestionRepo.saveCheckpoint(cp.copyWith(
        stage: IngestionStage.paused,
        lastUpdated: DateTime.now(),
      ));
    }
  }

  /// Cancels active or paused ingestion.
  Future<void> cancel() async {
    _isCancelled = true;
    _isPaused = false;
    _isRunning = false;
    _emit(_currentProgress.copyWith(stage: IngestionStage.cancelled));
    final cp = await _ingestionRepo.getCheckpoint();
    if (cp != null) {
      await _ingestionRepo.saveCheckpoint(cp.copyWith(
        stage: IngestionStage.cancelled,
        lastUpdated: DateTime.now(),
      ));
    }
  }

  /// Resumes paused ingestion.
  Future<void> resume() async {
    if (!_isPaused && _currentProgress.stage != IngestionStage.paused) return;
    _isPaused = false;
    await startIngestion(overrideMessages: _cachedMessages);
  }

  /// Retries ingestion from last committed batch checkpoint after failure.
  Future<void> retry() async {
    if (_currentProgress.stage != IngestionStage.failed) return;
    await startIngestion();
  }

  /// Re-analyzes historical SMS records from database with current parser rules.
  Future<void> reanalyzeHistorical() async {
    await startIngestion(reanalyze: true);
  }

  /// Main entry point for incremental ingestion.
  /// [overrideMessages] can be supplied for testing or manual fixture injection.
  Future<IngestionProgress> startIngestion({
    List<Map<String, dynamic>>? overrideMessages,
    bool reanalyze = false,
    int batchSize = defaultBatchSize,
  }) async {
    if (_isRunning) {
      return _currentProgress;
    }

    _isRunning = true;
    _isPaused = false;
    _isCancelled = false;

    final runId = const Uuid().v4();
    final startedAt = DateTime.now();

    try {
      // Step 1: DISCOVERING
      _emit(_currentProgress.copyWith(
        stage: IngestionStage.discovering,
        lastUpdated: DateTime.now(),
      ));

      // Read or resume checkpoint
      var checkpoint = await _ingestionRepo.getCheckpoint();
      final bool hasPreviousCompletion =
          checkpoint != null && checkpoint.isCompleted;

      // Determine messages to process
      List<Map<String, dynamic>> rawMessages;

      if (overrideMessages != null) {
        _cachedMessages = List.of(overrideMessages);
        rawMessages = _cachedMessages!;
      } else if (_cachedMessages != null && !reanalyze) {
        rawMessages = _cachedMessages!;
      } else if (reanalyze) {
        // Read historical raw_sms from local vault
        final allStored = await _smsRepo.getAllSms(limit: 50000);
        rawMessages = allStored
            .map((s) => {
                  'id': s.id,
                  'sender': s.sender,
                  'body': s.body,
                  'timestamp': s.timestamp,
                })
            .toList();
      } else {
        // Incremental: query only messages newer than last checkpoint timestamp
        final int? sinceTimestamp = (hasPreviousCompletion &&
                checkpoint.lastTimestamp > 0 &&
                checkpoint.parserVersion == currentParserVersion)
            ? checkpoint.lastTimestamp
            : null;

        rawMessages = await SmsDatasource.readInboxSms(
          limit: 5000,
          sinceTimestamp: sinceTimestamp,
        );
      }

      // If reanalyze requested or version changed, reset batch offset
      if (reanalyze ||
          (checkpoint != null &&
              checkpoint.parserVersion != currentParserVersion)) {
        checkpoint = IngestionCheckpoint(
          lastUpdated: DateTime.now(),
          parserVersion: currentParserVersion,
          totalCount: rawMessages.length,
        );
        await _ingestionRepo.saveCheckpoint(checkpoint);
      }

      final int totalCount = rawMessages.length;
      int startIndex = 0;

      // Check if resuming from an incomplete run
      if (checkpoint != null &&
          !checkpoint.isCompleted &&
          checkpoint.batchOffset > 0 &&
          checkpoint.batchOffset < totalCount &&
          !reanalyze) {
        startIndex = checkpoint.batchOffset;
        _emit(_currentProgress.copyWith(
          scannedCount: checkpoint.scannedCount,
          totalCount: totalCount,
          transactionsCount: checkpoint.transactionsCount,
          billsCount: checkpoint.billsCount,
          accountsCount: checkpoint.accountsCount,
          balancesCount: checkpoint.balancesCount,
          financialCount: checkpoint.financialCount,
          duplicatesCount: checkpoint.duplicatesCount,
          ignoredCount: checkpoint.ignoredCount,
          reviewCount: checkpoint.reviewCount,
          failedCount: checkpoint.failedCount,
        ));
      } else {
        // Fresh run or completed previous run
        checkpoint = IngestionCheckpoint(
          id: 'primary',
          parserVersion: currentParserVersion,
          totalCount: totalCount,
          lastUpdated: DateTime.now(),
          lastTimestamp: checkpoint?.lastTimestamp ?? 0,
        );
        await _ingestionRepo.saveCheckpoint(checkpoint);
        _emit(_currentProgress.copyWith(
          scannedCount: 0,
          totalCount: totalCount,
          transactionsCount: 0,
          billsCount: 0,
          accountsCount: 0,
          balancesCount: 0,
          financialCount: 0,
          duplicatesCount: 0,
          ignoredCount: 0,
          reviewCount: 0,
          failedCount: 0,
        ));
      }

      final totalBatches = (totalCount / batchSize).ceil();
      int currentBatchIndex = (startIndex / batchSize).floor();

      // Accumulator counts from current state
      int scannedCount = _currentProgress.scannedCount;
      int transactionsCount = _currentProgress.transactionsCount;
      int billsCount = _currentProgress.billsCount;
      int accountsCount = _currentProgress.accountsCount;
      int balancesCount = _currentProgress.balancesCount;
      int financialCount = _currentProgress.financialCount;
      int duplicatesCount = _currentProgress.duplicatesCount;
      int ignoredCount = _currentProgress.ignoredCount;
      int reviewCount = _currentProgress.reviewCount;
      int failedCount = _currentProgress.failedCount;
      int latestTimestamp = checkpoint.lastTimestamp;
      String? latestSmsId = checkpoint.lastSmsId;
      String? latestFingerprint = checkpoint.lastFingerprint;

      // Process in transactional batches
      for (int i = startIndex; i < totalCount; i += batchSize) {
        if (_isPaused) {
          _emit(_currentProgress.copyWith(stage: IngestionStage.paused));
          _isRunning = false;
          return _currentProgress;
        }

        if (_isCancelled) {
          _emit(_currentProgress.copyWith(stage: IngestionStage.cancelled));
          _isRunning = false;
          return _currentProgress;
        }

        currentBatchIndex++;
        final int end =
            (i + batchSize < totalCount) ? i + batchSize : totalCount;
        final batchSlice = rawMessages.sublist(i, end);

        // Step 2: READING
        _emit(_currentProgress.copyWith(
          stage: IngestionStage.reading,
          currentBatch: currentBatchIndex,
          totalBatches: totalBatches,
          lastUpdated: DateTime.now(),
        ));

        // Step 3: PARSING & DEDUPING
        _emit(_currentProgress.copyWith(stage: IngestionStage.parsing));

        final List<SmsRecord> batchRawSms = [];
        final List<ParsedTransaction> batchParsedTxns = [];
        final List<ParsedTransaction> nonDuplicateTxns = [];

        for (final msg in batchSlice) {
          scannedCount++;
          final sender = (msg['sender'] as String?)?.trim() ?? 'UNKNOWN';
          final body = (msg['body'] as String?)?.trim() ?? '';
          if (body.isEmpty) {
            ignoredCount++;
            continue;
          }

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

          if (timestamp.millisecondsSinceEpoch > latestTimestamp) {
            latestTimestamp = timestamp.millisecondsSinceEpoch;
          }

          final fingerprint =
              SmsRecord.generateFingerprint(sender, body, timestamp);
          final rawSmsId = (msg['id'] as String?) ?? const Uuid().v4();

          final smsRecord = SmsRecord(
            id: rawSmsId,
            sender: sender,
            body: body,
            timestamp: timestamp,
            fingerprint: fingerprint,
            ingestedAt: DateTime.now(),
          );
          batchRawSms.add(smsRecord);

          // Step 4: DEDUPING check
          _emit(_currentProgress.copyWith(stage: IngestionStage.deduping));
          final exists = await _smsRepo.existsByFingerprint(fingerprint);
          if (exists && !reanalyze) {
            duplicatesCount++;
            continue;
          }

          // Parse SMS through pipeline
          final parsed = _pipeline.parseSms(
            rawSmsId: rawSmsId,
            sender: sender,
            rawBody: body,
            timestamp: timestamp,
          );

          if (parsed.confidence == Confidence.unparsed &&
              (parsed.category == 'OTP' || parsed.category == 'Promotional')) {
            ignoredCount++;
          } else {
            financialCount++;
          }

          batchParsedTxns.add(parsed);
          nonDuplicateTxns.add(parsed);

          latestSmsId = rawSmsId;
          latestFingerprint = fingerprint;
        }

        // Step 5: RECONCILING
        _emit(_currentProgress.copyWith(stage: IngestionStage.reconciling));

        final List<ParsedTransaction> finalTxnsToCommit = [];
        final List<ParsedTransaction> txnsToUpdate = [];

        for (var parsed in nonDuplicateTxns) {
          final historical = await _txnRepo.getAllTransactions(
            limit: 100,
            bank: parsed.bank != Bank.unknown ? parsed.bank : null,
          );
          final match = Reconciler.reconcileSingle(parsed, historical);
          parsed = match.updatedCurrent;

          if (match.matchedOther != null) {
            txnsToUpdate.add(match.matchedOther!);
          }

          finalTxnsToCommit.add(parsed);

          if (parsed.confidence.needsReview) {
            reviewCount++;
          }
          if (parsed.confidence == Confidence.unparsed &&
              parsed.category != 'OTP' &&
              parsed.category != 'Promotional') {
            failedCount++;
          }
          transactionsCount++;
        }

        // Step 6: UPDATING_ENTITIES in atomic transactional batch
        _emit(
            _currentProgress.copyWith(stage: IngestionStage.updatingEntities));

        final db = await _dbHelper.database;
        await db.transaction((txn) async {
          // 1. Insert raw_sms records
          for (final r in batchRawSms) {
            await txn.insert(
              'raw_sms',
              r.toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }

          // 2. Insert or update parsed transactions
          for (final t in finalTxnsToCommit) {
            await txn.insert(
              'parsed_transactions',
              t.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (final t in txnsToUpdate) {
            await txn.update(
              'parsed_transactions',
              t.toMap(),
              where: 'id = ?',
              whereArgs: [t.id],
            );
          }

          // 3. Update associated entities (accounts, cards, bills, fastag)
          for (final t in finalTxnsToCommit) {
            final entitiesUpdated = await _updateEntitiesInTxn(txn, t);
            if (entitiesUpdated.accountUpdated) accountsCount++;
            if (entitiesUpdated.balanceExtracted) balancesCount++;
            if (entitiesUpdated.billCreated) billsCount++;
          }

          // 4. Update checkpoint in same transaction
          final updatedCp = IngestionCheckpoint(
            id: 'primary',
            lastSmsId: latestSmsId,
            lastTimestamp: latestTimestamp,
            lastFingerprint: latestFingerprint,
            parserVersion: currentParserVersion,
            batchOffset: end,
            stage: IngestionStage.updatingEntities,
            totalCount: totalCount,
            scannedCount: scannedCount,
            transactionsCount: transactionsCount,
            billsCount: billsCount,
            accountsCount: accountsCount,
            balancesCount: balancesCount,
            financialCount: financialCount,
            duplicatesCount: duplicatesCount,
            ignoredCount: ignoredCount,
            reviewCount: reviewCount,
            failedCount: failedCount,
            lastUpdated: DateTime.now(),
            isCompleted: end >= totalCount,
          );
          await txn.insert(
            'ingestion_checkpoint',
            updatedCp.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });

        // Update progress state after batch commit
        _emit(_currentProgress.copyWith(
          stage: IngestionStage.updatingEntities,
          scannedCount: scannedCount,
          totalCount: totalCount,
          currentBatch: currentBatchIndex,
          totalBatches: totalBatches,
          transactionsCount: transactionsCount,
          billsCount: billsCount,
          accountsCount: accountsCount,
          balancesCount: balancesCount,
          financialCount: financialCount,
          duplicatesCount: duplicatesCount,
          ignoredCount: ignoredCount,
          reviewCount: reviewCount,
          failedCount: failedCount,
          lastUpdated: DateTime.now(),
        ));

        // Notify incremental UI refresh hook
        if (onBatchCommitted != null) {
          try {
            await onBatchCommitted!();
          } catch (_) {}
        }

        // Micro-yield to keep UI 60fps and battery-friendly
        await Future.delayed(Duration.zero);
      }

      // Step 7: FINALIZING
      _emit(_currentProgress.copyWith(stage: IngestionStage.finalizing));

      final completedCp = IngestionCheckpoint(
        id: 'primary',
        lastSmsId: latestSmsId,
        lastTimestamp: latestTimestamp,
        lastFingerprint: latestFingerprint,
        parserVersion: currentParserVersion,
        batchOffset: totalCount,
        stage: IngestionStage.completed,
        totalCount: totalCount,
        scannedCount: scannedCount,
        transactionsCount: transactionsCount,
        billsCount: billsCount,
        accountsCount: accountsCount,
        balancesCount: balancesCount,
        financialCount: financialCount,
        duplicatesCount: duplicatesCount,
        ignoredCount: ignoredCount,
        reviewCount: reviewCount,
        failedCount: failedCount,
        lastUpdated: DateTime.now(),
        isCompleted: true,
      );
      await _ingestionRepo.saveCheckpoint(completedCp);

      // Record in ingestion history for Data Quality
      final historyRecord = IngestionHistoryRecord(
        id: runId,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        status: 'completed',
        totalScanned: scannedCount,
        financialCount: financialCount,
        transactionsCount: transactionsCount,
        billsCount: billsCount,
        balancesCount: balancesCount,
        duplicatesCount: duplicatesCount,
        ignoredCount: ignoredCount,
        reviewCount: reviewCount,
        failedCount: failedCount,
        parserVersion: currentParserVersion,
      );
      await _ingestionRepo.saveHistory(historyRecord);

      // Step 8: COMPLETED
      _emit(_currentProgress.copyWith(
        stage: IngestionStage.completed,
        scannedCount: scannedCount,
        totalCount: totalCount,
        transactionsCount: transactionsCount,
        billsCount: billsCount,
        accountsCount: accountsCount,
        balancesCount: balancesCount,
        financialCount: financialCount,
        duplicatesCount: duplicatesCount,
        ignoredCount: ignoredCount,
        reviewCount: reviewCount,
        failedCount: failedCount,
        lastUpdated: DateTime.now(),
      ));

      _isRunning = false;
      return _currentProgress;
    } catch (e, stack) {
      // Step 9: FAILED
      _isRunning = false;
      final errorMessage = e.toString();
      _emit(_currentProgress.copyWith(
        stage: IngestionStage.failed,
        errorMessage: errorMessage,
        lastUpdated: DateTime.now(),
      ));

      // Record failed run in history
      try {
        final failedRecord = IngestionHistoryRecord(
          id: runId,
          startedAt: startedAt,
          completedAt: DateTime.now(),
          status: 'failed',
          totalScanned: _currentProgress.scannedCount,
          financialCount: _currentProgress.financialCount,
          transactionsCount: _currentProgress.transactionsCount,
          billsCount: _currentProgress.billsCount,
          balancesCount: _currentProgress.balancesCount,
          duplicatesCount: _currentProgress.duplicatesCount,
          ignoredCount: _currentProgress.ignoredCount,
          reviewCount: _currentProgress.reviewCount,
          failedCount: _currentProgress.failedCount + 1,
          parserVersion: currentParserVersion,
          errorMessage: '$errorMessage\n$stack',
        );
        await _ingestionRepo.saveHistory(failedRecord);
      } catch (_) {}

      return _currentProgress;
    }
  }

  Future<_EntityUpdateResult> _updateEntitiesInTxn(
      dynamic txn, ParsedTransaction t) async {
    bool accountUpdated = false;
    bool balanceExtracted = false;
    bool billCreated = false;

    if (t.confidence == Confidence.unparsed || t.isExcluded) {
      return const _EntityUpdateResult();
    }

    // 1. Account & Balance
    if (t.accountLast4 != null && t.bank != Bank.unknown) {
      final existingRows = await txn.query(
        'accounts',
        where: 'bank = ? AND last4 = ?',
        whereArgs: [t.bank.name, t.accountLast4!],
        limit: 1,
      );

      final hasExisting = existingRows.isNotEmpty;
      final existing = hasExisting ? Account.fromMap(existingRows.first) : null;

      if (t.balance != null || existing != null) {
        final newBalance = t.balance ?? existing?.currentBalance ?? 0.0;
        final isReliable =
            t.balance != null || (existing?.isBalanceReliable ?? false);
        if (t.balance != null) balanceExtracted = true;

        final acct = Account(
          id: existing?.id ?? const Uuid().v4(),
          bank: t.bank,
          last4: t.accountLast4!,
          accountType: t.type == TransactionType.salary ? 'Salary' : 'Savings',
          currentBalance: newBalance,
          currency: t.currency,
          lastUpdated: t.transactionDate,
          isBalanceReliable: isReliable,
        );

        await txn.insert(
          'accounts',
          acct.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (!hasExisting) accountUpdated = true;
      }
    }

    // 2. Card
    String? resolvedCardLast4 = t.cardLast4;
    if (resolvedCardLast4 == null && t.bank != Bank.unknown) {
      final cardRows = await txn.query(
        'cards',
        where: 'bank = ?',
        whereArgs: [t.bank.name],
      );
      if (cardRows.isNotEmpty) {
        resolvedCardLast4 = cardRows.first['last4'] as String;
      }
    }

    if (resolvedCardLast4 != null && t.bank != Bank.unknown) {
      final existingRows = await txn.query(
        'cards',
        where: 'bank = ? AND last4 = ?',
        whereArgs: [t.bank.name, resolvedCardLast4],
        limit: 1,
      );
      final existing = existingRows.isNotEmpty
          ? CreditCard.fromMap(existingRows.first)
          : null;

      double? updatedOutstanding = t.outstanding ?? existing?.outstanding;
      double? updatedStatementDue = existing?.statementDue;
      double? updatedCurrentDue = existing?.currentDue;
      DateTime? updatedStatementDate = existing?.lastStatementDate;

      if (t.type == TransactionType.bill) {
        updatedStatementDue = t.billTotal ?? t.amount;
        updatedCurrentDue = t.billMinimum ?? 0.0;
        updatedStatementDate = t.statementDate ?? t.transactionDate;
        updatedOutstanding = updatedStatementDue;
      } else if (t.type == TransactionType.billPayment) {
        if (updatedStatementDue != null) {
          updatedStatementDue =
              (updatedStatementDue - t.amount).clamp(0.0, double.infinity);
        }
        if (updatedOutstanding != null) {
          updatedOutstanding =
              (updatedOutstanding - t.amount).clamp(0.0, double.infinity);
        }
        final cardBills = await txn.query(
          'bills',
          where: 'bank = ? AND card_last4 = ? AND status = ?',
          whereArgs: [t.bank.name, resolvedCardLast4, 'unpaid'],
        );
        for (final bMap in cardBills) {
          final b = Bill.fromMap(bMap);
          await txn.update(
            'bills',
            b
                .copyWith(
                  status: BillStatus.paid,
                  paymentTransactionId: t.id,
                )
                .toMap(),
            where: 'id = ?',
            whereArgs: [b.id],
          );
        }
      }

      final card = CreditCard(
        id: existing?.id ?? const Uuid().v4(),
        bank: t.bank,
        last4: resolvedCardLast4,
        availableLimit: t.availableLimit ?? existing?.availableLimit,
        totalLimit: existing?.totalLimit,
        outstanding: updatedOutstanding,
        statementDue: updatedStatementDue,
        currentDue: updatedCurrentDue,
        lastStatementDate: updatedStatementDate,
        currency: t.currency,
        lastUpdated: t.transactionDate,
      );

      await txn.insert(
        'cards',
        card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 3. Bill
    if (t.type == TransactionType.bill &&
        t.cardLast4 != null &&
        t.billDueDate != null) {
      final bill = Bill(
        id: const Uuid().v4(),
        bank: t.bank,
        cardLast4: t.cardLast4!,
        totalAmount: t.billTotal ?? t.amount,
        minimumAmount: t.billMinimum ?? 0.0,
        dueDate: t.billDueDate!,
        currency: t.currency,
        createdAt: DateTime.now(),
      );
      final reconciledBill = Reconciler.reconcileBill(bill);
      await txn.insert(
        'bills',
        reconciledBill.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      billCreated = true;
    }

    // 4. FASTag
    if (t.type == TransactionType.fastag) {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];
      if (t.vehicle != null && t.vehicle!.isNotEmpty) {
        whereClauses.add('vehicle = ?');
        whereArgs.add(t.vehicle);
      }
      if (t.fastagId != null && t.fastagId!.isNotEmpty) {
        whereClauses.add('fastag_id = ?');
        whereArgs.add(t.fastagId);
      }
      final existingRows = whereClauses.isNotEmpty
          ? await txn.query(
              'fastag',
              where: whereClauses.join(' OR '),
              whereArgs: whereArgs,
              limit: 1,
            )
          : <Map<String, dynamic>>[];
      final existing = existingRows.isNotEmpty
          ? FastagRecord.fromMap(existingRows.first)
          : null;

      final fastag = FastagRecord(
        id: existing?.id ?? const Uuid().v4(),
        fastagId: t.fastagId ?? existing?.fastagId,
        vehicle: t.vehicle ?? existing?.vehicle,
        bank: t.bank != Bank.unknown ? t.bank : existing?.bank,
        latestWalletBalance: t.walletBalance ?? existing?.latestWalletBalance,
        currency: t.currency,
        lastUpdated: t.transactionDate,
      );

      await txn.insert(
        'fastag',
        fastag.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return _EntityUpdateResult(
      accountUpdated: accountUpdated,
      balanceExtracted: balanceExtracted,
      billCreated: billCreated,
    );
  }

  void dispose() {
    _progressController.close();
  }
}

class _EntityUpdateResult {
  final bool accountUpdated;
  final bool balanceExtracted;
  final bool billCreated;

  const _EntityUpdateResult({
    this.accountUpdated = false,
    this.balanceExtracted = false,
    this.billCreated = false,
  });
}
