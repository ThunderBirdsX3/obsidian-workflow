---
tags: [type/test-plan]
status: archived
date: 2026-05-18
feature: [[FEAT-MemberSearch]]
target: cross
---

# Test Plan — Member Search

## 1. Scope
Member search across API + Web UI

## 2. Roles to test
- Librarian (full access)
- Member (should NOT access — auth check)

## 3. Scenarios

### TC-001 — Search returns matching members
- Pre: Logged in as Librarian, 5 members in DB
- Steps:
  1. Open /members/search
  2. Type "สมชาย"
  3. Wait debounce 300ms
- Expected: List shows 1 result "สมชาย ใจดี" with masked phone
- Route: VISIBLE_MENU
- Status: **PASS**

### TC-002 — Empty results state
- Pre: Logged in as Librarian
- Steps:
  1. Search "zzzzzz"
- Expected: "ไม่พบสมาชิก" + button "เพิ่มสมาชิกใหม่"
- Route: VISIBLE_MENU
- Status: **PASS**

### TC-003 — Query too short (< 3 chars)
- Steps:
  1. Type "ab"
- Expected: No API call, hint shown
- Status: **PASS**

### TC-004 — Phone masking
- Steps:
  1. Search any active member
- Expected: phone shown as `08xxxxxxxx42` (last 4 digit only)
- Status: **PASS**

### TC-005 — Auth required
- Pre: Logged out
- Steps:
  1. Direct call `GET /api/members?q=test`
- Expected: 401 Unauthorized
- Route: DIRECT_URL_TECHNICAL (auth check)
- Status: **PASS**

## 4. Recording requirements
- Expected vs actual ต่อ step ของ UI scenarios
- API response ที่ quote จริง (PII masked)

## 5. Done definition
- [x] All 5 scenarios PASS
- [x] ทุก scenario บันทึก expected/actual จาก run จริง
- [x] No PII leaks
- [x] safe_to_share: true
