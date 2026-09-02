import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  static const _storage = FlutterSecureStorage();
  static const _dbKeyName = 'smartspend_db_encryption_key_v1';
  static const _biometricEnabledKey = 'smartspend_biometric_lock_enabled';

  /// Retrieves or creates a secure 256-bit encryption key stored in Keystore/Keychain.
  static Future<String> getOrCreateDatabaseKey() async {
    try {
      final existingKey = await _storage.read(key: _dbKeyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }
    } catch (_) {
      // In test/unsupported environments, fallback gracefully
    }

    // Generate fresh cryptographically random 256-bit key
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final newKey = sha256.convert(values).toString();

    try {
      await _storage.write(key: _dbKeyName, value: newKey);
    } catch (_) {
      // Fallback
    }
    return newKey;
  }

  static Future<bool> isBiometricLockEnabled() async {
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBiometricLockEnabled(bool enabled) async {
    try {
      await _storage.write(
          key: _biometricEnabledKey, value: enabled ? 'true' : 'false');
    } catch (_) {}
  }
}
