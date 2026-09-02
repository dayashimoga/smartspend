# SmartSpend — CI/CD Pipeline Architecture

SmartSpend uses an automated GitHub Actions pipeline to enforce quality gates, run tests, and produce reproducible Android binaries.

---

## 1. Workflow Pipeline Map

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Actions Trigger                 │
│         (Push to main/develop, PRs, Workflow Dispatch)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Job 1: Quality & Test Gates                │
│  1. Format Check: dart format --set-exit-if-changed .       │
│  2. Static Analysis: flutter analyze --fatal-infos          │
│  3. Golden SMS Regressions: 100% Pass Enforced              │
│  4. Parser Fuzzing: 1,000 corrupt inputs without crash       │
│  5. Bulk Performance: 5,000 SMS parsed in < 5 seconds       │
│  6. Coverage Gate: flutter test --coverage                  │
│  7. Security Audit: dart pub audit                          │
│  8. Generate HTML & JSON Reports: acceptance, parser, perf  │
│  9. Upload Reports as Workflow Artifacts                    │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Needs: Quality Gates PASS)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Job 2: Build Android Binaries              │
│  1. Build Android Debug APK (flutter build apk --debug)     │
│  2. Build Android Release AAB (flutter build appbundle)     │
│  3. Upload APK and AAB Binaries as Workflow Artifacts       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. One-Command Local Reproduction

Using `Makefile` or container helper scripts, any developer or CI runner can execute the full suite:

```bash
make validate
```

Or via PowerShell:
```powershell
.\scripts\run-in-container.ps1 flutter test --coverage
.\scripts\run-in-container.ps1 dart run scripts/generate_reports.dart
```
