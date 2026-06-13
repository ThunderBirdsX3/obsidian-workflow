---
description: สร้าง session handoff note — สรุปงานเพื่อต่อ session หน้า + อัปเดต status
---

# /ow-handoff — ส่งต่องานข้าม session

สร้าง note สั้นๆ ให้ session ถัดไป (ตัวเองหรือ AI ตัวใหม่) เปิดมาแล้ว**ทำต่อได้ทันที** —
ไม่ใช่รายงาน ไม่มีพิธีการ

> ควรรัน `/ow-verify` ให้ผ่านก่อนถ้างานถึงจุด verify ได้ — งานค้างกลางทางก็ handoff ได้

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
/ow-handoff <plan-or-fix-path>     # handoff งานจาก plan/fix ที่ระบุ
/ow-handoff --feature <name>       # handoff ทั้ง feature
/ow-handoff --since <ref>          # handoff ทุกอย่างใน diff range
```

ว่าง → handoff งานของ session ปัจจุบัน (สรุปจาก context ที่คุยกันอยู่ + git status/diff)

## Phase 1 — Pre-flight

1. อ่าน plan/fix file ที่เกี่ยว (ถ้ามี)
2. อ่าน `EVIDENCE.md` manifest ของงานนี้ใต้ `test-artifacts/<date>/<source>-<NN>-<slug>/` (ถ้ามี)
3. `git status` + `git diff --stat` — งาน uncommitted ต้องถูกบันทึกใน note
4. งานยังไม่ done = ปกติ — handoff คือการบันทึกสถานะจริง ไม่ใช่ certificate

## Phase 2 — สร้าง Handoff Note

Path: `$HANDOFF_DIR/HANDOFF-<YYYY-MM-DD>-<slug>.md` ตาม `.ow/templates/handoff.md`:

```markdown
---
tags: [type/handoff]
date: YYYY-MM-DD HH:mm
title: <handoff title>
scope: <plan-slug | feature-name | diff-range>
status: open                 # open | continued | closed
related_plan: "[[<plan-slug>]]"
---

# <Title>

## Summary
<สรุปงานที่ทำ + สถานะปัจจุบัน 2-4 ประโยค>

## What Changed
- Files changed: N (production: M, tests: K)
- <feature/fix ที่เสร็จ> + Docs updated

## Verification
- Tests: <N passed / M total> — evidence: <test-artifacts path>
- Build / Lint: <pass|fail|not run>
- Working level: <compiles | lint clean | tests pass | local smoke>

## Remaining Work
- [ ] <งานที่ยังไม่เสร็จ + ไฟล์/จุดที่ค้าง>

## Context for Next Session
<gotcha, ทางที่ลองแล้วไม่ work, ไฟล์ที่ต้องอ่านก่อน>

## Next Steps
1. <ขั้นถัดไปที่แนะนำ>
```

ทุกตัวเลข (tests, files changed) ต้องมาจาก command จริง — no-fake-evidence

## Phase 3 — อัปเดต status

1. Plan frontmatter: `status:` ตามจริง (done ถ้าเสร็จ / in-progress ถ้าค้าง)
2. `$IMPL_STATUS` → update scope status
3. Session ถัดไปเปิดงานต่อ → set handoff note `status: continued`

## Output (3 หัวข้อบังคับ)

1. **Result** — handoff note path + status ที่อัปเดต
2. **Verification / Evidence** — ตัวเลขใน note มาจาก command ไหน (git diff --stat, test output)
3. **Limitations / Next steps** — remaining work ที่ note ระบุ

## ห้าม

- ห้าม fake evidence ใน handoff note — ตัวเลขทุกตัวมาจากการรันจริง
- ห้ามเขียน "done" ถ้า success criteria ยังไม่ครบ — บันทึกสถานะจริง
- ห้ามใส่ PII/secret ลง note
