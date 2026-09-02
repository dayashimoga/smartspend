import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  final String id;
  final String category;
  final double monthlyLimit;
  final String currency;
  final double currentSpend;
  final int month;
  final int year;

  const Budget({
    required this.id,
    required this.category,
    required this.monthlyLimit,
    this.currency = 'INR',
    this.currentSpend = 0.0,
    required this.month,
    required this.year,
  });

  double get remainingAmount =>
      (monthlyLimit - currentSpend).clamp(0.0, double.infinity);

  double get progressPercentage {
    if (monthlyLimit <= 0) return 0.0;
    return ((currentSpend / monthlyLimit) * 100.0).clamp(0.0, 100.0);
  }

  bool get isExceeded => currentSpend > monthlyLimit;

  Budget copyWith({
    String? id,
    String? category,
    double? monthlyLimit,
    String? currency,
    double? currentSpend,
    int? month,
    int? year,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      currency: currency ?? this.currency,
      currentSpend: currentSpend ?? this.currentSpend,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'currency': currency,
      'current_spend': currentSpend,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      category: map['category'] as String,
      monthlyLimit: (map['monthly_limit'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? 'INR',
      currentSpend: (map['current_spend'] as num?)?.toDouble() ?? 0.0,
      month: map['month'] as int,
      year: map['year'] as int,
    );
  }

  @override
  List<Object?> get props =>
      [id, category, monthlyLimit, currency, currentSpend, month, year];
}
