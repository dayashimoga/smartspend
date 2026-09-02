# SmartSpend — Troubleshooting & Diagnostics Guide

This document covers common diagnostic scenarios, platform nuances, and resolution steps.

---

## 1. Android SMS Permissions

### Issue: "SMS Permission Not Granted" error on sync
- **Cause**: Android 10+ requires explicit user consent for `READ_SMS`. Some OEM skins (MIUI, ColorOS, OxygenOS, FuntouchOS) have secondary "Auto-start" or "SMS privacy" guards.
- **Resolution**:
  1. Open your Android device **Settings** > **Apps** > **SmartSpend**.
  2. Tap **Permissions** > **SMS**.
  3. Ensure permission is set to **"Allow"**.
  4. If using Xiaomi/MIUI, also enable **"Service SMS"** in Privacy Protection.

---

## 2. iOS SMS Ingestion Policy & Honest Limitations

### Notice: `UNVERIFIED/HARDWARE_REQUIRED` for iOS SMS
- **Apple iOS Policy**: Apple iOS provides **zero** programmatic API access for apps to read the user's SMS inbox. Any app claiming automatic SMS scraping on standard iOS devices is either running in a jailbroken environment or misleading users.
- **SmartSpend iOS Pathway**:
  - The core architecture, domain models, encrypted database, charts, and review queues are 100% cross-platform iOS-ready.
  - On iOS devices, financial data is ingested via:
    1. **Direct CSV / JSON Import** (exported from your bank net-banking portal).
    2. **Manual Transaction Entry**.
  - SmartSpend will **never** fake unsupported iOS hardware ingestion or claim impossible capabilities.

---

## 3. Podman / Container Workflows

### Issue: "Cannot connect to Podman socket" or SSH EOF on Windows
- **Resolution**: The background Podman machine in WSL might be stopped. Run:
  ```powershell
  podman machine stop
  podman machine start
  ```
  Or invoke the commands via `wsl -d podman-machine-default -u root podman ...` as implemented in `scripts/run-in-container.ps1`.

### Issue: Pub cache permission denied inside container
- **Resolution**: Run `podman volume inspect flutter-pub-cache` to verify volume integrity.

---

## 4. Database Vault Recovery

### Issue: Want to reset the encrypted vault for fresh testing
- **Resolution**:
  1. Navigate to **Settings**.
  2. Tap **Export Data to JSON** to save a backup if needed.
  3. Clear app storage via Android Settings > Apps > SmartSpend > Clear Data, or invoke `DatabaseHelper.resetDatabaseForTesting()`.
