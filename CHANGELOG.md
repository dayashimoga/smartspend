# SmartSpend — Changelog (APPEND-ONLY FOREVER)

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **POLICY**: This file is strictly append-only. Old entries are never modified or removed.

---

## [1.0.0] - 2026-09-02

### Added
- Greenfield initialization of SmartSpend: Production-grade, privacy-first Flutter personal finance application.
- Hermetic Podman container integration (`scripts/run-in-container.ps1`, `scripts/run-in-container.sh`, `Containerfile`) enabling build, analysis, and test verification with zero local tool installation required.
- Permanent golden SMS regression suite (`test/fixtures/golden_sms.json`, `test/unit/parsers/golden_sms_test.dart`) certifying 100% field extraction across all 12 mandatory golden SMS examples from Indian banks.
- Extensible multi-stage deterministic SMS parsing pipeline (`Normalizer`, `InstitutionDetector`, `Validator`, `Reconciler`, and bank rules for HDFC, ICICI, Axis, SBI, HSBC, YES BANK, IDFC FIRST, IndusInd, Ujjivan, SIB, OneCard, and Generic fallback).
- Idempotent fingerprint ingestion engine: SHA-256 hash tuple `(sender|timestamp|body)` with unique constraint preventing duplicate transactions across rescans and app restarts.
- SQLCipher AES-256 encrypted database vault (`DatabaseHelper`) backed by hardware Keystore / Keychain key protection (`KeyManager`).
- Clean Architecture four-layer structure (Domain entities, value objects, abstract repository interfaces, application use cases, concrete SQLite repositories, and Riverpod presentation providers).
- Native Android MethodChannel in `MainActivity.kt` and ContentResolver queries for financial inbox scraping.
- Comprehensive UI presentation layer with Material 3, AMOLED dark mode, and high-contrast light mode:
  - `DashboardScreen`: Net cashflow hero banner, income/spend metrics, bank balances, card spent, sync action, alert banners, recent transactions.
  - `TransactionsScreen`: Full-text search across merchants/categories, type filter chips, detail sheets.
  - `AccountsScreen`: Bank accounts with balances and credit cards with available limits and utilization gauges.
  - `BillsScreen`: Credit card statement tracking with minimum amounts due, due dates, and zero-due handling.
  - `FastagScreen`: NETC FASTag vehicle passes, toll deductions, and wallet balances.
  - `InsightsScreen`: Interactive `fl_chart` bar and pie charts with tap-to-drill-down into category transactions.
  - `ReviewScreen`: Needs Review queue with side-by-side parsed fields, inline dialog editing, non-financial exclusions, duplicate merges, and splits.
  - `SettingsScreen`: Theme switch, currency switcher (INR, USD, EUR, GBP, AED), biometric lock toggle, golden data injector, and JSON/CSV export.
- Full automated test suite:
  - Golden regressions (100% pass)
  - AmountParser unit tests (Rupee prefixes, commas, decimals, formatting)
  - DateParser unit tests (text months, numeric formats, timestamps)
  - Reconciler unit tests (refund pairing, card-payment reclassification, zero bill handling)
  - Idempotent ingestion test (3x repeated rescans with zero duplicates)
  - Parser fuzz testing (1,000 randomized corrupt SMS inputs without crashes)
  - Bulk performance benchmark (5,000 SMS parsed in 190ms / ~26,000 msgs/sec)
  - Root widget mount and navigation smoke test.
- CI/CD pipeline (`.github/workflows/ci.yml`), `Makefile`, and automated report generator (`scripts/generate_reports.dart`) producing HTML and JSON acceptance, parser, security, and performance reports.
- Comprehensive 18-file documentation suite (`README.md`, `REQUIREMENTS.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `SMS_PARSER.md`, `SECURITY.md`, `PRIVACY.md`, `CODE_UNDERSTANDING.md`, `SETUP.md`, `CONFIGURATION.md`, `USER_GUIDE.md`, `TESTING.md`, `TROUBLESHOOTING.md`, `CI_CD.md`, `IMPLEMENTATION.md`, `PRODUCTION_READINESS.md`, `TODO.md`, `CHANGELOG.md`).
