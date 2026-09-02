class RegexPatterns {
  // Amount patterns: handles ₹, Rs, Rs., INR, with optional decimals and commas
  static final RegExp amountPrefix = RegExp(
    r'(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp amountGeneric = RegExp(
    r'(?:(?:Rs\.?|INR|₹)\s*|\b(?:INR|Rs\.?)\s*)([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Card patterns
  static final RegExp cardLast4 = RegExp(
    r'(?:Card\s*(?:no\.?)?\s*(?:ending|xx|x)?|ending\s*|XX|x)\s*([0-9]{4})\b',
    caseSensitive: false,
  );

  static final RegExp accountLast4 = RegExp(
    r'(?:A/c|Account|Acct)\s*(?:no\.?)?\s*(?:XX|\*|ending\s*)?\s*([0-9]{3,4})\b',
    caseSensitive: false,
  );

  // Balances
  static final RegExp availableBalance = RegExp(
    r'(?:available\s*balance|avl\s*bal|bal\s*Rs\.?|new\s*bal|wallet\s*bal|available\s*bal)\s*(?:is|:)?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp walletBalance = RegExp(
    r'(?:wallet\s*bal(?:ance)?)\s*(?:is|:)?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp availableLimit = RegExp(
    r'(?:Avl\s*Limit|Available\s*limit|Avl\s*Lmt)\s*:\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Bill patterns
  static final RegExp billTotalDue = RegExp(
    r'(?:Total\s*(?:due\s*amt|amount(?:\s*is)?|of)|Total\s*due)\s*(?:is|:)?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp billMinDue = RegExp(
    r'(?:Min(?:imum)?\s*(?:due\s*amt|amount(?:\s*is)?|of)|Min\s*due)\s*(?:is|:)?\s*(?:INR|Rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp billDueDate = RegExp(
    r'(?:due\s*(?:by|date|on)|payable\s*by)\s*(?:is|:)?\s*([0-9]{1,2}[-/][a-zA-Z0-9]{2,3}[-/][0-9]{2,4})',
    caseSensitive: false,
  );

  // Reference / UPI / RRN
  static final RegExp referenceNumber = RegExp(
    r'(?:Ref\s*(?:no\.?)?|RRN|UPI\s*Ref(?:\s*no\.?)?)\s*[:.]?\s*([a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  // FASTag & Vehicles
  static final RegExp fastagVehicle = RegExp(
    r'\b([A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4})\b',
    caseSensitive: false,
  );

  static final RegExp fastagId = RegExp(
    r'(?:FASTag\s*)([0-9]{10,24})\b',
    caseSensitive: false,
  );

  static final RegExp tollPlaza = RegExp(
    r'(?:At|at)\s+([A-Za-z0-9\s]+?)\s+(?:On|on|Toll)',
    caseSensitive: false,
  );

  // Transaction Classification Keywords
  static final RegExp debitKeywords = RegExp(
    r'\b(?:debited|deducted|withdrawn|sent|amt deducted|toll paid|spent|paid)\b',
    caseSensitive: false,
  );

  static final RegExp creditKeywords = RegExp(
    r'\b(?:credited|deposited|received|cashback|interest|refund|reversal)\b',
    caseSensitive: false,
  );

  static final RegExp salaryKeywords = RegExp(
    r'\b(?:salary|payroll|stipend)\b',
    caseSensitive: false,
  );

  static final RegExp atmKeywords = RegExp(
    r'\b(?:withdrawn|atm|cash withdrawal)\b',
    caseSensitive: false,
  );

  static final RegExp upiKeywords = RegExp(
    r'\b(?:upi|vpa|googlepay|gpay|phonepe|paytm)\b',
    caseSensitive: false,
  );

  static final RegExp fastagKeywords = RegExp(
    r'\b(?:fastag|netc fastag|toll paid)\b',
    caseSensitive: false,
  );
}
