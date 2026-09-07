enum TransactionType {
  debit,
  credit,
  purchase,
  refund,
  cashback,
  salary,
  interest,
  atm,
  upi,
  neft,
  ach,
  bbps,
  bill,
  billPayment,
  fastag,
  fastagRecharge,
  fastagFunding,
  transfer,
  investmentTransfer,
  reversal,
  unknown;

  String get displayName {
    switch (this) {
      case TransactionType.debit:
        return 'Debit';
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.purchase:
        return 'Card Purchase';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.cashback:
        return 'Cashback';
      case TransactionType.salary:
        return 'Salary';
      case TransactionType.interest:
        return 'Interest';
      case TransactionType.atm:
        return 'ATM Withdrawal';
      case TransactionType.upi:
        return 'UPI';
      case TransactionType.neft:
        return 'NEFT';
      case TransactionType.ach:
        return 'ACH';
      case TransactionType.bbps:
        return 'BBPS';
      case TransactionType.bill:
        return 'Credit Card Bill';
      case TransactionType.billPayment:
        return 'Credit Card Payment';
      case TransactionType.fastag:
        return 'FASTag Toll';
      case TransactionType.fastagRecharge:
        return 'FASTag Recharge';
      case TransactionType.fastagFunding:
        return 'FASTag Funding';
      case TransactionType.transfer:
        return 'Account Transfer';
      case TransactionType.investmentTransfer:
        return 'Investment Transfer';
      case TransactionType.reversal:
        return 'Reversal';
      case TransactionType.unknown:
        return 'Other';
    }
  }

  /// True for actual consumer spending (purchases, debits, ATM cash withdrawals, FASTag toll charges).
  /// Excludes internal movements (bill payments, transfers, FASTag funding, investment transfers).
  bool get isExpense =>
      this == TransactionType.debit ||
      this == TransactionType.purchase ||
      this == TransactionType.atm ||
      this == TransactionType.fastag;

  /// True for external inflows (salary, interest, cashback, general credits).
  /// Excludes own-account transfers, reversals, and refunds.
  bool get isIncome =>
      this == TransactionType.credit ||
      this == TransactionType.salary ||
      this == TransactionType.interest ||
      this == TransactionType.cashback;

  /// True for balance-neutral internal movements, bills, reversals, and non-expense/income records.
  bool get isNeutral =>
      this == TransactionType.billPayment ||
      this == TransactionType.transfer ||
      this == TransactionType.investmentTransfer ||
      this == TransactionType.fastagRecharge ||
      this == TransactionType.fastagFunding ||
      this == TransactionType.bill ||
      this == TransactionType.refund ||
      this == TransactionType.reversal ||
      this == TransactionType.unknown;
}
