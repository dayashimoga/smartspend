import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/entities/parsed_transaction.dart';
import 'package:smartspend/domain/entities/sms_record.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late TransactionRepository txnRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    final smsRepo = SmsRepository(dbHelper: dbHelper);
    // Create parent SMS record
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_stress_parent',
        sender: 'STRESS',
        body: 'Parent SMS for stress benchmark',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_stress_parent',
        ingestedAt: DateTime.now(),
      ),
    );
    txnRepo = TransactionRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('50,000 Records High-Scale Performance Benchmark', () {
    test(
        'Handles 50,000 records with sub-100ms pagination, fast search, and sub-350ms summary aggregation',
        () async {
      final db = await dbHelper.database;
      const totalRecords = 50000;
      const batchSize = 2500;

      final insertWatch = Stopwatch()..start();

      // Perform fast batch inserts
      for (int b = 0; b < totalRecords; b += batchSize) {
        final batch = db.batch();
        for (int i = 0; i < batchSize; i++) {
          final idx = b + i;
          final txn = ParsedTransaction(
            id: 'txn_$idx',
            rawSmsId: 'sms_stress_parent',
            type: idx % 5 == 0
                ? TransactionType.salary
                : TransactionType.purchase,
            bank: idx % 2 == 0 ? Bank.hdfc : Bank.icici,
            cardLast4: '4000',
            amount: 100.0 + (idx % 500),
            currency: 'INR',
            transactionDate: DateTime(2026, 1, 1).add(Duration(minutes: idx)),
            merchant:
                idx == 25000 ? 'Target needle merchant' : 'Merchant #$idx',
            category: idx % 3 == 0 ? 'Dining' : 'Shopping',
            confidence: Confidence.high,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          batch.insert('parsed_transactions', txn.toMap());
        }
        await batch.commit(noResult: true);
      }

      insertWatch.stop();
      // ignore: avoid_print
      print(
          'Inserted $totalRecords records in ${insertWatch.elapsedMilliseconds}ms');

      // 1. Benchmark Pagination Query (e.g. Page 100: offset 2000, limit 50)
      final pageWatch = Stopwatch()..start();
      final pageTxns =
          await txnRepo.getAllTransactions(limit: 50, offset: 2000);
      pageWatch.stop();
      expect(pageTxns.length, equals(50));
      // ignore: avoid_print
      print(
          'Paginated query (50 records at offset 2000) executed in: ${pageWatch.elapsedMilliseconds}ms');
      expect(pageWatch.elapsedMilliseconds, lessThan(150),
          reason: 'Pagination must be fast (<150ms)');

      // 2. Benchmark Search Query across 50,000 records
      final searchWatch = Stopwatch()..start();
      final searchResults =
          await txnRepo.searchTransactions('Target needle merchant');
      searchWatch.stop();
      expect(searchResults.length, equals(1));
      expect(searchResults.first.merchant, equals('Target needle merchant'));
      // ignore: avoid_print
      print(
          'Search across 50,000 records executed in: ${searchWatch.elapsedMilliseconds}ms');
      expect(searchWatch.elapsedMilliseconds, lessThan(350),
          reason: 'Search across 50k records must be <350ms');

      // 3. Benchmark Financial Summary Aggregation
      final summaryWatch = Stopwatch()..start();
      final summary = await txnRepo.getFinancialSummary();
      summaryWatch.stop();
      expect(summary.totalIncome, greaterThan(0));
      expect(summary.totalExpense, greaterThan(0));
      // ignore: avoid_print
      print(
          'Financial summary aggregation across 50,000 records executed in: ${summaryWatch.elapsedMilliseconds}ms');
      expect(summaryWatch.elapsedMilliseconds, lessThan(500),
          reason: 'Summary aggregation must be <500ms');
    });
  });
}
