---
tags: [type/function]
area: api
status: implemented
version: 1.0.0
date: 2026-05-18
feature: [[FEAT-MemberSearch]]
---

# FN-API-Members-Search

## 1. Purpose
REST endpoint ค้นหาสมาชิก — backing สำหรับ [[FN-Web-Librarian-MemberSearch]]

## 2. Trigger
- `GET /api/members?q=<query>&status=<all|active|inactive>&limit=20`

## 3. Inputs
| Param | Type | Required | Default |
|---|---|---|---|
| q | string | yes (min 3) | — |
| status | enum | no | all |
| limit | int | no | 20 (max 100) |

## 4. Behavior / Flow
1. Validate q length >= 3
2. Sanitize q (strip control chars, max 100 chars)
3. Query DB: name ILIKE %q% OR phone LIKE q% OR member_id = q
4. Apply status filter
5. Limit + order by (active first, then by last activity desc)
6. Return JSON

## 5. Outputs / Result

Success 200:
```json
{
  "items": [
    {
      "id": "uuid",
      "member_id": "M-0042",
      "name": "สมชาย ใจดี",
      "phone_masked": "081xxxxx42",
      "status": "active",
      "active_loans_count": 2
    }
  ],
  "total": 1
}
```

Errors:
- 400: q < 3 chars
- 401: not authenticated
- 403: insufficient role
- 500: server error (logged)

## 6. Side effects
- Audit log: `{user, action: "members:search", query: <hash>, timestamp}`

## 7. Auth / RBAC
- Required role: Librarian
- Required permission: `members:read`

## 8. Performance
- Target: p95 < 500ms
- Index: `members(name_lower)`, `members(phone)`, `members(member_id)`
- Cache: none (real-time data)

## 9. Test scenarios
- [[TP-MemberSearch]]

## 10. Implementation
- Plan: [[2026-05-18-0930-member-search]]
- Files:
  - `api/Controllers/MembersController.cs`
  - `api/Services/MemberService.cs`
  - `api/Repositories/MemberRepository.cs`
  - `api/Tests/MemberServiceTests.cs`
