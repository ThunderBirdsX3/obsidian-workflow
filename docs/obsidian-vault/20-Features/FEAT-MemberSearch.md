---
tags: [type/feature]
status: done
version: 1.0.0
date: 2026-05-18
prd: [[PRD-LibraryBookTracker]]
phase: [[PHASE-1-MVP]]
completed_at: 2026-05-18
related_functions:
  - [[FN-Web-Librarian-MemberSearch]]
  - [[FN-API-Members-Search]]
ui_components_used: [Input, Card, Badge]
design_tokens_used: [color-primary, color-neutral, space-3, space-4, radius-md]
---

# FEAT-MemberSearch — Member Search

## 1. Description
Librarian พิมพ์ค้นชื่อ/เบอร์/member_id → ได้ list สมาชิก พร้อม current loan count

## 2. User value
- Pull up member account < 2 วินาที
- ตัวกรองในตัว (active / inactive)

## 3. Scope

**In:**
- Free-text search ใน name, phone, member_id
- Debounced (300ms) เพื่อไม่ flood API
- Pagination 20/page

**Out:**
- Advanced filter (age, address)
- Export

## 4. Roles affected
- [[Librarian]]

## 5. UX flow
- ใช้เป็น sub-flow ใน [[FLOW-Checkout]] + FLOW-MemberPortalView (ยังไม่มี doc)

## 6. Functions involved
- [[FN-Web-Librarian-MemberSearch]]
- [[FN-API-Members-Search]]

## 7. Acceptance criteria
- [x] Search returns results in < 500ms (p95)
- [x] 0 results shows clear empty state
- [x] Phone masked (last 4 only)
- [x] Inactive members shown with badge

## 8. Edge cases
- Query < 3 chars → debounce + no search (avoid load)
- Special chars in query → sanitize input

## 9. Test scenarios
- [[TP-MemberSearch]]

## 10. Design System Compliance
- Components used: Input (search), Card (result item), Badge (status)
- Tokens used: `--color-primary-500`, `--color-neutral-400` (inactive), `--space-2/3`
- Violations: 0

## 11. Implementation plans
- [[2026-05-18-0930-member-search]] — status: done

## 12. Risks
- (none — feature complete)

## 13. Status notes
- 2026-05-18: complete, deployed to staging
- Handoff: [[HOR-2026-05-18-member-search]]
