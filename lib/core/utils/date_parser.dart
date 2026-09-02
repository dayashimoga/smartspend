class DateParser {
  static const Map<String, int> _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Parses diverse banking date formats into a standard DateTime.
  static DateTime? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();

    // 1. ISO-like: 2026-01-04:22:44:25 or 2025-07-22 21:01:40
    final isoMatch =
        RegExp(r'(\d{4})-(\d{2})-(\d{2})[:\s](\d{2}):(\d{2}):(\d{2})')
            .firstMatch(text);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      final hr = int.parse(isoMatch.group(4)!);
      final min = int.parse(isoMatch.group(5)!);
      final sec = int.parse(isoMatch.group(6)!);
      return DateTime(y, m, d, hr, min, sec);
    }

    // 2. YYYY-MM-DD
    final ymdMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (ymdMatch != null) {
      return DateTime(
        int.parse(ymdMatch.group(1)!),
        int.parse(ymdMatch.group(2)!),
        int.parse(ymdMatch.group(3)!),
      );
    }

    // 3. DD-MM-YYYY HH:mm:ss or DD-MM-YY HH:mm:ss
    final dmyTimeMatch = RegExp(
            r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\s+(\d{2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(text);
    if (dmyTimeMatch != null) {
      final d = int.parse(dmyTimeMatch.group(1)!);
      final m = int.parse(dmyTimeMatch.group(2)!);
      var y = int.parse(dmyTimeMatch.group(3)!);
      if (y < 100) y += 2000;
      final hr = int.parse(dmyTimeMatch.group(4)!);
      final min = int.parse(dmyTimeMatch.group(5)!);
      final sec =
          dmyTimeMatch.group(6) != null ? int.parse(dmyTimeMatch.group(6)!) : 0;
      return DateTime(y, m, d, hr, min, sec);
    }

    // 4. DD-MMM-YY / DD-MMM-YYYY (e.g., 30-Jan-26, 05-FEB-26, 27-JUN-25)
    final textMonthMatch =
        RegExp(r'(\d{1,2})[-/]([a-zA-Z]{3})[-/](\d{2,4})', caseSensitive: false)
            .firstMatch(text);
    if (textMonthMatch != null) {
      final d = int.parse(textMonthMatch.group(1)!);
      final monthStr = textMonthMatch.group(2)!.toLowerCase();
      var y = int.parse(textMonthMatch.group(3)!);
      if (y < 100) y += 2000;
      final m = _months[monthStr];
      if (m != null) {
        return DateTime(y, m, d);
      }
    }

    // 5. DD-MM-YY or DD/MM/YYYY or DD-MM-YYYY (e.g. 04-08-2025, 30/11/25, 21/01/26)
    final dmyMatch =
        RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})').firstMatch(text);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      var y = int.parse(dmyMatch.group(3)!);
      if (y < 100) y += 2000;
      return DateTime(y, m, d);
    }

    return null;
  }

  /// Formats a DateTime into YYYY-MM-DD string.
  static String toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats a DateTime into friendly human-readable format: "30 Jan 2026".
  static String toDisplayDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final mName = monthNames[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')} $mName ${date.year}';
  }
}
