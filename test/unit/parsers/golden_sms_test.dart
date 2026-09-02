import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/utils/date_parser.dart';
import 'package:smartspend/data/parsers/parser_pipeline.dart';
import 'package:smartspend/domain/enums/bank.dart';
import 'package:smartspend/domain/enums/confidence.dart';

void main() {
  late ParserPipeline pipeline;
  late List<dynamic> goldenFixtures;

  setUpAll(() {
    pipeline = ParserPipeline();
    final file = File('test/fixtures/golden_sms.json');
    final jsonString = file.readAsStringSync();
    goldenFixtures = jsonDecode(jsonString) as List<dynamic>;
  });

  group('Mandatory Golden SMS Regressions', () {
    test('100% Golden SMS Fixtures Parse Accurately', () {
      expect(goldenFixtures.isNotEmpty, isTrue);

      for (final fixture in goldenFixtures) {
        final id = fixture['id'] as String;
        final rawSms = fixture['raw_sms'] as String;
        final sender = fixture['sender'] as String;
        final timestamp = DateTime.parse(fixture['timestamp'] as String);
        final expected = fixture['expected'] as Map<String, dynamic>;

        final result = pipeline.parseSms(
          rawSmsId: id,
          sender: sender,
          rawBody: rawSms,
          timestamp: timestamp,
        );

        // 1. Validate Type
        if (expected.containsKey('type')) {
          final expTypeStr = expected['type'] as String;
          expect(
            result.type.name.toLowerCase(),
            equals(expTypeStr.toLowerCase()),
            reason: 'Fixture $id failed on type match for: "$rawSms"',
          );
        }

        // 2. Validate Bank
        if (expected.containsKey('bank')) {
          final expBankStr = expected['bank'] as String;
          final expBank = Bank.values.firstWhere(
            (b) =>
                b.name.toLowerCase() ==
                expBankStr.replaceAll('_', '').toLowerCase(),
            orElse: () => Bank.unknown,
          );
          expect(
            result.bank,
            equals(expBank),
            reason: 'Fixture $id failed on bank match for: "$rawSms"',
          );
        }

        // 3. Validate Card / Account Last 4
        if (expected.containsKey('card_last4')) {
          expect(result.cardLast4, equals(expected['card_last4']),
              reason: 'Fixture $id card_last4');
        }
        if (expected.containsKey('account_last4')) {
          expect(result.accountLast4, equals(expected['account_last4']),
              reason: 'Fixture $id account_last4');
        }

        // 4. Validate Amount
        if (expected.containsKey('amount')) {
          final expAmt = (expected['amount'] as num).toDouble();
          expect(result.amount, equals(expAmt), reason: 'Fixture $id amount');
        }

        // 5. Validate Currency
        if (expected.containsKey('currency')) {
          expect(result.currency, equals(expected['currency']),
              reason: 'Fixture $id currency');
        }

        // 6. Validate Date
        if (expected.containsKey('date')) {
          final expDateStr = expected['date'] as String;
          expect(
              DateParser.toIsoDate(result.transactionDate), equals(expDateStr),
              reason: 'Fixture $id date');
        }

        // 7. Validate Merchant / Payee
        if (expected.containsKey('merchant')) {
          expect(result.merchant, equals(expected['merchant']),
              reason: 'Fixture $id merchant');
        }
        if (expected.containsKey('payee')) {
          expect(result.payee, equals(expected['payee']),
              reason: 'Fixture $id payee');
        }

        // 8. Validate Balances / Limits
        if (expected.containsKey('balance')) {
          final expBal = (expected['balance'] as num).toDouble();
          expect(result.balance, equals(expBal), reason: 'Fixture $id balance');
        }
        if (expected.containsKey('available_limit')) {
          final expLimit = (expected['available_limit'] as num).toDouble();
          expect(result.availableLimit, equals(expLimit),
              reason: 'Fixture $id available_limit');
        }

        // 9. Validate Reference
        if (expected.containsKey('reference')) {
          expect(result.reference, equals(expected['reference']),
              reason: 'Fixture $id reference');
        }

        // 10. Validate Bill Fields
        if (expected.containsKey('bill_total')) {
          final expTotal = (expected['bill_total'] as num).toDouble();
          expect(result.billTotal, equals(expTotal),
              reason: 'Fixture $id bill_total');
        }
        if (expected.containsKey('bill_minimum')) {
          final expMin = (expected['bill_minimum'] as num).toDouble();
          expect(result.billMinimum, equals(expMin),
              reason: 'Fixture $id bill_minimum');
        }
        if (expected.containsKey('bill_due_date')) {
          final expDueDateStr = expected['bill_due_date'] as String;
          expect(
              DateParser.toIsoDate(result.billDueDate!), equals(expDueDateStr),
              reason: 'Fixture $id bill_due_date');
        }

        // 11. Validate FASTag Fields
        if (expected.containsKey('vehicle')) {
          expect(result.vehicle, equals(expected['vehicle']),
              reason: 'Fixture $id vehicle');
        }
        if (expected.containsKey('toll_plaza')) {
          expect(result.tollPlaza, equals(expected['toll_plaza']),
              reason: 'Fixture $id toll_plaza');
        }
        if (expected.containsKey('wallet_balance')) {
          final expWalletBal = (expected['wallet_balance'] as num).toDouble();
          expect(result.walletBalance, equals(expWalletBal),
              reason: 'Fixture $id wallet_balance');
        }
        if (expected.containsKey('fastag_id')) {
          expect(result.fastagId, equals(expected['fastag_id']),
              reason: 'Fixture $id fastag_id');
        }

        // 12. Validate Confidence
        if (expected.containsKey('confidence')) {
          expect(result.confidence, equals(Confidence.high),
              reason: 'Fixture $id confidence');
        }
      }
    });
  });
}
