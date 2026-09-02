import 'package:equatable/equatable.dart';

class Correction extends Equatable {
  final String id;
  final String transactionId;
  final String fieldName;
  final String? originalValue;
  final String? correctedValue;
  final String reason;
  final DateTime appliedAt;

  const Correction({
    required this.id,
    required this.transactionId,
    required this.fieldName,
    this.originalValue,
    this.correctedValue,
    this.reason = 'User Manual Correction',
    required this.appliedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'field_name': fieldName,
      'original_value': originalValue,
      'corrected_value': correctedValue,
      'reason': reason,
      'applied_at': appliedAt.millisecondsSinceEpoch,
    };
  }

  factory Correction.fromMap(Map<String, dynamic> map) {
    return Correction(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      fieldName: map['field_name'] as String,
      originalValue: map['original_value'] as String?,
      correctedValue: map['corrected_value'] as String?,
      reason: (map['reason'] as String?) ?? 'User Manual Correction',
      appliedAt: DateTime.fromMillisecondsSinceEpoch(map['applied_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        transactionId,
        fieldName,
        originalValue,
        correctedValue,
        reason,
        appliedAt
      ];
}
