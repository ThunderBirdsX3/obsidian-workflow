---
description: Auto smoke test changed surface — detect diff → spin servers → dispatch test-runner
---

# /ow-test — Smoke test changed surface

Detect diff → spin server เท่าที่จำเป็น → spawn `test-runner` agent → report

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
/ow-test                    # auto-detect จาก git diff
/ow-test web                # บังคับ web
/ow-test app                # บังคับ mobile
/ow-test api                # บังคับ backend (unit + integration)
/ow-test <plan-file>        # ใช้ scope ของ plan
/ow-test <test-plan-file>   # systematic role-by-role test plan
/ow-test --since <ref>      # diff ตั้งแต่ ref (default HEAD)
/ow-test <plan> --no-merge  # worktree mode: test ใน worktree แต่ "ห้าม" auto-merge (เก็บ worktree ไว้)
/ow-test <plan> --no-worktree  # บังคับ test ที่ main tree (override plan ที่มี worktree)
```

## Phase 0.1 — Detect mode

| `$ARGUMENTS` | Mode |
|---|---|
| ว่าง | **Auto** — Phase 1 → 2.5 → 3 |
| `web` / `app` / `api` | **Forced** — Phase 2 → 2.5 → 3 |
| path ใน `90-TestPlan/` | **Test Plan** — Phase T (+ Phase 2.5 evidence) |
| path ใน `80-ImplementPlan/` | **Plan scope** — Phase 2 → 2.5 → 3 (infer target จาก plan) |

🔴 **Evidence = folder ของ "task" เดียวกัน.** ทุก mode resolve evidence ไปที่ folder ของ plan/fix
ที่ task นี้สังกัด (ตัวที่ `/ow-implement` / `/ow-fix-issue` สร้างไว้) แล้ว **append** ลง `EVIDENCE.md` เดิม
แบบ flat — ไม่สร้าง `smoke-*` แยกอีก (ดู Phase 2.5).

## Phase 0.5 — Resolve worktree + WORK_ROOT (รันเสมอ)

🔴 **รันเสมอทุก mode** — set `WORK_ROOT` ที่ Phase 1/2/3/7 ใช้. normal mode → `WT_MODE=off`, `WORK_ROOT=$MAIN_ROOT`
(test ที่ main tree, ไม่มี Phase 7). worktree mode → resolve worktree fields แล้ว test รัน **ในนั้น** + auto-merge ตอน PASS.

ถ้า task ถูก build ใน worktree (`/ow-implement` ที่ worktree mode) → test ต้องรันใน worktree นั้น (server/build จากโค้ดใหม่):

```bash
MAIN_ROOT="${ROOT:-$(git rev-parse --show-toplevel)}"
ARGS=" $ARGUMENTS "
PLAN_PATH=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--(no-merge|no-worktree|worktree)//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
NO_MERGE=0; case "$ARGS" in *" --no-merge "*) NO_MERGE=1 ;; esac

WT_MODE=off; PLAN_FILE=""; WT=""; BR=""; BASE=""; REPO="$MAIN_ROOT"
# (1) explicit plan arg ที่มี worktree_status: built  (2) bare run → plan ล่าสุดที่ built
if [ -f "$PLAN_PATH" ] && grep -q '^worktree_status:[[:space:]]*built' "$PLAN_PATH" 2>/dev/null; then
  PLAN_FILE="$PLAN_PATH"; WT_MODE=on
