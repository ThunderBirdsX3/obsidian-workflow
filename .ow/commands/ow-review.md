---
description: Review diff เทียบ SRS contract — FR ครบตาม Given/When/Then ไหม + quality checklist; read-only ไม่แก้โค้ด
---

# /ow-review — Review ผูก spec

ตรวจสองชั้น: (1) **ตรงโจทย์ไหม** — diff implement FR ครบตาม acceptance Given/When/Then
ของ SRS หรือเปล่า (2) **คุณภาพ** — ตาม `.ow/checklists/code-review.md`

> code review ทั่วไปหา bug; command นี้ตอบสิ่งที่ generic review ตอบไม่ได้ —
> "โค้ดนี้ทำตามสัญญาใน SRS หรือยัง" — **read-only เสมอ ไม่แก้โค้ด**

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-review <plan-path>            # review งานของ plan — FR scope จาก ## FR Coverage
/ow-review --since <ref>          # review ทุกอย่างใน diff range
/ow-review --staged               # review เฉพาะ staged changes
/ow-review --fr FR-012 FR-013     # จำกัดเฉพาะ FR ที่ระบุ
/ow-review --quality-only         # ข้าม spec check — รันเฉพาะ quality checklist
```

## Phase 1 — Scope

1. Diff: จาก plan `Affected Files` / `git diff <ref>..HEAD` / `git diff --cached`
2. FR scope: plan `## FR Coverage` → อ่าน FR เต็มจาก SRS (`$PRD_DIR/SRS-*.md`) —
   ทั้ง description, pre/post-conditions, **ทุก acceptance scenario รวม sad path**, error handling
3. อ่าน FN spec ที่ `source_fr` ตรง scope (`$FN_DIR`) — validation rules, error states, UI states
4. ไม่มี plan + ไม่มี `--fr` → derive FR จาก FN ที่แตะไฟล์ใน diff; derive ไม่ได้ → ถาม user

## Phase 2 — Spec compliance (ต่อ FR)

ต่อ acceptance scenario ของแต่ละ FR: หา code path ใน diff ที่ทำให้ scenario นั้นจริง
แล้วให้ verdict — **ทุก verdict ต้อง cite `file:line` จริง**:

| Verdict | ความหมาย |
|---|---|
| `COVERED` | ทุก scenario มี code path + error handling ตรง Error Catalog |
| `PARTIAL` | happy path มี แต่ sad path / pre-condition / error handling ขาด — ระบุข้อที่ขาด |
| `MISSING` | FR อยู่ใน scope แต่ diff ไม่มีอะไร implement |
| `CONTRADICTS` | โค้ดทำตรงข้ามกับ acceptance (เช่น Then บอก 409 แต่โค้ดตอบ 200) |

เช็คเพิ่มต่อ FR:
- Error response ตรง **Error Catalog** (SRS §7) — code + message
- State transition ตรง **State & Lifecycle** (SRS §6) — ไม่มี transition เถื่อน
- Validation ครบตาม FN §11 — ทุก input มี rule + error message
- Test ใน diff cover acceptance ไหม (มี test ที่ assert ตาม Then จริง)

## Phase 3 — Quality review

รัน `.ow/checklists/code-review.md` ทุกข้อกับ diff — รายงานเป็น pass/fail/n.a. ต่อข้อ
Findings จัด severity: `blocker` (ผิด FR/security/data loss) > `major` > `minor` > `nit`

## Phase 4 — Report

```
## Review — <scope>

### Spec compliance
| FR | Verdict | Evidence | ที่ขาด |
|---|---|---|---|
| FR-012 | COVERED | src/api/checkout.ts:45-88 | — |
| FR-013 | PARTIAL | src/api/refund.ts:12 | sad path scenario 2 (duplicate refund → 409) ไม่มี handler + test |

### Findings (quality)
- [blocker] <finding + file:line + ทำไม>
- [minor] <...>

### Checklist
- ผ่าน N/M ข้อ — ข้อที่ fail: <list>

### Verdict รวม
READY / NOT READY — เหตุผลสั้น + งานที่เหลือ
```

`NOT READY` → แนะนำ next: กลับ `/ow-implement` (plan เดิม) หรือ `/ow-fix` ต่อ finding

## Output (3 หัวข้อบังคับ)

1. **Result** — ตาราง FR verdict + findings ต่อ severity + verdict รวม READY/NOT READY
2. **Verification / Evidence** — diff command ที่ใช้ + จำนวนไฟล์/บรรทัดที่ review + SRS/FN ที่อ่าน (path + FR ids)
3. **Limitations / Next steps** — FR ที่ derive ไม่ได้/`UNMAPPED` + ข้อจำกัด (เช่น ไม่ได้รัน test — review เป็น static)

## ห้าม

- ห้ามแก้โค้ด/ไฟล์ใดๆ — read-only เสมอ; เจอสิ่งต้องแก้ → รายงาน + ชี้ command ต่อ
- ห้ามให้ verdict `COVERED` โดยไม่ cite code จริง (`file:line`) — อ่านโค้ดก่อนตัดสิน
- ห้าม restate acceptance ใน report — link กลับ SRS (single source of truth)
- ห้าม READY ถ้ามี `blocker` หรือ FR `MISSING`/`CONTRADICTS` ค้าง
- ห้ามรัน test/build ใน command นี้ — นั่นงาน `/ow-verify` (review = static analysis)
