import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/financial_summary.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/widgets/summary_cards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;
  late AccountRepository acctRepo;
  late SmsRepository smsRepo;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    acctRepo = AccountRepository(dbHelper: dbHelper);
    smsRepo = SmsRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Incomplete vs Zero Financial Semantics Forensic Suite', () {
    test(
        'Empty vault returns null balance and isBalanceReliable = false (never ₹0)',
        () async {
      final summary = await txnRepo.getFinancialSummary();

      expect(summary.totalAccountBalance, isNull,
          reason:
              'When zero accounts or balances exist, totalAccountBalance must be null');
      expect(summary.isBalanceReliable, isFalse);
    });

    test(
        'Historical balance queries use latest known balance <= selected period end',
        () async {
      // 1. Setup account
      await acctRepo.upsertAccount(
        Account(
          id: 'acct_hdfc_1',
          bank: Bank.hdfc,
          last4: '1234',
          currentBalance: 50000.0,
          currency: 'INR',
          lastUpdated: DateTime(2026, 3, 1),
        ),
      );

      // Save prerequisite raw SMS records for foreign key constraints
      await smsRepo.saveSms(
        SmsRecord(
          id: 'sms_1',
          sender: 'HDFCBK',
          body: 'Test SMS 1',
          timestamp: DateTime(2026, 1, 15),
          fingerprint: 'fp_1',
          ingestedAt: DateTime.now(),
        ),
      );
      await smsRepo.saveSms(
        SmsRecord(
          id: 'sms_2',
          sender: 'HDFCBK',
          body: 'Test SMS 2',
          timestamp: DateTime(2026, 2, 20),
          fingerprint: 'fp_2',
          ingestedAt: DateTime.now(),
        ),
      );

      // 2. Add historical transaction with balance in January 2026
      await txnRepo.saveTransaction(
        ParsedTransaction(
          id: 'txn_jan',
          rawSmsId: 'sms_1',
          type: TransactionType.debit,
          bank: Bank.hdfc,
          accountLast4: '1234',
          amount: 2000.0,
          balance: 35000.0,
          currency: 'INR',
          transactionDate: DateTime(2026, 1, 15),
          confidence: Confidence.high,
          createdAt: DateTime(2026, 1, 15),
          updatedAt: DateTime(2026, 1, 15),
        ),
      );

      // 3. Add later transaction with balance in February 2026
      await txnRepo.saveTransaction(
        ParsedTransaction(
          id: 'txn_feb',
          rawSmsId: 'sms_2',
          type: TransactionType.credit,
          bank: Bank.hdfc,
          accountLast4: '1234',
          amount: 15000.0,
          balance: 50000.0,
          currency: 'INR',
          transactionDate: DateTime(2026, 2, 20),
          confidence: Confidence.high,
          createdAt: DateTime(2026, 2, 20),
          updatedAt: DateTime(2026, 2, 20),
        ),
      );

      // Query as of end of January 2026
      final janEnd = DateTime(2026, 1, 31, 23, 59, 59);
      final janSummary = await txnRepo.getFinancialSummary(
        startDate: DateTime(2026, 1, 1),
        endDate: janEnd,
      );

      expect(janSummary.totalAccountBalance, equals(35000.0),
          reason: 'Must pick the latest reliable balance <= January 31, 2026');

      // Query for an earlier period (e.g. December 2025) where NO balance existed
      final decSummary = await txnRepo.getFinancialSummary(
        startDate: DateTime(2025, 12, 1),
        endDate: DateTime(2025, 12, 31),
      );

      expect(decSummary.totalAccountBalance, isNull,
          reason:
              'No balance existed <= Dec 2025, must return null (Unavailable), NOT ₹0');
      expect(decSummary.isBalanceReliable, isFalse);
    });

    testWidgets(
        'SummaryCards renders Unavailable when totalAccountBalance is null',
        (tester) async {
      const summary = FinancialSummary(
        totalIncome: 10000.0,
        totalExpense: 2000.0,
        netCashFlow: 8000.0,
        totalAccountBalance: null, // Unavailable
        totalCardOutstanding: 5000.0,
        totalAvailableCredit: 50000.0,
        upcomingBillsCount: 0,
        upcomingBillsTotal: 0.0,
        needsReviewCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCards(summary: summary),
          ),
        ),
      );

      expect(find.text('Unavailable'), findsOneWidget,
          reason:
              'Must render Unavailable text instead of ₹0 when balance is null');
      expect(find.text('₹ 0.00'), findsNothing);
    });

    testWidgets('SummaryCards renders Updating badge when isUpdating is true',
        (tester) async {
      const summary = FinancialSummary(
        totalIncome: 10000.0,
        totalExpense: 2000.0,
        netCashFlow: 8000.0,
        totalAccountBalance: 45000.0,
        totalCardOutstanding: 5000.0,
        totalAvailableCredit: 50000.0,
        upcomingBillsCount: 0,
        upcomingBillsTotal: 0.0,
        needsReviewCount: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SummaryCards(
              summary: summary,
              isUpdating: true,
            ),
          ),
        ),
      );

      expect(find.text('Updating...'), findsOneWidget);
    });
  });
}
