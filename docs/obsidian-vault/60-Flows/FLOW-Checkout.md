---
tags: [type/flow]
status: approved
date: 2026-05-20
related_features: [[FEAT-Checkout]]
related_functions: [[FN-Web-Librarian-CheckoutFlow]] [[FN-API-Books-Checkout]]
---

# Flow — Book Checkout

## 1. Purpose
Librarian ยืมหนังสือให้สมาชิก

## 2. Actors
- Primary: Librarian
- Affected: Member (เห็น loan ใหม่ใน portal หลังจาก)

## 3. Pre-conditions
- Librarian authenticated
- Member active + < 5 loans (else override)
- Book status: available

## 4. Steps

```mermaid
flowchart TD
  S[เริ่มที่หน้า /checkout] --> Search[ค้นสมาชิก]
  Search --> Select[เลือกสมาชิก]
  Select --> CheckLoans{Loans >= 5?}
  CheckLoans -->|yes| ModalOverride[Modal: ยืนยัน override]
  ModalOverride -->|cancel| End1[จบ]
  ModalOverride -->|confirm| ScanBook
  CheckLoans -->|no| ScanBook[Scan/พิมพ์ barcode]
  ScanBook --> ApiCall[POST /api/loans]
  ApiCall -->|201| Toast1[Toast: ยืมเรียบร้อย]
  ApiCall -->|409| Toast2[Toast: ถูกยืมอยู่]
  ApiCall -->|422| Toast3[Toast: เงื่อนไขไม่ผ่าน]
  Toast1 --> ScanBook
  Toast2 --> ScanBook
  Toast3 --> ScanBook
```

## 5. Post-conditions / Success
- Loan record created
- Book.status = on_loan
- Member.active_loans_count + 1
- Audit log written

## 6. Error paths
- Book lost → cannot checkout, suggest report
- Member inactive → cannot checkout, suggest reactivate flow
- Concurrent checkout → 409, librarian retry with another book

## 7. Variations
- Override flow (member > 5 loans): require explicit confirm
