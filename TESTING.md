# SmartSpend — Testing Strategy & Quality Gates

SmartSpend enforces automated verification at every layer of the architecture.

---

## 1. Test Suite Architecture

```
test/
├── fixtures/
│   └── golden_sms.json                 # 12 mandatory golden SMS + edge cases
├── unit/
│   ├── parsers/
│   │   ├── golden_sms_test.dart        # 100% regression test across all golden fixtures
│   │   ├── amount_parser_test.dart     # Currency parsing, commas, symbols, negative amounts
│   │   ├── date_parser_test.dart       # Text months, numeric formats, timestamps
│   │   └── reconciler_test.dart        # Refund pairing, double-count prevention, zero bills
│   └── application/
│       └── idempotent_ingestion_test.dart # 3x rescanning proving 0 duplicate records
├── fuzz/
│   └── parser_fuzz_test.dart           # 1,000 malformed/corrupt inputs without crash
├── performance/
│   └── bulk_ingestion_test.dart        # 5,000 SMS bulk throughput benchmark
└── widget_test.dart                    # SmartSpendApp root mounting and navigation smoke test
```

---

## 2. Executable Quality Gates Summary

| Suite | File | Tests Run | Result | Metrics |
|---|---|---|---|---|
| **Golden Regressions** | `test/unit/parsers/golden_sms_test.dart` | 12+ fixtures | ✅ PASS | 100% field accuracy |
| **Amount Parser** | `test/unit/parsers/amount_parser_test.dart` | 3 groups | ✅ PASS | All symbols & Indian commas |
| **Date Parser** | `test/unit/parsers/date_parser_test.dart` | 4 groups | ✅ PASS | Text months & timestamps |
| **Reconciler** | `test/unit/parsers/reconciler_test.dart` | 3 groups | ✅ PASS | Refunds & repayments paired |
| **Idempotency** | `test/unit/application/idempotent_ingestion_test.dart` | 1 group (3 passes) | ✅ PASS | Exactly 0 duplicates |
| **Parser Fuzzing** | `test/fuzz/parser_fuzz_test.dart` | 1,000 iterations | ✅ PASS | 0 uncaught exceptions |
| **Bulk Performance** | `test/performance/bulk_ingestion_test.dart` | 5,000 messages | ✅ PASS | 190ms (~26k msgs/sec) |
| **Widget Mount** | `test/widget_test.dart` | 1 smoke test | ✅ PASS | Navigation bar & tabs mounted |

---

## 3. Running Tests via Podman

```powershell
# Run entire test suite
.\scripts\run-in-container.ps1 flutter test

# Run with coverage report generation
.\scripts\run-in-container.ps1 flutter test --coverage

# Run golden tests only
.\scripts\run-in-container.ps1 flutter test test/unit/parsers/golden_sms_test.dart

# Run fuzz testing
.\scripts\run-in-container.ps1 flutter test test/fuzz/parser_fuzz_test.dart
```