elif [ -z "$PLAN_PATH" ]; then
  PLAN_FILE=$(grep -lE '^worktree_status:[[:space:]]*built' "$PLAN_DIR"/*.md 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)
  [ -n "$PLAN_FILE" ] && WT_MODE=on
fi
case "$ARGS" in *" --no-worktree "*) WT_MODE=off ;; esac     # override: บังคับ test main tree

if [ "$WT_MODE" = on ]; then
  WT=$(grep -m1   '^worktree_dir:'    "$PLAN_FILE" | sed -E 's/^worktree_dir:[[:space:]]*//')
  BR=$(grep -m1   '^worktree_branch:' "$PLAN_FILE" | sed -E 's/^worktree_branch:[[:space:]]*//')
  BASE=$(grep -m1 '^worktree_base:'   "$PLAN_FILE" | sed -E 's/^worktree_base:[[:space:]]*//')
  REPO=$(grep -m1 '^worktree_repo:'   "$PLAN_FILE" | sed -E 's/^worktree_repo:[[:space:]]*//'); REPO="${REPO:-$MAIN_ROOT}"
  [ -d "$WT" ] || { echo "ℹ️ worktree หาย: $WT (อาจ merge/cleanup ไปแล้ว) → fall back ไป test ที่ main tree"; WT_MODE=off; }
fi
WORK_ROOT="$MAIN_ROOT"; [ "$WT_MODE" = on ] && WORK_ROOT="$WT"
```

🔑 **WORK_ROOT contract** (เหมือน /ow-implement): **server/build/test/`git diff`** → `$WORK_ROOT`; **evidence** → absolute MAIN_ROOT.
`WT_MODE=off` → WORK_ROOT = MAIN_ROOT (test ที่ main tree, ไม่มี Phase 7).

## Phase 1 — Detect scope (Auto only)

```bash
if [ "$WT_MODE" = on ]; then
  # worktree mode: การแก้ commit แล้วบน feature branch (implement Phase 6.4) → diff vs base
  changed=$(git -C "$WORK_ROOT" diff --name-only "$BASE"...HEAD)
else
  changed=$(git diff --name-only HEAD; git diff --name-only --cached; git ls-files --others --exclude-standard)
fi
```

ตรวจว่าแก้ที่ไหน:
- API/backend folders → `api`, `server`, `backend`, `*.controller.*`
- Web → `web`, `client`, `frontend`, `*.tsx`, `*.vue`, `*.svelte`
- Mobile → `app`, `mobile`, `*.dart`, `*.swift`, `*.kt`

| Changed | Action |
|---|---|
| API only | unit + integration tests (no UI) |
| Web (±API) | dispatch test-runner target=web |
| Mobile (±API) | dispatch test-runner target=app |
| Web + Mobile | dispatch twice |
| Nothing | Exit — "ไม่มี diff" |

## Phase 2 — Spin up servers (เท่าที่จำเป็น)

- Web → check ว่า dev server รันอยู่ที่ expected port; ถ้าไม่ → spin up
- Mobile → check emulator/simulator; ถ้าไม่ → start
- API → check ว่า API responsive; ถ้าไม่ → spin up

🔴 **worktree mode → spin server/build จาก `$WORK_ROOT`** (`( cd "$WORK_ROOT" && <serve cmd> )`) — ทดสอบ
**โค้ดใหม่ของ worktree** ไม่ใช่ main tree (ถ้ามี server รันจาก main tree อยู่แล้ว ต้อง restart จาก worktree)

ถ้า servers ต้อง credentials/secrets ที่ไม่มี → blocker → STOP + แจ้ง user

## Phase 2.5 — Resolve the task's evidence folder (REUSE plan/fix — never a separate smoke-*)

`/ow-test` verifies the SAME task that `/ow-implement` (or `/ow-fix-issue`) just built — so its
evidence belongs in **that task's ONE folder**, flat, appended to the existing `EVIDENCE.md`. The
orchestrator (has bash) resolves the absolute `$EVIDENCE_DIR` and passes it into Phase 3 (the
test-runner agent has no bash tool — resolving there would mis-root to the repo root):

```bash
TOPLEVEL="$(git rev-parse --show-toplevel)"; RES="$TOPLEVEL/scripts/ow-paths.sh"
DATE_DIR="$TOPLEVEL/test-artifacts/$EVIDENCE_DATE"
EVIDENCE_DIR=""; EV_SRC=""; EV_SLUG=""; NN=""

# (1) explicit plan-/test-plan-file arg → that task's folder (mirror /ow-implement Phase 5.0 slug)
if [ -f "$ARGUMENTS" ]; then
  BASE=$(basename "$ARGUMENTS" .md)
  NN=$(grep -m1 -oE 'issues/[0-9]+' "$ARGUMENTS" | grep -oE '[0-9]+$')        # github_issue:, if mapped
  [ -n "$NN" ] && EVIDENCE_DIR=$(find "$DATE_DIR" -maxdepth 1 -type d \( -name "fix-$NN-*" -o -name "plan-*$NN*" \) -exec ls -dt {} + 2>/dev/null | head -1)
  if [ -z "$EVIDENCE_DIR" ]; then                                            # no folder yet → derive
    case "$ARGUMENTS" in *85-FixLog*|*90-TestPlan*) EV_SRC=fix ;; *) EV_SRC=plan ;; esac
    DESC=$(echo "$BASE" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-?//')
    case "$DESC" in "$NN"-*) EV_SLUG="$DESC" ;; *) EV_SLUG="${NN:+$NN-}${DESC:-$BASE}" ;; esac   # don't double the issue#
  fi
