---
tags: [type/phase]
phase_number: 1
status: active
start_date: 2026-05-15
target_date: 2026-06-30
---

# Phase 1 — MVP

## 1. Goal
ส่ง MVP ที่ Librarian ใช้ทำ checkout/return ได้, สมาชิกดู loan ของตัวเอง ได้ — internal pilot ที่ห้องสมุดต้นแบบ

## 2. Scope

**In:**
- [[FEAT-MemberSearch]] — Priority 1 (foundation) — done
- [[FEAT-Checkout]] — Priority 1 — in-progress
- [[FEAT-Returns]] — Priority 1 — planning

**Out (Phase 2):**
- Reservations
- Notifications (email/SMS)
- Fines / late fee
- Multi-branch

## 3. Milestones

| Milestone | Target | Status |
|---|---|---|
| Member Search complete | 2026-05-18 | done |
| Checkout complete | 2026-05-25 | in-progress |
| Returns complete | 2026-06-08 | planning |
| Pilot at site A | 2026-06-20 | planning |
| Phase 1 sign-off | 2026-06-30 | planning |

## 4. Acceptance for phase complete

- [ ] FEAT-MemberSearch, FEAT-Checkout, FEAT-Returns: status: done
- [ ] All test plans PASS
- [ ] /ow-verify --feature Phase1 → handoff approved
- [ ] /ow-secure ALL GREEN
- [ ] PDPA compliance review signed
- [ ] Pilot run 1 week + no P0/P1 bug

## 5. Risks

- Librarian onboarding takes longer than expected → mitigation: in-app tutorial + live session
- PDPA legal review delay → mitigation: start review parallel with development

## 6. Progress
- 2026-05-18: FEAT-MemberSearch done
- 2026-05-20: FEAT-Checkout in-progress (API plan approved, implementation started)
- 2026-05-20: FEAT-Returns planning stage
