<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/prd.md` (lookup priority สูงกว่า)

  PRD = intent doc — สั้นได้ ตอบ "ทำไม + เพื่อใคร + อะไรคือความสำเร็จ"
  รายละเอียดระบบ (FR/NFR/data/error/integration) ไปอยู่ที่ SRS — อย่ายัดที่นี่
-->

---
tags: [type/prd]
status: draft                 # draft | review | approved | superseded
version: 0.1.0
date: <YYYY-MM-DD>
authors: [<user>]
related_docs:
  - "[[SRS-<slug>]]"
  - "[[REF-TechStack]]"
---

# PRD-<slug> — <Product / Feature Name>

<!-- Tip: slug = kebab-case สั้นๆ (≤ 5 คำ) ต้องตรงกับ filename -->

## 1. Vision

<!-- Tip: 2–3 ประโยค ตอบ "อีก 12 เดือนข้างหน้า ระบบนี้จะเปลี่ยนชีวิตใครยังไง" — ห้าม jargon -->

<vision>

## 2. Problem

<!-- Tip: ใคร เจอปัญหาอะไร ตอนนี้ workaround ยังไง ทำไมถึงเจ็บปวด — ใส่ตัวเลขถ้ามี -->

<problem>

## 3. Personas

<!-- Tip: 2–4 personas พอ; แต่ละตัวมี role + context + pain เฉพาะ -->

- **<Persona 1>** — <ใคร ทำอะไร ต้องการอะไร>
- **<Persona 2>** — <...>

## 4. Goals

<!-- Tip: เขียนเป็น outcome ที่ user ได้รับ (ไม่ใช่ feature list); 3–6 ข้อ -->

- <goal 1>
- <goal 2>

## 5. Non-goals

<!-- Tip: ระบุชัดว่า "ไม่ทำใน scope นี้" เพื่อกัน scope creep — โยงไปอนาคตได้ -->

- <non-goal 1> (เฟสหน้า / ไม่ใช่ scope)

## 6. Success Metrics (SC-###)

<!-- Tip: ทุก SC ต้อง measurable + technology-agnostic + บอกวิธีวัด -->

- **SC-001** — <metric + target + วิธีวัด>
- **SC-002** — <...>

## 7. User Stories Overview (Prioritized)

<!-- Tip: แต่ละ story ต้อง Independent Test ได้ (ทำ story เดียวแล้ว user ใช้งานได้จริง) -->
<!-- รายละเอียด acceptance Given/When/Then ไปอยู่ใน SRS (FR-###) — ที่นี่เอาแค่ overview -->

### US1 — <story title> (Priority: P1) — MVP

**As a** <persona> **I want** <action> **so that** <outcome>

**Why this priority:** <เหตุผล>

**Independent Test:** <ทำเฉพาะ story นี้แล้ว verify ยังไงว่าใช้งานได้จริง>

---

### US2 — <story title> (Priority: P2)

**As a** <persona> **I want** <action> **so that** <outcome>

**Why this priority:** <เหตุผล>

**Independent Test:** <...>

## 8. Constraints

<!-- Tip: deadline, budget, tech, compliance — สิ่งที่ "ต้องทำตาม" -->

- **Deadline**: <...>
- **Tech stack**: <... (ดู REF-TechStack)>
- **Compliance**: <...>
- **Language**: <UI language>

## 9. Assumptions

- <assumption 1>

## 10. Risks

<!-- Tip: risk → mitigation; ห้าม risk ลอยๆ ไม่มีแผนรับมือ -->

- **R1** — <risk> → mitigation: <plan>

## 11. Glossary

<!-- Tip: ใช้คำศัพท์ตรงกันทั้ง project — SRS/FEAT/FN อ้างกลับมาที่นี่ -->

- **<term>** — <นิยาม>

## 12. Open Questions

<!-- Tip: ใช้ /ow-clarify เพื่อแก้ทีละข้อ; ตอบแล้วย้ายไป Clarifications -->

- [ ] <คำถามที่ยังไม่มีคำตอบ>

## 13. Clarifications

<!-- Tip: section นี้ถูกเติมโดย /ow-clarify — ห้ามแก้ด้วยมือ; แต่ละ session = 1 block -->

_ยังไม่มี clarification session_
