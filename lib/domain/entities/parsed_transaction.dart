import 'package:equatable/equatable.dart';
import '../enums/bank.dart';
import '../enums/confidence.dart';
import '../enums/transaction_type.dart';

class ParsedTransaction extends Equatable {
  final String id;
  final String rawSmsId;
  final TransactionType type;
  final Bank bank;
  final String? accountLast4;
  final String? cardLast4;
  final double amount;
  final String currency;
  final DateTime transactionDate;
  final DateTime? smsReceivedAt;
  final DateTime? statementDate;
  final String? merchant;
  final String? payee;
  final String? payer;
  final String? reference;
  final String? rrn;
  final String? upiRef;
  final double? balance;
  final double? availableLimit;
  final double? outstanding;
  final double? billTotal;
  final double? billMinimum;
  final DateTime? billDueDate;
  final String? fastagId;
  final String? vehicle;
  final String? tollPlaza;
  final double? walletBalance;
  final Confidence confidence;
  final String parserVersion;
  final String category;
  final List<String> tags;
  final bool isExcluded;
  final bool isReconciled;
  final String? reconciledWithId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ParsedTransaction({
    required this.id,
    required this.rawSmsId,
    required this.type,
    required this.bank,
    this.accountLast4,
    this.cardLast4,
    required this.amount,
    this.currency = 'INR',
    required this.transactionDate,
    this.smsReceivedAt,
    this.statementDate,
    this.merchant,
    this.payee,
    this.payer,
    this.reference,
    this.rrn,
    this.upiRef,
    this.balance,
    this.availableLimit,
    this.outstanding,
    this.billTotal,
    this.billMinimum,
    this.billDueDate,
    this.fastagId,
    this.vehicle,
    this.tollPlaza,
    this.walletBalance,
    this.confidence = Confidence.high,
    this.parserVersion = '1.0.0',
    this.category = 'Uncategorized',
    this.tags = const [],
    this.isExcluded = false,
    this.isReconciled = false,
    this.reconciledWithId,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayTitle {
    if (merchant != null && merchant!.isNotEmpty) return merchant!;
    if (payee != null && payee!.isNotEmpty) return payee!;
    if (vehicle != null && vehicle!.isNotEmpty) return 'Toll: $vehicle';
    if (tollPlaza != null && tollPlaza!.isNotEmpty) return 'Toll at $tollPlaza';
    if (payer != null && payer!.isNotEmpty) return payer!;
    return '${bank.shortName} ${type.displayName}';
  }

  String get maskedAccountOrCard {
    if (cardLast4 != null && cardLast4!.isNotEmpty) {
      return '•••• $cardLast4';
    }
    if (accountLast4 != null && accountLast4!.isNotEmpty) {
      return '•••• $accountLast4';
    }
    return '';
  }

  ParsedTransaction copyWith({
    String? id,
    String? rawSmsId,
    TransactionType? type,
    Bank? bank,
    String? accountLast4,
    String? cardLast4,
    double? amount,
    String? currency,
    DateTime? transactionDate,
    DateTime? smsReceivedAt,
    DateTime? statementDate,
    String? merchant,
    String? payee,
    String? payer,
    String? reference,
    String? rrn,
    String? upiRef,
    double? balance,
    double? availableLimit,
    double? outstanding,
    double? billTotal,
    double? billMinimum,
    DateTime? billDueDate,
    String? fastagId,
    String? vehicle,
    String? tollPlaza,
    double? walletBalance,
    Confidence? confidence,
    String? parserVersion,
    String? category,
    List<String>? tags,
    bool? isExcluded,
    bool? isReconciled,
    String? reconciledWithId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParsedTransaction(
      id: id ?? this.id,
      rawSmsId: rawSmsId ?? this.rawSmsId,
      type: type ?? this.type,
      bank: bank ?? this.bank,
      accountLast4: accountLast4 ?? this.accountLast4,
      cardLast4: cardLast4 ?? this.cardLast4,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      smsReceivedAt: smsReceivedAt ?? this.smsReceivedAt,
      statementDate: statementDate ?? this.statementDate,
      merchant: merchant ?? this.merchant,
      payee: payee ?? this.payee,
      payer: payer ?? this.payer,
      reference: reference ?? this.reference,
      rrn: rrn ?? this.rrn,
      upiRef: upiRef ?? this.upiRef,
      balance: balance ?? this.balance,
      availableLimit: availableLimit ?? this.availableLimit,
      outstanding: outstanding ?? this.outstanding,
      billTotal: billTotal ?? this.billTotal,
      billMinimum: billMinimum ?? this.billMinimum,
      billDueDate: billDueDate ?? this.billDueDate,
      fastagId: fastagId ?? this.fastagId,
      vehicle: vehicle ?? this.vehicle,
      tollPlaza: tollPlaza ?? this.tollPlaza,
      walletBalance: walletBalance ?? this.walletBalance,
      confidence: confidence ?? this.confidence,
      parserVersion: parserVersion ?? this.parserVersion,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isExcluded: isExcluded ?? this.isExcluded,
      isReconciled: isReconciled ?? this.isReconciled,
      reconciledWithId: reconciledWithId ?? this.reconciledWithId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_sms_id': rawSmsId,
      'type': type.name,
      'bank': bank.name,
      'account_last4': accountLast4,
      'card_last4': cardLast4,
      'amount': amount,
      'currency': currency,
      'transaction_date': transactionDate.millisecondsSinceEpoch,
      'sms_received_at': smsReceivedAt?.millisecondsSinceEpoch,
      'statement_date': statementDate?.millisecondsSinceEpoch,
      'merchant': merchant,
      'payee': payee,
      'payer': payer,
      'reference': reference,
      'rrn': rrn,
      'upi_ref': upiRef,
      'balance': balance,
      'available_limit': availableLimit,
      'outstanding': outstanding,
      'bill_total': billTotal,
      'bill_minimum': billMinimum,
      'bill_due_date': billDueDate?.millisecondsSinceEpoch,
      'fastag_id': fastagId,
      'vehicle': vehicle,
      'toll_plaza': tollPlaza,
      'wallet_balance': walletBalance,
      'confidence': confidence.name,
      'parser_version': parserVersion,
      'category': category,
      'tags': tags.join(','),
      'is_excluded': isExcluded ? 1 : 0,
      'is_reconciled': isReconciled ? 1 : 0,
      'reconciled_with_id': reconciledWithId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ParsedTransaction.fromMap(Map<String, dynamic> map) {
    return ParsedTransaction(
      id: map['id'] as String,
      rawSmsId: map['raw_sms_id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.unknown,
      ),
      bank: Bank.values.firstWhere(
        (e) => e.name == map['bank'],
        orElse: () => Bank.unknown,
      ),
      accountLast4: map['account_last4'] as String?,
      cardLast4: map['card_last4'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? 'INR',
      transactionDate:
          DateTime.fromMillisecondsSinceEpoch(map['transaction_date'] as int),
      smsReceivedAt: map['sms_received_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['sms_received_at'] as int)
          : null,
      statementDate: map['statement_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['statement_date'] as int)
          : null,
      merchant: map['merchant'] as String?,
      payee: map['payee'] as String?,
      payer: map['payer'] as String?,
      reference: map['reference'] as String?,
      rrn: map['rrn'] as String?,
      upiRef: map['upi_ref'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      availableLimit: (map['available_limit'] as num?)?.toDouble(),
      outstanding: (map['outstanding'] as num?)?.toDouble(),
      billTotal: (map['bill_total'] as num?)?.toDouble(),
      billMinimum: (map['bill_minimum'] as num?)?.toDouble(),
      billDueDate: map['bill_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['bill_due_date'] as int)
          : null,
      fastagId: map['fastag_id'] as String?,
      vehicle: map['vehicle'] as String?,
      tollPlaza: map['toll_plaza'] as String?,
      walletBalance: (map['wallet_balance'] as num?)?.toDouble(),
      confidence: Confidence.values.firstWhere(
        (e) => e.name == map['confidence'],
        orElse: () => Confidence.high,
      ),
      parserVersion: (map['parser_version'] as String?) ?? '1.0.0',
      category: (map['category'] as String?) ?? 'Uncategorized',
      tags: (map['tags'] as String?)
              ?.split(',')
              .where((t) => t.isNotEmpty)
              .toList() ??
          [],
      isExcluded: (map['is_excluded'] as int?) == 1,
      isReconciled: (map['is_reconciled'] as int?) == 1,
      reconciledWithId: map['reconciled_with_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        rawSmsId,
        type,
        bank,
        accountLast4,
        cardLast4,
        amount,
        currency,
        transactionDate,
        smsReceivedAt,
        statementDate,
        merchant,
        payee,
        payer,
        reference,
        rrn,
        upiRef,
        balance,
        availableLimit,
        outstanding,
        billTotal,
        billMinimum,
        billDueDate,
        fastagId,
        vehicle,
        tollPlaza,
        walletBalance,
        confidence,
        parserVersion,
        category,
        tags,
        isExcluded,
        isReconciled,
        reconciledWithId,
        createdAt,
        updatedAt,
      ];
}
