import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/export/export_backup_usecase.dart';
import '../../application/review/correction_usecase.dart';
import '../../application/sms/ingest_sms_usecase.dart';
import '../../core/database/database_helper.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/bill_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/correction_repository.dart';
import '../../data/repositories/fastag_repository.dart';
import '../../data/repositories/sms_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/parsers/reconciler.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/fastag_record.dart';
import '../../domain/entities/financial_summary.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/models/time_period.dart';
import '../../domain/repositories/interfaces.dart';

// Database & Core
final dbHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());

// Repositories
final smsRepoProvider = Provider<ISmsRepository>(
    (ref) => SmsRepository(dbHelper: ref.watch(dbHelperProvider)));
final txnRepoProvider = Provider<ITransactionRepository>(
    (ref) => TransactionRepository(dbHelper: ref.watch(dbHelperProvider)));
final acctRepoProvider = Provider<IAccountRepository>(
    (ref) => AccountRepository(dbHelper: ref.watch(dbHelperProvider)));
final cardRepoProvider = Provider<ICardRepository>(
    (ref) => CardRepository(dbHelper: ref.watch(dbHelperProvider)));
final billRepoProvider = Provider<IBillRepository>(
    (ref) => BillRepository(dbHelper: ref.watch(dbHelperProvider)));
final fastagRepoProvider = Provider<IFastagRepository>(
    (ref) => FastagRepository(dbHelper: ref.watch(dbHelperProvider)));
final correctionRepoProvider = Provider<ICorrectionRepository>(
    (ref) => CorrectionRepository(dbHelper: ref.watch(dbHelperProvider)));
final budgetRepoProvider = Provider<IBudgetRepository>(
    (ref) => BudgetRepository(dbHelper: ref.watch(dbHelperProvider)));

// Use Cases
final ingestSmsUseCaseProvider = Provider<IngestSmsUseCase>((ref) {
  return IngestSmsUseCase(
    smsRepo: ref.watch(smsRepoProvider),
    txnRepo: ref.watch(txnRepoProvider),
    acctRepo: ref.watch(acctRepoProvider),
    cardRepo: ref.watch(cardRepoProvider),
    billRepo: ref.watch(billRepoProvider),
    fastagRepo: ref.watch(fastagRepoProvider),
  );
});

final correctionUseCaseProvider = Provider<CorrectionUseCase>((ref) {
  return CorrectionUseCase(
    txnRepo: ref.watch(txnRepoProvider),
    correctionRepo: ref.watch(correctionRepoProvider),
  );
});

final exportBackupUseCaseProvider = Provider<ExportBackupUseCase>((ref) {
  return ExportBackupUseCase(
    txnRepo: ref.watch(txnRepoProvider),
    acctRepo: ref.watch(acctRepoProvider),
    cardRepo: ref.watch(cardRepoProvider),
    billRepo: ref.watch(billRepoProvider),
    fastagRepo: ref.watch(fastagRepoProvider),
  );
});

// App State
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final defaultCurrencyProvider = StateProvider<String>((ref) => 'INR');
final isSyncingProvider = StateProvider<bool>((ref) => false);
final biometricAuthenticatedProvider = StateProvider<bool>((ref) => false);

// Data Query Providers
final financialSummaryProvider = FutureProvider<FinancialSummary>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  return repo.getFinancialSummary();
});

final recentTransactionsProvider =
    FutureProvider<List<ParsedTransaction>>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  return repo.getRecentTransactions(limit: 10);
});

final allTransactionsProvider =
    FutureProvider.autoDispose<List<ParsedTransaction>>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  return repo.getAllTransactions(limit: 200);
});

final needsReviewTransactionsProvider =
    FutureProvider<List<ParsedTransaction>>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  return repo.getNeedsReviewTransactions();
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(acctRepoProvider);
  return repo.getAllAccounts();
});

final cardsProvider = FutureProvider<List<CreditCard>>((ref) async {
  final repo = ref.watch(cardRepoProvider);
  return repo.getAllCards();
});

final billsProvider = FutureProvider<List<Bill>>((ref) async {
  final repo = ref.watch(billRepoProvider);
  return repo.getAllBills();
});

final fastagsProvider = FutureProvider<List<FastagRecord>>((ref) async {
  final repo = ref.watch(fastagRepoProvider);
  return repo.getAllFastag();
});

// Time Period Provider (Dashboard & Insights default to current month)
final selectedTimePeriodProvider =
    StateProvider<TimePeriod>((ref) => TimePeriod.thisMonth());

// Filtered Financial Summary respecting selected time period
final filteredFinancialSummaryProvider =
    FutureProvider<FinancialSummary>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  final period = ref.watch(selectedTimePeriodProvider);
  return repo.getFinancialSummary(
    startDate: period.startDate,
    endDate: period.endDate,
  );
});

// Filtered Transactions respecting selected time period
final filteredTransactionsProvider =
    FutureProvider<List<ParsedTransaction>>((ref) async {
  final repo = ref.watch(txnRepoProvider);
  final period = ref.watch(selectedTimePeriodProvider);
  return repo.getAllTransactions(
    limit: 500,
    startDate: period.startDate,
    endDate: period.endDate,
  );
});

// Reconciled and Filtered Bills Provider
final filteredBillsProvider = FutureProvider<List<Bill>>((ref) async {
  final billRepo = ref.watch(billRepoProvider);
  final txnRepo = ref.watch(txnRepoProvider);
  final period = ref.watch(selectedTimePeriodProvider);

  final rawBills = await billRepo.getBillsByDateRange(
    period.startDate.subtract(const Duration(days: 30)),
    period.endDate.add(const Duration(days: 60)),
  );
  final allTxns = await txnRepo.getAllTransactions(limit: 500);

  final reconciled = Reconciler.reconcileBillsWithPayments(rawBills, allTxns);
  return reconciled;
});

// Filtered Accounts and Cards respecting selected time period's end date
final filteredAccountsProvider = FutureProvider<List<Account>>((ref) async {
  final repo = ref.watch(acctRepoProvider);
  final period = ref.watch(selectedTimePeriodProvider);
  return repo.getAccountsAsOf(period.endDate);
});

final filteredCardsProvider = FutureProvider<List<CreditCard>>((ref) async {
  final repo = ref.watch(cardRepoProvider);
  final period = ref.watch(selectedTimePeriodProvider);
  return repo.getCardsAsOf(period.endDate);
});
