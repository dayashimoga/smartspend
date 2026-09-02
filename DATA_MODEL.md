# SmartSpend — Data Model & Schema Specification

This document details the encrypted database schema, table relationships, indexing strategy, and entity mappings.

---

## 1. Database Schema DDL

The database is encrypted using SQLCipher AES-256. Database filename: `smartspend_vault_v1.db`.

### 1.1 `raw_sms` Table (Immutable Raw Archive)
Stores original unmodified SMS messages. Never updated or deleted.

```sql
CREATE TABLE raw_sms (
  id TEXT PRIMARY KEY,
  sender TEXT NOT NULL,
  body TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  fingerprint TEXT NOT NULL UNIQUE,
  ingested_at INTEGER NOT NULL
);

CREATE INDEX idx_raw_sms_fingerprint ON raw_sms(fingerprint);
```

### 1.2 `parsed_transactions` Table
Stores normalized parsed financial transactions linked to original raw SMS.

```sql
CREATE TABLE parsed_transactions (
  id TEXT PRIMARY KEY,
  raw_sms_id TEXT NOT NULL,
  type TEXT NOT NULL,
  bank TEXT NOT NULL,
  account_last4 TEXT,
  card_last4 TEXT,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  transaction_date INTEGER NOT NULL,
  merchant TEXT,
  payee TEXT,
  payer TEXT,
  reference TEXT,
  rrn TEXT,
  upi_ref TEXT,
  balance REAL,
  available_limit REAL,
  outstanding REAL,
  bill_total REAL,
  bill_minimum REAL,
  bill_due_date INTEGER,
  fastag_id TEXT,
  vehicle TEXT,
  toll_plaza TEXT,
  wallet_balance REAL,
  confidence TEXT NOT NULL,
  parser_version TEXT NOT NULL,
  category TEXT NOT NULL,
  tags TEXT,
  is_excluded INTEGER NOT NULL DEFAULT 0,
  is_reconciled INTEGER NOT NULL DEFAULT 0,
  reconciled_with_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (raw_sms_id) REFERENCES raw_sms(id) ON DELETE CASCADE
);

CREATE INDEX idx_transactions_date ON parsed_transactions(transaction_date);
CREATE INDEX idx_transactions_bank ON parsed_transactions(bank);
CREATE INDEX idx_transactions_type ON parsed_transactions(type);
```

### 1.3 `accounts` Table (Bank Accounts)
Aggregated view of bank accounts derived from transaction balances.

```sql
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  bank TEXT NOT NULL,
  last4 TEXT NOT NULL,
  account_type TEXT NOT NULL,
  current_balance REAL NOT NULL,
  currency TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  UNIQUE(bank, last4)
);
```

### 1.4 `cards` Table (Credit Cards)
Tracks credit cards, available credit limits, outstanding balances, and utilization.

```sql
CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  bank TEXT NOT NULL,
  last4 TEXT NOT NULL,
  available_limit REAL,
  total_limit REAL,
  outstanding REAL,
  currency TEXT NOT NULL,
  last_updated INTEGER NOT NULL,
  UNIQUE(bank, last4)
);
```

### 1.5 `bills` Table (Credit Card Statements)
Stores statements, total due amounts, minimum amounts, due dates, and payment status.

```sql
CREATE TABLE bills (
  id TEXT PRIMARY KEY,
  bank TEXT NOT NULL,
  card_last4 TEXT NOT NULL,
  total_amount REAL NOT NULL,
  minimum_amount REAL NOT NULL,
  due_date INTEGER NOT NULL,
  status TEXT NOT NULL,
  currency TEXT NOT NULL,
  payment_transaction_id TEXT,
  created_at INTEGER NOT NULL
);
```

### 1.6 `fastag` Table (FASTag Passes)
Tracks vehicles, toll passes, and wallet balances.

```sql
CREATE TABLE fastag (
  id TEXT PRIMARY KEY,
  fastag_id TEXT,
  vehicle TEXT,
  bank TEXT,
  latest_wallet_balance REAL,
  currency TEXT NOT NULL,
  last_updated INTEGER NOT NULL
);
```

### 1.7 `corrections` Table (Reversible User Audit Trail)
Maintains audit trail of all manual user adjustments in the review queue.

```sql
CREATE TABLE corrections (
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  field_name TEXT NOT NULL,
  original_value TEXT,
  corrected_value TEXT,
  reason TEXT NOT NULL,
  applied_at INTEGER NOT NULL,
  FOREIGN KEY (transaction_id) REFERENCES parsed_transactions(id) ON DELETE CASCADE
);
```

### 1.8 `budgets` Table
Monthly category budgets and progress tracking.

```sql
CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  monthly_limit REAL NOT NULL,
  currency TEXT NOT NULL,
  current_spend REAL NOT NULL,
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  UNIQUE(category, month, year)
);
```

---

## 2. Idempotency Fingerprint Specification

To guarantee zero duplicate records when rescanning the inbox, every incoming SMS generates a deterministic SHA-256 fingerprint:

$$\text{fingerprint} = \text{SHA256}(\text{normalizedSender} \parallel \text{timestampMs} \parallel \text{normalizedBody})$$

Where:
- `normalizedSender` is uppercase and whitespace trimmed
- `timestampMs` is the millisecond timestamp from Android ContentResolver
- `normalizedBody` has collapsed whitespace (`\s+` $\to$ single space).
