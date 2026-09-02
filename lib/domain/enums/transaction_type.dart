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
  transfer,
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
        return 'Bill Payment';
      case TransactionType.fastag:
        return 'FASTag Toll';
      case TransactionType.fastagRecharge:
        return 'FASTag Recharge';
      case TransactionType.transfer:
        return 'Account Transfer';
      case TransactionType.reversal:
        return 'Reversal';
      case TransactionType.unknown:
        return 'Other';
    }
  }

  bool get isExpense =>
      this == TransactionType.debit ||
      this == TransactionType.purchase ||
      this == TransactionType.atm ||
      this == TransactionType.fastag ||
      this == TransactionType.billPayment;

  bool get isIncome =>
      this == TransactionType.credit ||
      this == TransactionType.salary ||
      this == TransactionType.interest ||
      this == TransactionType.refund ||
      this == TransactionType.cashback;
}
