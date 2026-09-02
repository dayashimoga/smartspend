import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

class SmsRecord extends Equatable {
  final String id;
  final String sender;
  final String body;
  final DateTime timestamp;
  final String fingerprint;
  final DateTime ingestedAt;

  const SmsRecord({
    required this.id,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.fingerprint,
    required this.ingestedAt,
  });

  /// Deterministic SHA-256 fingerprint generation to ensure idempotent ingestion.
  /// Repeated rescans will generate the exact same fingerprint.
  static String generateFingerprint(
      String sender, String body, DateTime timestamp) {
    final normalizedSender = sender.trim().toUpperCase();
    final normalizedBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final timeStr = timestamp.millisecondsSinceEpoch.toString();
    final rawKey = '$normalizedSender|$timeStr|$normalizedBody';
    return sha256.convert(utf8.encode(rawKey)).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'fingerprint': fingerprint,
      'ingested_at': ingestedAt.millisecondsSinceEpoch,
    };
  }

  factory SmsRecord.fromMap(Map<String, dynamic> map) {
    return SmsRecord(
      id: map['id'] as String,
      sender: map['sender'] as String,
      body: map['body'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      fingerprint: map['fingerprint'] as String,
      ingestedAt:
          DateTime.fromMillisecondsSinceEpoch(map['ingested_at'] as int),
    );
  }

  @override
  List<Object?> get props =>
      [id, sender, body, timestamp, fingerprint, ingestedAt];
}
