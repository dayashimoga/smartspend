import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/constants/regex_patterns.dart';

void main() {
  group('RegexPatterns Static Patterns Forensic Suite', () {
    test('Matches amount patterns across currencies and formats', () {
      expect(RegexPatterns.amountPrefix.hasMatch('INR 5,000.50'), isTrue);
      expect(RegexPatterns.amountPrefix.hasMatch('Rs. 1200'), isTrue);
      expect(RegexPatterns.amountPrefix.hasMatch('₹ 99.99'), isTrue);

      expect(RegexPatterns.amountGeneric.hasMatch('debited for Rs 450.00'),
          isTrue);
    });

    test('Matches card and account last4 patterns', () {
      expect(RegexPatterns.cardLast4.hasMatch('Card ending 4000'), isTrue);
      expect(RegexPatterns.cardLast4.hasMatch('Card ending in XX1234'), isTrue);

      expect(RegexPatterns.accountLast4.hasMatch('A/c *1234'), isTrue);
      expect(
          RegexPatterns.accountLast4.hasMatch('Account ending 5678'), isTrue);
    });

    test('Matches balance and limit patterns', () {
      expect(RegexPatterns.availableBalance.hasMatch('Avl Bal: Rs 45,000.00'),
          isTrue);
      expect(RegexPatterns.walletBalance.hasMatch('wallet bal is Rs. 450'),
          isTrue);
      expect(RegexPatterns.availableLimit.hasMatch('Avl Limit: INR 1,50,000'),
          isTrue);
    });
  });
}
