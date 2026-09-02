# SmartSpend — Security Architecture & Threat Model

This document specifies the security controls, encryption mechanisms, key lifecycle, and threat mitigations implemented in SmartSpend.

---

## 1. Threat Model

| Threat Scenario | Potential Impact | SmartSpend Countermeasure |
|---|---|---|
| **Stolen / Lost Device** | Physical extraction of SQLite database file | Database is encrypted at rest using SQLCipher AES-256. Without Keystore hardware key access, database file is indistinguishable from random noise. |
| **Malicious Co-Installed Apps** | Accessing shared preferences or app private storage | Android Keystore / iOS Keychain isolates the master encryption key inside secure hardware. Storage isolation prevents other apps from reading database files. |
| **Shoulder Surfing / Casual Physical Access** | Viewing balances and card numbers | Card and account numbers are automatically masked as `•••• 1234`. Optional biometric lock (Fingerprint / Face ID) blocks app entry. |
| **Data Leakage via Logging** | Logcat or terminal dumps exposing raw financial SMS | Zero PII logging policy. SMS bodies and financial account numbers are never logged to console or crash reporting tools. |
| **Backup Tampering** | Malicious alteration of exported financial records | Export files include SHA-256 integrity checksums to detect file tampering during backup / restore workflows. |

---

## 2. Cryptographic Architecture

### 2.1 Storage at Rest
- **Engine**: SQLCipher (SQLite extension providing 256-bit AES encryption of all database pages).
- **Cipher**: AES-256-CBC with PBKDF2 key derivation and HMAC-SHA512 page integrity checking.
- **Key Storage**: 256-bit randomly generated master key stored via `flutter_secure_storage` inside Android Keystore (`KeyStore.getInstance("AndroidKeyStore")`) and iOS Keychain (`kSecAccessControlBiometryAny`).

### 2.2 Ingestion Idempotency Fingerprint
- **Algorithm**: SHA-256 hash of normalized tuple: `sender|timestampMs|normalizedBody`.
- **Enforcement**: Unique constraint on `raw_sms.fingerprint` ensures idempotent database transactions.

---

## 3. Data Masking Standards

- **Credit Card Numbers**: Only the final 4 digits are retained (`card_last4`). The primary account number (PAN) is never stored or reconstructed.
- **Bank Accounts**: Only the final 3-4 digits are retained (`account_last4`). Full bank account numbers are discarded immediately during parsing.
- **Display Representation**: All UI views display identifiers as `•••• [last4]`.
