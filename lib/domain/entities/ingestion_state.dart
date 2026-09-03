import 'package:equatable/equatable.dart';

enum IngestionStage {
  idle,
  discovering,
  reading,
  parsing,
  deduping,
  reconciling,
  updatingEntities,
  finalizing,
  completed,
  failed,
  paused,
  cancelled,
}

extension IngestionStageX on IngestionStage {
  String get displayName {
    switch (this) {
      case IngestionStage.idle:
        return 'Idle';
      case IngestionStage.discovering:
        return 'Discovering SMS';
      case IngestionStage.reading:
        return 'Reading SMS';
      case IngestionStage.parsing:
        return 'Parsing SMS';
      case IngestionStage.deduping:
        return 'Deduplicating';
      case IngestionStage.reconciling:
        return 'Reconciling';
      case IngestionStage.updatingEntities:
        return 'Updating Accounts & Cards';
      case IngestionStage.finalizing:
        return 'Finalizing';
      case IngestionStage.completed:
        return 'Completed';
      case IngestionStage.failed:
        return 'Failed';
      case IngestionStage.paused:
        return 'Paused';
      case IngestionStage.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == IngestionStage.completed ||
      this == IngestionStage.failed ||
      this == IngestionStage.cancelled;

  bool get isBusy =>
      this != IngestionStage.idle &&
      this != IngestionStage.completed &&
      this != IngestionStage.failed &&
      this != IngestionStage.paused &&
      this != IngestionStage.cancelled;
}

class IngestionProgress extends Equatable {
  final IngestionStage stage;
  final int scannedCount;
  final int? totalCount;
  final int currentBatch;
  final int? totalBatches;
  final int transactionsCount;
  final int billsCount;
  final int accountsCount;
  final int balancesCount;
  final int financialCount;
  final int duplicatesCount;
  final int ignoredCount;
  final int reviewCount;
  final int failedCount;
  final DateTime? lastUpdated;
  final String? errorMessage;

  const IngestionProgress({
    this.stage = IngestionStage.idle,
    this.scannedCount = 0,
    this.totalCount,
    this.currentBatch = 0,
    this.totalBatches,
    this.transactionsCount = 0,
    this.billsCount = 0,
    this.accountsCount = 0,
    this.balancesCount = 0,
    this.financialCount = 0,
    this.duplicatesCount = 0,
    this.ignoredCount = 0,
    this.reviewCount = 0,
    this.failedCount = 0,
    this.lastUpdated,
    this.errorMessage,
  });

  bool get isIndeterminate =>
      totalCount == null || stage == IngestionStage.discovering;

  double get progressPercentage {
    if (totalCount == null || totalCount! <= 0) {
      if (stage == IngestionStage.completed) return 100.0;
      return 0.0;
    }
    return ((scannedCount / totalCount!) * 100.0).clamp(0.0, 100.0);
  }

  bool get isBusy => stage.isBusy;
  bool get isCompleted => stage == IngestionStage.completed;
  bool get isFailed => stage == IngestionStage.failed;
  bool get isPaused => stage == IngestionStage.paused;
  bool get isCancelled => stage == IngestionStage.cancelled;
  bool get canPause => isBusy && stage != IngestionStage.discovering;
  bool get canResume => stage == IngestionStage.paused;
  bool get canCancel => isBusy || stage == IngestionStage.paused;
  bool get canRetry => stage == IngestionStage.failed;

  String get displayText {
    final countsSummary =
        '$transactionsCount txns, $billsCount bills, $accountsCount accounts, $reviewCount review';
    if (stage == IngestionStage.completed) {
      return 'Sync Complete • $scannedCount scanned • $countsSummary';
    }
    if (stage == IngestionStage.failed) {
      return 'Sync Failed • $scannedCount scanned • ${errorMessage ?? "Unknown error"}';
    }
    if (stage == IngestionStage.paused) {
      return 'Sync Paused • $scannedCount${totalCount != null ? "/$totalCount" : ""} • $countsSummary';
    }
    if (isIndeterminate) {
      return 'Analyzing SMS • $scannedCount scanned • $countsSummary';
    }
    final pct = progressPercentage.toStringAsFixed(0);
    return 'Analyzing SMS • $scannedCount/$totalCount • $pct% • $countsSummary';
  }

  String get summaryText =>
      'Scanned: $scannedCount • Financial: $financialCount • Txns: $transactionsCount • Bills: $billsCount • Accounts: $accountsCount • Review: $reviewCount • Skipped: $duplicatesCount';

  IngestionProgress copyWith({
    IngestionStage? stage,
    int? scannedCount,
    int? totalCount,
    int? currentBatch,
    int? totalBatches,
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
    String? errorMessage,
  }) {
    return IngestionProgress(
      stage: stage ?? this.stage,
      scannedCount: scannedCount ?? this.scannedCount,
      totalCount: totalCount ?? this.totalCount,
      currentBatch: currentBatch ?? this.currentBatch,
      totalBatches: totalBatches ?? this.totalBatches,
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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        stage,
        scannedCount,
        totalCount,
        currentBatch,
        totalBatches,
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
        errorMessage,
      ];
}