fi

# (2) bare/forced run → attach to the task already in flight (no new folder)
if [ -z "$EVIDENCE_DIR" ] && [ -z "$EV_SRC" ]; then
  BR=$(git -C "$TOPLEVEL" rev-parse --abbrev-ref HEAD 2>/dev/null)
  case "$BR" in fix/*) EV_SRC=fix; EV_SLUG="${BR#fix/}" ;; esac              # (a) current fix branch
fi
[ -z "$EVIDENCE_DIR" ] && [ -z "$EV_SRC" ] && \
  EVIDENCE_DIR=$(find "$DATE_DIR" -maxdepth 1 -type d \( -name 'plan-*' -o -name 'fix-*' \) -exec ls -dt {} + 2>/dev/null | head -1)   # (b) today's task folder
if [ -z "$EVIDENCE_DIR" ] && [ -z "$EV_SRC" ]; then
  PF=$(find "$PLAN_DIR" -maxdepth 1 -name '*.md' -exec ls -t {} + 2>/dev/null | head -1)   # (c) most-recent plan file
  [ -n "$PF" ] && { EV_SRC=plan; EV_SLUG=$(basename "$PF" .md); }
fi

# (3) LAST RESORT — genuinely no task → traceable surface name, NOT "smoke-*"
if [ -z "$EVIDENCE_DIR" ] && [ -z "$EV_SRC" ]; then
  EV_SRC=test; EV_SLUG="${TARGET:-changes}"      # → test-<target>  (e.g. test-web)
  echo "ℹ️ ไม่พบ plan/fix ของ task นี้ — ใช้ test-$EV_SLUG/ ชั่วคราว; ถ้าเป็นส่วนของ plan รัน: /ow-test <plan-file>"
fi

# resolve to ABSOLUTE (resolver returns path relative-to-toplevel) when derived from src+slug
if [ -z "$EVIDENCE_DIR" ]; then
  REL=$(cd "$TOPLEVEL" && OW_EVIDENCE_SOURCE="$EV_SRC" OW_EVIDENCE_SLUG="$EV_SLUG" bash "$RES" --check EVIDENCE_ROOT)
  case "$REL" in /*) EVIDENCE_DIR="$REL" ;; *) EVIDENCE_DIR="$TOPLEVEL/$REL" ;; esac
fi
mkdir -p "$EVIDENCE_DIR"

# APPEND to the task's existing manifest; bootstrap from template only if /ow-test captures first
[ -f "$EVIDENCE_DIR/EVIDENCE.md" ] || \
  cp "$TOPLEVEL/.ow/templates/evidence/EVIDENCE.md" "$EVIDENCE_DIR/EVIDENCE.md"
```

🔴 ส่งค่า absolute `$EVIDENCE_DIR` เข้า prompt ของ Phase 3 — test-runner ไม่มี bash tool, resolve เองจะ root ผิด
(หลุดไป repo root แทน `test-artifacts/`). Forced/auto run ที่มี plan/fix ค้างอยู่ → reuse; ไม่มีจริง ๆ → `test-<target>/`.

## Phase 3 — Spawn test-runner

**Prepend the authoritative PROJECT CONTEXT block** to the prompt (assemble from the Phase-0
resolved vars exactly as `/ow-implement` Phase 3 — `VAULT_ABS`, `TEST_DIR`, `EVIDENCE_ROOT`,
`GUARDRAILS_JSON`, `--rules testing`, and a `SUBMODULES` line only if multi-repo). The agent has
no bash tool — without this block it STOPs (§0).

Prompt:
```
<PROJECT CONTEXT block from above>

Target: <web | app | api>
Scope: <files changed | plan file>
Working dir: <WORK_ROOT — worktree mode = worktrees/plan-<slug>/ ; ไม่งั้น = repo root>
  🔴 รัน test/serve จาก dir นี้ (worktree mode = ทดสอบโค้ดใหม่ของ worktree ไม่ใช่ main tree)
EVIDENCE_DIR: <absolute path resolved in Phase 2.5 — the TASK's plan/fix folder,
  e.g. /repo/test-artifacts/2026-06-05/plan-2026-06-05-1120-…>
  🔴 เขียน evidence ทุกไฟล์ FLAT ใต้ EVIDENCE_DIR ตรง ๆ (ห้ามสร้าง subdir, ห้าม relative path — agent อยู่นอก repo root)
Vault context: $TEST_DIR (อ่านที่มี relevant)

Tasks:
1. Run smoke tests สำหรับ surface ที่เปลี่ยน
2. Capture evidence — UI: screenshot บังคับ ≥1 · non-UI/API: captured output log บังคับ
3. Capture console + network logs
4. APPEND 1 แถวต่อ artifact ลง `$EVIDENCE_DIR/EVIDENCE.md` ที่มีอยู่ (manifest เดียวของ task —
   build จาก /ow-implement + smoke จาก /ow-test; columns `| ID | File | TC | State | Type |`)
5. Detect PII/secret ในผลลัพธ์ → mask
6. Mark route source trace ของแต่ละ check:
   VISIBLE_MENU / DIRECT_URL_USER / DIRECT_URL_TECHNICAL
7. Report: PASS / FAIL / BLOCKED + evidence paths (ชี้ EVIDENCE.md)
```

## Phase T — Test Plan mode

อ่าน test plan ที่ `90-TestPlan/TP-*.md` — ทำ systematic test ตาม:
- แต่ละ role ใน plan
- แต่ละ scenario
- เก็บ evidence ตาม `EVIDENCE.md` manifest format
- Status taxonomy: PASS / FAIL / INFO / LIMITED / PASS_NO_MUTATION / BLOCKED_* / NOT_RUN

## Phase 4 — Evidence collection (append to the task's EVIDENCE.md · FLAT · 1 folder ต่อ task)

`$EVIDENCE_DIR` ถูก resolve แล้วใน Phase 2.5 = folder ของ plan/fix ที่ task นี้สังกัด (ไม่ใช่ `smoke-*` แยก).
test-runner เขียนทุกไฟล์ **flat** ใต้ folder นั้น แล้ว **append** ลง `EVIDENCE.md` เดิม (under the gitignored
`EVIDENCE_ROOT` — NEVER the vault):
```
$EVIDENCE_DIR/   (= test-artifacts/<date>/plan-<slug>/  หรือ fix-<NN>-<slug>/ — ของ task เดียวกัน)
├── EVIDENCE.md                         # manifest เดียวของ task — /ow-implement สร้าง, /ow-test เติมแถว
├── build-output.txt                    # ← /ow-implement (ถ้ารันมาก่อน)
├── <SCENARIO-ID>-<STEP>-<state>.png    # ← /ow-test smoke screenshots (flat, มีแถวใน EVIDENCE.md)
├── console.log
└── network.log
```
- 🔴 **ไม่สร้าง folder/subdir ใหม่** — append เข้า task folder เดิม (Phase 2.5)
- ถ้า `EVIDENCE.md` ยังไม่มี (รัน `/ow-test` ก่อน `/ow-implement`) → bootstrap จาก `.ow/templates/evidence/EVIDENCE.md`
  (front-matter `source: <plan|fix|test>`, `slug:`, `issue: <#NN | ->`, `doc: "[[<plan/test-plan slug>]]"`)
- smoke ครอบหลาย task → คนละ folder ของ plan/fix นั้น ๆ (ไม่ pool ข้าม task)
- แถว smoke: State=`smoke` · Type=`screenshot|log` — append ลงตาราง `| ID | File | TC | State | Type |` (ห้ามแต่ง)

🔴 **บังคับทุก test run:** **UI** → screenshot อย่างน้อย 1 (ขาด = INFO/incomplete, ห้าม claim "PASS มีหลักฐาน");
**non-UI/API** → captured output log. ทุก artifact ต้องมี 1 แถวใน EVIDENCE.md.

แต่ละ screenshot บันทึก (EVIDENCE.md row + `## Notes`): scenario/step · page/URL · expected/actual ·
console summary · network summary · PII / masking / safe-to-share flag.

## Phase 5 — Visible-menu rule

> Gate: the visible-menu default follows `guardrails.visible_menu_default != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.visible_menu_default // true'` (default true). When
> `false`, direct-URL navigation is allowed without the visible-menu-first requirement.

UI tests ต้องเริ่มจาก **visible menu navigation** เป็น default

ถ้า skip menu → ระบุ:
- `DIRECT_URL_USER` (URL ที่ user-facing) — ต้องอธิบายเหตุผล
- `DIRECT_URL_TECHNICAL` (สำหรับ tech check เท่านั้น) — label ชัดเจน

ห้าม claim user journey ผ่าน hidden route

## Phase 6 — Output report

แสดง:
```
Test summary
============
Target: web
Scenarios: 5 (PASS: 4, FAIL: 1, BLOCKED: 0)

[FAIL] TC-003 — Search returns empty when DB has results
  Page: /search
  Console: TypeError: cannot read 'items' of undefined
  Screenshot: $EVIDENCE_DIR/TC-003-04-error-state.png   (indexed in EVIDENCE.md)

Next: รัน /ow-fix "search returns empty..." → diagnose
```

## Phase 7 — Auto-merge on PASS (worktree mode เท่านั้น)

วิ่งเฉพาะ **`WT_MODE=on` AND ทุก scenario PASS AND ไม่มี `--no-merge`** → merge feature branch กลับ base branch
**local เท่านั้น (ไม่ push)** + cleanup worktree. 🔴 **non-destructive เด็ดขาด** — ไม่แตะงาน uncommitted ใน main tree
("อย่าไป restore file อื่นที่ change อยู่" — กฎห้ามแตะงานคู่ขนาน ขยายมาถึง merge step).

🔴 **ข้าม Phase 7 (ไม่ merge, เก็บ worktree ไว้) เมื่อ:**
- scenario ใด ๆ FAIL/BLOCKED → user เข้า worktree (`$WT`) แก้ต่อ แล้วรัน `/ow-test` ซ้ำ
- `--no-merge` → user review ก่อน merge เอง
- `WT_MODE=off` → ไม่มี worktree (จบที่ Output ตามปกติ)

### 7.1 Pre-merge guards (ทุก fail = STOP, เก็บ worktree, ไม่ destructive)
```bash
# defensive re-read (เผื่อ bash block แยก call จาก Phase 0.5 → var ไม่ persist): merge เป็น step สำคัญ ต้อง self-sufficient
[ -n "$WT" ] || WT=$(grep -m1 '^worktree_dir:' "$PLAN_FILE" | sed -E 's/^worktree_dir:[[:space:]]*//')
[ -n "$BR" ] || BR=$(grep -m1 '^worktree_branch:' "$PLAN_FILE" | sed -E 's/^worktree_branch:[[:space:]]*//')
[ -n "$BASE" ] || BASE=$(grep -m1 '^worktree_base:' "$PLAN_FILE" | sed -E 's/^worktree_base:[[:space:]]*//')
[ -n "$REPO" ] || { REPO=$(grep -m1 '^worktree_repo:' "$PLAN_FILE" | sed -E 's/^worktree_repo:[[:space:]]*//'); REPO="${REPO:-$MAIN_ROOT}"; }
[ -n "$BR" ] && [ -n "$BASE" ] && [ -n "$REPO" ] || { echo "🛑 worktree fields ไม่ครบใน $PLAN_FILE — ข้าม merge (เก็บ worktree)"; exit 0; }
SLUG="${BR#plan/}"
CUR=$(git -C "$REPO" rev-parse --abbrev-ref HEAD)
if [ "$CUR" != "$BASE" ]; then
  echo "🛑 main tree อยู่ branch '$CUR' ไม่ใช่ base '$BASE' — ไม่ checkout (กันแตะงาน uncommitted ของคุณ)"
  echo "   worktree เก็บไว้: $WT — กลับมา '$BASE' แล้วรัน /ow-test ซ้ำ หรือ merge เอง: git -C \"$REPO\" merge --no-ff $BR"
  exit 0    # ไม่ใช่ error — แค่ยังไม่พร้อม merge
