import 'package:equatable/equatable.dart';
import '../enums/bank.dart';

class CreditCard extends Equatable {
  final String id;
  final Bank bank;
  final String last4;
  final double? availableLimit;
  final double? totalLimit;
  final double? outstanding;
  final double? statementDue;
  final double? currentDue;
  final DateTime? lastStatementDate;
  final String currency;
  final DateTime lastUpdated;

  const CreditCard({
    required this.id,
    required this.bank,
    required this.last4,
    this.availableLimit,
    this.totalLimit,
    this.outstanding,
    this.statementDue,
    this.currentDue,
    this.lastStatementDate,
    this.currency = 'INR',
    required this.lastUpdated,
  });

  String get displayName => '${bank.displayName} Card (•••• $last4)';

  /// Returns null when sufficient limit data is absent (shows "Unknown" in UI, never false 0%).
  double? get utilizationPercentage {
    if (totalLimit != null && totalLimit! > 0 && availableLimit != null) {
      final used = totalLimit! - availableLimit!;
      if (used <= 0) return 0.0;
      return (used / totalLimit!) * 100.0;
    }
    if (availableLimit != null &&
        outstanding != null &&
        (availableLimit! + outstanding!) > 0) {
      return (outstanding! / (availableLimit! + outstanding!)) * 100.0;
    }
    return null;
  }

  CreditCard copyWith({
    String? id,
    Bank? bank,
    String? last4,
    double? availableLimit,
    double? totalLimit,
    double? outstanding,
    double? statementDue,
    double? currentDue,
    DateTime? lastStatementDate,
    String? currency,
    DateTime? lastUpdated,
  }) {
    return CreditCard(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      last4: last4 ?? this.last4,
      availableLimit: availableLimit ?? this.availableLimit,
      totalLimit: totalLimit ?? this.totalLimit,
      outstanding: outstanding ?? this.outstanding,
      statementDue: statementDue ?? this.statementDue,
      currentDue: currentDue ?? this.currentDue,
      lastStatementDate: lastStatementDate ?? this.lastStatementDate,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank': bank.name,
      'last4': last4,
      'available_limit': availableLimit,
      'total_limit': totalLimit,
      'outstanding': outstanding,
      'statement_due': statementDue,
      'current_due': currentDue,
      'last_statement_date': lastStatementDate?.millisecondsSinceEpoch,
      'currency': currency,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory CreditCard.fromMap(Map<String, dynamic> map) {
    return CreditCard(
      id: map['id'] as String,
      bank: Bank.values.firstWhere(
        (e) => e.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      last4: map['last4'] as String,
      availableLimit: (map['available_limit'] as num?)?.toDouble(),
      totalLimit: (map['total_limit'] as num?)?.toDouble(),
      outstanding: (map['outstanding'] as num?)?.toDouble(),
      statementDue: (map['statement_due'] as num?)?.toDouble(),
      currentDue: (map['current_due'] as num?)?.toDouble(),
      lastStatementDate: map['last_statement_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['last_statement_date'] as int)
          : null,
      currency: (map['currency'] as String?) ?? 'INR',
      lastUpdated:
          DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        bank,
        last4,
        availableLimit,
        totalLimit,
        outstanding,
        statementDue,
        currentDue,
        lastStatementDate,
        currency,
        lastUpdated
      ];
}
