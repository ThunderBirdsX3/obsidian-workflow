# .ow/templates/ — Default templates

Templates ที่นี่คือ **default** ของ obsidian-workflow — แก้ได้โดยตรง (เป็นของคุณเอง)

## Override per-project

Lookup chain (สูงกว่าชนะ):

1. `templates/<name>.md` — project override (ถ้ามี)
2. `.ow/templates/<name>.md` — default (fallback)

ต้องการปรับ template ให้เข้ากับ project ไหน → copy ไฟล์จากที่นี่ไป `templates/<name>.md`
ของ project นั้นแล้วแก้ — resolver จะเลือกตัว override ก่อนเสมอ

## ไฟล์ทั้งหมด

| Template | ใช้ทำอะไร |
|---|---|
| `prd.md` | PRD — intent doc (ทำไม + เพื่อใคร + ความสำเร็จ) |
| `srs.md` | SRS — system contract (FR/NFR/data/error/traceability) — เอกสารทำงานหลัก |
| `tech-spec.md` | Tech stack + architecture + deployment |
| `adr.md` | Architecture Decision Record |
| `feature.md` | FEAT-* — feature spec + user stories + acceptance |
| `function.md` | FN-* — UI states / API contract / validation / error states ต่อ FR |
| `role.md` | Role — permissions + menu + screens |
| `flow.md` | FLOW-* — user flow (mermaid + steps) |
| `phase.md` | PHASE-* — phase planning |
| `plan.md` | Implementation plan (สร้างโดย /ow-plan) |
| `fix-log.md` | Bug fix log (สร้างโดย /ow-fix) |
| `postmortem.md` | PM-* — production incident postmortem (blameless; ผ่าน /ow-doc Postmortem) |
| `runbook.md` | RUNBOOK-* — คู่มือแก้เหตุ step-by-step (ผ่าน /ow-doc Runbook) |
| `test-plan.md` | TP-* — test plan per feature |
| `test-scenario-report.md` | Test execution report (ใช้โดย /ow-test) |
| `evidence-manifest.md` | Taxonomy reference (Status / Route source / Drift) |
| `evidence/EVIDENCE.md` | Evidence manifest per task folder (ใต้ test-artifacts/) |
| `design-component.md` | Component block ใน DS-Components.md (ใช้โดย /ow-design) |
| `checklist.md` | Spec-quality checklist (ใช้โดย /ow-checklist) |
| `init.md` | Init prompt — ให้ AI สำรวจโครงสร้าง vault/project |
| `obsidian-context.md` | Obsidian context manifest |
| `handoff.md` | Session handoff note (สร้างโดย /ow-handoff) |
