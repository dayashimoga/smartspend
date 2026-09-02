import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/parser_pipeline.dart';

void main() {
  group('Parser Fuzz & Property Tests', () {
    test(
        'Parser NEVER crashes or throws on 1000 randomized malformed SMS inputs',
        () {
      final pipeline = ParserPipeline();
      final random = Random(42); // Deterministic seed

      final bankKeywords = [
        'HDFC',
        'ICICI',
        'SBI',
        'Axis',
        'HSBC',
        'YES',
        'IDFC',
        'IndusInd',
        'OneCard',
        'Ujjivan',
        'UNKNOWN'
      ];
      final amounts = [
        '0',
        '10',
        '99.9',
        '1,250.00',
        '1,96,021.82',
        '-500',
        '0.000',
        '9999999999',
        'Rs.',
        'INR',
        '₹'
      ];
      final actions = [
        'debited',
        'credited',
        'spent',
        'deposited',
        'withdrawn',
        'toll paid',
        'due by',
        'salary',
        ''
      ];
      final symbols = [
        '@',
        '#',
        '\$',
        '%',
        '^',
        '&',
        '*',
        '(',
        ')',
        '_',
        '+',
        '=',
        '{',
        '}',
        '[',
        ']',
        ':',
        ';',
        '"',
        '\'',
        '<',
        '>',
        ',',
        '?',
        '/',
        '\\',
        '|',
        '~',
        '`',
        '\u0000',
        '\uFFFF',
        '🚨',
        '💰'
      ];

      for (int i = 0; i < 1000; i++) {
        // Construct fuzzed string
        final buffer = StringBuffer();
        final tokenCount = random.nextInt(15) + 1;
        for (int t = 0; t < tokenCount; t++) {
          final choice = random.nextInt(4);
          switch (choice) {
            case 0:
              buffer.write(
                  '${bankKeywords[random.nextInt(bankKeywords.length)]} ');
              break;
            case 1:
              buffer.write('${amounts[random.nextInt(amounts.length)]} ');
              break;
            case 2:
              buffer.write('${actions[random.nextInt(actions.length)]} ');
              break;
            case 3:
              buffer.write('${symbols[random.nextInt(symbols.length)]} ');
              break;
          }
        }

        final fuzzedBody = buffer.toString();
        final sender = bankKeywords[random.nextInt(bankKeywords.length)];

        // Execution must complete without throwing any uncaught exception
        final parsed = pipeline.parseSms(
          rawSmsId: 'fuzz_$i',
          sender: sender,
          rawBody: fuzzedBody,
          timestamp: DateTime.now(),
        );

        expect(parsed, isNotNull,
            reason: 'Parser returned null on fuzz iteration $i: "$fuzzedBody"');
        expect(parsed.rawSmsId, equals('fuzz_$i'));
      }
    });
  });
}
