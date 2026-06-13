---
description: Release flow — gate ด้วย checklist → generate changelog จาก vault → delegate bump/tag ให้ /ow-git
---

# /ow-release — ปล่อย version

ปิดท่อนสุดท้ายของ SDLC: รวมงานที่ done ตั้งแต่ tag ล่าสุด → เขียน `CHANGELOG.md` →
bump + tag + push ผ่าน `/ow-git --bump` (logic เดียว — command นี้**ไม่ bump เอง**)

> changelog ไม่ต้องเขียนใหม่จากศูนย์ — ดึงจาก plan (`status: done`) + fix log ใน vault ที่มีอยู่แล้ว

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
/ow-release patch|minor|major        # full release: gate → changelog → /ow-git --bump
/ow-release --dry-run patch          # แสดง draft changelog + version ที่จะได้ — ไม่เขียน/ไม่ bump
/ow-release --notes-only             # เขียน/เติม CHANGELOG.md ของ tag ที่มีอยู่แล้ว — ไม่ bump
```

ไม่ระบุ kind → ถาม user (ห้ามเดา; ดู SemVer hint จาก scope: fix-only = patch, feature = minor, breaking = major)

## Phase 1 — Release gate

1. รัน checklist `.ow/checklists/before-release.md` ทีละข้อ — แสดงผลต่อข้อ
2. ตรวจว่า `/ow-verify` รอบล่าสุดของ scope **ผ่าน** — ดูจาก evidence/manifest จริง
   ไม่มีหลักฐาน verify → **STOP**: บอก user รัน `/ow-verify` ก่อน (ห้าม release บนคำว่า "น่าจะผ่าน")
3. `git status` ทุก repo — working tree ต้อง clean หรือมีเฉพาะไฟล์ที่อยู่ใน release scope

Gate ไม่ผ่านข้อไหน → STOP + list สิ่งที่ต้องแก้ ไม่มี `--force`

## Phase 2 — Collect changes since last release

ทุกรายการมาจาก command จริง (no-fake-evidence):

```bash
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
LAST_TAG=$(git tag --list 'v*.*.*' | sort -V | tail -1)    # ไม่มี tag = first release (range ทั้งหมด)
RANGE="${LAST_TAG:+$LAST_TAG..}HEAD"
git log "$RANGE" --format='%h %s'                          # commits ในรอบ
# plans ที่ done ในรอบ
grep -l 'status: done' "$PLAN_DIR"/*.md
# fix logs ที่ถูก stamp ในรอบ (fixed_in_version / fixed_commit จาก /ow-git Phase 8.6)
grep -l 'fixed_commit:' "$FIX_DIR"/*.md
# GitHub issues ที่ปิดในรอบ
git log "$RANGE" --format=%B | grep -ioE '(close[sd]?|fixe?[sd]?) #[0-9]+' | grep -oE '#[0-9]+' | sort -u
```

Cross-check: commit ที่ไม่ map กับ plan/fix ไหนเลย → list เป็น `unattributed` ให้ user จัดหมวดเอง

## Phase 3 — Draft changelog

Format ตาม [Keep a Changelog](https://keepachangelog.com) — หมวด: `Added` (plan feat) /
`Changed` / `Fixed` (fix logs + `Closes #NN`) / `Security` / `Removed`:

```markdown
## [vX.Y.Z] - YYYY-MM-DD

### Added
- <plan title> ([[80-ImplementPlan/<slug>]])

### Fixed
- <fix title> (#62) ([[85-FixLog/<slug>]])
```

- เลข `vX.Y.Z` preview ด้วยสูตรเดียวกับ `/ow-git` Phase 5.5 (max ของ tag ทุก repo + kind) —
  ตัวจริงคือ `TARGET_VERSION` ที่ `/ow-git --bump` คำนวณใน Phase 5; ถ้าไม่ตรง preview → แก้ header ก่อน push
- ทุก bullet ต้องชี้ commit / plan / fix / issue ที่มีจริง — ไม่มีที่มา = ห้ามใส่
- ภาษา user-facing สั้นๆ — ไม่ใช่ copy commit message ดิบ

## Phase 4 — User approval (STOP)

แสดง draft changelog + version ที่จะ bump + repo ที่จะ tag → **รอ user ยืนยัน**
Release เป็น decision ของ user เสมอ — เหมือนกฎ `--bump` ของ `/ow-git`
(`--dry-run` จบที่ phase นี้)

## Phase 5 — Write + delegate bump

1. เขียน/prepend section ใหม่ลง `CHANGELOG.md` ที่ repo root (สร้างไฟล์ถ้ายังไม่มี
   พร้อม header มาตรฐาน Keep a Changelog) — แก้เฉพาะ section ของ version นี้
2. `git add CHANGELOG.md` แล้ว delegate:
   ```
   /ow-git --message "chore(release): vX.Y.Z" --bump <kind>
   ```
   bump/tag/push/unified-version/issue-handoff ทั้งหมดเป็นงานของ `/ow-git` Phase 5.5-8.6 —
   **ห้าม duplicate logic ที่นี่** (pattern เดียวกับ ow-git Phase 8.5 delegate ไป fix-issue)
3. `--notes-only`: ข้ามข้อ 2 — เขียน CHANGELOG ของ `$LAST_TAG` ย้อนหลังเท่านั้น

## Phase 6 — Post-release

1. เทียบ `TARGET_VERSION` จริง (tag ที่เกิด) กับ header ใน CHANGELOG — ไม่ตรง = แก้ทันทีก่อนจบ
2. แนะนำ next: `/ow-trace --update` (refresh SRS §10 หลัง release) + `/ow-handoff` ถ้าจบ session

## Output (3 หัวข้อบังคับ)

1. **Result** — version ที่ release + CHANGELOG section ที่เขียน + repo/tag summary (จาก /ow-git report)
2. **Verification / Evidence** — gate checklist ผลต่อข้อ + `git tag` / push results จริง + commands ที่ใช้ collect (Phase 2); ไม่ได้รัน = `pending evidence`
3. **Limitations / Next steps** — commit `unattributed` ที่ user ควรจัดหมวด + งานที่หลุดรอบนี้

## ห้าม

- ห้าม bump / tag / push เอง — delegate `/ow-git --bump` เท่านั้น (logic เดียว ห้าม duplicate)
- ห้าม release ถ้า gate ไม่ผ่าน — ไม่มี `--force`; verify ไม่มีหลักฐาน = ไม่ผ่าน
- ห้ามแต่ง changelog entry ที่ไม่มี commit/plan/fix/issue รองรับ — no-fake-evidence
- ห้ามรันอัตโนมัติ — user เรียกเท่านั้น และต้องยืนยัน Phase 4 ก่อนเขียน/bump
- ห้ามแก้ CHANGELOG section ของ version เก่า (immutable history) — ยกเว้น user สั่งชัดเจน
