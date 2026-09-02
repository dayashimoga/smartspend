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

## [1.1.0] - 2026-09-02

### Forensic Production-Certification Pass

#### Added
- Forensic test suites certifying production readiness:
  - `test/unit/application/correction_usecase_test.dart`: Field edits, exclusions, duplicate merges, splits, and audit trail.
  - `test/unit/application/export_import_test.dart`: SHA-256 integrity verification, database restore, and malicious input sanitization.
  - `test/integration/reconciliation_e2e_test.dart`: End-to-end guarantee of zero double-counted expenses during SMS ingestion.
  - `test/integration/full_lifecycle_test.dart`: Fresh-install -> ingestion -> manual correction -> process kill / restart -> rescan non-destructive verification.
  - `test/unit/database/migration_test.dart`: SQLite indexing and `ON DELETE CASCADE` foreign key cascading integrity.
  - `test/unit/database/corrupt_db_test.dart`: Corrupt database resilience throwing `DatabaseException` without application crash.
  - `test/unit/security/pii_leakage_test.dart`: Strict data masking (only last 4 digits revealed) and zero PAN leakage in JSON/CSV exports.
  - `test/performance/stress_50k_test.dart`: High-scale benchmark testing 50,000 records (<10ms pagination, <20ms search, <200ms aggregation).
  - `test/unit/domain/entities_test.dart`: Entity serialization, `copyWith`, and enum coverage for Clean Architecture models.
  - `test/unit/repositories/repositories_test.dart`: Complete repository CRUD testing.
- Automated security audit and SBOM generator (`scripts/security_audit.dart`): Scans codebase for secret keys and creates CycloneDX `reports/sbom.json`.
- Automated test coverage calculator (`scripts/calculate_coverage.dart`) and architectural layer breakdown (`scripts/coverage_by_layer.dart`).

#### Changed
- `lib/core/database/database_helper.dart`: Replaced static state with instance-isolated database references to prevent test race conditions; escaped PRAGMA encryption keys; enabled foreign keys on database open.
- `lib/application/sms/ingest_sms_usecase.dart`: Integrated real-time reconciliation into ingestion flow, reclassifying bank card debits and pairing refunds on arrival.
- `lib/data/parsers/reconciler.dart`: Added `reconcileSingle` and `ReconciliationMatch` for incremental reconciliation.
- `lib/application/export/export_backup_usecase.dart`: Added `importFromJson` with SHA-256 checksum verification and sanitization against malicious payloads.
- `lib/data/parsers/parser_pipeline.dart`: Added early detection and classification for OTPs and spam loan offers.
- `android/app/src/main/kotlin/com/smartspend/smartspend/MainActivity.kt`: Added asynchronous `onRequestPermissionsResult` callback handler and `WindowManager.LayoutParams.FLAG_SECURE` to block recents screenshot data leaks.
- `android/app/src/main/AndroidManifest.xml`: Disabled ADB backups (`android:allowBackup="false"`, `android:fullBackupContent="false"`).
- `lib/core/theme/app_theme.dart` and presentation screens: Modernized deprecated `.withOpacity(...)` calls to `.withValues(alpha: ...)`.
- `.github/workflows/ci.yml`: Updated with all 11 forensic quality gates, security scans, coverage validation, and release AAB build with R8 shrinking enabled.
- `test/fixtures/golden_sms.json`: Expanded with OTP, promotional, and whitespace edge case fixtures (19 fixtures total).
- `test/unit/parsers/golden_sms_test.dart`: Refactored to execute 19 granular tests with exact field match assertions (100% pass).

