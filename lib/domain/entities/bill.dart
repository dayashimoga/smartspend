import 'package:equatable/equatable.dart';
import '../enums/bank.dart';

enum BillStatus {
  unpaid,
  paid,
  overdue,
  noPaymentRequired;

  String get displayName {
    switch (this) {
      case BillStatus.unpaid:
        return 'Due';
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
  final double totalAmount;
  final double minimumAmount;
  final DateTime dueDate;
  final BillStatus status;
  final String currency;
  final String? paymentTransactionId;
  final DateTime createdAt;

  const Bill({
    required this.id,
    required this.bank,
    required this.cardLast4,
    required this.totalAmount,
    this.minimumAmount = 0.0,
    required this.dueDate,
    this.status = BillStatus.unpaid,
    this.currency = 'INR',
    this.paymentTransactionId,
    required this.createdAt,
  });

  bool get isDueSoon {
    final now = DateTime.now();
    final diff = dueDate.difference(now).inDays;
    return diff >= 0 && diff <= 5 && status == BillStatus.unpaid;
  }

  bool get isOverdue {
    final now = DateTime.now();
    return dueDate.isBefore(now) && status == BillStatus.unpaid;
  }

  Bill copyWith({
    String? id,
    Bank? bank,
    String? cardLast4,
    double? totalAmount,
    double? minimumAmount,
    DateTime? dueDate,
    BillStatus? status,
    String? currency,
    String? paymentTransactionId,
    DateTime? createdAt,
  }) {
    return Bill(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      cardLast4: cardLast4 ?? this.cardLast4,
      totalAmount: totalAmount ?? this.totalAmount,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank': bank.name,
      'card_last4': cardLast4,
      'total_amount': totalAmount,
      'minimum_amount': minimumAmount,
      'due_date': dueDate.millisecondsSinceEpoch,
      'status': status.name,
      'currency': currency,
      'payment_transaction_id': paymentTransactionId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    final total = (map['total_amount'] as num?)?.toDouble() ?? 0.0;
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
      cardLast4: map['card_last4'] as String,
      totalAmount: total,
      minimumAmount: (map['minimum_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      status: resolvedStatus,
      currency: (map['currency'] as String?) ?? 'INR',
      paymentTransactionId: map['payment_transaction_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        bank,
        cardLast4,
        totalAmount,
        minimumAmount,
        dueDate,
        status,
        currency,
        paymentTransactionId,
        createdAt,
      ];
}
