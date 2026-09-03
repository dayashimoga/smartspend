import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';
import 'package:smartspend/presentation/screens/review/review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_rev_1',
        sender: 'UNKNOWN',
        body: 'Generic spend 750 at XYZ Store',
        timestamp: DateTime(2026, 1, 10),
        fingerprint: 'fp_rev_1',
        ingestedAt: DateTime.now(),
      ),
    );

    final txnRepo = TransactionRepository(dbHelper: dbHelper);
    await txnRepo.saveTransaction(
      ParsedTransaction(
        id: 'txn_rev_1',
        rawSmsId: 'sms_rev_1',
        type: TransactionType.purchase,
        bank: Bank.unknown,
        amount: 750.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 10),
        merchant: 'XYZ Store',
        category: 'General',
        confidence: Confidence.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('ReviewScreen Comprehensive UI Test Suite', () {
    testWidgets(
        'Renders review queue, opens Edit dialog, and triggers Approve/Exclude',
        (tester) async {
      final sampleTxn = ParsedTransaction(
        id: 'txn_rev_1',
        rawSmsId: 'sms_rev_1',
        type: TransactionType.purchase,
        bank: Bank.unknown,
        amount: 750.0,
        currency: 'INR',
        transactionDate: DateTime(2026, 1, 10),
        merchant: 'XYZ Store',
        category: 'General',
        confidence: Confidence.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(dbHelper),
            needsReviewTransactionsProvider
                .overrideWith((ref) => Future.value([sampleTxn])),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Review Queue'), findsOneWidget);
      expect(find.text('XYZ Store'), findsOneWidget);
      expect(find.text('Edit Details'), findsOneWidget);
      expect(find.text('Non-Financial'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);

      // 1. Test Edit Dialog
      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsNothing);

      // 2. Test Edit Dialog with Save & Approve
      await tester.tap(find.text('Edit Details'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Corrected Store');
      await tester.tap(find.text('Save & Approve'));
      await tester.pumpAndSettle();

      // 3. Test Non-Financial button
      await tester.tap(find.text('Non-Financial'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Test Approve button
      await tester.tap(find.text('Approve'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Drain sqflite locks
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('Renders empty state when queue is all caught up',
        (tester) async {
      final emptyDb = DatabaseHelper.inMemory();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbHelperProvider.overrideWithValue(emptyDb),
            needsReviewTransactionsProvider
                .overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Review Queue'), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.text('No low-confidence or unparsed SMS in the queue'),
          findsOneWidget);

      await tester.pump(const Duration(seconds: 11));
      await emptyDb.close();
    });

    testWidgets('Renders error state gracefully', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            needsReviewTransactionsProvider
                .overrideWith((ref) => Future.error('DB_ERROR')),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Error: DB_ERROR'), findsOneWidget);
    });
  });
}
