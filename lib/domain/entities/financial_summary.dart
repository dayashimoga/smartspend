import 'package:equatable/equatable.dart';

class FinancialSummary extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final double totalAccountBalance;
  final double totalCardOutstanding;
  final double totalCardSpent;
  final double totalAvailableCredit;
  final int upcomingBillsCount;
  final double upcomingBillsTotal;
  final int needsReviewCount;
  final String currency;

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.totalAccountBalance,
    required this.totalCardOutstanding,
    this.totalCardSpent = 0.0,
    required this.totalAvailableCredit,
    required this.upcomingBillsCount,
    required this.upcomingBillsTotal,
    required this.needsReviewCount,
    this.currency = 'INR',
  });

  /// Returns null if insufficient credit limit data exists to prevent misleading false 0%.
  double? get cardUtilizationPercentage {
    final effectiveSpent =
        totalCardOutstanding > 0 ? totalCardOutstanding : totalCardSpent;
    final total = effectiveSpent + totalAvailableCredit;
    if (total <= 0 || totalAvailableCredit <= 0) return null;
    return (effectiveSpent / total) * 100.0;
  }

  factory FinancialSummary.empty({String currency = 'INR'}) {
    return FinancialSummary(
      totalIncome: 0.0,
      totalExpense: 0.0,
      netCashFlow: 0.0,
      totalAccountBalance: 0.0,
      totalCardOutstanding: 0.0,
      totalCardSpent: 0.0,
      totalAvailableCredit: 0.0,
      upcomingBillsCount: 0,
      upcomingBillsTotal: 0.0,
      needsReviewCount: 0,
      currency: currency,
    );
  }

  @override
  List<Object?> get props => [
        totalIncome,
        totalExpense,
        netCashFlow,
        totalAccountBalance,
        totalCardOutstanding,
        totalCardSpent,
        totalAvailableCredit,
        upcomingBillsCount,
        upcomingBillsTotal,
        needsReviewCount,
        currency,
      ];
}
