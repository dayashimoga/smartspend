class AmountParser {
  /// Parses amount string into a double, handling ₹/Rs/INR/symbols, commas, decimals.
  static double? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    var cleaned = raw.trim();
    // Remove known currency identifiers
    cleaned = cleaned.replaceAll(
        RegExp(r'(?:INR|Rs\.?|₹|\$|€|£)\s*', caseSensitive: false), '');
    // Remove thousand separators
    cleaned = cleaned.replaceAll(',', '');
    // Remove any trailing non-numeric characters except period
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.-]'), '');

    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Formats amount into standard display string with currency symbol.
  static String format(double amount, {String currency = 'INR'}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    String formattedInt;
    if (currency == 'INR') {
      // Indian numbering system: 12,34,567
      if (intPart.length > 3) {
        final lastThree = intPart.substring(intPart.length - 3);
        final otherNumbers = intPart.substring(0, intPart.length - 3);
        final formattedOther = otherNumbers.replaceAllMapped(
          RegExp(r'(\d)(?=(\d{2})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        formattedInt = '$formattedOther,$lastThree';
      } else {
        formattedInt = intPart;
      }
      return '${isNegative ? '-' : ''}₹$formattedInt.$decPart';
    } else {
      // Standard international 3-digit comma grouping
      formattedInt = intPart.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      final symbol = _getCurrencySymbol(currency);
      return '${isNegative ? '-' : ''}$symbol$formattedInt.$decPart';
    }
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED ';
      default:
        return '$currency ';
    }
  }
}
