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
  });
}
