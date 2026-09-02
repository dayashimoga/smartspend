# SmartSpend — Developer Setup & Container Workflows

This guide explains how to build, test, and run SmartSpend hermetically using **Podman** container technology with **zero local tooling required**.

---

## 1. Prerequisites

- **Podman** 4.x / 5.x installed on your workstation.
- That's it! Flutter, Dart, Java, and Android SDKs are all encapsulated within the hermetic build container.

---

## 2. Podman Containerized Commands

We provide native helper scripts that run every command inside the container:

### PowerShell (Windows)
```powershell
# Run all unit, widget, and property tests with coverage
.\scripts\run-in-container.ps1 flutter test --coverage

# Run golden SMS regressions
.\scripts\run-in-container.ps1 flutter test test/unit/parsers/golden_sms_test.dart

# Run static analysis
.\scripts\run-in-container.ps1 flutter analyze

# Format code
.\scripts\run-in-container.ps1 dart format .

# Generate verification reports
.\scripts\run-in-container.ps1 dart run scripts/generate_reports.dart
```

### Bash (Linux / macOS / WSL)
```bash
# Run tests
./scripts/run-in-container.sh flutter test --coverage

# Run golden tests
./scripts/run-in-container.sh flutter test test/unit/parsers/golden_sms_test.dart
```

---

## 3. Building Android Artifacts

```powershell
# Build Debug APK
.\scripts\run-in-container.ps1 flutter build apk --debug

# Build Release App Bundle (AAB) for Play Store
.\scripts\run-in-container.ps1 flutter build appbundle --release --no-shrink
```

Output binaries will be generated in:
- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/bundle/release/app-release.aab`
