import '../entities/account.dart';
import '../entities/bill.dart';
import '../entities/budget.dart';
import '../entities/correction.dart';
import '../entities/credit_card.dart';
import '../entities/fastag_record.dart';
import '../entities/financial_summary.dart';
import '../entities/parsed_transaction.dart';
import '../entities/sms_record.dart';
import '../enums/bank.dart';
import '../enums/transaction_type.dart';

abstract class ISmsRepository {
  Future<void> saveSms(SmsRecord record);
  Future<void> saveBulkSms(List<SmsRecord> records);
  Future<SmsRecord?> getSmsByFingerprint(String fingerprint);
  Future<bool> existsByFingerprint(String fingerprint);
  Future<List<SmsRecord>> getAllSms({int limit = 100, int offset = 0});
  Future<SmsRecord?> getSmsById(String id);
  Future<int> getSmsCount();
}

abstract class ITransactionRepository {
  Future<void> saveTransaction(ParsedTransaction transaction);
  Future<void> saveBulkTransactions(List<ParsedTransaction> transactions);
  Future<void> updateTransaction(ParsedTransaction transaction);
  Future<void> deleteTransaction(String id);
  Future<ParsedTransaction?> getTransactionById(String id);
  Future<List<ParsedTransaction>> getAllTransactions({
    int limit = 100,
    int offset = 0,
    TransactionType? type,
    Bank? bank,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    bool includeExcluded = false,
  });
  Future<List<ParsedTransaction>> getNeedsReviewTransactions();
  Future<List<ParsedTransaction>> getRecentTransactions({int limit = 10});
  Future<List<ParsedTransaction>> searchTransactions(String query);
  Future<FinancialSummary> getFinancialSummary(
      {DateTime? startDate, DateTime? endDate});
}

abstract class IAccountRepository {
  Future<void> upsertAccount(Account account);
  Future<List<Account>> getAllAccounts();
  Future<Account?> getAccountByBankAndLast4(Bank bank, String last4);
}

abstract class ICardRepository {
  Future<void> upsertCard(CreditCard card);
  Future<List<CreditCard>> getAllCards();
  Future<CreditCard?> getCardByBankAndLast4(Bank bank, String last4);
  Future<List<CreditCard>> getCardsByBank(Bank bank);
}

abstract class IBillRepository {
  Future<void> upsertBill(Bill bill);
  Future<List<Bill>> getAllBills();
  Future<List<Bill>> getBillsByCard(Bank bank, String cardLast4);
  Future<List<Bill>> getUpcomingBills({int days = 30});
}

abstract class IFastagRepository {
  Future<void> upsertFastag(FastagRecord record);
  Future<List<FastagRecord>> getAllFastag();
  Future<FastagRecord?> getFastagByVehicleOrId(
      String? vehicle, String? fastagId);
}

abstract class ICorrectionRepository {
  Future<void> saveCorrection(Correction correction);
  Future<List<Correction>> getCorrectionsForTransaction(String transactionId);
  Future<void> deleteCorrection(String id);
}

abstract class IBudgetRepository {
  Future<void> upsertBudget(Budget budget);
  Future<List<Budget>> getBudgetsForMonth(int month, int year);
}
