# SmartSpend — Code Understanding & Architecture Tour

This guide helps engineers navigate the SmartSpend codebase and understand key abstractions.

---

## 1. Directory Blueprint

```
lib/
├── main.dart                             # App startup, ProviderScope initialization
├── app.dart                              # MaterialApp.router, theme configuration
├── core/
│   ├── constants/regex_patterns.dart     # Comprehensive regex patterns for parsing
│   ├── crypto/key_manager.dart           # Keystore/Keychain encryption key manager
│   ├── database/database_helper.dart     # SQLCipher encrypted SQLite initialization & schema
│   ├── theme/app_theme.dart              # Dark AMOLED & Light themes, AppColors tokens
│   └── utils/
│       ├── amount_parser.dart            # Indian and international currency parsing
│       └── date_parser.dart              # Text month and numeric date parsing
├── domain/
│   ├── entities/                         # Immutable domain models (Equatable)
│   │   ├── account.dart                  # Bank accounts with balances
│   │   ├── bill.dart                     # Credit card bills, dues, statuses
│   │   ├── budget.dart                   # Monthly category limits
│   │   ├── correction.dart               # User edit audit trail
│   │   ├── credit_card.dart              # Credit cards, limits, utilization
│   │   ├── fastag_record.dart            # Vehicle tolls and wallet balances
│   │   ├── financial_summary.dart        # Aggregated net cashflow & metrics
│   │   ├── parsed_transaction.dart       # Core normalized transaction record
│   │   └── sms_record.dart               # Raw immutable SMS with SHA-256 fingerprint
│   ├── enums/                            # Bank, TransactionType, Confidence, BillStatus
│   └── repositories/interfaces.dart      # Clean architecture repository interfaces
├── application/
│   ├── export/export_backup_usecase.dart # JSON & CSV data export
│   ├── review/correction_usecase.dart    # Reversible edits, splits, merges
│   └── sms/ingest_sms_usecase.dart       # Idempotent batch SMS ingestion orchestrator
├── data/
│   ├── datasources/sms_datasource.dart   # Android MethodChannel ContentResolver queries
│   ├── parsers/
│   │   ├── normalizer.dart               # Text cleaning & unicode standardization
│   │   ├── institution_detector.dart     # Sender header & body institution classification
│   │   ├── validator.dart                # Sanity checking on extracted fields
│   │   ├── reconciler.dart               # Duplicate/refund/reversal & card-payment pairing
│   │   ├── parser_pipeline.dart          # Multi-stage parsing pipeline orchestrator
│   │   └── bank_rules/                   # Extensible bank-specific rule sets
│   │       ├── bank_rule.dart            # Abstract BankRule base class
│   │       ├── hdfc_rules.dart           # HDFC bills, salary, ATM, transfers, FASTag
│   │       ├── icici_rules.dart          # ICICI card spends, bills, limits
│   │       ├── axis_rules.dart           # Axis card spends, merchants, limits
│   │       ├── sbi_rules.dart            # SBI credit card purchases
│   │       ├── hsbc_rules.dart           # HSBC credit card statements
│   │       ├── idfc_first_rules.dart     # IDFC FIRST account debits & balances
│   │       ├── yes_bank_rules.dart       # YES BANK UPI transactions & refs
│   │       ├── indusind_rules.dart       # IndusInd card spends & limits
│   │       ├── ujjivan_rules.dart        # Ujjivan SFB interest credits
│   │       ├── onecard_rules.dart        # OneCard co-branded purchases
│   │       ├── fastag_rules.dart         # NETC FASTag toll deductions
│   │       └── generic_rules.dart        # Contextual fallback for unknown banks
│   └── repositories/                     # Concrete SQLite repository implementations
└── presentation/
    ├── router.dart                       # GoRouter navigation paths with ShellRoute
    ├── providers/app_providers.dart      # Riverpod state providers
    ├── widgets/
    │   ├── summary_cards.dart            # Net cashflow banner, income/spend metrics
    │   └── transaction_tile.dart         # Card tile with category icon & amounts
    └── screens/
        ├── dashboard/dashboard_screen.dart
        ├── transactions/transactions_screen.dart
        ├── accounts/accounts_screen.dart
        ├── bills/bills_screen.dart
        ├── fastag/fastag_screen.dart
        ├── insights/insights_screen.dart
        ├── review/review_screen.dart
        ├── settings/settings_screen.dart
        └── home_shell.dart
```

---

## 2. Key Workflows

### 2.1 SMS Ingestion Flow
1. User taps **Sync SMS** on Dashboard or the Android Background Receiver triggers.
2. `SmsDatasource.readInboxSms()` queries the Android `ContentResolver` for financial messages.
3. `IngestSmsUseCase.execute()` computes SHA-256 fingerprint for each message.
4. If fingerprint exists in `raw_sms` table, message is skipped.
5. If new, message is parsed by `ParserPipeline.parseSms()`.
6. `Reconciler` links related transactions (refunds, repayments).
7. `ParsedTransaction` is inserted and derived `Account`, `CreditCard`, `Bill`, and `FastagRecord` entities are updated.
