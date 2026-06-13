<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/srs.md` (lookup priority สูงกว่า)

  SRS = "system contract" — เอกสารทำงานหลักของ project นี้. PRD ตอบ "ทำไม";
  SRS ตอบ "ระบบทำอะไร แค่ไหน ตรวจยังไง" — ทุก FR ต้องละเอียดพอที่
  /ow-plan จะ plan ได้โดยไม่ต้องถาม user เพิ่ม.

  ห้ามเขียน FR ที่ไม่มี acceptance — /ow-clarify และ /ow-checklist จะ flag
  เป็น underspecification.
-->

---
tags: [type/srs]
status: draft                 # draft | review | approved | superseded
version: 0.1.0
date: <YYYY-MM-DD>
prd: "[[PRD-<slug>]]"
related_features:
  - "[[FEAT-<slug>]]"
related_functions:
  - "[[FN-<area>-<slug>]]"
---

# SRS-<slug> — <Product / Feature Name>

## 1. System Overview

<!-- Tip: 1 paragraph อธิบาย system context — ใครใช้, ทำอะไร, ต่อกับอะไร, data store อะไร — ไม่เกิน 5 บรรทัด -->

<overview>

## 2. Scope

<!-- Tip: ดึงจาก PRD § Goals/Non-goals — แต่ในมุม system, ไม่ใช่ user outcome -->

**In scope:**
- <system capability 1>

**Out of scope:**
- <excluded capability 1>

## 3. Functional Requirements (FR-###)

<!-- ทุก FR ต้องมีครบ:
     • id (FR-001..) + priority (P1/P2/P3 ตรงกับ user story ที่ link)
     • source-user-story (US# จาก PRD)
     • description — ระบบ "ต้อง" ทำอะไร (testable statement)
     • inputs / outputs (ชนิดข้อมูล + format)
     • pre-conditions / post-conditions (รวม business rules)
     • acceptance เป็น Given/When/Then ≥ 1 scenario (รวม sad path)
     • error handling (HTTP code / error message / race condition)
     • dependencies (FR อื่น / external system / DB schema)
     จัด block เป็นช่วง 10: FR-001..009 = core stories; FR-010..019 = cross-cutting
     (auth/security); FR-020+ = ตาม functional area -->

### FR-001 — <requirement title>

- **Priority**: P1
- **Source user story**: US1 ([[PRD-<slug>]])
- **Description**: ระบบต้อง<พฤติกรรมที่ตรวจสอบได้>
- **Inputs**: <field (type, constraint)>
- **Outputs**: <field (type, format)>
- **Pre-conditions**:
  - <เงื่อนไขก่อนทำงาน / business rule>
- **Post-conditions**:
  - <สถานะระบบหลังทำงานสำเร็จ — รวม side effect เช่น audit log>
- **Acceptance** (Given/When/Then):
  1. **Given** <บริบท>, **When** <การกระทำ>, **Then** <ผลที่ตรวจได้>
  2. **Given** <edge/sad path>, **When** <...>, **Then** <error ที่คาดหวัง>
- **Error handling**: <HTTP code + message ต่อ failure mode; ระบุ race condition ถ้ามี>
- **Dependencies**: <FR-### อื่น / external system / DB schema>

---

<!-- เพิ่ม FR-### ตามจำนวน user story + functional area -->

## 4. Non-functional Requirements (NFR-###)

<!-- Tip: ทุก NFR ต้องมี measurable threshold + วิธีวัด — ห้าม "fast", "secure" ลอยๆ -->

### NFR-001 — Performance

- **Threshold**: <เช่น API p95 ≤ 800 ms under N concurrent users>
- **Measurement**: <เครื่องมือ + วิธีวัด>
- **Linked SC**: <SC-### จาก PRD>

### NFR-002 — Security

- **Threshold**: <เช่น password hashing algo + cost, token type + expiry, PII encryption>
- **Measurement**: `/ow-secure` pre-flight + <scan tool>

### NFR-003 — Reliability

- **Threshold**: <uptime / error budget>
- **Measurement**: <monitor>

<!-- เพิ่มตามจริง: Accessibility (WCAG), i18n, Data retention/compliance, Scalability -->

## 5. Data Model

<!-- Tip: entity + field สำคัญ + relationship; รายละเอียด column เต็มอยู่ที่ migration/schema จริง -->

- **<Entity>** (<key fields>) — <relationship เช่น 1:N → <ChildEntity>>

## 6. State & Lifecycle

<!-- Tip: ทุก entity ที่มี status ต้องมี state diagram/ตาราง — transition ไหน allowed,
     ใคร trigger, side effect อะไร. นี่คือจุดที่ bug ชอบซ่อน -->

### <Entity> states

| From | Event / Actor | To | Side effects |
|---|---|---|---|
| <state A> | <action โดย role> | <state B> | <audit / notification / ...> |

## 7. Error Catalog

<!-- Tip: รวม error ที่ระบบตอบทั้งหมดไว้ที่เดียว — code, message, เกิดเมื่อไหร่, user เห็นอะไร -->

| Code | When | Message (user-facing) | FR |
|---|---|---|---|
| <400/409/...> | <เงื่อนไข> | <ข้อความ> | FR-### |

## 8. External Integrations

<!-- Tip: ทุก integration ระบุ protocol + auth + retry policy + failure mode -->

- **<service>** — <protocol, auth, retry, timeout, fallback เมื่อ down>

## 9. UX Flows

<!-- Tip: link ไป FLOW-* docs; ไม่วาดที่นี่ -->

- "[[FLOW-<slug>]]"

## 10. Traceability

<!-- Tip: ตารางมัด FR ↔ FN spec ↔ test — /ow-plan ใช้เช็ค coverage; เติมเมื่อสร้าง FN/TP
     หรือ generate จากข้อมูลจริงด้วย /ow-trace <slug> --update (ดู report: /ow-trace) -->

| FR | FN spec | Test plan | Status |
|---|---|---|---|
| FR-001 | [[FN-<area>-<slug>]] | [[TP-<slug>]] | not-started |

## 11. Dependencies (system-level)

- <runtime / DB / external account ที่ต้องมี>

## 12. Acceptance for Release

<!-- Tip: ตอบ "เมื่อไรถึงปล่อย version นี้ได้" -->

- [ ] ทุก FR P1+P2 implement + acceptance Given/When/Then pass (มี evidence)
- [ ] ทุก NFR ผ่าน threshold (มี evidence)
- [ ] SC-### (PRD) วัดผลได้
- [ ] `/ow-secure` ผ่าน (no secret/PII leak)
- [ ] `/ow-verify` ผ่าน

## 13. Clarifications

<!-- Tip: section นี้ถูกเติมโดย /ow-clarify — ห้ามแก้ด้วยมือ -->

_ยังไม่มี clarification session_
