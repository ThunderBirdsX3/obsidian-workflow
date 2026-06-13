---
description: Execute approved plan file via subagent — captures evidence, syncs vault
---

# /ow-implement — ลงมือทำตาม plan

Execute plan file ที่ approve แล้ว spawn subagent ที่ถูกต้อง เก็บ evidence

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
/ow-implement <plan-path>           # $PLAN_DIR/YYYY-MM-DD-HHmm-<slug>.md
/ow-implement <slug>                # auto-locate by slug ใน $PLAN_DIR
/ow-implement <plan> --worktree     # บังคับ build ใน git worktree แยก (แม้ plan frontmatter ไม่มี worktree:)
/ow-implement <plan> --no-worktree  # บังคับ build ใน main tree (override plan ที่มี worktree: true)
/ow-implement --from-fix <fix-log-path>   # P3 polish เท่านั้น — ข้าม plan; ปิด fix-log นี้เองตอน done (6.5)
```

ว่าง → ถามว่า plan ไหน + list 5 plans ล่าสุดที่ `status: approved`

> `--from-fix` = escape hatch สำหรับ P3 polish ที่ข้าม `/ow-plan` (ดู /ow-fix option B). โหมดนี้ **fix-log = หน่วยงาน** (ไม่มี plan แยก): Phase 1 ข้าม `status: approved` gate (invoke = approval); evidence/coverage/discipline gate (5.0/5.2/5.3) + open-checkbox gate (6.0) รันกับ fix-log; Phase 6 ปิด fix-log เป็น `status: fixed` ผ่าน Phase 6.5 (แทน plan `status: done`). บั๊กที่ใหญ่กว่า P3 → ใช้ `/ow-plan fix:<slug>` ก่อนเสมอ

## Phase 1 — Validate

1. อ่าน plan file
2. **Refuse** ถ้า `status != approved` → แจ้ง user ให้ set status ก่อน
3. **Refuse** ถ้า `status: done` แล้ว → แจ้ง user
4. ตรวจว่า `Implementation Steps` ครบ + `subagent_target` set
5. **Resolve target repo** — plan ไม่มี field repo: monorepo = main root; multi-repo → infer submodule
   จาก path ใน `Affected Files` เทียบ prefix กับ `submodules:` config (resolver `--submodules`);
   ก้ำกึ่ง/แตะหลาย repo → แจ้ง user ก่อนเริ่ม
6. แสดง task + subagent_target + repo + step count → ถาม "ลงมือเลย?"
7. ถ้า `Doc Gaps Found` ไม่ว่าง → ไป Phase 2 ก่อน

## Phase 2 — Fix doc gaps (ถ้ามี)

Spawn `docs` subagent — prepend **PROJECT CONTEXT block** (assemble แบบเดียวกับ Phase 3) แล้วส่ง
**Doc Brief ที่คิด design เสร็จแล้ว**: orchestrator (model ใหญ่) เป็นชั้นคิด — docs agent เป็น executor
ที่รัน model เล็กได้ ห้ามโยน gap ดิบๆ ให้ agent ไปตีความเอง:
```
<PROJECT CONTEXT block>

