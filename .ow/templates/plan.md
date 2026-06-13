<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/plan.md` (lookup priority สูงกว่า)

  สร้างโดย /ow-plan (Phase 3) — โครงสร้างต้องตรงกับ template ใน .ow/commands/ow-plan.md
  plan = text only: ห้ามแก้โค้ด; /ow-implement รันได้เมื่อ status: approved เท่านั้น
-->

---
tags: [type/plan]
date: <YYYY-MM-DD HH:mm>
title: <one-line task title>
status: planning            # planning | approved | in-progress | done | abandoned
subagent_target: <backend | frontend | mobile | docs | design | all>
worktree: true                              # ⬅ ใส่เฉพาะเมื่อเรียกด้วย --worktree (ไม่งั้นตัด field นี้ออก)
source_fix: <"[[fix-log-slug]]" or none>   # set เมื่อ /ow-plan fix:<slug> — /ow-implement ใช้ปิด fix-log ตอน plan done
related_docs:
  - "[[SRS-<slug>]]"
  - "[[FEAT-<slug>]]"
  - "[[FN-<area>-<slug>]]"
estimate_hours: <number>
risk_level: <low | medium | high>
---

# <Task title>

<!-- Tip: filename = YYYY-MM-DD-HHmm-<slug>.md; slug = kebab-case ≤ 5 คำ -->

## Vault Context Read

<!-- Tip: list ทุก doc ที่อ่านจริงระหว่าง /ow-plan Phase 1 + section/FR ids — หลักฐานว่า vault-first จริง -->

- <doc path + section/FR ids ที่อ่าน>

## Task

<clear one-paragraph task description — ตอบ what + why>

## FR Coverage

- FR-### ที่ plan นี้ implement: <list>
- FR orphan/underspecified ที่เจอ: <list หรือ none>

## Goals

- [ ] <goal 1 — ตรวจสอบได้จริง>

## Non-goals

- <อะไรที่ **จะไม่ทำ** ใน plan นี้>

## Doc Gaps Found

- <vault inconsistent/missing ที่เจอระหว่างอ่าน — /ow-implement จะ fix ก่อน; ไม่มี = none>

## Affected Files

- `path/to/file1.ts` — <what changes>

## Implementation Steps

<!-- Tip: กึ่ง declarative ไม่ใส่โค้ดยาว; 5-15 steps สำหรับงานกลาง, 3-5 สำหรับงานเล็ก -->

1. <step>

## Design System Compliance (ถ้า frontend/mobile)

- [ ] ใช้ tokens จาก `DS-Tokens.md` เท่านั้น (สี/font/spacing)
- [ ] ใช้ components จาก `DS-Components.md`
- [ ] ต้อง component ใหม่ → log ใน "Design Additions" ก่อน
- [ ] WCAG AA contrast ผ่านทุก state

## Design Additions (ถ้ามี)

- <component/token ใหม่ — trigger /ow-design ก่อน /ow-implement>

## Test Plan

- [ ] Unit tests สำหรับ <X>
- [ ] Integration tests สำหรับ <Y>
- [ ] Manual checks: <scenarios>

## Success Criteria

- [ ] <เกณฑ์ที่ตรวจสอบได้จริง เช่น "unit test X ผ่าน", "endpoint ตอบ 200" — map กับ FR acceptance>

## Verification

- <map กลับไปยัง Success Criteria แต่ละข้อพร้อมผลลัพธ์จริง — เติมหลัง /ow-implement>

## Risks

- <risk> → mitigation: <plan>

## Approval

- [ ] Approved (set `status: approved` ใน frontmatter ก่อน /ow-implement)
