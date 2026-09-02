# SmartSpend — Privacy Charter & Data Policy

> **Core Promise**: Your financial data is yours alone. SmartSpend does not have servers, accounts, cloud sync, analytics, or trackers.

---

## 1. Zero-Cloud Architecture

Traditional finance apps upload your financial SMS messages, bank statements, and transactions to remote cloud servers to sell ads, train commercial AI models, or sell credit products.

SmartSpend operates on a completely different paradigm:
- **No Remote Servers**: SmartSpend has no backend servers, databases, or API gateways.
- **No Analytics / Telemetry**: Zero Google Analytics, Firebase, Mixpanel, Sentry, or advertising SDKs.
- **No Third-Party Trackers**: No third-party network requests are ever dispatched.
- **No Cloud Sync**: Your data lives exclusively in an encrypted vault on your physical hardware.

---

## 2. Permission Transparency

SmartSpend requests only the minimum permissions required for operation:

### `READ_SMS` & `RECEIVE_SMS` (Android Only)
- **Why It's Needed**: To read historical financial transactions from your inbox and parse incoming real-time notifications.
- **How It's Handled**: Only messages containing financial signatures (e.g. `Rs`, `INR`, `debited`, `credited`, `FASTag`, `bill`) are processed. Non-financial messages are discarded.
- **Network Isolation**: Scraped SMS text is NEVER sent over the internet.

### `USE_BIOMETRIC` / `USE_FINGERPRINT`
- **Why It's Needed**: To allow you to lock the app behind your device's biometric authentication (Fingerprint / Face ID).

---

## 3. Data Portability & Deletion

- **Export Your Data Anytime**: Full data portability via plain/encrypted JSON and spreadsheet-compatible CSV.
- **Full Deletion**: Uninstalling the app permanently deletes the encrypted database and Keystore keys.
