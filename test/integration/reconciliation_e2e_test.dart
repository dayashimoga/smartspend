import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/application/sms/ingest_sms_usecase.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/data/repositories/account_repository.dart';
import 'package:smartspend/data/repositories/bill_repository.dart';
import 'package:smartspend/data/repositories/card_repository.dart';
import 'package:smartspend/data/repositories/fastag_repository.dart';
import 'package:smartspend/data/repositories/sms_repository.dart';
import 'package:smartspend/data/repositories/transaction_repository.dart';
import 'package:smartspend/domain/enums/transaction_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;
  late IngestSmsUseCase ingestUseCase;
  late TransactionRepository txnRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    txnRepo = TransactionRepository(dbHelper: dbHelper);
    ingestUseCase = IngestSmsUseCase(
      smsRepo: SmsRepository(dbHelper: dbHelper),
      txnRepo: txnRepo,
      acctRepo: AccountRepository(dbHelper: dbHelper),
      cardRepo: CardRepository(dbHelper: dbHelper),
      billRepo: BillRepository(dbHelper: dbHelper),
      fastagRepo: FastagRepository(dbHelper: dbHelper),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Reconciliation & Zero Double-Count E2E Suite', () {
    test(
        'Ingest card purchase + bank card-payment debit results in ZERO double-counted expenses',
        () async {
      // Message 1: ICICI Card spend of INR 483.40
      final sms1 = {
        'sender': 'ICICIB',
        'body':
            'INR 483.40 spent using ICICI Bank Card XX4000 on 18-Jan-26 on AMAZON PAY IN E. Avl Limit: INR 1,96,021.82.',
        'timestamp': DateTime(2026, 1, 18, 14, 30),
      };

      // Message 2: Bank debit paying the credit card bill (e.g. from HDFC account)
      final sms2 = {
        'sender': 'HDFCBK',
        'body':
            'Sent Rs.483.40 From HDFC Bank A/C *0564 To CRED Credit Card Payment On 20/01/26 Ref 638798306591',
        'timestamp': DateTime(2026, 1, 20, 10, 0),
      };

      final result = await ingestUseCase.execute([sms1, sms2]);
      expect(result.newlyIngested, equals(2));

      // Fetch all transactions
      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(2));

      // The second transaction should be automatically classified as billPayment
      final billPaymentTxn =
          allTxns.firstWhere((t) => t.type == TransactionType.billPayment);
      expect(billPaymentTxn.amount, equals(483.40));
      expect(billPaymentTxn.category, equals('Credit Card Payment'));

      // Calculate Financial Summary
      final summary = await txnRepo.getFinancialSummary();

      // Crucial Gate: Total expense must be 483.40, NOT 966.80!
      expect(
        summary.totalExpense,
        equals(483.40),
        reason:
            'Credit card payment debit must NOT be double-counted as expense alongside card purchase',
      );
    });

    test(
        'Ingest card purchase followed by refund reconciles and links both records',
        () async {
      // Message 1: Card purchase
      final smsPurchase = {
        'sender': 'ICICIB',
        'body':
            'INR 1000.00 spent using ICICI Bank Card XX4000 on 10-Jan-26 on Myntra. Avl Limit: INR 1,90,000.00.',
        'timestamp': DateTime(2026, 1, 10, 12, 0),
      };

      await ingestUseCase.execute([smsPurchase]);

      // Message 2: Refund for the exact same card & amount
      final smsRefund = {
        'sender': 'ICICIB',
        'body':
            'INR 1000.00 refunded to your ICICI Bank Card XX4000 on 12-Jan-26 from Myntra. Avl Limit: INR 1,91,000.00.',
        'timestamp': DateTime(2026, 1, 12, 16, 0),
      };

      await ingestUseCase.execute([smsRefund]);

      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(2));

      final purchase =
          allTxns.firstWhere((t) => t.type == TransactionType.purchase);
      final refund =
          allTxns.firstWhere((t) => t.type == TransactionType.refund);

      expect(purchase.isReconciled, isTrue);
      expect(purchase.reconciledWithId, equals(refund.id));

      expect(refund.isReconciled, isTrue);
      expect(refund.reconciledWithId, equals(purchase.id));
    });

    test(
        'Multiple partial payments of credit card bill do not double-count expense',
        () async {
      // Message 1: Card purchase Rs 5000
      final smsPurchase = {
        'sender': 'ICICIB',
        'body':
            'INR 5,000.00 spent using ICICI Bank Card XX4000 on 05-Jan-26 at Croma. Avl Limit: INR 1,50,000.00.',
        'timestamp': DateTime(2026, 1, 5, 11, 0),
      };

      // Message 2: Partial payment 1 of Rs 2000 from HDFC Bank
      final smsPayment1 = {
        'sender': 'HDFCBK',
        'body':
            'Sent Rs.2,000.00 From HDFC Bank A/C *0564 To CRED Credit Card Payment On 15/01/26 Ref 111111',
        'timestamp': DateTime(2026, 1, 15, 10, 0),
      };

      // Message 3: Partial payment 2 of Rs 3000 from Axis Bank
      final smsPayment2 = {
        'sender': 'AXISBK',
        'body':
            'Rs. 3,000.00 debited from Axis Bank A/c no. XX1234 on 16-01-26 for Card Payment Ref 222222.',
        'timestamp': DateTime(2026, 1, 16, 14, 0),
      };

      await ingestUseCase.execute([smsPurchase, smsPayment1, smsPayment2]);

      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(3));

      final billPayments =
          allTxns.where((t) => t.type == TransactionType.billPayment).toList();
      expect(billPayments.length, equals(2));

      final summary = await txnRepo.getFinancialSummary();
      expect(summary.totalExpense, equals(5000.0));
    });

    test(
        'Own-account transfer between user accounts nets to zero income and expense',
        () async {
      // Message 1: Debit from HDFC savings account
      final smsDebit = {
        'sender': 'HDFCBK',
        'body':
            'Rs 15000.00 debited from HDFC Bank A/C *1111 on 10-Jan-26 to A/C *2222 Ref 777888',
        'timestamp': DateTime(2026, 1, 10, 14, 0),
      };

      // Message 2: Credit to ICICI savings account within 30 minutes
      final smsCredit = {
        'sender': 'ICICIB',
        'body':
            'Rs 15,000.00 credited to ICICI Bank A/C XX2222 on 10-Jan-26 from A/C *1111. Total Bal: INR 45,000.00.',
        'timestamp': DateTime(2026, 1, 10, 14, 15),
      };

      await ingestUseCase.execute([smsDebit, smsCredit]);

      final allTxns = await txnRepo.getAllTransactions();
      expect(allTxns.length, equals(2));

      final transfers =
          allTxns.where((t) => t.type == TransactionType.transfer).toList();
      expect(transfers.length, equals(2));
      expect(transfers[0].isReconciled, isTrue);
      expect(transfers[1].isReconciled, isTrue);

      final summary = await txnRepo.getFinancialSummary();
      expect(summary.totalExpense, equals(0.0));
      expect(summary.totalIncome, equals(0.0));
    });

    test(
        'Ambiguous same-value transactions resolve to correct merchant and proximity',
        () async {
      // Message 1: Spend Rs 500 at Cafe Coffee Day on Jan 5
      final sms1 = {
        'sender': 'ICICIB',
        'body':
            'INR 500.00 spent using ICICI Bank Card XX4000 on 05-Jan-26 on Cafe Coffee Day. Avl Limit: INR 1,90,000.00.',
        'timestamp': DateTime(2026, 1, 5, 9, 0),
      };

      // Message 2: Spend Rs 500 at BookStore on Jan 10
      final sms2 = {
        'sender': 'ICICIB',
        'body':
            'INR 500.00 spent using ICICI Bank Card XX4000 on 10-Jan-26 on BookStore. Avl Limit: INR 1,89,500.00.',
        'timestamp': DateTime(2026, 1, 10, 15, 0),
      };

      // Message 3: Refund of Rs 500 from BookStore on Jan 11
      final smsRefund = {
        'sender': 'ICICIB',
        'body':
            'INR 500.00 refunded to your ICICI Bank Card XX4000 on 11-Jan-26 from BookStore. Avl Limit: INR 1,90,000.00.',
        'timestamp': DateTime(2026, 1, 11, 12, 0),
      };

      await ingestUseCase.execute([sms1, sms2, smsRefund]);

      final allTxns = await txnRepo.getAllTransactions();
      final cafe = allTxns.firstWhere((t) => t.merchant == 'Cafe Coffee Day');
      final bookstore = allTxns.firstWhere((t) => t.merchant == 'BookStore');
      final refund =
          allTxns.firstWhere((t) => t.type == TransactionType.refund);

      // Crucial Gate: BookStore must be reconciled with refund, Cafe Coffee Day must NOT be reconciled!
      expect(bookstore.isReconciled, isTrue);
      expect(bookstore.reconciledWithId, equals(refund.id));
      expect(cafe.isReconciled, isFalse);
    });
  });
}
