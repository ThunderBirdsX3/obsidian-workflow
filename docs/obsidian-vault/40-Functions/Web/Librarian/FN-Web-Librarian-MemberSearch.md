---
tags: [type/function]
area: web
role: Librarian
status: implemented
version: 1.0.0
date: 2026-05-18
feature: [[FEAT-MemberSearch]]
ui_components_used: [Input, Card, Badge]
design_tokens_used: [color-primary, color-neutral-400, color-success-500, space-3, space-4, radius-md, text-body-md]
---

# FN-Web-Librarian-MemberSearch

## 1. Purpose
ค้นหาสมาชิก ก่อนทำ action อื่น (ยืม / คืน / แก้ข้อมูล)

## 2. Trigger / Entry point
- Route: `/members/search`
- Menu: "สมาชิก > ค้นหา"
- Inline component: ใช้ใน checkout flow ด้วย

## 3. Inputs
| Input | Type | Source | Required |
|---|---|---|---|
| query | string | text input | yes (min 3 chars) |
| status_filter | enum | dropdown | no (default: all) |

## 4. Behavior / Flow
1. User พิมพ์ใน search input
2. Debounce 300ms
3. ถ้า query >= 3 chars → call `GET /api/members?q=<query>`
4. แสดง results เป็น list of Card
5. แต่ละ Card click → ไป member detail

## 5. Outputs / Result
- Success: list of MemberCardSummary (max 20)
- Empty: "ไม่พบสมาชิก" + ปุ่ม "เพิ่มสมาชิกใหม่"
- Error: Toast + retry

## 6. Side effects
- (none — read-only)

## 7. Auth / RBAC
- Role required: Librarian
- API requires: `members:read` permission

## 8. UI elements
- Container: page Card (`--radius-md`, `--space-4` padding)
- Search input: `Input` component (variant: search)
- Result list: stacked `Card` components
- Status badge: `Badge` (success for active, neutral for inactive)
- Empty state: text + `Button` (primary) "เพิ่มสมาชิกใหม่"
- States: idle / loading (skeleton) / success / empty / error

## 9. Design System Compliance
- Components: `Input`, `Card`, `Badge`, `Button` (all from DS)
- Tokens: `--color-primary-600`, `--color-neutral-400`, `--color-success-500`, `--space-3`, `--space-4`, `--radius-md`, `--text-body-md`
- Accessibility:
  - Search input: `aria-label="ค้นหาสมาชิก"`
  - Result list: `role="list"`, each item `role="listitem"`
  - Focus visible: 2px primary-500 ring
  - Keyboard: Tab through results, Enter selects

## 10. Validation rules
- query: min 3 chars (no API call below)
- query: sanitize special chars (XSS)

## 11. Edge cases
- Network failure → Toast + retry; query stays in input
- Slow response > 2s → show "ค้นหานานกว่าปกติ..." message
- Query too short → no API call, hint shown

## 12. Test scenarios
- [[TP-MemberSearch]]

## 13. Implementation
- Plan: [[2026-05-18-0930-member-search]] (status: done)
- Files:
  - `web/src/features/members/MemberSearch.tsx`
  - `web/src/features/members/MemberSearch.test.tsx`
  - `web/src/api/members.ts`
