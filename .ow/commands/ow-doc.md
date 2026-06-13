---
description: Write or update vault doc (PRD/SRS/Tech/ADR/Feature/Function/Role/Postmortem/Runbook) using template
---

# /ow-doc — เขียน/แก้เอกสาร vault

ทำงานกับเอกสารทุกประเภทใน vault โดยใช้ template ที่กำหนด — รักษา link graph + frontmatter conventions เสมอ

> **ชั้นคิดของงานเอกสาร**: command นี้รันใน main session ที่ command model (pin opus ได้ผ่าน `.ow.yml`) —
> การออกแบบโครง/ตัดสิน spec เกิดที่นี่; `docs` agent (model เล็ก) เป็น executor เท่านั้น
> Escalation จาก docs agent (`/ow-implement` Phase 2, agent §4.5) ชี้กลับมาที่ command นี้กับ `/ow-clarify`

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
/ow-doc                              # interactive — ถาม type
/ow-doc <type> <name>                # เช่น /ow-doc SRS CheckoutFlow
/ow-doc --edit <path>                # แก้ไฟล์ที่มีอยู่
/ow-doc --review <path>              # review only ไม่แก้
```

## Phase 0.5 — เลือก type

| Type | Folder | Template |
|---|---|---|
| `PRD` | `$PRD_DIR/PRD-<slug>.md` | `prd.md` |
| `SRS` | `$PRD_DIR/SRS-<slug>.md` | `srs.md` |
| `Tech` | `$REF_DIR/REF-Architecture.md` | `tech-spec.md` |
| `ADR` | `$REF_DIR/ADR/ADR-NNNN-<slug>.md` | `adr.md` |
| `Feature` | `$FEAT_DIR/FEAT-<slug>.md` | `feature.md` |
| `Function` | `$FN_DIR/<area>/FN-<slug>.md` | `function.md` |
| `Role` | `$ROLE_DIR/<platform>/<role>.md` | `role.md` |
| `Flow` | `$FLOW_DIR/FLOW-<slug>.md` | `flow.md` |
| `Phase` | `$PHASE_DIR/PHASE-<n>-<slug>.md` | `phase.md` |
| `TestPlan` | `$TEST_DIR/TP-<slug>.md` | `test-plan.md` |
| `Postmortem` | `$FIX_DIR/PM-<YYYY-MM-DD>-<slug>.md` | `postmortem.md` |
| `Runbook` | `$REF_DIR/Runbooks/RUNBOOK-<slug>.md` | `runbook.md` |
| `Reference` | `$REF_DIR/REF-<slug>.md` | (free-form heading structure) |

Template lookup: ตาม `$TEMPLATE_CHAIN` (ที่เดียว: `.ow/templates/` — customize โดยแก้ไฟล์ในนั้นตรงๆ)

## Phase 1 — Determine action

| สภาพ | Action |
|---|---|
| ไฟล์ยังไม่มี | **Create** mode |
| ไฟล์มีอยู่, `--edit` | **Edit** mode — เพิ่ม/แก้ section |
| ไฟล์มีอยู่, `--review` | **Review** mode — ตรวจ gaps แต่ไม่แก้ |
| ไฟล์มีอยู่, ไม่มี flag | ถาม edit หรือ review |

## Phase 2 — Read context

อ่าน:
1. Template ที่จะใช้ (ตาม `$TEMPLATE_CHAIN`)
2. Related docs ที่ link ไป — เช่น สร้าง Feature → อ่าน PRD+SRS ก่อน; สร้าง FN → อ่าน SRS FR ที่เกี่ยว
3. `$IMPL_STATUS`
4. Docs ใน folder เดียวกันที่มี pattern คล้าย (keep consistency)

## Phase 3 — Create / Edit

### Create mode:
1. Copy template → target path
2. Fill frontmatter (`status: draft`, `date`, `version`, `authors`)
3. **Design pass ก่อนเติม body** (contract docs — PRD/SRS/Feature/Function): เสนอ outline + FR/section
   mapping + content source ต่อ section ให้ user เห็นก่อน → confirm แล้วค่อยเติมเต็ม — งานคิดจบที่ชั้นนี้
   เพื่อให้ downstream (docs agent) เหลือแต่งาน execute
4. Fill body ตาม context + ถามคำถามที่ template ระบุ (`<TODO: ...>` placeholders)
5. ถาม batch — 3-5 คำถาม ใน message เดียว

**Depth bar ต่อ type:**
- **SRS** — ทุก FR ครบ inputs/outputs/pre/post/acceptance(Given/When/Then ≥ 2 รวม sad path)/
  error handling/dependencies; NFR มี threshold วัดได้; มี State & Lifecycle + Error Catalog
- **Function (FN)** — ผูกกับ FR-### ใน SRS เสมอ (`source_fr:` ใน frontmatter); ระบุ
  UI states / API contract / validation / error states ครบ
- **Feature** — list FR ที่ feature ครอบ + link FN ลูก
- เอกสารที่เขียนได้ไม่ถึง bar → ใส่ `<TODO>` ชัดๆ + บอก user — ห้ามเดา

### Edit mode:
1. แสดง outline current → ถามว่าจะแก้ section ไหน
2. แสดง diff ก่อน save
3. Preserve frontmatter ที่ไม่เกี่ยว (`version` bump only ถ้า substantive change)
4. Update `last_modified`
5. **แก้ PRD แล้ว** → ตรวจ SRS ที่ link ว่า out-of-sync ไหม (FR ครอบ US ใหม่หรือยัง) — flag ถ้าต้อง sync
6. **แก้ SRS FR** → flag FN/TP ที่ trace ถึง FR นั้นให้ review

### Review mode:
1. เทียบ section actual กับ template
2. List missing sections + sections ที่ตื้นไป (เทียบ depth bar ข้างบน)
3. ตรวจ link integrity (link ไป doc ที่ไม่มี)
4. ตรวจ frontmatter completeness
5. **ไม่แก้ไฟล์** — แค่ output report

## Phase 4 — Update MOC + link graph

หลัง create/edit:
1. Update relevant MOC (`$INDEX_DIR/MOC-*.md`) เพิ่ม link
2. Update `$IMPL_STATUS` ถ้า status เปลี่ยน
3. ตรวจว่าทุก `[[link]]` ชี้ไปไฟล์จริง
4. ถ้าเป็น Function → update related Feature, Role + Traceability table ใน SRS
5. ถ้าเป็น PRD/SRS update → flag dependent Features ที่อาจต้อง review

## Phase 5 — Design system bind (ถ้า doc เป็น Function/Feature ที่มี UI)

ถ้า `$DS_DIR` มีอยู่:
- Section "UI Components Used" ใน doc → ระบุ components จาก `DS-Components.md`
- Section "Design Tokens Used" → ระบุ tokens จาก `DS-Tokens.md`
- Validate ว่า component ที่อ้างมีอยู่จริงใน design system

## Output (3 หัวข้อบังคับ)

1. **Result** — file path + mode (create/edit/review) + sections ที่เติม/แก้
2. **Verification / Evidence** — link integrity result + frontmatter check + depth bar check
3. **Limitations / Next steps** — `draft` status ต้อง review, dependent docs ที่ flag ไว้

## ห้าม

- ห้ามแต่ง stakeholder name, business rule, requirement ที่ user ไม่ได้ระบุ
- ห้าม overwrite section ที่ user เขียนเองโดยไม่ confirm
- ห้าม bump version ใน frontmatter โดยไม่ confirm
- ห้ามทำ wikilink เสีย — rename ต้องทิ้ง alias
