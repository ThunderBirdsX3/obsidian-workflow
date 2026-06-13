<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/phase.md` (lookup priority สูงกว่า)
-->

---
tags: [type/phase]
phase_number: <N>
status: planning              # planning | active | done
start_date: <YYYY-MM-DD>
target_date: <YYYY-MM-DD>
---

# Phase <N> — <Phase title>

## 1. Goal

<paragraph อธิบาย phase นี้คืออะไร + target outcome>

## 2. Scope

**In:**
- [[FEAT-<slug>]] — <priority>

**Out:** (phase ถัดไป)
- <future feature>

## 3. Milestones

| Milestone | Target date | Status |
|---|---|---|
| <M1> | <date> | planning/active/done |

## 4. Acceptance for phase complete

- [ ] ทุก feature ใน scope: status: done
- [ ] ทุก test plan passed
- [ ] /ow-verify ผ่านทุก feature
- [ ] /ow-secure ผ่านทั้ง scope
- [ ] Handoff note สร้างแล้ว: [[HANDOFF-<YYYY-MM-DD>-<slug>]]

## 5. Risks

- <risk> → mitigation: <plan>

## 6. Progress

<!-- Tip: update โดย /ow-implement เมื่อ feature status เปลี่ยน -->

- <Feature>: <status>
