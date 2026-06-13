---
description: Finalize evidence — cleanup (archive files outside the manifest) + verify + PII audit (local-only)
---

# /ow-evidence — Finalize Evidence (local-only)

`/ow-evidence` **finalize** evidence ที่ถูก capture ไว้แล้ว — ไม่ได้ capture เอง. ตัว capture เกิดที่
`/ow-implement` (Phase 5) · `/ow-fix-issue` (agent) · `/ow-fix` (Phase 2.5) · `/ow-test` (Phase 4)
ซึ่ง**เขียน `EVIDENCE.md` manifest ตั้งแต่ตอน capture** ลง `test-artifacts/<date>/<source>-<NN>-<slug>/`

> **Evidence model:** source of truth = `EVIDENCE.md` manifest ใน `test-artifacts/` (gitignored, นอก vault).
> Vault doc **ไม่เก็บ** evidence index — manifest ชี้กลับ vault ผ่าน field `doc:`
> Evidence อยู่ local เท่านั้น — ไม่มี cloud upload

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules testing)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-evidence                       # 🌟 DEFAULT — finalize ทุก manifest ของวันนี้ (cleanup + verify)
/ow-evidence --since <date>        # finalize manifest ตั้งแต่ <date> (default: วันนี้)
/ow-evidence --slug <slug>         # เฉพาะ folder ที่ slug ตรง (เช่น fix-94-login-dropdown)
/ow-evidence --dry-run             # แสดงว่าจะ archive อะไร — ไม่ทำจริง
/ow-evidence list                  # list manifest + สถานะ (complete / incomplete)
/ow-evidence verify                # ตรวจ manifest table vs filesystem (ไฟล์ครบ + ไม่มีไฟล์หลุดนอก manifest)
/ow-evidence audit                 # PII/secret scan ใน evidence
```

## Phase 1 — Discover manifests

```bash
# manifests ทั้งหมดใต้ test-artifacts/ (gitignored). EVIDENCE_ROOT encode {date}/{source}-{slug}
# อยู่แล้ว — สแกนระดับ test-artifacts/ เพื่อหา EVIDENCE.md ทุก folder
ART_ROOT=$(printf '%s' "$EVIDENCE_ROOT" | sed 's#/[^/]*/[^/]*$##')   # → test-artifacts
SINCE="${SINCE:-$EVIDENCE_DATE}"                                     # default = today's date dir
find "$ART_ROOT" -mindepth 2 -maxdepth 3 -name 'EVIDENCE.md' 2>/dev/null
```

แต่ละ `EVIDENCE.md` = 1 manifest (1 fix / plan / test-case). อ่าน front-matter
(`source` / `slug` / `issue` / `doc` / `build` / `test`) + ตาราง index

🔴 **ไม่มี manifest = ไม่มีอะไรให้ finalize** — แจ้ง user ว่า capture ยังไม่เกิด
(`/ow-implement` / `/ow-fix` สร้าง `EVIDENCE.md` ตั้งแต่ capture; ไม่มี = ยังไม่ได้รัน test/fix)

## Phase 2 — Cleanup (archive files outside the manifest)

ทุกไฟล์ใน slug folder ที่**ไม่อยู่ในคอลัมน์ File ของตาราง** → **ย้าย**ไป `<slug-folder>/_archive/`
(ไม่ลบ — กัน regret). `EVIDENCE.md` เอง + `_archive/` + `_debug/` ถูกข้าม

🔴 **ย้าย ไม่ลบ** · 🔴 `--dry-run` = list ไฟล์ที่จะย้าย แล้วจบ

## Phase 3 — PII scan

Re-scan ไฟล์ text (log/json/csv) หา PII (email / phone / 13-digit id) ด้วย regex; screenshot
ที่มี PII (หน้า/ลายเซ็น/บัตร) **ต้องให้ user mask ด้วยตา** — command ไม่ mask image อัตโนมัติ

```bash
sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/[email-redacted]/g' "$IN" > "$OUT"   # log mask ตัวอย่าง
```

ไฟล์ที่ PII scan ติด → **flag ใน output** จนกว่าจะ mask + user confirm

## Phase 4 — Summary

```
📦 Evidence finalize — <date>
  Manifests:        4
  Archived files:   7 → _archive/
  ✅ Complete:       3 (ทุก row มีไฟล์จริง)
  ⚠️ Incomplete:     1 (row ขาดไฟล์ / build|test ยังเป็น -)
  🚫 PII flagged:    1 (mask ก่อนแชร์)
```

## Phase 5 — verify mode (`verify`)

ต่อ manifest: ทุก **File** ในตารางต้องมีไฟล์จริง (`test -f`); ทุกไฟล์ใน folder (ยกเว้น `EVIDENCE.md`,
`_archive/`, `_debug/`) ต้อง**อยู่ในตาราง** ไม่งั้นรายงาน "untracked — รัน /ow-evidence เพื่อ archive".
รายงาน mismatch ไม่แก้เอง

## Phase 6 — audit mode (`audit`)

Scan evidence text files หา unmasked PII (email/phone/id regex) + filename ต้องสงสัย (`*customer-data*`).
รายงานผลใน chat — ไฟล์ที่ติดให้ user ตัดสินใจ mask/archive

## Output (3 หัวข้อบังคับ)

1. **Result** — manifests finalized + files archived + summary table
2. **Verification / Evidence** — ผล verify (manifest vs filesystem) ต่อ manifest
3. **Limitations / Next steps** — incomplete manifests, PII-flagged files ที่ต้อง mask

## ห้าม

- ห้าม capture evidence เอง — `/ow-evidence` finalize เท่านั้น (capture เกิดที่ implement/fix/test)
- ห้าม**ลบ**ไฟล์ใน slug folder — ไฟล์นอก manifest **ย้าย**ไป `_archive/`
- ห้ามเขียน binary ลง vault — evidence อยู่ใต้ `test-artifacts/` (gitignored) เท่านั้น
- ห้ามฝัง evidence index กลับ vault doc — vault เก็บ TEXT เท่านั้น; manifest `doc:` ชี้กลับ vault ทางเดียว
- ห้ามแก้ row ในตาราง — column ทั้งหมด writer ตอน capture เป็นเจ้าของ
