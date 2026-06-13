---
description: Diagnose bug + create fix-log with evidence trail (no code change)
---

# /ow-fix — Diagnose bug (ไม่แก้โค้ด)

วินิจฉัย + เตรียม fix-log + เก็บ before evidence เท่านั้น
**code change ทั้งหมดต้องผ่าน `/ow-implement`** — ห้ามแก้ตรงๆ ใน /ow-fix

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
/ow-fix <bug description>
/ow-fix <bug> --update <fix-log-path>
```

ว่าง → ถาม "บั๊กอะไร?"

## Phase 1 — Detect mode

| Arg | Mode |
|---|---|
| free text | **New** fix-log |
| `--update <path>` | **Append** section ใน existing fix-log |

## Phase 2 — Diagnose (read-only)

ก่อนเขียนไฟล์:
1. ระบุ submodule/area (api / web / mobile / cross)
2. Reproduce ถ้าทำได้ (start dev server เท่าที่จำเป็น; preferred: read code)
3. หา root cause ผ่าน grep/Read — **ห้ามแก้โค้ด**
4. ร่าง **Success Criteria** (fixed behavior + regression ที่ต้องไม่พัง + out-of-scope) → map กับ test cases ที่จะพิสูจน์ว่า bug หาย

Bug ไม่ชัด → ถาม 1-3 คำถาม **ใน message เดียว**

## Phase 2.5 — Before-Evidence Baseline (🔴 capture RED proof — ยัง diagnose-only)

บันทึก state ที่ bug **ยังอยู่** เพื่อให้ `/ow-implement` พิสูจน์ red→green ได้ (RED ที่นี่ / GREEN ตอน implement)

> ยัง **ห้ามแก้โค้ด** — phase นี้คือการ *สังเกต+บันทึก* ไม่ใช่แก้ ไม่ใช่เขียน test ใหม่

```bash
[ -n "$EVIDENCE_ROOT" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# Evidence binaries go to the gitignored EVIDENCE_ROOT (test-artifacts/...), NEVER the
# vault — the resolver owns the {source}/{slug} expansion.
# slug ต้อง traceable: ใส่เลข GitHub issue ถ้า bug มาจาก issue (#NN ใน $ARGUMENTS),
# ไม่งั้นใช้ fix-log timestamp id นำหน้า → folder = test-artifacts/<date>/fix-<NN|TS>-<slug>/
NN=$(echo "$ARGUMENTS" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
TS=$(date +%Y%m%d%H%M)
SLUG="${NN:-$TS}-<short-bug-slug>"
EVIDENCE_DIR=$(OW_EVIDENCE_SOURCE=fix OW_EVIDENCE_SLUG="$SLUG" \
  bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --check EVIDENCE_ROOT)
mkdir -p "$EVIDENCE_DIR"
# Bootstrap the canonical EVIDENCE.md manifest at capture START — front-matter: source=fix,
# slug=$SLUG, issue=${NN:+#$NN}, doc=[[<fix-log slug>]]; ตาราง | ID | File | TC | State | Type |
# เริ่มว่าง แล้วเพิ่ม 'before' row ทุกครั้งที่ capture artifact
cp "$(git rev-parse --show-toplevel)/.ow/templates/evidence/EVIDENCE.md" "$EVIDENCE_DIR/EVIDENCE.md" 2>/dev/null
```

🔴 **`fix-<NN|TS>-<slug>/` = folder เดียวของ task ตลอด flow** — `/ow-implement` + `/ow-test` จะ **reuse**
folder นี้ (match ด้วย issue#) แล้ว append after/GREEN + smoke ลง `EVIDENCE.md` เดียวกัน ไม่เปิด `plan-*`/`smoke-*` ใหม่.
(issue-driven `/ow-fix-issue` ทำ diagnose+implement+test ครบใน folder เดียวนี้อยู่แล้ว)

เก็บอย่างน้อย 1 อย่าง (ตามชนิด bug):
1. **มี test reproduce อยู่แล้ว** → รันให้เห็น FAIL: `{ <test-cmd> 2>&1; echo "EXIT=$?"; } > "$EVIDENCE_DIR/before-test-output.txt"`
2. **UI bug** → before screenshot (prefer ดึงจาก issue attachment ถ้ามาจาก issue / ไม่งั้น capture หน้าที่เกิด bug — ไม่เริ่มจาก /login)
3. **ไม่ใช่ UI / ยังไม่มี test** → error log / console output / stack trace ที่พิสูจน์ว่า bug reproduce

🔴 ระบุใน fix-log `## Before Evidence` ว่าเก็บอะไร + path — ถ้าเก็บไม่ได้ ให้เขียน `pending evidence` (ห้ามแต่ง)

🔴 **reproduce test ที่จะ "เขียนจริง" เป็นหน้าที่ `/ow-implement`** — fix-log แค่ *ระบุ* test case ที่ต้อง FAIL→PASS (ดู Test Cases ใน template)

## Phase 3 — สร้าง fix-log

Path: `$FIX_DIR/YYYY-MM-DD-HHMM-<slug>.md`

```markdown
---
tags: [type/fix-log]
date: YYYY-MM-DD HH:mm
title: <one-line bug title>
status: in-progress         # in-progress | fixed | wont-fix | regressed
severity: P1                # P0 blocker | P1 major | P2 minor | P3 polish
area: <api | web | mobile | cross>
reported_by: <user | qa | self | customer>
related_plan: <"[[plan-slug]]" or none>   # /ow-fix→/ow-plan path: /ow-plan fix: เขียน back-link; ปิด auto โดย /ow-implement
# fixed_commit / fixed_in_version — เติม auto ตอนปิด (/ow-fix-issue เขียน merge hash ตอน merge local; version stamp โดย /ow-git --bump — ห้ามกรอกมือ)
---

# <Bug title>

## Symptom
<what user sees / what's broken>

## Reproduction
1. <step 1>
2. <step 2>
3. <expected vs actual>

## Success Criteria
<!-- bug success criteria: อะไรต้องกลับมาถูก + อะไรต้องไม่พัง (regression). map กับ Test Cases ทีละข้อ -->
- [ ] <fixed behavior — อาการหาย> — verify via TC-01
- [ ] <regression: feature ใกล้เคียง X ยังทำงาน> — verify via TC-02
- [ ] Out of scope: <unrelated refactor/cleanup ที่ "จะไม่ทำ" ใน fix นี้>

## Root Cause
<technical cause — file path, function, line — from grep/read>

## Vault Context Read
- FN-<related> (จาก $FN_DIR)
- REF-AuthorizationMatrix (จาก $REF_DIR — ถ้าเกี่ยว auth)
- fix-log เก่าที่อาการคล้ายกัน (จาก $FIX_DIR — ถ้าเคยมี regression)

## Before Evidence
<!-- Evidence folder: $EVIDENCE_DIR (= test-artifacts/<date>/fix-<NN|TS>-<slug>/, gitignored, นอก vault),
     indexed by its EVIDENCE.md manifest — RED proof ก่อน fix. Vault เก็บแค่ text นี้ -->
- Before test output: `before-test-output.txt` (test FAIL / EXIT≠0) — หรือ `pending evidence`
- Before screenshot: `before-<slug>.png` (UI bug state) — หรือ N/A (ไม่ใช่ UI)
- Console / error log: <path or paste>

## Fix Approach
<paragraph อธิบาย fix ที่จะทำ — ยังไม่ใช่โค้ด>

## Affected Files
- `path/file1.ts` — <what to change>
- `path/file2.ts` — <what to change>

## Test Cases (พิสูจน์ red→green — `/ow-implement` จะรันตาม list นี้)
<!-- บังคับ: reproduce test (FAIL ก่อน fix) + regression test อย่างละ ≥1; ระบุ layer -->
- [ ] TC-01: <layer (unit/integration/e2e)> — <reproduce scenario + expected> — ต้อง FAIL ก่อน fix → PASS หลัง fix
- [ ] TC-02: (regression) <layer> — <adjacent feature ที่ต้องยังทำงานได้>

## Risk
- ความเสี่ยงของ fix นี้ + mitigation

## Next
- [ ] รัน `/ow-plan fix:<slug>` — สร้าง plan + ผูก link สองทาง (`source_fix:` ↔ `related_plan:`)
- [ ] รัน `/ow-implement <plan-path>` เพื่อแก้จริง (capture after-evidence + พิสูจน์ red→green)
- [ ] ปิด fix-log: `status: fixed` + tick checkboxes — 🤖 **auto โดย `/ow-implement` ตอน plan done**; `fixed_in_version`/`fixed_commit` เติมโดย `/ow-git --bump` (ไม่ต้องทำมือ)
```

## Phase 4 — Auto-link plan

หลังสร้าง fix-log → เสนอ:

> Fix-log สร้างแล้ว: `$FIX_DIR/2026-05-20-1530-search-not-returning-results.md`
>
> ตัวเลือก:
> - **A)** สร้าง implement plan จาก fix-log นี้: `/ow-plan fix:<slug>` → pre-fill plan + ผูก link สองทาง (`source_fix:` ↔ `related_plan:`) → fix-log นี้ถูก **ปิดอัตโนมัติ** (`status: fixed`) เมื่อ plan `done`
> - **B)** บั๊กเล็ก ข้าม plan ไปเลย: `/ow-implement --from-fix <fix-log-path>` (P3 polish เท่านั้น) → `/ow-implement` ปิด fix-log นี้เองตอนเสร็จ
> - **C)** บั๊กยังไม่ urgent — ปิดไว้ก่อน status: in-progress

