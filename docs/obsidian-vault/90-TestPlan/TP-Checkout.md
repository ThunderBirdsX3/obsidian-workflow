---
tags: [type/test-plan]
status: active
date: 2026-05-20
feature: [[FEAT-Checkout]]
target: cross
---

# Test Plan — Checkout Flow

## 1. Scope
Full checkout — Librarian flow from menu → search member → scan book → confirm

## 2. Roles to test
- Librarian (full)
- Member (must NOT be able to checkout — read-only on own portal)

## 3. Scenarios

### TC-001 — Happy path checkout
- Pre: Member active, has 2 active loans; Book status: available
- Steps:
  1. Open /checkout (via menu)
  2. Search member, select
  3. Scan barcode "B-12345"
  4. Confirm
- Expected: Loan created, Toast "ยืมเรียบร้อย — กำหนดคืน [date]"
- Route: VISIBLE_MENU
- Status: NOT_RUN (waiting for implementation)

### TC-002 — Book already on loan
- Pre: Book is currently loaned to Member A
- Steps:
  1. Try to checkout to Member B
- Expected: Toast (danger) "หนังสือนี้ถูกยืมอยู่โดย คุณ <A>"
- Status: NOT_RUN

### TC-003 — Member over limit
- Pre: Member has 5 active loans
- Steps:
  1. Try checkout 6th book
- Expected: Modal "เกินจำนวนสูงสุด (5 เล่ม) — ยืนยันยืมเพิ่มไหม?"
  2. Confirm
- Expected: Loan created
- Status: NOT_RUN

### TC-004 — Concurrent checkout (race)
- Pre: Same book, 2 librarians attempt simultaneously
- Steps:
  1. Both submit POST /api/loans within 100ms
- Expected: 1 succeeds (201), 1 receives 409
- Route: DIRECT_URL_TECHNICAL (load test)
- Status: NOT_RUN

### TC-005 — Lost book block
- Pre: Book status: lost
- Steps:
  1. Try checkout
- Expected: Toast (danger) "หนังสือสถานะ: หาย — ไม่สามารถยืมได้"
- Status: NOT_RUN

### TC-006 — Inactive member block
- Pre: Member status: inactive
- Steps:
  1. Try select member
- Expected: Cannot select; tooltip "สมาชิกระงับการใช้งาน"
- Status: NOT_RUN

### TC-007 — Audit log entry created
- After TC-001 success
- Steps:
  1. Query audit_log table
- Expected: 1 entry with action=loan:create, member_id, librarian_id, book_id, timestamp
- Route: DIRECT_URL_TECHNICAL (DB inspection)
- Status: NOT_RUN

## 4. Recording requirements
- Expected vs actual ต่อ UI scenario
- Network summary ที่ quote จริง (PII masked)
- DB audit log query result (member_id masked)

## 5. Done definition
- [ ] All scenarios PASS or BLOCKED with justification
- [ ] ทุก scenario บันทึกผลจาก run จริง
- [ ] PII masked
- [ ] safe_to_share: true overall
