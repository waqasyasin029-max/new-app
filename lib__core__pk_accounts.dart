/// Ready-made choices for the accounts a person in Pakistan may have.
class PkAccount {
  final String name;
  final String type; // cash | wallet | bank
  const PkAccount(this.name, this.type);
}

class PkAccounts {
  PkAccounts._();

  static const cash = PkAccount('Cash', 'cash');

  static const wallets = <PkAccount>[
    PkAccount('JazzCash', 'wallet'),
    PkAccount('Easypaisa', 'wallet'),
    PkAccount('SadaPay', 'wallet'),
    PkAccount('Naya Pay', 'wallet'),
    PkAccount('Zindigi', 'wallet'),
    PkAccount('UPaisa', 'wallet'),
  ];

  static const banks = <PkAccount>[
    PkAccount('HBL', 'bank'),
    PkAccount('UBL', 'bank'),
    PkAccount('MCB', 'bank'),
    PkAccount('Meezan Bank', 'bank'),
    PkAccount('Allied Bank', 'bank'),
    PkAccount('Bank Alfalah', 'bank'),
    PkAccount('Askari Bank', 'bank'),
    PkAccount('Faysal Bank', 'bank'),
    PkAccount('Standard Chartered', 'bank'),
    PkAccount('Bank Al Habib', 'bank'),
    PkAccount('Habib Metro Bank', 'bank'),
    PkAccount('Soneri Bank', 'bank'),
    PkAccount('JS Bank', 'bank'),
    PkAccount('National Bank of Pakistan', 'bank'),
    PkAccount('Bank of Punjab', 'bank'),
    PkAccount('Dubai Islamic Bank', 'bank'),
  ];

  static List<PkAccount> get all => [cash, ...wallets, ...banks];
}
