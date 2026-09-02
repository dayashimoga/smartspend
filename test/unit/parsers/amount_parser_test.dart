import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/utils/amount_parser.dart';

void main() {
  group('AmountParser Unit Tests', () {
    test('Parses Indian Rupee prefixes correctly', () {
      expect(AmountParser.parse('₹1,96,021.82'), equals(196021.82));
      expect(AmountParser.parse('Rs.11,397.00'), equals(11397.00));
      expect(AmountParser.parse('INR 483.40'), equals(483.40));
      expect(AmountParser.parse('Rs 3,494.78'), equals(3494.78));
      expect(AmountParser.parse('INR 560.2'), equals(560.20));
      expect(AmountParser.parse('Rs.3,676.00'), equals(3676.00));
      expect(AmountParser.parse('INR 93,807.00'), equals(93807.00));
      expect(AmountParser.parse('Rs.30000.00'), equals(30000.00));
      expect(AmountParser.parse('Rs.65'), equals(65.0));
      expect(AmountParser.parse('Rs.100'), equals(100.0));
    });

    test('Handles international currencies and edge cases', () {
      expect(AmountParser.parse('\$1,250.50'), equals(1250.50));
      expect(AmountParser.parse('€450.00'), equals(450.00));
      expect(AmountParser.parse('£99.99'), equals(99.99));
      expect(AmountParser.parse('0.0'), equals(0.0));
      expect(AmountParser.parse('-500.00'), equals(-500.00));
      expect(AmountParser.parse(null), isNull);
      expect(AmountParser.parse('   '), isNull);
      expect(AmountParser.parse('invalid text'), isNull);
    });

    test('Formats currency accurately', () {
      expect(AmountParser.format(1234567.89, currency: 'INR'),
          equals('₹12,34,567.89'));
      expect(AmountParser.format(500.0, currency: 'INR'), equals('₹500.00'));
      expect(
          AmountParser.format(-1500.50, currency: 'INR'), equals('-₹1,500.50'));
      expect(AmountParser.format(1000000.0, currency: 'USD'),
          equals('\$1,000,000.00'));
    });
  });
}
