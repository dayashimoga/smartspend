import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/database/database_helper.dart';
import 'package:smartspend/presentation/providers/app_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper dbHelper;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('AppProviders Forensic Suite', () {
    test('Resolves all default repository and usecase providers cleanly',
        () async {
      final container = ProviderContainer(
        overrides: [
          dbHelperProvider.overrideWithValue(dbHelper),
        ],
      );

      // Verify core providers
      expect(container.read(dbHelperProvider), isNotNull);
      expect(container.read(smsRepoProvider), isNotNull);
      expect(container.read(txnRepoProvider), isNotNull);
      expect(container.read(acctRepoProvider), isNotNull);
      expect(container.read(cardRepoProvider), isNotNull);
      expect(container.read(billRepoProvider), isNotNull);
      expect(container.read(fastagRepoProvider), isNotNull);
      expect(container.read(correctionRepoProvider), isNotNull);
      expect(container.read(budgetRepoProvider), isNotNull);

      // Verify use cases
      expect(container.read(ingestSmsUseCaseProvider), isNotNull);
      expect(container.read(correctionUseCaseProvider), isNotNull);
      expect(container.read(exportBackupUseCaseProvider), isNotNull);

      // Verify app state
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
      expect(container.read(defaultCurrencyProvider), equals('INR'));
      expect(container.read(isSyncingProvider), isFalse);
      expect(container.read(biometricAuthenticatedProvider), isFalse);

      // Verify query providers
      final summary = await container.read(financialSummaryProvider.future);
      expect(summary.currency, equals('INR'));

      final recent = await container.read(recentTransactionsProvider.future);
      expect(recent.isEmpty, isTrue);

      final allTxns = await container.read(allTransactionsProvider.future);
      expect(allTxns.isEmpty, isTrue);

      final needsReview =
          await container.read(needsReviewTransactionsProvider.future);
      expect(needsReview.isEmpty, isTrue);

      final accounts = await container.read(accountsProvider.future);
      expect(accounts.isEmpty, isTrue);

      final cards = await container.read(cardsProvider.future);
      expect(cards.isEmpty, isTrue);

      final bills = await container.read(billsProvider.future);
      expect(bills.isEmpty, isTrue);

      final fastags = await container.read(fastagsProvider.future);
      expect(fastags.isEmpty, isTrue);

      container.dispose();
    });
  });
}
