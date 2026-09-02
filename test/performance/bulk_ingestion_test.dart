import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/parsers/parser_pipeline.dart';

void main() {
  group('Bulk Performance Benchmark', () {
    test('Parses 5,000 SMS messages in under 5 seconds', () {
      final pipeline = ParserPipeline();

      final sampleTemplates = [
        'INR 483.40 spent using ICICI Bank Card XX4000 on 18-Jan-26 on AMAZON PAY IN E. Avl Limit: INR 1,96,021.82.',
        'Spent INR 560.2 Axis Bank Card no. XX0449 27-09-25 19:54:30 IST ZOMATO Avl Limit: INR 434142.32',
        'Update! INR 93,807.00 deposited in HDFC Bank A/c XX0564 on 27-JUN-25 ... Salary... Avl bal INR 1,76,306.56.',
        'Sent Rs.30000.00 From HDFC Bank A/C *0564 To MUTUAL FUNDS ICCL On 21/01/26 Ref 638798306591',
        'Withdrawn Rs.3000 From HDFC Bank Card x4617 At INDUSIND BANK LIMITED On 2026-01-04:22:44:25 Bal Rs.40643.25',
        'Toll Paid! Rs.65 for KA05MS4053 At Rajatadripura On 2025-07-22 21:01:40 Wallet Bal: Rs.275',
        'Rs. 1,250.00 debited from YES BANK A/c XX8812 on 14-FEB-26 via UPI: Swiggy. Avl Bal: Rs. 45,210.00. Ref 392019482910.',
      ];

      final stopwatch = Stopwatch()..start();
      const int targetCount = 5000;

      for (int i = 0; i < targetCount; i++) {
        final template = sampleTemplates[i % sampleTemplates.length];
        final parsed = pipeline.parseSms(
          rawSmsId: 'perf_$i',
          sender: 'BANK',
          rawBody: template,
          timestamp: DateTime.now(),
        );
        expect(parsed.amount, greaterThan(0));
      }

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final throughputPerSec = (targetCount / (elapsedMs / 1000.0)).round();

      // ignore: avoid_print
      print(
          'Parsed $targetCount messages in ${elapsedMs}ms ($throughputPerSec msgs/sec)');

      // Performance Gate: 5000 SMS parsed in < 5000ms (1 second per 1000 messages)
      expect(elapsedMs, lessThan(5000),
          reason: 'Bulk throughput was too slow: ${elapsedMs}ms for 5000 msgs');
    });
  });
}
