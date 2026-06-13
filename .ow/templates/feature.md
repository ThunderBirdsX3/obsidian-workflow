<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/feature.md` (lookup priority สูงกว่า)
-->

---
tags: [type/feature]
status: planning              # planning | approved | in-progress | done | abandoned
priority: P1                  # P1 | P2 | P3 (รวมของ feature; user story อาจ mixed)
version: 0.1.0
date: <YYYY-MM-DD>
prd: "[[PRD-<slug>]]"
srs: "[[SRS-<slug>]]"
phase: "[[PHASE-<N>-<slug>]]"
related_frs:                  # FR-### ที่ feature นี้ implement
  - FR-###
related_functions:
  - "[[FN-<area>-<slug>]]"
blocked_by: []                # FEAT อื่นที่ต้องเสร็จก่อน
ui_components_used: []        # จาก DS-Components.md
design_tokens_used: []        # จาก DS-Tokens.md
---

# FEAT-<slug> — <Feature title>

<!-- Tip: feature ต้องเล็กพอที่จะ ship 1 sprint ได้ (≤ 2 สัปดาห์); ถ้าใหญ่กว่า → ตัดเป็นหลาย FEAT -->

## 1. Goal

<!-- Tip: 1–2 ประโยค ตอบ "feature นี้ทำให้ user ทำอะไรได้" — outcome ไม่ใช่ task list -->

<goal>

## 2. Roles

<!-- Tip: ใคร "ทำอะไร" ใน feature นี้ — link กลับ Role doc -->

- **[[Role-<name>]]** — <ทำอะไรได้ใน feature นี้>

## 3. User Stories (Prioritized)

<!-- Tip: ดึงจาก PRD § User Stories Overview แล้วลงรายละเอียด acceptance Given/When/Then -->
<!-- ทุก story ต้อง **Independent Test ได้** — implement แค่ story เดียวก็ใช้งานจริงได้ -->

### US1 — <story title> (Priority: P1) — MVP

**As a** <persona> **I want** <action> **so that** <outcome>

**Independent Test:**
1. <setup ขั้นต่ำ เช่น seed data>
2. <การกระทำ>
3. <verify อะไรว่าใช้งานได้จริง>

**Acceptance Criteria (Given/When/Then):**

1. **Given** <บริบท>, **When** <การกระทำ>, **Then** <ผลที่ตรวจได้>
2. **Given** <edge/sad path>, **When** <...>, **Then** <error/ผลที่คาดหวัง>

<!-- ตัวอย่าง (example เท่านั้น — ลบได้):
1. **Given** สินค้า A สถานะ available, **When** user กด reserve, **Then** record สร้าง + สถานะ → reserved + UI แสดง due date
2. **Given** สินค้า A ถูก reserve แล้ว, **When** user อื่นกด reserve, **Then** ระบบ reject + แสดงข้อความแนะนำคิวถัดไป -->

**FR refs covered:** <FR-###, ...>
**Function refs:** [[FN-<area>-<slug>]]
**DS components used:** <`Button`, `Input`, ...>
**Risks:** <risk เฉพาะ story นี้ + mitigation>

---

### US2 — <story title> (Priority: P2)

**As a** <persona> **I want** <action> **so that** <outcome>

**Independent Test:** <...>

**Acceptance Criteria:**

1. **Given** <...>, **When** <...>, **Then** <...>

**FR refs covered:** <FR-###>
**Function refs:** [[FN-<area>-<slug>]]
**DS components used:** <...>
**Risks:** <...>

---

## 4. Functions Involved

<!-- Tip: link FN-* docs; แต่ละ FN มี state/UI detail + API contract ของตัวเอง -->

- **[[FN-<area>-<slug>]]** — <หน้าที่สั้นๆ>

## 5. UX Flows

- "[[FLOW-<slug>]]"

## 6. Test Plan

<!-- Tip: link ไป `90-TestPlan/TP-FEAT-<slug>.md` ที่มี scenario ครบ + evidence manifest -->

- **[[TP-FEAT-<slug>]]** — รวม scenario per story + edge cases + a11y check

## 7. Design System Compliance

<!-- Tip: บังคับใช้ tokens + components จาก DS; ถ้าต้อง component ใหม่ → run /ow-design ก่อน /ow-plan -->

- **Tokens used**: <list จาก DS-Tokens.md>
- **Components used**: <list จาก DS-Components.md>
- **New components needed**: <_none_ หรือ list (ถ้ามี → /ow-design component <name> ก่อน)>
- **A11y check**: <keyboard nav / screen reader / contrast WCAG AA>

## 8. Implementation Status

<!-- Tip: update ทุกครั้งที่ status เปลี่ยน — ตารางนี้ต้องตรงกับ plan files ใน 80-ImplementPlan -->

| User Story | Priority | Status | Plan file | FR covered | Evidence |
|------------|----------|--------|-----------|------------|----------|
| US1 | P1 | planning | _ยังไม่มี plan_ | <FR-###> | — |

## 9. Risks

- **R1** — <risk> — mitigation: <plan>

## 10. Clarifications

<!-- Tip: section นี้ถูกเติมโดย /ow-clarify — ห้ามแก้ด้วยมือ -->

_ยังไม่มี clarification session_
