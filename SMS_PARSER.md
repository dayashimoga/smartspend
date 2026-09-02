# SmartSpend — SMS Parser Pipeline Specification

This document details the multi-stage parsing pipeline, regular expression architecture, bank-specific rule definitions, and extension procedures.

---

## 1. Pipeline Stages

```
[Raw SMS]
   │
   ▼
[Stage 1: Normalizer] ── Clean Unicode non-breaking spaces, standardize ₹ to Rs., collapse whitespace
   │
   ▼
[Stage 2: Institution Detector] ── Map sender header or body keywords to Bank enum
   │
   ▼
[Stage 3: Rule Dispatch] ── Try BankRule in priority order (Bank-specific first, FASTag, Generic fallback)
   │
   ▼
[Stage 4: Field Extractor] ── Amount, dates, identifiers, merchants, balances, dues
   │
   ▼
[Stage 5: Cross-Field Validator] ── Amount ranges, date plausibility, confidence assignment
   │
   ▼
[Stage 6: Reconciler] ── Link refunds, reversals, card payments; adjust zero-due bills
   │
   ▼
[Parsed Transaction] ── Ready for encrypted persistence
```

---

## 2. Mandatory Golden SMS Regressions

The following 12 golden test cases are permanently regression-tested in `test/unit/parsers/golden_sms_test.dart`:

### 1. HSBC Credit Card Statement
- **SMS**: `HSBC Credit Card ending 0741 : Total amount is 955.9 and minimum amount is 100 ; payable by 30-Jan-26.`
- **Parsed**: `{bank: HSBC, card: 0741, total: 955.90, min: 100.0, due: 2026-01-30, type: bill}`

### 2. HDFC Bank Credit Card Statement
- **SMS**: `HDFC Bank Credit Card XX9137 Statement: Total due amt: Rs.11,397.00 Min due amt: Rs.570.00 Due by:04-08-2025.`
- **Parsed**: `{bank: HDFC, card: 9137, total: 11397.00, min: 570.00, due: 2025-08-04, type: bill}`

### 3. ICICI Bank Credit Card Statement
- **SMS**: `ICICI Bank Credit Card XX4000... Total of Rs 3,494.78 or minimum of Rs 180.00 is due by 05-FEB-26.`
- **Parsed**: `{bank: ICICI, card: 4000, total: 3494.78, min: 180.00, due: 2026-02-05, type: bill}`

### 4. ICICI Bank Card Purchase
- **SMS**: `INR 483.40 spent using ICICI Bank Card XX4000 on 18-Jan-26 on AMAZON PAY IN E. Avl Limit: INR 1,96,021.82.`
- **Parsed**: `{bank: ICICI, card: 4000, amount: 483.40, date: 2026-01-18, merchant: "AMAZON PAY IN E", limit: 196021.82, type: purchase}`

### 5. Axis Bank Card Purchase
- **SMS**: `Spent INR 560.2 Axis Bank Card no. XX0449 27-09-25 19:54:30 IST ZOMATO Avl Limit: INR 434142.32`
- **Parsed**: `{bank: Axis, card: 0449, amount: 560.20, date: 2025-09-27 19:54:30, merchant: "ZOMATO", limit: 434142.32, type: purchase}`

### 6. SBI Credit Card Purchase
- **SMS**: `Rs.3,676.00 spent on your SBI Credit Card ending 7036 at FlipkartInternetPvt on 30/11/25.`
- **Parsed**: `{bank: SBI, card: 7036, amount: 3676.00, date: 2025-11-30, merchant: "FlipkartInternetPvt", type: purchase}`

### 7. HDFC Bank Salary Credit
- **SMS**: `Update! INR 93,807.00 deposited in HDFC Bank A/c XX0564 on 27-JUN-25 ... Salary... Avl bal INR 1,76,306.56.`
- **Parsed**: `{bank: HDFC, account: 0564, amount: 93807.00, date: 2025-06-27, balance: 176306.56, type: salary}`

### 8. HDFC Bank Transfer Debit
- **SMS**: `Sent Rs.30000.00 From HDFC Bank A/C *0564 To MUTUAL FUNDS ICCL On 21/01/26 Ref 638798306591`
- **Parsed**: `{bank: HDFC, account: 0564, amount: 30000.00, date: 2026-01-21, payee: "MUTUAL FUNDS ICCL", ref: "638798306591", type: debit}`

### 9. HDFC Bank ATM Withdrawal
- **SMS**: `Withdrawn Rs.3000 From HDFC Bank Card x4617 At INDUSIND BANK LIMITED On 2026-01-04:22:44:25 Bal Rs.40643.25`
- **Parsed**: `{bank: HDFC, card: 4617, amount: 3000.00, date: 2026-01-04 22:44:25, merchant: "INDUSIND BANK LIMITED", balance: 40643.25, type: atm}`

### 10. IDFC FIRST Bank Account Debit
- **SMS**: `Your A/c XX1717 debited by Rs.30,000.00 on 21/01/26... Available balance Rs.5,38,908.98. Team IDFC FIRST Bank`
- **Parsed**: `{bank: IDFC FIRST, account: 1717, amount: 30000.00, date: 2026-01-21, balance: 538908.98, type: debit}`

### 11. NETC FASTag Toll Deduction
- **SMS**: `Toll Paid! Rs.65 for KA05MS4053 At Rajatadripura On 2025-07-22 21:01:40 Wallet Bal: Rs.275`
- **Parsed**: `{vehicle: "KA05MS4053", amount: 65.00, plaza: "Rajatadripura", date: 2025-07-22 21:01:40, balance: 275.00, type: fastag}`

### 12. HDFC Bank NETC FASTag Recharge
- **SMS**: `FASTag Alert Rs.100 added to HDFC Bank NETC FASTag 19000011559872 on 22-07-2025 19:42:12.`
- **Parsed**: `{bank: HDFC, fastag_id: "19000011559872", amount: 100.00, date: 2025-07-22 19:42:12, type: fastag}`

---

## 3. Adding a New Bank Rule

To add support for a new banking institution:
1. Create `lib/data/parsers/bank_rules/<bank_name>_rules.dart` extending `BankRule`.
2. Define target `Bank` enum and override `canHandle` and `parse`.
3. Register the new rule in `ParserPipeline._rules` list in `lib/data/parsers/parser_pipeline.dart`.
4. Add golden test cases to `test/fixtures/golden_sms.json`.
5. Run `flutter test test/unit/parsers/golden_sms_test.dart` to verify.
