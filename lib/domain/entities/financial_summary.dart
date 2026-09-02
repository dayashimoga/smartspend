import 'package:equatable/equatable.dart';

class FinancialSummary extends Equatable {
  final double totalIncome;
  final double totalExpense;
  final double netCashFlow;
  final double totalAccountBalance;
  final double totalCardOutstanding;
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
    required this.totalAvailableCredit,
    required this.upcomingBillsCount,
    required this.upcomingBillsTotal,
    required this.needsReviewCount,
    this.currency = 'INR',
  });

  double get cardUtilizationPercentage {
    final total = totalCardOutstanding + totalAvailableCredit;
    if (total <= 0) return 0.0;
    return (totalCardOutstanding / total) * 100.0;
  }

  factory FinancialSummary.empty({String currency = 'INR'}) {
    return FinancialSummary(
      totalIncome: 0.0,
      totalExpense: 0.0,
      netCashFlow: 0.0,
      totalAccountBalance: 0.0,
      totalCardOutstanding: 0.0,
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
        totalAvailableCredit,
        upcomingBillsCount,
        upcomingBillsTotal,
        needsReviewCount,
        currency,
      ];
}