fi
git -C "$REPO" log "$BASE..$BR" --oneline | head -1 >/dev/null 2>&1 \
  || { echo "ℹ️ ไม่มี commit ใหม่บน $BR (worktree ว่าง?) — ข้าม merge"; exit 0; }
```
🔴 **ห้าม `git checkout $BASE`** — main tree อยู่บน base อยู่แล้ว (guard ด้านบน); ถ้าไม่ใช่ = STOP (ไม่ switch = ไม่เสี่ยงงาน user)
🔴 **ห้าม `git pull`** — flow นี้ local เท่านั้น (push/sync = `/ow-git`)

### 7.2 Non-destructive merge (--no-ff, local)
```bash
TITLE=$(grep -m1 '^title:' "$PLAN_FILE" | sed -E 's/^title:[[:space:]]*//; s/^"//; s/"$//')
git -C "$REPO" merge --no-ff "$BR" -m "Merge plan/$SLUG: ${TITLE:-$SLUG}

<Co-Authored-By per project convention>"
if [ $? -ne 0 ]; then
  # git ปฏิเสธ/conflict — non-destructive: abort คืนสภาพก่อน merge (uncommitted ของ user อยู่ครบ)
  git -C "$REPO" merge --abort 2>/dev/null || true
  echo "🛑 merge ไม่สำเร็จ (conflict หรือ local change ทับไฟล์ที่ merge แตะ) — main tree คืนสภาพก่อน merge"
  echo "   uncommitted ของคุณอยู่ครบ · worktree + branch เก็บไว้: $WT ($BR)"
  echo "   resolve เอง: cd \"$REPO\" && git merge --no-ff $BR    (หรือเข้า worktree แก้ conflict)"
  exit 0
