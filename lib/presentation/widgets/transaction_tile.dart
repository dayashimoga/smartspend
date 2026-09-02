import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/date_parser.dart';
import '../../domain/entities/parsed_transaction.dart';

class TransactionTile extends StatelessWidget {
  final ParsedTransaction transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.type.isIncome;
    final isExpense = transaction.type.isExpense;

    Color amountColor;
    String prefix;
    if (isIncome) {
      amountColor = AppColors.income;
      prefix = '+';
    } else if (isExpense) {
      amountColor = AppColors.expense;
      prefix = '-';
    } else {
      amountColor =
          isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
      prefix = '';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isIncome
                          ? AppColors.income
                          : (isExpense ? AppColors.expense : AppColors.primary))
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(transaction.category),
                  color: isIncome
                      ? AppColors.income
                      : (isExpense ? AppColors.expense : AppColors.primary),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title, Date & Masked Account
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.displayTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateParser.toDisplayDate(transaction.transactionDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (transaction.maskedAccountOrCard.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('•',
                              style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                  fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            transaction.maskedAccountOrCard,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                        if (transaction.confidence.needsReview) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Review',
                              style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$prefix${AmountParser.format(transaction.amount, currency: transaction.currency)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.bank.shortName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'salary':
      case 'income':
        return Icons.account_balance_wallet;
      case 'transportation':
      case 'toll & fastag':
        return Icons.directions_car;
      case 'bills & utilities':
        return Icons.receipt_long;
      case 'cash & atm':
        return Icons.local_atm;
      case 'investments':
        return Icons.trending_up;
      case 'entertainment':
        return Icons.movie;
      default:
        return Icons.credit_card;
    }
  }
}
