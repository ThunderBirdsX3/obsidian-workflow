---
tags: [type/feature]
status: in-progress
version: 0.3.0
date: 2026-05-20
prd: [[PRD-LibraryBookTracker]]
phase: [[PHASE-1-MVP]]
related_functions:
  - [[FN-Web-Librarian-CheckoutFlow]]
  - [[FN-API-Books-Checkout]]
ui_components_used: [Button, Input, Card, Toast, Modal]
design_tokens_used: [color-primary, color-success, space-3, space-4, radius-md]
---

# FEAT-Checkout — Book Checkout Flow

## 1. Description
ฟีเจอร์ให้ Librarian check-out หนังสือให้สมาชิก — search member → scan/type barcode → confirm → loan created

## 2. User value
- ลด checkout time จาก > 2 min → < 30 sec
- ลด human error (typing member ID ผิด)
- รักษา PDPA compliance — มี audit log

## 3. Scope

**In:**
- Member search by name/phone/member_id
- Barcode entry (scanner หรือ keyboard)
- Loan creation with default 14-day due date
- Override flow ถ้า member เกิน 5 active loans
- Concurrent checkout protection (optimistic lock)

**Out:**
- Reservation (Phase 2)
- ค่าปรับ (Phase 2)
- Bulk checkout (Phase 3)

## 4. Roles affected
- [[Librarian]] — primary user
- Member — sees new loan in portal after (role doc not written yet)

## 5. UX flow
- [[FLOW-Checkout]]

## 6. Functions involved
- [[FN-Web-Librarian-CheckoutFlow]] — UI orchestration
- [[FN-API-Books-Checkout]] — POST /api/loans

## 7. Acceptance criteria
- [x] Member search works (FR-001)
- [ ] Checkout creates loan with correct due_date (FR-002)
- [ ] Override flow shows confirm dialog when > 5 loans
- [ ] Concurrent checkout returns 409 + clear message
- [ ] Audit log entry created (member_id, librarian_id, book_id, timestamp)

## 8. Edge cases
- Book ที่ status: lost — block with clear message
- Member ที่ status: inactive — block + suggest reactivate flow
- Network failure between barcode scan + confirm — keep barcode in state, retry button

## 9. Test scenarios (links)
- [[TP-Checkout]]

## 10. Design System Compliance
- Components used: Button (primary, danger), Input (search, barcode), Card (member info), Toast (success), Modal (override confirm)
- Tokens used: `--color-primary-600` (CTA), `--color-success-500` (toast), `--space-3/4`, `--radius-md`
- New components needed: none

## 11. Implementation plans
- [[2026-05-20-1015-checkout-api]] — status: approved, in-progress

## 12. Risks
- Concurrent race condition → mitigation: optimistic lock via Loan version column

## 13. Status notes
- 2026-05-18: feature started, member search done
- 2026-05-20: API plan created, in-progress
- 2026-05-25: target complete