fi
MERGE_SHA=$(git -C "$REPO" rev-parse HEAD)
```
🔴 **`git merge` non-destructive by design** — ถ้าจะทับไฟล์ที่มี local uncommitted change → git **abort เอง ไม่เขียนทับ**;
เรา `merge --abort` ซ้ำให้ index สะอาดแล้ว STOP. **ห้าม `reset --hard` / `git stash` / `git checkout --` / `git clean`**
เพื่อดัน merge ให้ผ่าน = ลบงาน uncommitted ของ user. conflict = งานของ user, ไม่ใช่ของ skill.

### 7.3 Cleanup + record (merge สำเร็จเท่านั้น)
```bash
git -C "$REPO" worktree remove "$WT" 2>/dev/null || git -C "$REPO" worktree remove --force "$WT"
git -C "$REPO" branch -d "$BR" 2>/dev/null || true     # -d (merged-only) ปลอดภัย — ไม่ใช้ -D
```
อัปเดต `$PLAN_FILE` frontmatter (surgical **Edit**, MAIN_ROOT): `worktree_status: merged` · `merge_commit: <MERGE_SHA>`

### 7.4 Handoff
```
✅ Smoke PASS → merged plan/<slug> เข้า <base> (local, <sha>) + cleanup worktree
   main tree: <base> @ <sha> (ยังไม่ push)
