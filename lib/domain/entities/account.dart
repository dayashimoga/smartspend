import 'package:equatable/equatable.dart';
import '../enums/bank.dart';

class Account extends Equatable {
  final String id;
  final Bank bank;
  final String last4;
  final String accountType; // Savings, Current, Salary, Wallet
  final double currentBalance;
  final String currency;
  final DateTime lastUpdated;
  final bool isBalanceReliable;

  const Account({
    required this.id,
    required this.bank,
    required this.last4,
    this.accountType = 'Savings',
    required this.currentBalance,
    this.currency = 'INR',
    required this.lastUpdated,
    this.isBalanceReliable = true,
  });

  String get displayName => '${bank.displayName} (•••• $last4)';

  Account copyWith({
    String? id,
    Bank? bank,
    String? last4,
    String? accountType,
    double? currentBalance,
    String? currency,
    DateTime? lastUpdated,
    bool? isBalanceReliable,
  }) {
    return Account(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      last4: last4 ?? this.last4,
      accountType: accountType ?? this.accountType,
      currentBalance: currentBalance ?? this.currentBalance,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isBalanceReliable: isBalanceReliable ?? this.isBalanceReliable,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank': bank.name,
      'last4': last4,
      'account_type': accountType,
      'current_balance': currentBalance,
      'currency': currency,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      bank: Bank.values.firstWhere(
        (e) => e.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      last4: map['last4'] as String,
      accountType: (map['account_type'] as String?) ?? 'Savings',
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? 'INR',
      lastUpdated:
          DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
      isBalanceReliable: (map['is_balance_reliable'] as bool?) ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bank,
        last4,
        accountType,
        currentBalance,
        currency,
        lastUpdated,
        isBalanceReliable
      ];
}
