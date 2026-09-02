# SmartSpend — Configuration Guide

This document describes all user preferences, environment parameters, and runtime configurations.

---

## 1. Application Preferences

Preferences are managed by Riverpod providers in `lib/presentation/providers/app_providers.dart`:

| Parameter | Default | Options | Location in UI | Description |
|---|---|---|---|---|
| `themeModeProvider` | `ThemeMode.dark` | `ThemeMode.dark`, `ThemeMode.light` | Settings Screen | Toggles between AMOLED dark mode and high-contrast light mode. |
| `defaultCurrencyProvider` | `'INR'` | `'INR'`, `'USD'`, `'EUR'`, `'GBP'`, `'AED'` | Settings Screen | Default currency symbol and formatting standard (Indian vs international commas). |
| `isBiometricLockEnabled` | `false` | `true`, `false` | Settings Screen | Protects app launch with Fingerprint / Face ID via `local_auth`. |

---

## 2. Ingestion Engine Configuration

Parameters can be tuned in `lib/data/datasources/sms_datasource.dart`:

| Constant | Value | Description |
|---|---|---|
| `defaultLimit` | `2000` | Maximum messages scraped in single historical synchronization pass. |
| `financialKeywords` | `Rs, INR, debited, credited, spent` | ContentResolver query filters to avoid processing non-financial personal SMS. |

---

## 3. Database & Encryption Settings

Managed in `lib/core/database/database_helper.dart`:

| Setting | Value | Description |
|---|---|---|
| `_dbName` | `smartspend_vault_v1.db` | Local encrypted database filename. |
| `_dbVersion` | `1` | Schema version for automated SQL migrations. |
| `PRAGMA key` | 256-bit AES | Hardware-backed key derived via `KeyManager`. |
| `PRAGMA foreign_keys` | `ON` | Enforces relational integrity across tables. |
