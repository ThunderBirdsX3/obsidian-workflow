<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/checklist.md` (lookup priority สูงกว่า)
  ใช้โดย /ow-checklist — "unit tests for English" (spec-quality gate)
  เขียนออกที่ <vault>/95-Handoff/checklists/<domain>-<scope>-<YYYY-MM-DD>.md
-->

---
tags: [type/checklist, domain/<domain>]
status: in-review              # in-review | passed | blocked
date: <YYYY-MM-DD>
scope: feature:<slug>          # feature:<slug> | project
domain: <ux | api | security | perf | data | <custom>>
generated_by: /ow-checklist
items_total: 0
items_passed: 0
items_failed: 0
items_pending: 0
---

# Checklist — <domain> · <scope>

> แต่ละ item คือ **คำถามที่ทดสอบ spec ไม่ใช่ implementation** — ตอบไม่ได้/คลุมเครือ = spec gap
> Mark: `[x]` passed · `[ ]` pending · `[!]` failed (เขียนเหตุผล + ลิงก์ spec ที่ต้องแก้)

## Items

- [ ] CHK001 <คำถามทดสอบ spec — ระบุสิ่งที่ spec ต้องตอบให้ชัด>
- [ ] CHK002 <...>
- [ ] CHK003 <...>

<!-- 10–30 items/domain. กลุ่มย่อยได้ด้วย ### sub-heading ถ้า domain ใหญ่ -->

## Failed items (ต้องแก้ spec ก่อนผ่าน)

| CHK | ปัญหา (spec ตอบไม่ได้/คลุมเครือ) | spec doc ที่ต้องแก้ |
|---|---|---|
| <CHK0xx> | <gap> | [[<FN/FEAT/REF doc>]] |

## Verdict

- **items_total / passed / failed / pending**: <n> / <n> / <n> / <n>
- **status**: in-review | passed | blocked
- **Next**: <ถ้า blocked — ส่ง gap ให้ /ow-clarify หรือแก้ spec ก่อน>
