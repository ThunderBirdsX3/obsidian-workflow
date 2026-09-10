---
tags: [type/plan]
date: 2026-05-19 15:00
title: Fix member search returning empty for Thai names
status: done
completed_at: 2026-05-19 16:20
submodule_target: api
subagent_target: backend
source_fix: [[2026-05-19-1430-search-returns-empty]]
related_feature: "[[FEAT-MemberSearch]]"
related_docs:
  - "[[FN-API-Members-Search]]"
  - "[[REF-TechStack]]"
covers_frs: [FR-001]
estimate_hours: 2
risk_level: low
---

# Fix member search returning empty for Thai names

## Vault Context Read
- docs/85-FixLog/2026-05-19-1430-search-returns-empty.md (root cause + RED baseline)
- docs/40-Functions/API/FN-API-Members-Search.md
- docs/70-Reference/REF-TechStack.md

## Problem
`MemberRepository.SearchAsync()` matches against a `name_lower` computed column. Postgres
lower-casing is not meaningful for Thai characters, so every Thai query misses and the API
answers `{items: [], total: 0}`.

## Task
Match case-insensitively at query time and drop the column the old approach needed.

## Goals
- [x] Thai-name search returns the matching members
- [x] Search stays under the 300 ms budget in FN-API-Members-Search

## Non-goals
- Transliteration / fuzzy matching (English query → Thai record stays out of scope)

## Affected Files
- `api/Repositories/MemberRepository.cs`
- `api/Migrations/20260519_FixMemberSearchCaseInsensitive.cs`
- `api/Tests/MemberServiceTests.cs`

## Implementation Steps
1. `MemberRepository.SearchAsync()` → `EF.Functions.ILike(name, $"%{query}%")`
2. Migration: drop `name_lower`, add a functional index on `lower(name)`
3. Tests: Thai name, Thai surname, lowercase variant, English-only miss
4. Run the RED test from the fix-log and confirm it turns GREEN

## Success Criteria
- [x] `dotnet test --filter MemberSearch` — the RED case passes (was 1 failed / 11)
- [x] No regression: full API suite green
- [x] Search latency on ~5k rows stays < 300 ms

## Test Plan
- Unit: repository query shape · Integration: search endpoint with Thai fixtures
- Regression: the 11 tests that already existed

## Approvals
- [x] Approved + completed 2026-05-19 16:20

---

## Implementation Result
- Files changed: 2 (production), 1 (tests)
- Tests added: 3 (Thai name, Thai surname, lowercase variant)
- Success criteria → check map: all three checked by `dotnet test --filter MemberSearch`
- Build/test result: `dotnet test` 14 passed / 14 (was 10 passed / 11)
- Executed by: subagent `backend` · Time: 1.5h
- Commits: 7d3f9a2
- Deployed to: staging on 2026-05-19 16:30
- Fix-log closed: [[2026-05-19-1430-search-returns-empty]] → `status: fixed`