Plan: <path>
Doc Brief (ต่อ gap — ระบุให้ครบ ไม่ให้ agent ต้องเดา):
- <vault-file>: <create|edit|fix-gap> §<section> — เนื้อหาจาก <plan §X | SRS FR-###> — wikilink: [[...]]
- ...
Rule: แก้ factual discrepancy เท่านั้น ห้ามเปลี่ยน implementation intent
ถ้า gap ไหนติด design-level (spec ขัดกัน / โครงไม่ชัด / เนื้อหาไม่มี source) → ESCALATE ตาม protocol §4.5 ของ agent — ห้ามเดา
```

รอจบ → ถ้า hand-back มี **Escalations**: แสดง recommended command ต่อ user ตรงๆ (เช่น `/ow-clarify SRS-X`)
แล้วรอ decision เฉพาะ item นั้น — **ห้าม retry เงียบๆ หรือเติมเนื้อหาแทน agent เอง**; item ที่ไม่ติดไป Phase 2.7 ต่อได้

## Phase 2.7 — Resolve mode + Worktree Setup

🔴 **2.7.1 รันเสมอทุก mode** (เป็น mode gate + set `WORK_ROOT`/`PLAN_PATH`/`MAIN_ROOT` ที่ Phase 3-6 ใช้);
**2.7.2–2.7.3 รันเฉพาะ worktree mode** (สร้าง worktree จริง). normal mode = `WORK_ROOT=$MAIN_ROOT` (build ใน main tree).

worktree mode build ใน **git worktree แยก** เพื่อ **กัน main working tree ไม่ให้ถูกแตะ** (งาน uncommitted คู่ขนานปลอดภัย)
แล้ว `/ow-test` จะ auto-merge กลับเมื่อ test ผ่าน. mirror `/ow-fix-issue` Phase 3 แต่เป็น **single task** (ไม่ parallel).

> 🔑 **WORK_ROOT contract** (ใช้ตลอด Phase 3-6): **โค้ด** (subagent cwd · `git diff` · build/test) → `$WORK_ROOT`;
> **vault + plan file + evidence** (`$VAULT_ABS` · `$PLAN_DIR` · `$EVIDENCE_DIR`) → **`$MAIN_ROOT` absolute เสมอ**.
> ⇒ worktree commit = **โค้ดล้วน**, merge กลับ = โค้ดล้วน → ไม่ชน vault/plan-file copy ใน worktree.

### 2.7.1 Resolve mode (รันเสมอ — flag override > plan frontmatter > off)
```bash
[ -n "$VAULT_ABS" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# $ROOT จาก Phase 0 (--shell) = absolute project root. fallback = git toplevel (orchestrator อยู่ main tree
# ตอนนี้เสมอ — worktree ยังไม่ถูกสร้างจนถึง 2.7.2) เผื่อ bash block แยก call แล้ว $ROOT ไม่ persist
MAIN_ROOT="${ROOT:-$(git rev-parse --show-toplevel)}"
PLAN_PATH=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--(no-)?worktree//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
WT_MODE=off
grep -q '^worktree:[[:space:]]*true' "$PLAN_PATH" 2>/dev/null && WT_MODE=on   # plan frontmatter (จาก /ow-plan --worktree)
case " $ARGUMENTS " in *" --worktree "*)    WT_MODE=on ;;  esac               # explicit flag ชนะ frontmatter
case " $ARGUMENTS " in *" --no-worktree "*) WT_MODE=off ;; esac               # --no-worktree ชนะสุด
WORK_ROOT="$MAIN_ROOT"                                # default = build ใน main tree (ไม่เปิด worktree)
```
🔴 ทุก phase ต่อจากนี้ใช้ **`$PLAN_PATH`** (strip flag แล้ว) เป็น plan file — ไม่ใช่ `$ARGUMENTS` ดิบ
`WT_MODE=off` → **ข้าม 2.7.2–2.7.3** ไป Phase 3 (`WORK_ROOT=$MAIN_ROOT`).

### 2.7.2 Create worktree (WT_MODE=on)
```bash
mkdir -p "$MAIN_ROOT/worktrees"
grep -qx 'worktrees/' "$MAIN_ROOT/.gitignore" 2>/dev/null || echo 'worktrees/' >> "$MAIN_ROOT/.gitignore"

BASE=$(git -C "$MAIN_ROOT" rev-parse --abbrev-ref HEAD)
[ "$BASE" = HEAD ] && { echo '🛑 main tree = detached HEAD — checkout branch ก่อน หรือใช้ --no-worktree'; exit 1; }

SLUG=$(basename "$PLAN_PATH" .md)
WT="$MAIN_ROOT/worktrees/plan-$SLUG"                  # gitignored (Phase 2.7.2 ensure)
BR="plan/$SLUG"

# แตกจาก **local HEAD** (รวม local commit, ไม่รวม uncommitted ของ main tree → งานคู่ขนานปลอดภัย).
# ไม่ fetch / ไม่แตะ network. มี worktree อยู่แล้ว → reuse (re-run idempotent).
if git -C "$MAIN_ROOT" worktree list --porcelain | grep -qx "worktree $WT"; then
  echo "♻️  reuse worktree ที่มีอยู่: $WT"
else
  git -C "$MAIN_ROOT" worktree add -b "$BR" "$WT" HEAD \
    || git -C "$MAIN_ROOT" worktree add "$WT" "$BR" \
    || { echo "🛑 worktree create fail: $WT — เก็บกวาดแล้วลองใหม่ หรือ --no-worktree"; exit 1; }