🎯 Next: /ow-git --bump   # push + version bump (— /ow-test ไม่ push เด็ดขาด)
```

## Output (3 หัวข้อบังคับ)

1. **Result** — target ที่ test + scenario summary (PASS/FAIL/BLOCKED counts ตาม status taxonomy) + worktree merge result (merge sha / STOP reason — ถ้า worktree mode)
2. **Verification / Evidence** — commands ที่รันจริง (`git diff`, server, test, `git merge --no-ff`) พร้อม exit code + evidence folder path + screenshot count; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — flaky tests, blocked scenarios, suggested fix-log; worktree mode → "รัน `/ow-git --bump` เพื่อ push" (PASS) หรือ "worktree เก็บไว้ที่ … แก้ต่อ" (FAIL/conflict)

## ห้าม

- ห้ามแต่ง screenshot, console log, network log
- ห้ามรัน test กับ production env
- ห้าม claim PASS ถ้า test ไม่ได้รันจริง — mark `NOT_RUN_RISK` แทน
- ห้าม commit evidence ที่มี PII โดยไม่ mask
- 🔴 worktree mode → **ห้าม push** (merge local เท่านั้น — push เป็นงาน `/ow-git`)
- 🔴 worktree merge → **ห้าม `git reset --hard` / `git stash` / `git checkout --` / `git clean`** เพื่อดัน merge ให้ผ่าน — ลบงาน uncommitted คู่ขนานของ user; conflict/dirty = STOP เก็บ worktree ให้ user resolve
- 🔴 **ห้าม auto-merge ถ้ามี scenario FAIL/BLOCKED** หรือมี `--no-merge` — เก็บ worktree ไว้แก้ต่อ
