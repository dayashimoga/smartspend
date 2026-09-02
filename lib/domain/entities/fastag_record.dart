import 'package:equatable/equatable.dart';
import '../enums/bank.dart';

class FastagRecord extends Equatable {
  final String id;
  final String? fastagId;
  final String? vehicle;
  final Bank? bank;
  final double? latestWalletBalance;
  final String currency;
  final DateTime lastUpdated;

  const FastagRecord({
    required this.id,
    this.fastagId,
    this.vehicle,
    this.bank,
    this.latestWalletBalance,
    this.currency = 'INR',
    required this.lastUpdated,
  });

  String get displayName {
    if (vehicle != null && vehicle!.isNotEmpty) return vehicle!;
    if (fastagId != null && fastagId!.isNotEmpty) return 'FASTag $fastagId';
    return 'FASTag';
  }

  FastagRecord copyWith({
    String? id,
    String? fastagId,
    String? vehicle,
    Bank? bank,
    double? latestWalletBalance,
    String? currency,
    DateTime? lastUpdated,
  }) {
    return FastagRecord(
      id: id ?? this.id,
      fastagId: fastagId ?? this.fastagId,
      vehicle: vehicle ?? this.vehicle,
      bank: bank ?? this.bank,
      latestWalletBalance: latestWalletBalance ?? this.latestWalletBalance,
      currency: currency ?? this.currency,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fastag_id': fastagId,
      'vehicle': vehicle,
      'bank': bank?.name,
      'latest_wallet_balance': latestWalletBalance,
      'currency': currency,
      'last_updated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  factory FastagRecord.fromMap(Map<String, dynamic> map) {
    return FastagRecord(
      id: map['id'] as String,
      fastagId: map['fastag_id'] as String?,
      vehicle: map['vehicle'] as String?,
      bank: map['bank'] != null
          ? Bank.values.firstWhere(
              (e) => e.name == map['bank'],
              orElse: () => Bank.unknown,
            )
          : null,
      latestWalletBalance: (map['latest_wallet_balance'] as num?)?.toDouble(),
      currency: (map['currency'] as String?) ?? 'INR',
      lastUpdated:
          DateTime.fromMillisecondsSinceEpoch(map['last_updated'] as int),
    );
  }

  @override
  List<Object?> get props =>
      [id, fastagId, vehicle, bank, latestWalletBalance, currency, lastUpdated];
}
