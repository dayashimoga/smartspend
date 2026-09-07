import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/utils/date_parser.dart';

void main() {
  group('DateParser Unit Tests', () {
    test('Parses text month dates accurately', () {
      final d1 = DateParser.parse('30-Jan-26');
      expect(d1, isNotNull);
      expect(d1!.year, equals(2026));
      expect(d1.month, equals(1));
      expect(d1.day, equals(30));

      final d2 = DateParser.parse('05-FEB-26');
      expect(d2, isNotNull);
      expect(d2!.year, equals(2026));
      expect(d2.month, equals(2));
      expect(d2.day, equals(5));

      final d3 = DateParser.parse('27-JUN-25');
      expect(d3, isNotNull);
      expect(d3!.year, equals(2025));
      expect(d3.month, equals(6));
      expect(d3.day, equals(27));
    });

    test('Parses numeric dates with various delimiters', () {
      final d1 = DateParser.parse('04-08-2025');
      expect(d1, isNotNull);
      expect(d1!.year, equals(2025));
      expect(d1.month, equals(8));
      expect(d1.day, equals(4));

      final d2 = DateParser.parse('30/11/25');
      expect(d2, isNotNull);
      expect(d2!.year, equals(2025));
      expect(d2.month, equals(11));
      expect(d2.day, equals(30));

      final d3 = DateParser.parse('21/01/26');
      expect(d3, isNotNull);
      expect(d3!.year, equals(2026));
      expect(d3.month, equals(1));
      expect(d3.day, equals(21));

      // 2-part date without year
      final d4 = DateParser.parse('07-09', referenceYear: 2026);
      expect(d4, isNotNull);
      expect(d4!.year, equals(2026));
      expect(d4.month, equals(9));
      expect(d4.day, equals(7));

      final d5 = DateParser.parse('07-Sep', referenceYear: 2026);
      expect(d5, isNotNull);
      expect(d5!.year, equals(2026));
      expect(d5.month, equals(9));
      expect(d5.day, equals(7));

      final d6 = DateParser.parse('06-SEP-26');
      expect(d6, isNotNull);
      expect(d6!.year, equals(2026));
      expect(d6.month, equals(9));
      expect(d6.day, equals(6));
    });

    test('Parses date-time timestamps with hours, minutes, seconds', () {
      final d1 = DateParser.parse('2026-01-04:22:44:25');
      expect(d1, isNotNull);
      expect(d1!.year, equals(2026));
      expect(d1.month, equals(1));
      expect(d1.day, equals(4));
      expect(d1.hour, equals(22));
      expect(d1.minute, equals(44));
      expect(d1.second, equals(25));

      final d2 = DateParser.parse('2025-07-22 21:01:40');
      expect(d2, isNotNull);
      expect(d2!.year, equals(2025));
      expect(d2.month, equals(7));
      expect(d2.day, equals(22));
      expect(d2.hour, equals(21));
      expect(d2.minute, equals(1));
      expect(d2.second, equals(40));
    });

    test('Formats dates correctly', () {
      final dt = DateTime(2026, 1, 30);
      expect(DateParser.toIsoDate(dt), equals('2026-01-30'));
      expect(DateParser.toDisplayDate(dt), equals('30 Jan 2026'));
    });
  });
}
