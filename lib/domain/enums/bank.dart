enum Bank {
  hdfc,
  icici,
  axis,
  sbi,
  hsbc,
  yesBank,
  idfcFirst,
  indusind,
  ujjivan,
  sib,
  onecard,
  rbl,
  kotak,
  unknown;

  String get displayName {
    switch (this) {
      case Bank.hdfc:
        return 'HDFC Bank';
      case Bank.icici:
        return 'ICICI Bank';
      case Bank.axis:
        return 'Axis Bank';
      case Bank.sbi:
        return 'State Bank of India';
      case Bank.hsbc:
        return 'HSBC Bank';
      case Bank.yesBank:
        return 'YES BANK';
      case Bank.idfcFirst:
        return 'IDFC FIRST Bank';
      case Bank.indusind:
        return 'IndusInd Bank';
      case Bank.ujjivan:
        return 'Ujjivan Small Finance Bank';
      case Bank.sib:
        return 'South Indian Bank';
      case Bank.onecard:
        return 'OneCard';
      case Bank.rbl:
        return 'RBL Bank';
      case Bank.kotak:
        return 'Kotak Mahindra Bank';
      case Bank.unknown:
        return 'General / Other';
    }
  }

  String get shortName {
    switch (this) {
      case Bank.hdfc:
        return 'HDFC';
      case Bank.icici:
        return 'ICICI';
      case Bank.axis:
        return 'Axis';
      case Bank.sbi:
        return 'SBI';
      case Bank.hsbc:
        return 'HSBC';
      case Bank.yesBank:
        return 'YES';
      case Bank.idfcFirst:
        return 'IDFC FIRST';
      case Bank.indusind:
        return 'IndusInd';
      case Bank.ujjivan:
        return 'Ujjivan';
      case Bank.sib:
        return 'SIB';
      case Bank.onecard:
        return 'OneCard';
      case Bank.rbl:
        return 'RBL';
      case Bank.kotak:
        return 'Kotak';
      case Bank.unknown:
        return 'Other';
    }
  }
}
