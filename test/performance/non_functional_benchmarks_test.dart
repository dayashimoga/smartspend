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
  late SmsRepository smsRepo;
  late TransactionRepository txnRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    smsRepo = SmsRepository(dbHelper: dbHelper);
    txnRepo = TransactionRepository(dbHelper: dbHelper);

    // Insert root raw SMS
    await smsRepo.saveSms(
      SmsRecord(
        id: 'sms_perf_root',
        sender: 'HDFCBK',
        body: 'Perf seed root',
        timestamp: DateTime(2026, 1, 1),
        fingerprint: 'fp_perf_root',
        ingestedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Non-Functional Benchmarks & High-Load Forensic Suite', () {
    test(
        '5,000 bulk transactions insert and financial summary aggregation performance',
        () async {
      final transactions = List.generate(
        5000,
        (i) => ParsedTransaction(
          id: 'perf_txn_$i',
          rawSmsId: 'sms_perf_root',
          type: i % 5 == 0 ? TransactionType.salary : TransactionType.purchase,
          bank: Bank.hdfc,
          amount: (100 + (i % 500)).toDouble(),
          currency: 'INR',
          transactionDate: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          merchant: 'Merchant $i',
          category: i % 2 == 0 ? 'Groceries' : 'Utilities',
          confidence: Confidence.high,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final insertWatch = Stopwatch()..start();
      await txnRepo.saveBulkTransactions(transactions);
      insertWatch.stop();

      expect(insertWatch.elapsedMilliseconds, lessThan(4000),
          reason: 'Bulk insert of 5,000 transactions must complete in < 4s');

      final queryWatch = Stopwatch()..start();
      final summary = await txnRepo.getFinancialSummary();
      queryWatch.stop();

      expect(queryWatch.elapsedMilliseconds, lessThan(200),
          reason:
              'Aggregating financial summary across 5,000 transactions must complete in < 200ms');

      expect(summary.totalIncome, greaterThan(0));
      expect(summary.totalExpense, greaterThan(0));
    });

    test('Indexed query latency under indexed columns is < 50ms', () async {
      final queryWatch = Stopwatch()..start();
      final txns = await txnRepo.getAllTransactions(limit: 50);
      queryWatch.stop();

      expect(txns, isNotNull);
      expect(queryWatch.elapsedMilliseconds, lessThan(50),
          reason: 'Indexed transaction query must return in < 50ms');
    });
  });
}
