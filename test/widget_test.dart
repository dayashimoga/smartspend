import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/app.dart';
import 'package:smartspend/presentation/screens/accounts/accounts_screen.dart';
import 'package:smartspend/presentation/screens/bills/bills_screen.dart';
import 'package:smartspend/presentation/screens/fastag/fastag_screen.dart';
import 'package:smartspend/presentation/screens/insights/insights_screen.dart';
import 'package:smartspend/presentation/screens/review/review_screen.dart';
import 'package:smartspend/presentation/screens/settings/settings_screen.dart';
import 'package:smartspend/presentation/screens/transactions/transactions_screen.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/domain/entities/account.dart';
import 'package:smartspend/domain/entities/bill.dart';
import 'package:smartspend/domain/entities/credit_card.dart';
import 'package:smartspend/domain/entities/fastag_record.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_ui_1',
        sender: 'HDFCBK',
        body: 'Sample UI testing SMS',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_ui_1',
        ingestedAt: DateTime.now(),
      ),
    );

    final txnRepo = TransactionRepository(dbHelper: dbHelper);
    await txnRepo.saveTransaction(
      ParsedTransaction(
        id: 'txn_ui_1',
        rawSmsId: 'sms_ui_1',
        type: TransactionType.purchase,
        bank: Bank.hdfc,
        cardLast4: '4000',
        amount: 350.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 15),
        merchant: 'Cafe Coffee Day',
        category: 'Dining',
        confidence: Confidence.high,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await txnRepo.saveTransaction(
      ParsedTransaction(
        id: 'txn_ui_review',
        rawSmsId: 'sms_ui_1',
        type: TransactionType.unknown,
        bank: Bank.icici,
        amount: 1200.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 16),
        confidence: Confidence.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final acctRepo = AccountRepository(dbHelper: dbHelper);
    await acctRepo.upsertAccount(
      Account(
        id: 'acct_ui_1',
        bank: Bank.hdfc,
        last4: '0564',
        accountType: 'Savings',
        currentBalance: 50000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      ),
    );

    final cardRepo = CardRepository(dbHelper: dbHelper);
    await cardRepo.upsertCard(
      CreditCard(
        id: 'card_ui_1',
        bank: Bank.hdfc,
        last4: '4000',
        availableLimit: 150000.0,
        totalLimit: 200000.0,
        outstanding: 50000.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      ),
    );

    final billRepo = BillRepository(dbHelper: dbHelper);
    await billRepo.upsertBill(
      Bill(
        id: 'bill_ui_1',
        bank: Bank.hdfc,
        cardLast4: '4000',
        totalAmount: 15000.0,
        minimumAmount: 1500.0,
        dueDate: DateTime(2026, 3, 10),
        currency: 'INR',
        createdAt: DateTime.now(),
      ),
    );

    final fastagRepo = FastagRepository(dbHelper: dbHelper);
    await fastagRepo.upsertFastag(
      FastagRecord(
        id: 'fastag_ui_1',
        vehicle: 'KA01AB1234',
        bank: Bank.hdfc,
        latestWalletBalance: 450.0,
        currency: 'INR',
        lastUpdated: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  testWidgets(
      'SmartSpendApp comprehensive UI navigation and screen interaction test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbHelperProvider.overrideWithValue(dbHelper),
        ],
        child: const SmartSpendApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify Root App mounts
    expect(find.text('SmartSpend'), findsOneWidget);

    // 2. Test TransactionsScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: TransactionsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Cafe');
    await tester.pump(const Duration(milliseconds: 300));

    // 3. Test AccountsScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: AccountsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bank Accounts'), findsOneWidget);
    expect(find.text('Credit Cards'), findsOneWidget);
    await tester.tap(find.text('Credit Cards'));
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Test InsightsScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: InsightsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Financial Insights'), findsOneWidget);

    // 5. Test ReviewScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: ReviewScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Review Queue'), findsOneWidget);

    // 6. Test BillsScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: BillsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bills & Statements'), findsOneWidget);

    // 7. Test FastagScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: FastagScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FASTag & Tolls'), findsOneWidget);

    // 8. Test SettingsScreen directly
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbHelperProvider.overrideWithValue(dbHelper)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings & Privacy'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Data & Tools'), findsOneWidget);

    // Drain sqflite internal lock timer
    await tester.pump(const Duration(seconds: 11));
  });
}