fi
WORK_ROOT="$WT"
```
🔴 **create fail → STOP** (ห้าม fallback เงียบไป main tree — ผู้ใช้ขอ isolation มากันแตะงานคู่ขนาน; เงียบ = เสีย guarantee)

### 2.7.3 Record worktree state → plan frontmatter (surgical Edit ที่ MAIN_ROOT plan file)
แก้ frontmatter ของ `$PLAN_PATH` (ไฟล์ใน `$MAIN_ROOT` vault — **ห้าม**แตะ copy ใน worktree):
```yaml
worktree: true
worktree_dir: <WT — absolute>
worktree_branch: plan/<slug>
worktree_base: <BASE>
worktree_repo: <MAIN_ROOT>          # monorepo = MAIN_ROOT; multi-repo → submodule path (infer จาก Affected Files + resolver --submodules, Phase 1)
worktree_status: built              # /ow-test อ่าน field นี้ → flip เป็น merged เมื่อ merge สำเร็จ
```
🔴 plan file อยู่ MAIN_ROOT → worktree copy ไม่ถูกแก้ → merge ไม่ชน vault docs (worktree = โค้ดล้วน)

## Phase 3 — Spawn subagent ตาม target

| `subagent_target` ใน plan | Spawn |
|---|---|
| `backend` | `.claude/agents/backend.md` |
| `frontend` | `.claude/agents/frontend.md` |
| `mobile` | `.claude/agents/mobile.md` |
| `docs` | `.claude/agents/docs.md` |
| `design` | `.claude/agents/design.md` |
| `all` | sequence: backend → frontend → mobile → docs |

Before spawning, assemble the **authoritative PROJECT CONTEXT block** from the Phase-0
resolved vars and **prepend it to the subagent prompt** — agents have no bash tool, so this
injected block is their only context channel. The `SUBMODULES` line is omitted entirely
on a single-repo project (single-repo is the default — not an error).

```bash
RES="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
AREA="$subagent_target"                                   # backend|frontend|mobile|design|docs
SUBS=$(bash "$RES" --submodules | cut -f1 | paste -sd' ' -)
RULES=$(bash "$RES" --rules "$AREA" | paste -sd' ' -)
RULES_EXP=$(bash "$RES" --rules-expected "$AREA" | cut -f1)   # canonical file, named even when absent
{
  echo "=== PROJECT CONTEXT (resolved — authoritative, do NOT rediscover) ==="
  echo "PROJECT=$PROJECT_NAME  LANG=$PROJECT_LANG"
  echo "VAULT_ABS=$VAULT_ABS"
  echo "PLAN_DIR=$PLAN_DIR  FIX_DIR=$FIX_DIR  TEST_DIR=$TEST_DIR  FN_DIR=$FN_DIR  REF_DIR=$REF_DIR"
  echo "EVIDENCE_ROOT=$EVIDENCE_ROOT   # evidence binaries go here ONLY — never the vault"
  [ -n "$SUBS" ]  && echo "SUBMODULES: $SUBS"             # omitted entirely on single-repo
  echo "GUARDRAILS=$GUARDRAILS_JSON"
  # RULES line is ALWAYS emitted — names the specific file so a missing rule cannot vanish silently
  if [ -n "$RULES" ]; then
    echo "RULES($AREA): $RULES   # Read each — they OVERRIDE the generic agent guidance"
  else
    echo "RULES($AREA): (none resolved) — expected file: $RULES_EXP (create it to add project $AREA conventions)"
  fi
  # Fail loud: a rule REGISTERED in .ow.yml rules.files that fails to resolve is a STOP-RISK,
  # never a silent skip — the agent must surface it, not proceed as if no rule existed.
  bash "$RES" --rules-validate >/dev/null 2>&1 || \
    echo "⚠ STOP-RISK: a rule registered in .ow.yml rules.files did not resolve — run: bash \"$RES\" --rules-validate"
  echo "=== END CONTEXT ==="
}
```

**Worktree mode (WT_MODE=on) — assemble WORKTREE block ต่อท้าย PROJECT CONTEXT** (mirror `/ow-fix-issue` 4.1).
agent ไม่มี bash + อยู่ใน worktree → block นี้คือ context เดียวที่บอกมันว่าทำงานที่ไหน:
```bash
if [ "$WT_MODE" = on ]; then
  echo "=== WORKTREE (worktree mode — authoritative) ==="
  echo "Working tree: $WORK_ROOT   # แก้โค้ดเฉพาะที่นี่ — ห้ามแตะอะไรนอก dir นี้ (vault/evidence ใช้ absolute ด้านบน)"
  echo "Branch: $BR   ·   Base: $BASE   ·   Repo: $MAIN_ROOT"
  echo "หลัง implement+test pass: commit ใน worktree (NO push, NO merge) — /ow-test จะ merge ให้ตอน smoke ผ่าน"
  echo "=== END WORKTREE ==="
fi
```

Prompt ที่ส่งให้ subagent (ขึ้นต้นด้วย PROJECT CONTEXT block ที่ assemble ด้านบน + WORKTREE block ถ้า worktree mode):
```
<PROJECT CONTEXT block from above>
<WORKTREE block from above — worktree mode เท่านั้น>

Plan file: <path>
Task: <task field จาก frontmatter>

Instructions:
1. อ่าน full plan ก่อนแตะ code — โดยเฉพาะ Success Criteria และ Implementation Steps
2. ทำตาม Implementation Steps ตามลำดับ — minimum correct change เท่านั้น
3. ทุก changed line ต้อง trace กลับไปยัง step ใน plan, success criteria, หรือ verification ได้
4. ห้ามเพิ่ม abstraction/config/dependency/feature นอก scope ของ plan
5. ห้าม refactor / reformat ไฟล์นอก scope ของ task — และเวลา "ล้าง churn" ต้องปลอดภัย:
   - formatter/linter: รันเฉพาะไฟล์ที่ task แก้เอง (`<fmt> <changed-files>`) — ห้าม whole-tree `--fix`/`--write`
     (whole-tree ใช้ได้แค่ read-only `--check`). repo ที่บังคับ format แบบ whole-tree → format เฉพาะไฟล์ที่แก้
   - 🔴 **ห้าม `git checkout`/`git restore`/`git stash`/`git clean`** กับไฟล์ที่ task ไม่ได้สร้าง/แก้เอง — main
     working tree อาจมีงาน uncommitted ของ `/ow-fix`/`/ow-implement` คู่ขนาน คำสั่งพวกนี้ลบ**ทั้งไฟล์** = data loss
     (แม้อยู่ใน worktree ก็ห้าม — ลบงาน uncommitted ของ agent เอง)
   - revert hunk นอก scope = แก้ **surgical ด้วย Edit** เฉพาะไฟล์ที่ task เป็นเจ้าของ (เฉพาะ hunk ที่เกิน ไม่ revert ทั้งไฟล์)
