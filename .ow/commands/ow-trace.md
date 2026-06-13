---
description: Traceability matrix — FR → FN → Plan → Test → Evidence ตัวไหนครบ ตัวไหนขาด + อัปเดตตาราง SRS §10
---

# /ow-trace — Traceability Matrix

ตอบคำถามเดียว: **"สัญญาใน SRS ครบหรือยัง"** — FR แต่ละข้อมี FN spec ไหม วาง plan หรือยัง
implement แล้วยัง มี test + evidence รองรับไหม — สรุปเป็นตารางเดียว มองปุ๊บรู้ว่าเหลืออะไร

> read-only ต่อโค้ดและ vault — เขียนไฟล์เฉพาะโหมด `--update` (แตะแค่ตาราง §10 ของ SRS เท่านั้น)

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
/ow-trace                     # ทุก SRS ใน vault
/ow-trace <srs-slug>          # เฉพาะ SRS เดียว
/ow-trace --gaps              # แสดงเฉพาะ FR ที่ยังขาดอะไรสักอย่าง (short mode)
/ow-trace --update            # เขียนผล derive กลับตาราง §10 Traceability ของ SRS
```

Default = report ใน chat เท่านั้น ไม่แตะไฟล์ใดๆ

## Phase 1 — Collect FR inventory

1. หา SRS ทั้งหมด (หรือตัวที่ user ระบุ): `grep -l 'type/srs' "$PRD_DIR"/SRS-*.md`
2. ดึง FR id + title จาก § 3 headings: `grep -E '^### FR-[0-9]+' <srs>` + บรรทัด `**Priority**`
3. ดึง NFR ids ด้วย (report แยกตาราง — NFR ส่วนใหญ่ verify ที่ระดับ release ไม่ใช่ per-plan)

ทุกตัวเลขที่นับ ต้องมาจาก grep/parse จริง — no-fake-evidence ใช้กับ report นี้เต็มรูปแบบ

## Phase 2 — Map coverage chain (ต่อ FR)

| Chain link | แหล่งข้อมูล (ของจริงเท่านั้น) |
|---|---|
| FR → FN | frontmatter `source_fr:` ใน `$FN_DIR/*.md` + `status:` ของ FN (spec/implemented/deprecated) |
| FR → Plan | section `## FR Coverage` ใน `$PLAN_DIR/*.md` + frontmatter `status:` ของ plan |
| FR → Test | TP ที่ FN §14 link ไว้ หรือตาราง §10 เดิมของ SRS ระบุ — ไฟล์ต้องมีจริงใน `$TEST_DIR` |
| Test → Evidence | `EVIDENCE.md` manifest ใต้ `$EVIDENCE_ROOT` ที่ `doc:` ชี้ TP/plan นั้น + นับ row ตาม `State` |

```bash
[ -n "$FN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# ตัวอย่าง: FN ที่ implement FR-012
grep -l 'source_fr:.*FR-012' "$FN_DIR"/*.md
# plan ที่ประกาศ cover FR-012
grep -l 'FR-012' "$PLAN_DIR"/*.md
# manifest ที่มี PASS
find "$(dirname "$(dirname "$EVIDENCE_ROOT")")" -name EVIDENCE.md -exec grep -l 'PASS' {} \;
```

## Phase 3 — Derive status ต่อ FR

เช็คจากบนลงล่าง ตัวแรกที่ตรง = status:

| เงื่อนไข | Status |
|---|---|
| ไม่มี FN และไม่มี plan ไหนอ้างถึง | `not-started` |
| มี FN แต่ไม่มี plan (หรือ plan ทั้งหมด `abandoned`) | `spec-only` |
| plan ล่าสุด `planning` / `approved` | `planned` |
| plan ล่าสุด `in-progress` | `in-progress` |
| plan `done` (หรือ FN `status: implemented`) แต่ไม่มี manifest PASS | `implemented — pending evidence` |
| มี manifest ที่ TC เกี่ยวข้อง `State: PASS` ≥ 1 | `verified` |

**Drift / orphan checks** (รายงานแยก section):

- `ORPHAN_FN` — FN ที่ `source_fr` ชี้ FR ที่ไม่มีจริงใน SRS ไหนเลย
- `PLAN_DRIFT` — plan อ้าง FR ที่ไม่มีจริง
- `STALE_TABLE` — ตาราง §10 ใน SRS ไม่ตรงกับผล derive → แนะนำรัน `--update`
- `LOOSE_TP` — test plan ที่ไม่ถูก FN/SRS ตัวไหน link (info เฉยๆ ไม่ block)
- FR↔FN ที่ mapping กำกวม (เช่น FN list หลาย FR แบบ wildcard) → `UNMAPPED` — list ให้ user ตัดสิน ห้ามเดา

## Phase 4 — Report

ตารางต่อ SRS (chat):

```
## SRS-<slug> — coverage 12/20 FR verified (60%)

| FR | P | FN | Plan | Test | Evidence | Status |
|---|---|---|---|---|---|---|
| FR-001 | P1 | [[FN-api-login]] | [[2026-06-01-1030-login]] | [[TP-login]] | PASS 3/3 | verified |
| FR-002 | P1 | [[FN-api-reset]] | — | — | — | spec-only |
| FR-003 | P2 | — | — | — | — | not-started |

### Summary
- verified: 12 · implemented—pending evidence: 2 · in-progress: 1 · planned: 0 · spec-only: 3 · not-started: 2

### Gaps (actionable)
- FR-002, FR-007 ไม่มี plan       → /ow-plan <task>
- FR-003, FR-015 ไม่มี FN spec    → /ow-doc function <slug>
- FR-009 implement แล้ว ไม่มี test → /ow-test
- FR-011 มี test ไม่มี evidence    → /ow-verify (จะ flag pending evidence)

### Drift
- ORPHAN_FN: FN-web-export (source_fr: FR-099 — ไม่มีใน SRS)
- STALE_TABLE: SRS-checkout §10 ล้าหลัง 4 แถว → /ow-trace checkout --update
```

คอลัมน์ใช้ wikilink จริงเมื่อไฟล์มี, `—` เมื่อไม่มี · `--gaps` mode แสดงเฉพาะแถวที่ status ≠ `verified`

## Phase 5 — `--update` mode

1. เขียนทับ**เฉพาะ**ตาราง `## 10. Traceability` ของ SRS ที่เกี่ยว — ห้ามแตะ section อื่น
2. Status column = ค่าที่ derive จาก Phase 3 (ห้ามใส่ค่าที่อยากให้เป็น)
3. **ไม่แตะ** `$IMPL_STATUS` — นั่นของ `/ow-doc`/`/ow-handoff`; ถ้าเห็นไม่ sync ให้รายงานเฉยๆ

## Output (3 หัวข้อบังคับ)

1. **Result** — ตาราง coverage ต่อ SRS + summary นับต่อ status + จำนวน gap/drift (+ ไฟล์ SRS ที่อัปเดตถ้า `--update`)
2. **Verification / Evidence** — grep/find commands ที่ใช้นับจริง + จำนวนไฟล์ที่ scan (SRS n, FN n, plan n, TP n, manifest n)
3. **Limitations / Next steps** — FR ที่ขาดอะไร + command ถัดไปต่อ gap · mapping ที่ `UNMAPPED` รอ user ตัดสิน

## ห้าม

- ห้ามแก้โค้ด / สร้าง doc ใหม่ — command นี้ read-only ยกเว้นตาราง §10 ในโหมด `--update`
- ห้ามแต่งตัวเลข coverage — ทุกค่ามาจาก grep/parse จริง ตรวจซ้ำได้
- ห้าม mark `verified` โดยไม่มี manifest `PASS` จริง — ไม่มี = `implemented — pending evidence`
- ห้ามเดา mapping ที่กำกวม — list เป็น `UNMAPPED` ให้ user ตัดสิน
