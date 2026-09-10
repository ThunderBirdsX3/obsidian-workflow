---
tags: [type/fix-log]
date: 2026-05-19 14:30
title: Member search returns empty when DB has matching records
status: fixed
severity: P1
area: api
reported_by: qa
related_plan: [[2026-05-19-1500-fix-search-empty]]
---

# Member search returns empty when DB has matching records

## Symptom
QA report: ค้น "สมชาย" ใน /members/search → "ไม่พบสมาชิก" แม้ DB มี member ชื่อ "สมชาย ใจดี"

## Reproduction
1. Login as Librarian
2. Open /members/search
3. Type "สมชาย" → debounce 300ms → API call
4. Expected: 1+ result
5. Actual: empty state shown

## Root Cause
ใน `MemberRepository.SearchAsync()`:
- Query ใช้ `EF.Functions.Like(name_lower, $"%{query}%")`
- แต่ `name_lower` คอลัมน์ใน DB ไม่ได้ store เป็น lowercase actually
- Migration ก่อนหน้ามี computed column `name_lower` แต่ใน Postgres lowercase ของ Thai char ไม่ trivial
- Result: ทุก query Thai char miss

## Vault Context Read
- docs/40-Functions/API/FN-API-Members-Search.md
- docs/70-Reference/REF-TechStack.md
- docs/85-FixLog/ (history — no similar prior fix)

## RED baseline
- Reproduce test: `dotnet test --filter MemberSearch` → FAIL (1 failed / 11 total)
```
MemberSearchTests.Search_ThaiName_ReturnsRows
  Expected: 3 rows   Actual: 0 rows
```
- API response: `{items: [], total: 0}` · Console: clean (ไม่มี error — query return 0 rows)

## Fix Approach
1. Switch search query to use `EF.Functions.ILike()` (case-insensitive at query time) แทน lowercase column
2. Drop `name_lower` computed column ใน migration ใหม่
3. Add index on `name` (lower-case-insensitive functional index for performance)

## Affected Files
- `api/Repositories/MemberRepository.cs` — switch to ILike
- `api/Migrations/20260519_FixMemberSearchCaseInsensitive.cs` — drop name_lower, add functional index
- `api/Tests/MemberServiceTests.cs` — add Thai char search test

## Test Cases
- [x] Search "สมชาย" → 1 result (existing member)
- [x] Search "SOMCHAI" (English) → still 0 (member is Thai only)
- [x] Search "ใจดี" → 1 result (last name match)
- [x] Search lowercase variant → match
- [x] Regression: previous tests still pass

## Risk
- Migration ลบ computed column — มี data dependency ที่อื่น? → checked: only used by SearchAsync; safe
- Index migration on table ขนาด ~5k rows — fast (< 1s)

## Next
- [x] /ow-plan สร้าง fix plan [[2026-05-19-1500-fix-search-empty]]
- [x] /ow-implement plan
- [x] Update status: fixed
- [x] GREEN result recorded

---

## GREEN result
- Same test → PASS
```
Passed! - Failed: 0, Passed: 14, Skipped: 0
```
- Test results: 14 pass (including 3 new Thai char tests)
- Migration applied: staging at 2026-05-19 16:20
- Manual UAT: PASS — ค้น "สมชาย" คืน 3 rows ตามที่ควรเป็น
- Commit: 7d3f9a2
- Deployed: staging 2026-05-19 16:30; production 2026-05-19 18:00
- Status: **fixed**
