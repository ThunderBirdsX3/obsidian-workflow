# /ow-new

> **เริ่ม project/feature ใหม่** — brainstorm จาก idea หรือ import PRD ที่มีอยู่ → สร้าง PRD/SRS/Tech-spec ครบชุด

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-new.md`](../.ow/commands/ow-new.md)

## เมื่อไหร่ใช้

- มี idea แต่ยังไม่มีเอกสารใดๆ — **Brainstorm mode**
- มี PRD เขียนไว้แล้ว อยากต่อ SRS/Tech-spec — **Import mode**
- เริ่ม project ใหม่หลัง `/ow-init` แล้ว

## Quick start

```
/ow-new
```

ตัวอย่าง flow (brainstorm):
```
ถามทีเดียว 5 คำถาม:
  1. Problem: ปัญหาอะไร? ใครเจอ?
  2. Target users: ใครคือผู้ใช้หลัก? (1-3 personas)
  3. Goals: ใช้แล้วได้อะไร? (3-5 outcomes)
  4. Non-goals: ที่จะไม่ทำใน MVP?
  5. Constraints: deadline, budget, tech stack, compliance?

→ สร้าง PRD + SRS + REF-TechStack + REF-Architecture + PHASE-1-MVP + update IMPLEMENTATION-STATUS
```

## รูปแบบเต็ม

```
/ow-new                              # interactive — ถาม brainstorm/import
/ow-new "<one-line description>"     # brainstorm with seed
/ow-new --import <path>              # รับ PRD ที่มีอยู่ → gap analysis → ต่อ SRS/Tech
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--import <path>` | n/a | import PRD จาก path (ภายนอกหรือใน repo) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect mode (brainstorm / import / show-existing)
2. **Phase 1 (Brainstorm)** — ถาม 5 คำถาม batch → สร้าง PRD → (1 รอบ clarify) → SRS → Tech-spec → Phase plan → update IMPLEMENTATION-STATUS
3. **Phase 1 (Import)** — อ่าน PRD → copy → gap analysis vs `templates/prd.md` → ให้ user เลือก section ที่เติม → ต่อ SRS/Tech
4. **Phase 2** — แนะนำ next step (`/ow-plan`, `/ow-design`)

## Output ที่ได้

- `docs/obsidian-vault/10-PRD/PRD-<slug>.md` — Product Requirements (status: draft)
- `docs/obsidian-vault/10-PRD/SRS-<slug>.md` — Software Requirements (FR-001, FR-002, …) · ถ้า FR ครอบคลุม ≥ 2 โมดูลและยาวเกิน ~10k token จะแยกเป็น hub + `SRS-<slug>-<module>.md` ต่อโมดูล เพื่อให้ `/ow-plan` อ่านเฉพาะโมดูลที่งานแตะ
- `docs/obsidian-vault/70-Reference/REF-TechStack.md` — tech stack list
- `docs/obsidian-vault/70-Reference/REF-Architecture.md` — Mermaid diagram + data model + API contracts
- `docs/obsidian-vault/50-Phases/PHASE-1-MVP.md` — Phase 1 breakdown
- `docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md` — เพิ่ม project entry (status: planning)

## Workflow ที่นิยม

ตัวอย่าง 1: เริ่มจาก idea
```
1. /ow-init                        ← ตั้งค่า project
2. /ow-new                          ← คุณอยู่ที่นี่ — brainstorm
3. /ow-clarify                      ← scan ambiguity (recommended)
4. /ow-plan FEAT-X                  ← วางแผน feature แรก
```

ตัวอย่าง 2: มี PRD ของลูกค้าอยู่แล้ว
```
1. /ow-new --import ~/Downloads/customer-prd.docx
   → อ่าน + copy → docs/obsidian-vault/10-PRD/PRD-<slug>.md
   → gap analysis: ขาด Goals, Personas, KPIs
   → user เลือก section ที่จะเติม
2. /ow-doc PRD-<slug>               ← เติม detail ที่ขาด
3. /ow-plan <first feature>
```

ตัวอย่าง 3: idea + seed
```
/ow-new "ระบบจองคิวสำหรับร้านตัดผม"
  → seed Problem section ให้
  → ยังถาม 5 คำถามครบ (ไม่ skip)
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามเล่าการแก้ในเอกสาร vault** — "เดิม X → ใหม่ Y" / หัวข้อ `## Changelog` ให้ทับด้วยค่าปัจจุบันแทน · before/after อยู่ใน plan (`80-ImplementPlan`) หรือ fix-log (`85-FixLog`) · `/ow-secure` Phase 2.6 บล็อกให้
- 🚫 ห้ามแต่ง user data, stakeholder, requirement ที่ user ไม่ได้ระบุ — ถามดีกว่า
- 🚫 ห้าม overwrite PRD เดิมโดยไม่ confirm
- 🚫 ห้ามแก้โค้ดใน `/ow-new` — สร้างเอกสารเท่านั้น
- ⚠️ คำถาม 5 ข้อ ถาม **ครั้งเดียว** (batch) — ห้ามทยอย ถ้ายังขาด detail → ถามเพิ่มอีก **1 รอบ** ได้
- ⚠️ Tech-spec auto-fill จาก `templates/tech-spec.md` — review กับทีม backend ก่อน implement
- 💡 PRD status default = `draft` — ต้อง review กับ stakeholder ก่อน `/ow-plan`

## Related

- ก่อน `/ow-new`: [/ow-init](./ow-init.md) (config + vault skeleton)
- หลัง `/ow-new`: [/ow-clarify](./ow-clarify.md) → [/ow-plan](./ow-plan.md) → [/ow-implement](./ow-implement.md)
- Doc editing: [/ow-doc](./ow-doc.md) — เติม section ที่ขาด
- Template: `templates/prd.md`, `templates/srs.md`, `templates/srs-module.md`, `templates/tech-spec.md`

## FAQ

**Q: ผมมี PRD เป็น .docx — `/ow-new --import` อ่านได้ไหม?**
A: รองรับ markdown หลัก ถ้าเป็น .docx อาจต้อง convert (`pandoc -f docx -t md`) ก่อน

**Q: ถ้า vault มี PRD-* อยู่แล้ว?**
A: `/ow-new` จะแจ้ง + ถามว่าจะเริ่มใหม่หรือต่อจากของเดิม

**Q: ทำไม Tech-spec ใช้ REF-Architecture.md แทน TECH-spec.md?**
A: ตาม template convention ของ obsidian-workflow — Architecture diagram + data model + API contracts รวมที่ `REF-Architecture.md` ใน `70-Reference/`
