import 'package:equatable/equatable.dart';
import '../enums/bank.dart';

enum BillStatus {
  unpaid,
  dueToday,
  partial,
  paid,
  overdue,
  noPaymentRequired;

  String get displayName {
    switch (this) {
      case BillStatus.unpaid:
        return 'Due';
      case BillStatus.dueToday:
        return 'Due Today';
      case BillStatus.partial:
        return 'Partial';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.noPaymentRequired:
        return 'No Payment Required';
    }
  }
}

class Bill extends Equatable {
  final String id;
  final Bank bank;
  final String cardLast4;
  final String? billerName;
  final String? accountNumber;
  final double totalAmount;
  final double minimumAmount;
  final double paidAmount;
  final DateTime dueDate;
  final BillStatus status;
  final String currency;
  final String? paymentTransactionId;
  final DateTime? sourceDate;
  final DateTime createdAt;

  const Bill({
    required this.id,
    required this.bank,
    required this.cardLast4,
    this.billerName,
    this.accountNumber,
    required this.totalAmount,
    this.minimumAmount = 0.0,
    this.paidAmount = 0.0,
    required this.dueDate,
    this.status = BillStatus.unpaid,
    this.currency = 'INR',
    this.paymentTransactionId,
    this.sourceDate,
    required this.createdAt,
  });

  /// Days left until due date (negative if overdue, 0 if due today).
  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  /// Calculates dynamically resolved status based on payment and calendar date.
  BillStatus get effectiveStatus {
    if (totalAmount <= 0) return BillStatus.noPaymentRequired;
    if (paidAmount >= totalAmount && totalAmount > 0) return BillStatus.paid;
    if (status == BillStatus.paid) return BillStatus.paid;
    if (paidAmount > 0 && paidAmount < totalAmount) return BillStatus.partial;

    final days = daysUntilDue;
    if (days < 0) return BillStatus.overdue;
    if (days == 0) return BillStatus.dueToday;
    return BillStatus.unpaid;
  }

  double get remainingAmount {
    final rem = totalAmount - paidAmount;
    return rem > 0 ? rem : 0.0;
  }

  bool get isDueSoon {
    final now = DateTime.now();
    final diff = dueDate.difference(now).inDays;
    return diff >= 0 && diff <= 5 && status != BillStatus.paid;
  }

  bool get isOverdue {
    final now = DateTime.now();
    return dueDate.isBefore(now) && status != BillStatus.paid;
  }

  String get billerDisplayName {
    if (billerName != null && billerName!.isNotEmpty) {
      return billerName!;
    }
    return '${bank.displayName} Card';
  }

  String get maskedTarget {
    if (cardLast4.isNotEmpty) {
      return '•••• $cardLast4';
    }
    if (accountNumber != null && accountNumber!.isNotEmpty) {
      return '•••• ${accountNumber!.length > 4 ? accountNumber!.substring(accountNumber!.length - 4) : accountNumber}';
    }
    return '';
  }

  DateTime get asOnDate => sourceDate ?? createdAt;

  Bill copyWith({
    String? id,
    Bank? bank,
    String? cardLast4,
    String? billerName,
    String? accountNumber,
    double? totalAmount,
    double? minimumAmount,
    double? paidAmount,
    DateTime? dueDate,
    BillStatus? status,
    String? currency,
    String? paymentTransactionId,
    DateTime? sourceDate,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      cardLast4: cardLast4 ?? this.cardLast4,
      billerName: billerName ?? this.billerName,
      accountNumber: accountNumber ?? this.accountNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      sourceDate: sourceDate ?? this.sourceDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank': bank.name,
      'card_last4': cardLast4,
      'biller_name': billerName,
      'account_number': accountNumber,
      'total_amount': totalAmount,
      'minimum_amount': minimumAmount,
      'paid_amount': paidAmount,
      'due_date': dueDate.millisecondsSinceEpoch,
      'status': status.name,
      'currency': currency,
      'payment_transaction_id': paymentTransactionId,
      'source_date': sourceDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    final total = (map['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (map['paid_amount'] as num?)?.toDouble() ?? 0.0;

    BillStatus resolvedStatus = BillStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => BillStatus.unpaid,
    );
    if (total <= 0) {
      resolvedStatus = BillStatus.noPaymentRequired;
    }

    return Bill(
      id: map['id'] as String,
      bank: Bank.values.firstWhere(
        (e) => e.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      cardLast4: (map['card_last4'] as String?) ?? '',
      billerName: map['biller_name'] as String?,
      accountNumber: map['account_number'] as String?,
      totalAmount: total,
      minimumAmount: (map['minimum_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: paid,
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      status: resolvedStatus,
      currency: (map['currency'] as String?) ?? 'INR',
      paymentTransactionId: map['payment_transaction_id'] as String?,
      sourceDate: map['source_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['source_date'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        bank,
        cardLast4,
        billerName,
        accountNumber,
        totalAmount,
        minimumAmount,
        paidAmount,
        dueDate,
        status,
        currency,
        paymentTransactionId,
        sourceDate,
        createdAt,
      ];
}
