import 'package:equatable/equatable.dart';
import 'ingestion_state.dart';

class IngestionCheckpoint extends Equatable {
  final String id;
  final String? lastSmsId;
  final int lastTimestamp;
  final String? lastFingerprint;
  final String parserVersion;
  final int batchOffset;
  final IngestionStage stage;
  final int? totalCount;
  final int scannedCount;
  final int transactionsCount;
  final int billsCount;
  final int accountsCount;
  final int balancesCount;
  final int financialCount;
  final int duplicatesCount;
  final int ignoredCount;
  final int reviewCount;
  final int failedCount;
  final DateTime lastUpdated;
  final bool isCompleted;

  const IngestionCheckpoint({
    this.id = 'primary',
    this.lastSmsId,
    this.lastTimestamp = 0,
    this.lastFingerprint,
    this.parserVersion = '1.0.0',
    this.batchOffset = 0,
    this.stage = IngestionStage.idle,
    this.totalCount,
    this.scannedCount = 0,
    this.transactionsCount = 0,
    this.billsCount = 0,
    this.accountsCount = 0,
    this.balancesCount = 0,
    this.financialCount = 0,
    this.duplicatesCount = 0,
    this.ignoredCount = 0,
    this.reviewCount = 0,
    this.failedCount = 0,
    required this.lastUpdated,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'last_sms_id': lastSmsId,
      'last_timestamp': lastTimestamp,
      'last_fingerprint': lastFingerprint,
      'parser_version': parserVersion,
      'batch_offset': batchOffset,
      'stage': stage.name,
      'total_count': totalCount,
      'scanned_count': scannedCount,
      'transactions_count': transactionsCount,
      'bills_count': billsCount,
      'accounts_count': accountsCount,
      'balances_count': balancesCount,
      'financial_count': financialCount,
      'duplicates_count': duplicatesCount,
      'ignored_count': ignoredCount,
      'review_count': reviewCount,
      'failed_count': failedCount,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory IngestionCheckpoint.fromMap(Map<String, dynamic> map) {
    return IngestionCheckpoint(
      id: (map['id'] as String?) ?? 'primary',
      lastSmsId: map['last_sms_id'] as String?,
      lastTimestamp: (map['last_timestamp'] as int?) ?? 0,
      lastFingerprint: map['last_fingerprint'] as String?,
      parserVersion: (map['parser_version'] as String?) ?? '1.0.0',
      batchOffset: (map['batch_offset'] as int?) ?? 0,
      stage: IngestionStage.values.firstWhere(
        (s) => s.name == map['stage'],
        orElse: () => IngestionStage.idle,
      ),
      totalCount: map['total_count'] as int?,
      scannedCount: (map['scanned_count'] as int?) ?? 0,
      transactionsCount: (map['transactions_count'] as int?) ?? 0,
      billsCount: (map['bills_count'] as int?) ?? 0,
      accountsCount: (map['accounts_count'] as int?) ?? 0,
      balancesCount: (map['balances_count'] as int?) ?? 0,
      financialCount: (map['financial_count'] as int?) ?? 0,
      duplicatesCount: (map['duplicates_count'] as int?) ?? 0,
      ignoredCount: (map['ignored_count'] as int?) ?? 0,
      reviewCount: (map['review_count'] as int?) ?? 0,
      failedCount: (map['failed_count'] as int?) ?? 0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(
          (map['last_updated'] as int?) ??
              DateTime.now().millisecondsSinceEpoch),
      isCompleted: (map['is_completed'] as int?) == 1,
    );
  }

  IngestionCheckpoint copyWith({
    String? id,
    String? lastSmsId,
    int? lastTimestamp,
    String? lastFingerprint,
    String? parserVersion,
    int? batchOffset,
    IngestionStage? stage,
    int? totalCount,
    int? scannedCount,
    int? transactionsCount,
    int? billsCount,
    int? accountsCount,
    int? balancesCount,
    int? financialCount,
    int? duplicatesCount,
    int? ignoredCount,
    int? reviewCount,
    int? failedCount,
    DateTime? lastUpdated,
    bool? isCompleted,
  }) {
    return IngestionCheckpoint(
      id: id ?? this.id,
      lastSmsId: lastSmsId ?? this.lastSmsId,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      lastFingerprint: lastFingerprint ?? this.lastFingerprint,
      parserVersion: parserVersion ?? this.parserVersion,
      batchOffset: batchOffset ?? this.batchOffset,
      stage: stage ?? this.stage,
      totalCount: totalCount ?? this.totalCount,
      scannedCount: scannedCount ?? this.scannedCount,
      transactionsCount: transactionsCount ?? this.transactionsCount,
      billsCount: billsCount ?? this.billsCount,
      accountsCount: accountsCount ?? this.accountsCount,
      balancesCount: balancesCount ?? this.balancesCount,
      financialCount: financialCount ?? this.financialCount,
      duplicatesCount: duplicatesCount ?? this.duplicatesCount,
      ignoredCount: ignoredCount ?? this.ignoredCount,
      reviewCount: reviewCount ?? this.reviewCount,
      failedCount: failedCount ?? this.failedCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        lastSmsId,
        lastTimestamp,
        lastFingerprint,
        parserVersion,
        batchOffset,
        stage,
        totalCount,
        scannedCount,
        transactionsCount,
        billsCount,
        accountsCount,
        balancesCount,
        financialCount,
        duplicatesCount,
        ignoredCount,
        reviewCount,
        failedCount,
        lastUpdated,
        isCompleted,
      ];
}

class IngestionHistoryRecord extends Equatable {
  final String id;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status;
  final int totalScanned;
  final int financialCount;
  final int transactionsCount;
  final int billsCount;
  final int balancesCount;
  final int duplicatesCount;
  final int ignoredCount;
  final int reviewCount;
  final int failedCount;
  final String parserVersion;
  final String? errorMessage;

  const IngestionHistoryRecord({
    required this.id,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.totalScanned,
    required this.financialCount,
    required this.transactionsCount,
    required this.billsCount,
    required this.balancesCount,
    required this.duplicatesCount,
    required this.ignoredCount,
    required this.reviewCount,
    required this.failedCount,
    required this.parserVersion,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at': startedAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'status': status,
      'total_scanned': totalScanned,
      'financial_count': financialCount,
      'transactions_count': transactionsCount,
      'bills_count': billsCount,
      'balances_count': balancesCount,
      'duplicates_count': duplicatesCount,
      'ignored_count': ignoredCount,
      'review_count': reviewCount,
      'failed_count': failedCount,
      'parser_version': parserVersion,
      'error_message': errorMessage,
    };
  }

  factory IngestionHistoryRecord.fromMap(Map<String, dynamic> map) {
    return IngestionHistoryRecord(
      id: map['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      status: map['status'] as String,
      totalScanned: (map['total_scanned'] as int?) ?? 0,
      financialCount: (map['financial_count'] as int?) ?? 0,
      transactionsCount: (map['transactions_count'] as int?) ?? 0,
      billsCount: (map['bills_count'] as int?) ?? 0,
      balancesCount: (map['balances_count'] as int?) ?? 0,
      duplicatesCount: (map['duplicates_count'] as int?) ?? 0,
      ignoredCount: (map['ignored_count'] as int?) ?? 0,
      reviewCount: (map['review_count'] as int?) ?? 0,
      failedCount: (map['failed_count'] as int?) ?? 0,
      parserVersion: (map['parser_version'] as String?) ?? '1.0.0',
      errorMessage: map['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        startedAt,
        completedAt,
        status,
        totalScanned,
        financialCount,
        transactionsCount,
        billsCount,
        balancesCount,
        duplicatesCount,
        ignoredCount,
        reviewCount,
        failedCount,
        parserVersion,
        errorMessage,
      ];
}