6. ทำตาม existing patterns ของ repo ก่อนสร้าง pattern ใหม่
7. Enforce gates ของ agent (test creation, design system compliance, security)
8. หลังเสร็จ: map verification กลับไปยัง Success Criteria ทีละข้อ
9. Update vault per Vault Update Checklist ของ plan — เขียนที่ `VAULT_ABS` (absolute, อยู่ MAIN_ROOT) เสมอ;
   worktree mode → **ห้ามเขียน vault docs ใน worktree** (จะติด commit + ชน merge — worktree เก็บโค้ดล้วน)
10. Report: files changed (production vs test), vault docs updated
11. ห้าม fake evidence — ถ้า test รันไม่ผ่าน บอก blocker
12. **Worktree mode เท่านั้น** — แก้โค้ดใน worktree แล้ว **ทิ้งไว้ uncommitted** (เหมือน normal mode ทิ้ง uncommitted ใน main tree) —
    orchestrator จะ audit (Phase 5.2/5.3) แล้ว **commit ให้เองที่ Phase 6** หลัง gates ผ่าน · 🔴 agent **ห้าม** commit / push / merge เอง
13. ติดการตัดสินใจระดับ design/spec ที่ plan ไม่ครอบ → หยุดเฉพาะส่วนนั้น ทำส่วนอื่นให้จบ แล้วรายงาน
    **Escalations** ใน hand-back (blocked-on + command ที่แนะนำ เช่น `/ow-clarify <doc>` / `/ow-plan --revise`) — ห้ามเดา
