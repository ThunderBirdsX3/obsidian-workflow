---
description: Start new project from idea (brainstorm) or existing PRD — builds PRD → SRS → Tech spec chain (SRS = the working contract)
---

# /ow-new — เริ่มโปรเจกต์ใหม่ จาก idea หรือ PRD

ใช้เมื่อ:
- มี idea แต่ยังไม่มีเอกสารใดๆ → **Brainstorm mode**
- มี PRD เขียนไว้แล้ว อยากต่อ SRS/Tech spec → **Import mode**

> หลักของ doc chain: **PRD = intent (สั้นได้), SRS = system contract (ละเอียด)**
> PRD อย่างเดียวไม่พอสำหรับ plan/implement — `/ow-new` ต้องจบที่ SRS เสมอ ห้ามข้าม

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble — identical across all commands. Do NOT edit per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/ow-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)" || {
  echo "FATAL: resolver missing/failed — run /ow-init"; exit 1; }
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules docs)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-new
/ow-new <one-line description>
/ow-new --import <path-to-existing-prd>
```

## Phase 0.5 — Detect mode

| Argument | Mode |
|---|---|
| ว่าง | ถาม "มี PRD แล้วหรือยัง? (brainstorm / import / show-existing)" |
| free text | **Brainstorm** with seed |
| `--import <path>` | **Import** existing PRD file |

ถ้าใน `$PRD_DIR` มีไฟล์อยู่แล้ว → แจ้ง user + ถามว่าจะเริ่มอันใหม่ หรือต่อจากของเดิม

## Phase 1 (Brainstorm mode) — เปิด idea

ถาม **5 คำถาม ครั้งเดียว** (ห้ามทยอย):

1. **Problem**: ปัญหาที่อยากแก้คืออะไร? ใครเจอ?
2. **Target users**: ใครคือผู้ใช้หลัก? (1-3 personas)
3. **Goals**: เมื่อใช้แล้วผู้ใช้ได้อะไร? (3-5 outcomes)
4. **Non-goals**: ที่จะ**ไม่ทำ**ใน MVP นี้? (กันขอบเขต)
5. **Constraints**: deadline, tech stack, compliance, language ที่บังคับ?

จาก answers → สร้าง:

### 1.1 PRD draft (สั้น — intent เท่านั้น)

`$PRD_DIR/PRD-<project-slug>.md` ตาม template chain (`.ow/templates/prd.md` ก่อน, fallback `.ow/templates/prd.md`)

Frontmatter:
```yaml
---
tags: [type/prd]
status: draft           # draft | review | approved | superseded
version: 0.1.0
date: YYYY-MM-DD
authors: [<user>]
---
```

PRD เก็บแค่ vision / problem / personas / goals / non-goals / SC-### / US overview /
constraints — **ห้ามใส่รายละเอียดระบบใน PRD** (จะไปอยู่ SRS)

### 1.2 ถาม clarification (รอบ 2, ถ้ามีคำถามเหลือ)

ถ้ายังขาด detail เรื่อง business rule, scale, integration → ถามอีกแค่ **1 รอบ** แล้วเขียนต่อ

### 1.3 สร้าง SRS — เอกสารหลัก ห้ามข้าม ห้ามตื้น

`$PRD_DIR/SRS-<project-slug>.md` ตาม `.ow/templates/srs.md`

**Depth bar ของ SRS (ตรวจก่อนเขียนเสร็จ):**
- ทุก US ใน PRD ต้องแตกเป็น FR-### อย่างน้อย 1 ตัว + cross-cutting FR (auth ฯลฯ)
- ทุก FR มีครบ: priority, source US, description, inputs/outputs, pre/post-conditions,
  **acceptance Given/When/Then ≥ 2 scenario (ต้องมี sad path)**, error handling, dependencies
- NFR ทุกตัวมี **measurable threshold + วิธีวัด** — ห้าม "fast"/"secure" ลอยๆ
- มี Data Model, **State & Lifecycle** (ทุก entity ที่มี status), **Error Catalog**,
  External Integrations, Traceability table (FR ↔ FN ↔ TP)
- FR ที่เขียนไม่ครบ → ใส่ `<TODO>` + ลง Open Questions ของ PRD แล้วบอก user — ห้ามเดาเอง

### 1.4 สร้าง Tech spec

`$REF_DIR/REF-TechStack.md` + `$REF_DIR/REF-Architecture.md` ตาม `.ow/templates/tech-spec.md`

Section: Tech stack, Architecture diagram (Mermaid), Data model, API contracts, Auth, Deployment

### 1.5 สร้าง Phase plan

`$PHASE_DIR/PHASE-1-MVP.md` — แตก SRS เป็น features ใน Phase 1

### 1.6 Update IMPLEMENTATION-STATUS

`$IMPL_STATUS` — เพิ่ม project entry, link ไปไฟล์ที่สร้าง, status: `planning`

## Phase 1 (Import mode) — รับ PRD เข้ามา

```bash
# ถ้า user ระบุ path ไม่ถูกหรือไม่มี → ขอ path ใหม่
test -f "$PRD_PATH" || echo "ไฟล์ไม่พบ"
```

1. อ่าน PRD ที่ user ให้
2. Copy/move → `$PRD_DIR/PRD-<slug>.md`
3. ถ้า frontmatter ไม่ครบ → เติมให้ตาม template (ถาม user ถ้าจำเป็น)
4. **Gap analysis** — เทียบกับ `.ow/templates/prd.md`:
   - หา section ที่ขาด (Goals, Non-goals, Personas, SC, Risks, ฯลฯ)
   - แสดงให้ user เห็นแต่ละ gap → ถามแบบ batch: "ต้องการเติม section ไหนบ้าง?"
5. เติม section ที่ user เลือก
6. ต่อ **เหมือน Phase 1.3 onward** — สร้าง SRS (depth bar เดียวกัน) → Tech spec → Phase plan
7. Update `$IMPL_STATUS`

## Phase 2 — แนะนำขั้นต่อไป

แสดง next-step menu:

> เอกสาร foundation พร้อมแล้ว ขั้นต่อไป:
>
> - สแกน ambiguity ใน SRS → `/ow-clarify` (แนะนำก่อน plan)
> - วางแผน feature แรก → `/ow-plan <feature>`
> - สร้าง design system → `/ow-design`
> - เพิ่ม detail เอกสาร → `/ow-doc SRS <slug>`

## Output (3 หัวข้อบังคับ)

1. **Result** — ไฟล์ที่สร้าง (PRD/SRS/Tech/Phase) + จำนวน FR/NFR ใน SRS
2. **Verification / Evidence** — file existence check + frontmatter validation + FR depth check
   (ทุก FR มี acceptance ครบไหม — list FR ที่ยัง `<TODO>`)
3. **Limitations / Next steps** — เช่น "SRS ยังเป็น draft — review + `/ow-clarify` ก่อน plan"

## ห้าม

- ห้ามแก้โค้ดใดๆ ใน command นี้ — `/ow-new` สร้างเอกสารเท่านั้น
- ห้ามข้าม SRS หรือสร้าง SRS ตื้น (FR ไม่มี acceptance) — นี่คือเอกสารทำงานหลัก
- ห้ามแต่ง user data, requirement ที่ user ไม่ได้ระบุ — ถามหรือใส่ `<TODO>` ดีกว่า
- ห้าม overwrite PRD เดิมโดยไม่ confirm
