import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SmsDatasource {
  static const MethodChannel _channel = MethodChannel('com.smartspend/sms');

  /// Requests SMS reading permissions from Android OS.
  static Future<bool> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      // iOS / Web / Desktop do not support direct SMS inbox scraping
      return false;
    }
    try {
      final bool granted = await _channel.invokeMethod('requestSmsPermission');
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Checks if SMS permissions are currently granted.
  static Future<bool> hasPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return false;
    }
    try {
      final bool hasPerm = await _channel.invokeMethod('hasSmsPermission');
      return hasPerm;
    } catch (_) {
      return false;
    }
  }

  /// Reads historical financial SMS from the Android device inbox.
  /// Filters for sender addresses with known financial keywords (HDFC, ICICI, SBI, AXIS, etc.)
  /// Supports incremental querying via [sinceTimestamp].
  static Future<List<Map<String, dynamic>>> readInboxSms({
    int limit = 2000,
    int? sinceTimestamp,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return [];
    }
    try {
      final Map<String, dynamic> args = {'limit': limit};
      if (sinceTimestamp != null) {
        args['sinceTimestamp'] = sinceTimestamp;
      }
      final List<dynamic>? result =
          await _channel.invokeMethod('readInboxSms', args);
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream of real-time incoming SMS messages from native SmsReceiver.
  static const EventChannel _eventChannel =
      EventChannel('com.smartspend/sms_stream');

  static Stream<Map<String, dynamic>> get incomingSmsStream {
    if (kIsWeb || !Platform.isAndroid) {
      return const Stream.empty();
    }
    return _eventChannel.receiveBroadcastStream().map(
          (dynamic event) => Map<String, dynamic>.from(event as Map),
        );
  }

  /// Drains background-queued SMS messages that arrived while app process was inactive or rebooted.
  static Future<List<Map<String, dynamic>>> getQueuedSms() async {
    if (kIsWeb || !Platform.isAndroid) {
      return [];
    }
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getQueuedSms');
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