```

หลังรับ hand-back: มี **Escalations** → relay recommended command ให้ user ตรงๆ — ห้าม orchestrator
เดาคำตอบแทนหรือ re-spawn ด้วย prompt เดิม; ส่วนที่ไม่ติดเดินหน้า Phase 4-5 ตามปกติ

## Phase 4 — Design system gate (ถ้ามี)

ถ้า `$DS_DIR` มีอยู่ และ subagent คือ `frontend` หรือ `mobile`:

ก่อน subagent เขียน UI code → บังคับให้:
1. อ่าน `DS-Tokens.md`, `DS-Components.md`, `DS-Patterns.md`
2. ใช้ token/component ที่มี
3. ถ้าต้อง component ใหม่ → STOP, แจ้ง user ให้รัน `/ow-design` เพิ่ม component นั้นก่อน

## Phase 5 — Capture evidence + integrity audit (🔴 ก่อน mark done)

> หัวใจ no-fake-evidence: evidence ต้องมาจาก build/test ที่ **รันจริง** + ตรวจด้วย **คำสั่งจริง** ไม่ใช่เชื่อ subagent อย่างเดียว

### 5.0 Capture build/test evidence (🔴 ห้ามข้าม)

ถ้าไม่มี evidence → `/ow-verify` ถือว่า "ไม่ได้ทำงาน"

```bash
# (context already loaded in Phase 0 — no redundant resolver call here)
# Evidence binaries go to the gitignored EVIDENCE_ROOT (test-artifacts/...),
# NEVER the vault. The resolver owns the {source}/{slug} expansion.
# 🔴 worktree mode: resolve เป็น ABSOLUTE ใต้ MAIN_ROOT เสมอ (agent อยู่ใน worktree → relative path หายตอน cleanup);
#    ใช้ $PLAN_PATH (strip flag) + $MAIN_ROOT (จาก Phase 2.7.1) — ไม่ใช่ $ARGUMENTS / show-toplevel (อาจ root ที่ worktree)
PLAN_SLUG=$(basename "$PLAN_PATH" .md)
# slug ต้อง traceable: ใส่เลข GitHub issue ถ้า plan map กับ issue (frontmatter github_issue:/fix:),
# ไม่งั้นใช้ plan slug (มี timestamp อยู่แล้ว = traceable)
NN=$(grep -m1 -oE 'issues/[0-9]+' "$PLAN_PATH" | grep -oE '[0-9]+$')
# 1 folder ต่อ TASK: ถ้าบั๊กนี้ /ow-fix (หรือ /ow-fix-issue) เปิด fix-<NN>-<slug>/ ไว้แล้ว
# (มี before/RED evidence) → REUSE folder เดิม ให้ after/GREEN + build ลงที่เดียวกัน ไม่แตก plan-* ใหม่
EVIDENCE_DIR=""
[ -n "$NN" ] && EVIDENCE_DIR=$(find "$MAIN_ROOT/test-artifacts/$EVIDENCE_DATE" -maxdepth 1 -type d -name "fix-$NN-*" -exec ls -dt {} + 2>/dev/null | head -1)
if [ -z "$EVIDENCE_DIR" ]; then                 # ไม่มี fix folder ของ task นี้ → folder ของ plan เอง
  if [ -n "$NN" ]; then
    DESC=$(echo "$PLAN_SLUG" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-?//')
    SLUG="${NN}-${DESC:-$PLAN_SLUG}"
  else
    SLUG="$PLAN_SLUG"
  fi
  EV_REL=$(cd "$MAIN_ROOT" && OW_EVIDENCE_SOURCE=plan OW_EVIDENCE_SLUG="$SLUG" \
    bash "$MAIN_ROOT/scripts/ow-paths.sh" --check EVIDENCE_ROOT)
  case "$EV_REL" in /*) EVIDENCE_DIR="$EV_REL" ;; *) EVIDENCE_DIR="$MAIN_ROOT/$EV_REL" ;; esac   # absolute (worktree-safe)
fi
mkdir -p "$EVIDENCE_DIR"
# Bootstrap the canonical EVIDENCE.md manifest at capture START; add one table row per artifact below
# (columns: | ID | File | TC | State | Type |). ถ้า /ow-fix สร้าง manifest ไว้แล้ว (reuse) → APPEND after-evidence ต่อ ไม่ทับ.
[ -f "$EVIDENCE_DIR/EVIDENCE.md" ] || \
  cp "$MAIN_ROOT/.ow/templates/evidence/EVIDENCE.md" "$EVIDENCE_DIR/EVIDENCE.md" 2>/dev/null
# fill front-matter: source=<fix ถ้า reuse / plan> · slug · issue=${NN:+#$NN} · doc=[[$PLAN_SLUG]] · captured=now
```
🔴 worktree mode → `$EVIDENCE_DIR` เป็น **absolute ใต้ `$MAIN_ROOT/test-artifacts/`** แล้ว — ส่งค่านี้เข้า agent prompt
(agent อยู่ใน worktree, ไม่มี bash → resolve เองจะ root ผิด). normal mode → MAIN_ROOT = working tree.

🔴 **`$EVIDENCE_DIR` คือ folder เดียวของ "task" นี้** ตลอด flow:
`/ow-fix` เปิด `fix-<NN>-<slug>/` + before/RED → `/ow-implement` (ที่นี่) **reuse** folder เดิม + after/GREEN + build →
`/ow-test` (Phase 2.5) **reuse** ต่อ + smoke — ทุก step append `EVIDENCE.md` เดียวกัน ไม่แตกเป็น `plan-*`/`smoke-*` แยก.

รัน **build + test ต่อ submodule/area ที่แตะ** — capture stdout+stderr ลงไฟล์ (ห้าม stream เข้า context):

```bash
START=$(date +%s)
# 🔴 build/test รันที่ $WORK_ROOT (worktree mode = worktree code; normal = main tree) — output ไป EVIDENCE_DIR (absolute)
( cd "$WORK_ROOT" && { <build-or-test-cmd> 2>&1; echo "EXIT=$?"; } ) > "$EVIDENCE_DIR/build-output.txt"
echo "DURATION=$(($(date +%s)-START))s" >> "$EVIDENCE_DIR/build-output.txt"
```

🔴 **build/test command อ่านจาก config / repo convention — ไม่ hardcode**
- monorepo: ใช้ script จาก `package.json`/`Makefile`/`pyproject.toml` ฯลฯ ที่ repo มี
- multi-repo: รันต่อ submodule ที่แตะ (infer จาก Affected Files ของ plan เทียบ `submodules:` config — resolver `--submodules`) —
  submodule ที่ไม่แตะ mark `not-touched`

กฎ:
- Build/test **fail → บันทึก EXIT, ห้ามหยุด** — failure คือ evidence
- ต้องมีอย่างน้อย 1 area ที่รันจริง

### 5.1 BUILD-INFO.md + parse pass/fail (🔴 บังคับ)

Parse จำนวน pass/fail จาก stdout จริง (regex ตาม test runner ที่ใช้ เช่น `Passed: \d+, Failed: \d+` / `Tests \d+ passed` / `\d+ passed`).

🔴 **parse ไม่ได้ → ใส่ `?/?` + `parse-failed: true` — ห้ามเดาตัวเลข** (no-fake-evidence)

เขียน `$EVIDENCE_DIR/BUILD-INFO.md`:

```markdown
# Build/Test Info — <plan-slug>

- Plan: [[<slug>]]   · Run at: YYYY-MM-DD HH:mm   · Areas touched: <list>

## Results
| Area | Build | Duration | Test | Duration | Output |
|---|---|---|---|---|---|
| <area1> | ✅ EXIT=0 | 12s | ✅ 23/23 | 4s | build-output.txt |
| <area2> | not-touched | — | not-touched | — | — |

## Summary
- Total: N | Passed: N | Failed: 0 | Build: all-pass
- Notes: <anomalies — new tests, migration re-seed, parse-failed flags>

## Test Coverage Added (🔴 บังคับ — list ทุก test file ที่เพิ่ม/แก้)
| Layer | File | Behavior covered |
|---|---|---|
| Unit | <path> | <behavior> |
| Integration | <path> | <behavior> |
| E2E | <path> | <behavior> |

Total test files added/modified: N
(ถ้า skip — list ไฟล์ + untestable reason 1–6; ไม่งั้นเขียน "All changes covered.")
```

ตารางนี้คือ integrity artifact ที่ `/ow-verify` audit — ห้าม fabricate

### 5.2 Coverage audit — STOP gate (🔴 ก่อน mark done)

```bash
# production files vs test files ใน diff (ปรับ extension/path pattern ตาม stack ของ repo)
# 🔴 diff ที่ $WORK_ROOT — worktree mode = การแก้อยู่ใน worktree (committed บน feature branch หรือ working);
#    `git -C "$WORK_ROOT" diff --name-only HEAD` เห็น uncommitted; ถ้า agent commit แล้ว ใช้ `HEAD~1` / `$BASE...HEAD`
PROD=$(git -C "$WORK_ROOT" diff --name-only HEAD | grep -vE '(test|spec|__tests__|/tests/|\.spec\.|\.test\.|/e2e/|\.md$)' | grep -E '\.[a-zA-Z]+$' | wc -l | tr -d ' ')
TEST=$(git -C "$WORK_ROOT" diff --name-only HEAD | grep -E '(test|spec|__tests__|/tests/|\.spec\.|\.test\.|/e2e/)' | wc -l | tr -d ' ')
```

- `PROD>0 && TEST==0` → **🛑 STOP** — เลือกอย่างใดอย่างหนึ่ง:
  - justify ด้วย **untestable reason เฉพาะเจาะจง** (list 1–6 ด้านล่าง) — ไม่ใช่ "no logic"
  - หรือ spawn subagent เขียน test ก่อน
- `PROD>0 && TEST>0` → pass; log ratio
- `PROD==0` → pass; note "docs-only / config-only"

**Untestable list (1–6) — เหตุผลที่ acceptable เท่านั้น:**
1. pure styling/layout (CSS/markup ไม่มี logic)
2. config/constants/env wiring
3. generated code (codegen, migration scaffolding)
4. static content / i18n string
5. third-party integration ที่ไม่มี sandbox/stub
6. vault docs / markdown only

🔴 **"ยาก / ใช้เวลานาน" ≠ untestable** — ต้อง map กับ 1 ใน 6 ข้อนี้เท่านั้น

### 5.3 Coding-discipline audit (🔴 ก่อน mark done)

ตรวจ `git diff HEAD`:

- [ ] **Success criteria** ใน plan มี evidence map ครบทุกข้อ — verification (5.0) link กลับ criterion ไหน · ระบุ "ผ่าน / ไม่ผ่าน / ยังไม่ตรวจ + เหตุผล"
- [ ] **Changed-line traceability** — ทุก hunk โยงกลับ plan step / success criterion ได้ · hunk ที่อธิบาย "ทำไม" ไม่ได้ → revert (surgical, ดูวิธีปลอดภัยด้านล่าง)
- [ ] **No speculative additions** — ไม่มี abstraction / config / dependency / feature ที่ plan ไม่ได้ขอ
- [ ] **No unrelated refactor / format churn** — ไม่มี rename / reformat / cleanup นอก scope. Formatter/linter
  รันเฉพาะ **changed files** (`<fmt> <files>`) — whole-tree ใช้ได้แค่ read-only `--check` (ห้าม whole-tree `--fix`/`--write` ที่ churn ไฟล์นอก scope)

ถ้าข้อใดไม่ผ่าน → **revert hunk ที่เกิน scope ก่อน mark done** ด้วยวิธี **ปลอดภัยเท่านั้น** (scope discipline = งานนี้ ห้ามผลักไป follow-up):
- ✅ แก้ **surgical ด้วย Edit** เฉพาะ hunk ที่เกิน ใน **ไฟล์ที่ task นี้สร้าง/แก้เอง** เท่านั้น
- 🔴 **ห้าม `git checkout` / `git restore` / `git stash` / `git clean`** เพื่อล้าง churn — คำสั่งพวกนี้ลบ uncommitted
  **ทั้งไฟล์** (ไม่ใช่แค่ format) + working tree อาจมีงานคู่ขนานของ `/ow-fix`/`/ow-implement` อื่นที่ยังไม่ commit → **data loss**

### 5.4 Capture evidence (🔴 บังคับทุก test run — UI screenshot / non-UI log)

- **UI / e2e** → screenshot **บังคับ** (ขาด = evidence ไม่ครบ → ห้าม mark done): ผ่าน `/ow-test` หรือ manual,
  เก็บใน `$EVIDENCE_DIR/` (prefer capture หน้าที่เกิด feature ตรงๆ ไม่ใช่หน้า login)
- **non-UI (unit / API)** → captured **output log บังคับ** (`build-output.txt` / test stdout) ใน `$EVIDENCE_DIR/`
- เพิ่ม 1 แถวต่อ artifact ใน `$EVIDENCE_DIR/EVIDENCE.md` (`| ID | File | TC | State | Type |`) — ห้ามแต่ง;
  `/ow-evidence` จะ finalize/verify manifest ภายหลัง

## Phase 6 — Update plan

### 6.0 Open-checkbox gate (🔴 ก่อน flip status: done)
```bash
grep -c "\- \[ \]" "$PLAN_PATH"   # ต้อง = 0  (plan file ใน MAIN_ROOT vault — strip flag แล้ว, Phase 2.7.1)
```
ถ้า >0 → spawn `docs` subagent ทำรายการที่ค้างให้ครบก่อน — ห้าม flip status

🔴 **`status: done` ต้องผ่านครบ:** 5.0 evidence + 5.2 coverage audit + 5.3 discipline audit + 6.0 open-checkbox = 0

1. Plan frontmatter: `status: done`, `completed_at: YYYY-MM-DD HH:mm`
2. Append section ใน plan:
   ```markdown
   ## Implementation Result
   - Files changed (prod / test): <list>
   - Tests added: <list จาก 5.1 Test Coverage table>
   - Success criteria → evidence map: <จาก 5.3>
   - Evidence: `$EVIDENCE_DIR/EVIDENCE.md` (manifest — test-artifacts, gitignored)
   - Subagent used: <name>   · Time: <duration>
   ```
3. Update `$IMPL_STATUS` mark feature/phase done

### 6.4 Commit ใน worktree (worktree mode เท่านั้น)

หลัง gates ผ่านครบ (5.0/5.2/5.3/6.0) → orchestrator **commit โค้ดใน worktree** (NO push, NO merge) — กลายเป็น
feature-branch commit ที่ `/ow-test` จะ merge กลับ base ตอน smoke ผ่าน:
```bash
if [ "$WT_MODE" = on ]; then
  git -C "$WORK_ROOT" add -A
  git -C "$WORK_ROOT" diff --cached --quiet && { echo "ℹ️ ไม่มีการแก้โค้ดใน worktree — ข้าม commit"; } || \
  git -C "$WORK_ROOT" commit -m "<type>(<scope>): <one-line จาก plan title> (plan/$SLUG)

<Co-Authored-By per project convention>"
  # อัปเดต worktree_status ใน plan frontmatter (MAIN_ROOT): built (ยืนยัน) — /ow-test จะ flip → merged
fi
```
🔴 commit จับเฉพาะไฟล์โค้ดใน worktree (vault/evidence อยู่นอก worktree → ไม่ติด) · **ห้าม push · ห้าม merge** (เป็นงาน `/ow-test`)
🔴 worktree ว่าง (agent ไม่ได้แก้โค้ด เช่น docs-only plan) → ข้าม commit + แจ้ง user (จะไม่มีอะไรให้ merge — รัน `/ow-test` ปกติได้, Phase 7 ของมันจะ skip merge)

### 6.5 Close source fix-log (🔴 ถ้า plan escalate มาจาก fix-log)

ถ้า plan นี้มาจาก `/ow-plan fix:<slug>` (มี `source_fix:`) **หรือ** ถูกเรียกแบบ `/ow-implement --from-fix <fix-log-path>` (option B, P3) → ปิด fix-log ต้นทาง **อัตโนมัติ** เมื่อ plan `done` — ไม่ปล่อยค้าง `in-progress`

```bash
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
TGT=$(echo "$PLAN_PATH" | sed -E 's/^--from-fix[[:space:]]+//')   # resolved target file: plan (normal) | fix-log (--from-fix); $PLAN_PATH = flag-stripped (Phase 2.7.1)
FIXLOG=""
if grep -q 'type/fix-log' "$TGT" 2>/dev/null; then
  FIXLOG="$TGT"                                  # (b) option B — /ow-implement --from-fix: target IS the fix-log เอง
else
  # (a) option A — plan with source_fix: (wikilink/path) → resolve fix-log slug ใต้ $FIX_DIR  [primary]
  SRC=$(grep -m1 '^source_fix:' "$TGT" | sed -E 's/^source_fix:[[:space:]]*//; s/^"?\[\[//; s/\]\]"?$//; s/\.md$//')
  { [ -z "$SRC" ] || [ "$SRC" = "none" ]; } && SRC=""
  [ -n "$SRC" ] && FIXLOG=$(find "$FIX_DIR" -maxdepth 1 -name "${SRC##*/}.md" 2>/dev/null | head -1)
  # 🔴 SRC ตั้งไว้แต่หา fix-log ไม่เจอ (เช่น fix-log ถูก rename หลัง plan) → STOP, อย่า flip plan done เงียบ
  [ -n "$SRC" ] && [ -z "$FIXLOG" ] && { echo "🛑 STOP: source_fix ชี้ fix-log ที่หาไม่เจอ: $SRC (link เสีย)"; exit 1; }
fi
# (ไม่มีทั้ง --from-fix fix-log target และ plan source_fix → ไม่ใช่ fix-escalated → ข้าม 6.5 เงียบ)
```

ถ้าเจอ `$FIXLOG` และ `status` ยังไม่ใช่ `fixed`/`wont-fix`:
1. Frontmatter (surgical **Edit**): `status: fixed` · `fixed_commit: pending` (🔴 sha จริงเติมโดย `/ow-git --bump` Phase 8.6 — `/ow-implement` ไม่ commit เอง; **ห้าม**เขียน HEAD sha ที่ยังไม่ใช่ commit ของงานนี้ = no-fake-evidence) · `fixed_in_version` เว้นให้ `/ow-git` stamp
2. Tick checkbox ที่ **พิสูจน์แล้วจริง** ใน `## Test Cases` (+ `## Success Criteria` ถ้ามี) ของ fix-log — map กับ evidence (5.0) + red→green ที่รันใน implement นี้; ข้อที่ยังไม่ได้พิสูจน์ → คงไว้ `[ ]` + หมายเหตุ (🔴 ห้าม tick มั่ว)

🔴 **bi-directional close:** plan `done` (หรือ `--from-fix` เสร็จ) ⇒ fix-log `fixed` เสมอ — ไม่มี fix-log ค้าง `in-progress` หลังงานที่ own มัน เสร็จ ทั้ง option A (plan) และ option B (--from-fix)
🔴 `source_fix:` ชี้ไฟล์ที่หาไม่เจอ → **STOP** (อย่าเงียบ — link เสีย; บังคับใน bash ด้านบนแล้ว)

## Phase 7 — Handoff message

**Worktree mode (WT_MODE=on)** — ต่อท้าย output:
```
🌳 Worktree build เสร็จ — branch plan/<slug> (commit <sha>) ใน worktrees/plan-<slug>/
   main working tree ไม่ถูกแตะ (งาน uncommitted คู่ขนานปลอดภัย)

🎯 ขั้นต่อไป: /ow-test <plan>   →  smoke test ใน worktree → PASS = auto-merge กลับ <base> (local, ไม่ push) + cleanup
   (FAIL = worktree เก็บไว้ที่ worktrees/plan-<slug>/ ให้แก้ต่อ)
```

normal mode → แนะนำขั้นต่อไป: `/ow-test <plan>` (smoke) แล้วค่อย `/ow-git --plan <plan>` (commit/push — user สั่งเอง)

## Output (3 หัวข้อบังคับ)

1. **Result** — plan `status: done` + files changed (prod/test) + vault docs ที่ update + fix-log ที่ปิด (ถ้ามี `source_fix`)
2. **Verification / Evidence** — build/test commands ที่รันจริง + pass/fail counts ที่ parse ได้ + `$EVIDENCE_DIR/EVIDENCE.md` + `BUILD-INFO.md` + success criteria → evidence map; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — blockers, untestable justification (ข้อ 1–6), เช่น "Manual UAT ยังไม่ทำ", ขั้นต่อไป `/ow-test` → `/ow-verify`

## ห้าม

- ห้าม implement ถ้า plan ไม่ `approved`
- 🔴 worktree mode → orchestrator **ห้าม merge** (เป็นงาน `/ow-test` ตอน smoke ผ่าน) · **ห้าม push** · agent ห้าม commit/merge เอง (orchestrator commit ที่ 6.4)
- 🔴 worktree create fail → **STOP** (ห้าม fallback เงียบไป main tree — เสีย isolation ที่ผู้ใช้ขอ; ใช้ `--no-worktree` ถ้าตั้งใจ in-tree)
- ห้ามแก้ scope จาก plan โดยไม่ revise plan ก่อน (`/ow-plan <task> --revise <path>`)
- ห้าม fake test/build evidence — pass/fail count ต้อง parse จาก stdout จริง; parse ไม่ได้ → `?/?` + `parse-failed: true` ห้ามเดา
- ห้าม flip `status: done` ถ้า **coverage audit (5.2) ไม่ผ่าน** — `PROD>0 && TEST==0` = STOP, เขียน test หรือ justify ด้วย untestable list 1–6
- ห้ามอ้าง "untestable" โดยไม่ map กับ 1 ใน 6 เหตุผล — "ยาก/ใช้เวลานาน" ≠ untestable
- ห้าม flip `status: done` ถ้ายังมี open checkbox (`grep -c "- [ ]"` ต้อง = 0)
- 🔴 ห้าม flip plan `done` ทั้งที่ plan มี `source_fix:` แต่ไม่ปิด source fix-log (Phase 6.5) — plan done ⇒ source fix-log `status: fixed` เสมอ
- ห้ามแก้ shared/production env โดยไม่ confirm
- ห้ามเพิ่ม speculative abstraction/config/dependency/feature ที่ plan ไม่ได้ระบุ
- ห้าม refactor / format churn ไฟล์นอก scope — formatter รันเฉพาะ changed files (whole-tree = read-only `--check` เท่านั้น)
- 🔴 ห้าม `git checkout`/`git restore`/`git stash`/`git clean` กับไฟล์ที่ task ไม่ได้สร้าง/แก้เอง — ลบงาน uncommitted ของ task คู่ขนาน (data loss); revert churn = surgical Edit เฉพาะไฟล์ที่ task เป็นเจ้าของ
- ห้าม deliver งานโดยไม่มี verification map กลับไปยัง success criteria
