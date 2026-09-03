import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Cryptographic utilities for authenticated backups and secure key derivation.
class CryptoUtils {
  /// Generates cryptographically secure random bytes.
  static Uint8List generateRandomBytes(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }

  /// Derives a key from a passphrase and salt using PBKDF2 with HMAC-SHA256.
  static Uint8List pbkdf2HmacSha256({
    required String passphrase,
    required List<int> salt,
    int iterations = 10000,
    int keyLength = 32,
  }) {
    final passwordBytes = utf8.encode(passphrase);
    final hmac = Hmac(sha256, passwordBytes);
    final numBlocks = (keyLength + 31) ~/ 32;
    final derivedKey = BytesBuilder(copy: false);

    for (int block = 1; block <= numBlocks; block++) {
      // U1 = HMAC(passphrase, salt || INT_32_BE(block))
      final blockBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, block, Endian.big);
      final initialData = [...salt, ...blockBytes];
      var u = hmac.convert(initialData).bytes;
      var xorSum = List<int>.from(u);

      for (int i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < xorSum.length; j++) {
          xorSum[j] ^= u[j];
        }
      }

      derivedKey.add(xorSum);
    }

    return Uint8List.fromList(derivedKey.takeBytes().sublist(0, keyLength));
  }

  /// Computes HMAC-SHA256 authentication tag over data.
  static String computeHmacHex(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).toString();
  }

  /// Constant-time comparison of two hex strings to prevent timing attacks.
  static bool constantTimeHexEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