🔴 เลือก A/B → ไม่ต้องปิด fix-log มือ (`status: fixed` + checkboxes auto โดย `/ow-implement`; `fixed_in_version`/`fixed_commit` โดย `/ow-git --bump`). เลือก C → คงค้าง `in-progress` จนกว่าจะ escalate

🔴 escalation เป็น **1:1** — 1 fix-log ↔ 1 plan; บั๊กที่ 2 → fix-log ใหม่ + plan ใหม่ (ตรงตาม fix-source mode ของ `/ow-plan`)

## Phase 5 — Update mode (`--update`)

อ่าน existing fix-log → append section ใหม่:
- Investigation update
- New evidence
- Status change (เช่น `in-progress` → `regressed` พร้อม reason)

ไม่ overwrite ของเดิม

## Severity guide

| Level | ใช้เมื่อ |
|---|---|
| P0 — blocker | prod down / data loss / security breach |
| P1 — major | feature broken กระทบผู้ใช้กว้าง, มี workaround |
| P2 — minor | edge case / wrong behavior, workaround ง่าย |
| P3 — polish | cosmetic / copy / a11y / small UX |

## Output (3 หัวข้อบังคับ)

1. **Result** — fix-log path + severity/area + root cause หนึ่งบรรทัด
2. **Verification / Evidence** — commands ที่รันจริงเพื่อ confirm root cause (grep, Read, `git log -S <symbol>`) + before evidence ที่เก็บได้ (paths) หรือ `pending evidence`
3. **Limitations / Next steps** — "Fix ยังไม่ทำ — เลือก A (/ow-plan fix:<slug>) / B (/ow-implement --from-fix) / C (พักไว้)" + risk จาก fix-log

## ห้าม

- ห้ามแก้โค้ดใน /ow-fix — code change ทั้งหมดผ่าน `/ow-implement` เท่านั้น
- ห้ามเดา root cause โดยไม่ verify ที่ source (grep/read)
- ห้ามแต่ง error message / stack trace / before-evidence — เก็บไม่ได้ให้เขียน `pending evidence`
- ห้ามข้าม Success Criteria + Test Cases — ต้องมี reproduce test (FAIL ก่อน fix) + regression test ≥1 ก่อน route ไป `/ow-implement`
- ห้าม `--update` แบบ overwrite — append section ใหม่ (Updates) เท่านั้น
