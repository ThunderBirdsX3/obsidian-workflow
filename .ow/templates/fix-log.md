<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/fix-log.md` (lookup priority สูงกว่า)
-->

---
tags: [type/fix-log]
date: <YYYY-MM-DD HH:mm>
title: <one-line bug title>
status: in-progress           # in-progress | fixed | wont-fix | regressed
severity: P1                   # P0 blocker | P1 major | P2 minor | P3 polish
area: <api | web | mobile | cross>
reported_by: <user | qa | self>
related_plan: <"[[plan-slug]]" or none>   # escalate path: /ow-plan fix:<slug> เขียน back-link; /ow-implement ปิด fix-log auto ตอน plan done
# fixed_commit / fixed_in_version — เติม auto ตอนปิด (/ow-fix path: /ow-git --bump · /ow-fix-issue path: ปิด+stamp เอง)
---

# <Bug title>

## Symptom

<user เห็นอะไร / อะไรพัง>

## Reproduction

1. <step 1>
2. <step 2>
3. Expected: <X>; Actual: <Y>

## Root Cause

<สาเหตุทาง technical — file path, function, line — จาก grep/read จริง>

## Vault Context Read

- <[[FN-<area>-<slug>]] ที่เกี่ยวข้อง>
- <[[REF-AuthorizationMatrix]] ถ้าเกี่ยว auth>

## Before Evidence

- Error log: <path หรือ paste>
- Screenshot: <path>
- Console output: <paste>

## Fix Approach

<paragraph อธิบาย fix ที่จะทำ — ยังไม่ใช่โค้ด>

## Affected Files

- `path/to/file1.ts` — <what to change>

## Test Cases (เพื่อพิสูจน์ว่า fix ใช้ได้)

- [ ] Test 1: <scenario>
- [ ] Regression test: <scenario>

## Risk

- <risk> → mitigation: <plan>

## Next

- [ ] รัน `/ow-plan fix:<slug>` — สร้าง plan + ผูก link สองทาง (`source_fix:` ↔ `related_plan:`)
- [ ] รัน `/ow-implement` เพื่อแก้จริง (capture after-evidence)
- [ ] ปิด fix-log: `status: fixed` + tick checkboxes — 🤖 auto โดย `/ow-implement` ตอน plan done; `fixed_in_version`/`fixed_commit` โดย `/ow-git --bump`

---

## After Evidence (เติมหลัง fix)

- Screenshot: <path>
- Test results: <pass/fail count>
- Commit: <hash>
- Status: <fixed | regressed | wont-fix>
