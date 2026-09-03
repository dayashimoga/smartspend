import '../../domain/enums/bank.dart';

class InstitutionDetector {
  /// Detects the financial institution from SMS sender header or body text.
  static Bank detect(String sender, String body) {
    final s = sender.toUpperCase();
    final b = body.toUpperCase();

    // 1. Check sender ID prefixes/suffixes (e.g., AD-HDFCBK, VK-ICICIB, SBICRD)
    if (s.contains('HDFC')) return Bank.hdfc;
    if (s.contains('ICICI')) return Bank.icici;
    if (s.contains('AXIS')) return Bank.axis;
    if (s.contains('SBI')) return Bank.sbi;
    if (s.contains('HSBC')) return Bank.hsbc;
    if (s.contains('YES') || s.contains('YESB')) return Bank.yesBank;
    if (s.contains('IDFC')) return Bank.idfcFirst;
    if (s.contains('INDUS') || s.contains('INDBNK')) return Bank.indusind;
    if (s.contains('UJJIV')) return Bank.ujjivan;
    if (s.contains('ONECRD') || s.contains('ONECARD')) return Bank.onecard;
    if (s.contains('SIB') || s.contains('SOUTHI')) return Bank.sib;
    if (s.contains('RBL')) return Bank.rbl;
    if (s.contains('KOTAK')) return Bank.kotak;

    // 2. Check body content
    if (b.contains('HDFC BANK') || b.contains('HDFC')) return Bank.hdfc;
    if (b.contains('ICICI BANK') || b.contains('ICICI')) return Bank.icici;
    if (b.contains('AXIS BANK') || b.contains('AXIS')) return Bank.axis;
    if (b.contains('SBI CREDIT CARD') ||
        b.contains('STATE BANK') ||
        b.contains('SBI')) {
      return Bank.sbi;
    }
    if (b.contains('HSBC')) return Bank.hsbc;
    if (b.contains('YES BANK') || b.contains('YESBANK')) return Bank.yesBank;
    if (b.contains('IDFC FIRST') || b.contains('IDFC')) return Bank.idfcFirst;
    if (b.contains('INDUSIND BANK') || b.contains('INDUSIND')) {
      return Bank.indusind;
    }
    if (b.contains('UJJIVAN')) return Bank.ujjivan;
    if (b.contains('ONECARD')) return Bank.onecard;
    if (b.contains('SOUTH INDIAN BANK') || b.contains('SIB')) return Bank.sib;
    if (b.contains('RBL BANK') || b.contains('RBL')) return Bank.rbl;
    if (b.contains('KOTAK MAHINDRA') ||
        b.contains('KOTAK BANK') ||
        b.contains('KOTAK')) {
      return Bank.kotak;
    }

    return Bank.unknown;
  }
}
