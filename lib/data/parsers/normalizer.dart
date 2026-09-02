class Normalizer {
  /// Cleans and normalizes raw SMS text while retaining critical financial tokens.
  static String normalize(String raw) {
    if (raw.isEmpty) return '';

    var text = raw;
    // Normalize unicode non-breaking spaces
    text = text.replaceAll('\u00A0', ' ');
    text = text.replaceAll('\u200B', ' ');

    // Standardize Rupee symbols
    text = text.replaceAll('₹', 'Rs.');

    // Normalize multiple periods or ellipsis
    text = text.replaceAll(RegExp(r'\.{2,}'), ' ');

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }
}
