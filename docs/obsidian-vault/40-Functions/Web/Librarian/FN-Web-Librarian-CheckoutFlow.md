---
tags: [type/function]
area: web
role: Librarian
status: in-progress
version: 0.3.0
date: 2026-05-20
feature: [[FEAT-Checkout]]
ui_components_used: [Button, Input, Card, Toast, Modal, Badge]
design_tokens_used: [color-primary, color-danger, color-success, color-warning, space-3, space-4, space-6, radius-md, shadow-md]
---

# FN-Web-Librarian-CheckoutFlow

## 1. Purpose
ยืมหนังสือให้สมาชิก — single-page flow ที่รวม member search + book entry + confirm

## 2. Trigger / Entry point
- Route: `/checkout`
- Menu: "ยืม-คืน > ยืมหนังสือ"

## 3. Inputs
| Input | Type | Source | Required |
|---|---|---|---|
| member_query | string | text input | yes |
| book_barcode | string | scanner/text | yes |
| override_max | boolean | confirm dialog | only if 5+ loans |

## 4. Behavior / Flow
1. Member search section: ใช้ [[FN-Web-Librarian-MemberSearch]] inline
2. Member selected → แสดง member card + current loans count
3. Barcode input area appears (focus auto)
4. Scan/type barcode → call `POST /api/loans`
5. Success → Toast + clear barcode (ready for next book)
6. Failure (over limit) → Modal "เกินจำนวนสูงสุด — ยืนยันต่อ?" → confirm → retry with `override=true`

## 5. Outputs / Result
- Success: Toast "ยืมเรียบร้อย — กำหนดคืน YYYY-MM-DD" + barcode cleared
- Over-limit: Modal confirm → override possible
- Book already on loan: Toast (danger) "หนังสือนี้ถูกยืมอยู่โดย XXX"
- Lost book: Toast (danger) "หนังสือสถานะ: หาย — ไม่สามารถยืมได้"

## 6. Side effects
- Database: Loan row created, Book.status → on_loan
- Audit log: entry with member_id, librarian_id, book_id, timestamp, override flag

## 7. Auth / RBAC
- Role: Librarian
- Permissions: `members:read`, `books:read`, `loans:write`

## 8. UI elements
- Top section: Member search (Input + result Cards)
- Middle section (after member selected): Member Card with name + loan count Badge
- Bottom section: Barcode Input (large font, auto-focus, monospace)
- Status area: Toast for success/error
- Override flow: Modal with title "เกินจำนวนสูงสุด", Button (primary) "ยืนยันยืม", Button (ghost) "ยกเลิก"

## 9. Design System Compliance
- Components: `Input`, `Card`, `Button`, `Toast`, `Modal`, `Badge`
- Tokens:
  - `--color-primary-600` (primary CTA)
  - `--color-danger-500` (error toast)
  - `--color-success-500` (success toast)
  - `--color-warning-500` (override modal accent)
  - `--space-3`, `--space-4`, `--space-6`
  - `--radius-md` (Cards, Inputs)
  - `--shadow-md` (Modal)
- Accessibility:
  - Barcode input: `aria-label="บาร์โค้ดหนังสือ"`, autofocus after member selected
  - Modal: focus trap, `aria-labelledby`, Escape closes
  - Toast: `role="status"` for success, `role="alert"` for error
  - Keyboard: Enter in barcode → submit; Tab → ปุ่ม "ยืนยัน"

## 10. Validation rules
- member_id: must exist + status: active
- book_barcode: must exist + status: available (unless override)
- member.active_loans < 5 (else require override)

## 11. Edge cases
- Concurrent checkout (2 librarians, same book) → 409 → Toast "หนังสือถูกยืมไปแล้ว"
- Network failure mid-flow → barcode kept in state, retry button
- Member becomes inactive during flow → re-check on submit + alert

## 12. Test scenarios
- [[TP-Checkout]]

## 13. Implementation
- Plan: [[2026-05-20-1015-checkout-api]] (status: in-progress)
- Files (planned):
  - `web/src/features/checkout/CheckoutFlow.tsx`
  - `web/src/features/checkout/CheckoutFlow.test.tsx`
  - `web/src/api/loans.ts`
  - `api/Controllers/LoansController.cs`
  - `api/Services/LoanService.cs`
  - `api/Tests/LoanServiceTests.cs`
