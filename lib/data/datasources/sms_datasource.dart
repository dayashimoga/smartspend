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
  static Future<List<Map<String, dynamic>>> readInboxSms(
      {int limit = 2000}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return [];
    }
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('readInboxSms', {'limit': limit});
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
