---
description: Fix GitHub bug issues end-to-end — auto-discover real-bugs, parallel worktree agents diagnose+fix+test+commit, auto-merge to base branch locally (NO push), handoff to /ow-test + /ow-git
---

# /ow-fix-issue — Issue → Fix Orchestrator (parallel worktree)

รับ GitHub issue (single / batch / cluster) → spawn **worktree agents** ขนานกัน diagnose + implement + test + commit แต่ละ fix ใน working tree แยก → **auto-merge** fix branch เข้า base branch ของแต่ละ submodule (serial ภายใน submodule) → cleanup → **STOP** handoff ให้ user รัน `/ow-test` + `/ow-git`

> **กฎหลัก:** `/ow-fix-issue` = **parallel implement + serial merge (local) + cleanup** ภายใน scope เดียว — user invoke = approval ครอบคลุม `commit` + `merge (local)` + `worktree remove`
> **แต่ห้าม push, ห้าม flip `ready for test`, ห้าม comment, ห้าม close issue** — handoff กลับ user ที่ขั้น `/ow-test` + `/ow-git`
>
> ขั้นนี้ต่อจาก `/ow-triage-issues` — หยิบเฉพาะ real-bug ที่ confirm แล้ว (มี label `bug`, ไม่มี question/wontfix/need-info/not-implement-yet)

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

## Why auto-merge but no push?

obsidian-workflow มีกฎ **no auto-push** เด็ดขาด — push + version bump + cross-submodule coordination เป็นงานของ `/ow-git` (user trigger เท่านั้น) `/ow-fix-issue` merge เข้า base branch **local** ได้ (reversible, ยังไม่ออกนอกเครื่อง) แต่หยุดก่อน push เสมอ

## Prerequisite

- `gh` CLI authenticated + อยู่ใน git repo
- subagent `gh-issue` enabled ใน `.ow.yml` `subagents:` (default on — ดู `/ow-init` Phase 5)
- specialized subagent ที่เกี่ยวข้อง enabled (`backend` / `frontend` / `mobile` ตาม stack — set ใน `.ow.yml` `subagents:`)
- `.ow.yml` มี `submodules:` ที่ถูกต้อง (ถ้าเป็น multi-repo) หรือ `[]` (monorepo)

## Trigger

```
/ow-fix-issue                              # 🌟 DEFAULT — auto-discover ทุก real-bug + per-group approval + parallel execute
/ow-fix-issue --dry-run                    # default mode + แสดง plan แล้วจบ ไม่ approve ไม่ run

# Specific mode (ระบุ issue เอง — ข้าม auto-discover + approval gate)
/ow-fix-issue #62                          # 1 issue → 1 worktree, 1 agent
/ow-fix-issue #62 #63 #64                  # 1 explicit group (cluster) — 1 worktree, 1 agent closes ทั้งหมด
/ow-fix-issue #62 --diagnose-only          # agent หยุดที่ fix-log + capture before evidence (เหมือน /ow-fix flow)
/ow-fix-issue #62 --submodule web          # บังคับ submodule ถ้า detect ไม่ออก
```

**Mode detection (จาก `$ARGUMENTS`):**
- ไม่มี `#NN` → **Auto-discover mode** (default) → ทำ Phase 0.5
- มี `#NN` → **Specific mode** → ข้าม Phase 0.5 (auto-discover + approval) ไป Phase 1 เลย (invoke = approval)

> **comment version + flip `ready for test` ไม่ใช่งานของ command นี้** — เป็นงานของ `/ow-git --bump` หลัง push:
> มันอ่าน `Closes #NN` จาก commit ที่ push แล้ว comment "fixed in vX.Y.Z" + flip label `ready for test` ให้อัตโนมัติ
> (เพราะ "version ที่ fix" รู้ได้ก็ต่อเมื่อ push + bump เสร็จแล้ว — Phase 1-6 ของ command นี้ไม่ push/ไม่รู้ version)
> ลำดับเต็ม: `/ow-fix-issue #NN` → `/ow-test` → `/ow-git --bump patch`

---

## Phase 0 — Pre-flight

### 0.1 gh CLI + repo
```bash
[ -n "$VAULT_ABS" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
gh auth status || { echo "Run 'gh auth login'"; exit 1; }
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
MAIN_ROOT="$(git rev-parse --show-toplevel)"
```

### 0.2 Resolve repo layout (monorepo vs multi-repo submodules)

อ่าน `.ow.yml` `submodules:`:

```yaml
# Multi-repo example
submodules:
  - name: api
    path: ./api
    branch: develop      # base branch ของ submodule นี้
  - name: web
    path: ./web
    branch: develop
  - name: app
    path: ./app
    branch: master
```

| Layout | ตีความ |
|---|---|
| `submodules: []` (monorepo) | 1 repo เดียว — base branch = current branch หรือ `main`/`develop` ที่ตั้งใน `.ow.yml` `default_branch` (ถ้าไม่มี → current HEAD upstream) — wave parallelism = ขนานที่ implement, serial ที่ merge (1 base branch เดียว) |
| `submodules: [...]` (multi-repo) | แต่ละ submodule มี base branch ของตัวเอง — merge ขนานข้าม submodule, serial ภายใน submodule |

🔴 **ห้าม hardcode `develop`/`master`** — อ่านจาก config เสมอ ต่อ submodule เก็บเป็น `FIX[base_branch]`

### 0.3 Worktrees dir + .gitignore
```bash
mkdir -p "$MAIN_ROOT/worktrees"
grep -qx "worktrees/" "$MAIN_ROOT/.gitignore" 2>/dev/null || echo "worktrees/" >> "$MAIN_ROOT/.gitignore"
```

### 0.4 Validate args (Specific mode)
แต่ละ issue ต้อง:
- มี label `bug` (real bug confirm ผ่าน triage)
- ไม่มี label ใดใน { `question`, `wontfix`, `need info`, `not implement yet`, `in progress`, `ready for test` }
- state = open

ถ้า fail → list issue ที่ skip + reason แล้วถาม user "ยังไป? (yes/no)"

---

## Phase 0.5 — Auto-Discover Mode (🌟 default — เมื่อ `$ARGUMENTS` ไม่มี `#NN`)

🔴 **ข้าม phase นี้ทั้งหมด** เมื่อ user ระบุ issue เอง (Specific mode) → ไป Phase 1

### 0.5.1 Fetch all eligible bugs
```bash
gh issue list \
  --label bug \
  --search "is:open \
            -label:\"in progress\" -label:\"ready for test\" \
            -label:question -label:\"need info\" \
            -label:\"not implement yet\" -label:wontfix" \
  --limit 100 \
  --json number,title,body,labels,comments,createdAt,url
```

ผลลัพธ์ = pool ของ real-bug ที่พร้อม fix (ผ่าน triage แล้ว)

### 0.5.2 Auto-group (cluster vs standalone)
สำหรับแต่ละ issue:
- มี label `cluster` → parse comment "**Cluster proposal:**" หา list `#<NN>, #<MM>, ...` → group ด้วย member list ที่ตรงกัน (sort เพื่อ canonical group key)
- ไม่มี `cluster` → standalone (1 issue = 1 group)
- ถ้า cluster member อยู่หลาย proposal (overlap) → merge เป็น group เดียว (transitive closure)

### 0.5.3 Auto-priority order
เรียง group (top to bottom = run first):

| Priority | Group type | เหตุผล |
|---|---|---|
| 1 | P0 standalone | severe + เร็ว (1 fix) — unblock ก่อน |
| 2 | P0 cluster | severe แต่หลาย fix |
| 3 | P1 standalone | major + เร็ว |
| 4 | P1 cluster | major หลาย fix |
| 5 | P2 standalone, P2 cluster | minor |
| 6 | P3 standalone, P3 cluster | polish |
| 7 | unscored | severity infer ไม่ได้ |

**Severity infer:** จาก issue body field "ระดับความรุนแรง"/"severity" หรือ keyword (P0/blocker/data loss → P0; major → P1; minor → P2; polish/i18n/cosmetic → P3)

**Submodule tie-breaker:** ภายใน priority เดียวกัน → group ตาม submodule order ใน config (ลด context switch + ใช้ dev server ร่วม)

### 0.5.4 Display queue plan (overview — informational)

```
🗂️ Queue plan — N groups (auto-ordered)

| # | Group                    | Submodule | Issues               | Priority |
|---|--------------------------|-----------|----------------------|----------|
| 1 | P0 standalone — #37      | api       | [#37](url)           | P0       |
| 2 | P1 standalone — #35      | web       | [#35](url)           | P1       |
| 3 | Cluster A — register     | web       | [#62](u) [#63](u)    | P1       |
| 4 | Cluster B — upload       | app       | [#58](u) [#59](u)    | P2       |

🔍 จะถามทุก group up-front (Phase 0.5.5) แล้ว execute parallel ตาม submodule (Phase 0.5.6)
```

🔴 **`--dry-run` flag = แสดง plan แล้วจบ ไม่เข้า 0.5.5**

### 0.5.5 Approval phase (🔴 ถามทุก group **ก่อน** เริ่ม execute)

วน loop ผ่านทุก group ถาม user ทีละ group — **ไม่ run อะไรเลย แค่เก็บคำตอบ**

```
for GROUP in queue:
  ──────────────────────────────────────
  🛑 Approve Group <N>/<TOTAL> — <name>
     Submodule: <name>     Priority: P<n>
     Issues:
       - [#NN](url) — <title> (<severity hint>)
       - [#MM](url) — <title>

  - "yes" / "y"  → mark approved → ถาม group ถัดไป
  - "skip"       → mark skipped → ถาม group ถัดไป
  - "stop"       → จบ approval phase (group ที่เหลือถือว่า skipped) → execute เฉพาะที่ approve
  - "edit"       → user แก้ list issue ใน group → show ใหม่ + ถามอีกครั้ง
  ──────────────────────────────────────
```

🔴 **Approval phase = ไม่มี execution เลย** — แค่ collect yes/skip/stop
🔴 **ตอบไม่ชัด = ถามซ้ำ ห้ามเดา**

หลัง approval ครบ → แสดง summary approved list

### 0.5.6 Parallel execution — decoupled implement vs merge

**Core insight:** ตัวที่ชน base branch จริง ๆ คือ **merge step** เท่านั้น — implement step (เขียน code ใน worktree) ไม่ชนกันเพราะแต่ละ group มี worktree + branch ของตัวเอง

#### Stage A — Implement (parallel ทุก approved group)
- เปิด worktree ให้ทุก approved group พร้อมกัน (1 group = 1 worktree = 1 agent)
- spawn agent ทุก group ลง concurrency pool
- **Cap = global max concurrent agents** (default 7) — ถ้า approved > 7 ก็ batch ทีละ 7
- agent ใน worktree ทำ Phase 4.1 ตามปกติ (diagnose → test → fix → test pass → commit)

🔴 **Implement = ขนานเต็มที่** — แต่ละ worktree แยก, base branch ไม่ถูกแตะตอน implement

#### Stage B — Merge (serial **ภายใน** submodule, parallel **ข้าม** submodule — local only)
- เมื่อ agent commit เสร็จ → enter merge queue ของ submodule ที่ group นั้นแตะ
- 1 merge worker ต่อ submodule (parallel ข้าม submodule)
- แต่ละ worker: `git checkout base → pull --ff-only → merge --no-ff → cleanup` ทีละ group serial
- **monorepo:** 1 merge worker เดียว (1 base branch) — merge serial ทุก group

🔴 **Merge ภายใน submodule = serial บังคับ** — `git merge` ต้อง atomic บน base branch
🔴 **Merge = local เท่านั้น — ไม่ push** (push เป็นงาน `/ow-git`)

#### Failure handling
- **Test fail ใน Stage A** → mark group "partial" + ไม่ enter merge queue + ไม่กระทบ group อื่น
- **Merge conflict ใน Stage B** → 🛑 หยุด merge queue ของ submodule นั้นเฉพาะ — submodule อื่นทำต่อ — worktree เก็บไว้ + รายงาน user
- **Stage A fatal (worktree create fail)** → skip group นั้น, group อื่นทำต่อ

### 0.5.7 Final report → ไป Phase 6

---

## Phase 1 — Resolve Pool (Specific mode)

### 1.1 Direct issue list
ถ้า `$ARGUMENTS` มี `#NN` → ดึงเลขออกมา list

### 1.2 Cluster reference (`cluster:<slug>`)
หา issue ที่มี label `cluster` + comment มี `Cluster proposal:` + slug ตรงกัน — หรือ simpler: ใช้ Phase 1.1 (user ใส่เลขทั้งกลุ่มเอง)

---

## Phase 2 — Submodule Detection (per issue)

แต่ละ issue → ตัดสินว่าเป็น submodule ไหน (monorepo = ข้าม phase นี้):

| Hint ใน issue body | Submodule (map ตาม config) |
|---|---|
| "Mobile App", "iOS", "Android", "Flutter", "React Native" | mobile submodule |
| "Web", "Dashboard", "Vue", "React", "หน้าเว็บ" | web submodule |
| "API", "GraphQL", "mutation", "schema", "endpoint", error pattern `Validation failed` | api submodule |
| Cross-cutting (เช่น validation ใน API + form ใน web) | `cross` — แจ้ง user ก่อน |

🔴 **map keyword → submodule ตาม `.ow.yml` `submodules[].name`** — ถ้า project ตั้งชื่อต่าง (เช่น `backend`/`frontend`) ก็ map ตามนั้น
ถ้าตัดสินไม่ออก → ask 1 message ก่อนต่อ (หรือใช้ `--submodule <name>`)

🔴 **Cross-submodule = ไม่ auto parallel** — fall back serial

---

## Phase 3 — Worktree Setup (per issue, parallel-safe)

### 3.1 Slug + path
```bash
NN=<issue number>
SUBMODULE=<name from config | "" for monorepo>
SLUG=<kebab-case จาก issue title, ≤ 5 words>
WORKTREE_DIR="$MAIN_ROOT/worktrees/${SUBMODULE:-main}-${NN}-${SLUG}"
BRANCH="fix/${NN}-${SLUG}"
TARGET_REPO="${SUBMODULE_PATH:-$MAIN_ROOT}"   # submodule path or main root

# 🔴 Resolve EVIDENCE_DIR เป็น ABSOLUTE path ใต้ MAIN_ROOT/test-artifacts (ไม่ใช่ worktree)
# ต้อง: (1) รันจาก $MAIN_ROOT — เพราะ resolver root ตัวเองที่ project root ที่ใกล้ที่สุด ซึ่ง
#        "ภายใน worktree จะ root ที่ worktree"  (2) บังคับ absolute ก่อนใช้ — agent อยู่ใน
#        worktree → relative path จะตกไปที่ worktree แล้วหายตอน cleanup (Phase 5.3)
EV_REL=$(cd "$MAIN_ROOT" && OW_EVIDENCE_SOURCE=fix OW_EVIDENCE_SLUG="${NN}-${SLUG}" \
  bash "$MAIN_ROOT/scripts/ow-paths.sh" --check EVIDENCE_ROOT)
case "$EV_REL" in /*) EVIDENCE_DIR="$EV_REL" ;; *) EVIDENCE_DIR="$MAIN_ROOT/$EV_REL" ;; esac
mkdir -p "$EVIDENCE_DIR"   # = <MAIN_ROOT>/test-artifacts/<date>/fix-<NN>-<slug>/  (absolute)
```

🔴 **`EVIDENCE_DIR` resolve โดย orchestrator (มี bash) แล้วส่งค่า absolute เข้า agent prompt** — agent ไม่มี bash tool + อยู่ใน worktree จึง resolve เองไม่ได้ (จะ root ผิดไปที่ worktree → เก็บลง root project / worktree แทน test-artifacts)

### 3.2 Base branch (อ่านจาก config — ห้าม hardcode)
- multi-repo: `BASE_BRANCH = submodules[name].branch`
- monorepo: `BASE_BRANCH = .ow.yml default_branch` หรือ current upstream

🔴 **เก็บเป็น `FIX[base_branch]`** เพื่อ Phase 5 อ่านได้

### 3.3 Create worktree (ระดับ submodule/repo ที่จะแก้)
```bash
git -C "$TARGET_REPO" fetch origin
git -C "$TARGET_REPO" worktree add -b "$BRANCH" "$WORKTREE_DIR" "origin/$BASE_BRANCH"
```

🔴 **worktree ระดับ submodule เท่านั้น** (ไม่ใช่ superproject) — เลี่ยงปัญหา submodule init recursion

### 3.4 Flip label: + `in progress`
```bash
gh issue edit "$NN" --add-label "in progress"   # ไม่ลบ bug — bug ยังเป็น bug แค่กำลังทำ
```

---

## Phase 4 — Parallel Implement Agents (1 message, N agents)

**ส่ง Agent N ตัวใน 1 message** (max 7 parallel) — `subagent_type` ตาม submodule:

| Submodule role | subagent_type |
|---|---|
| web / frontend | `frontend` |
| mobile | `mobile` |
| api / backend | `backend` |
| monorepo (mixed) | เลือกตาม area ของ fix |

🔴 **ห้ามใช้ `isolation: "worktree"` flag** — เราจัด worktree เอง (Phase 3) แล้ว

### 4.1 Agent prompt template

ส่ง prompt structured ให้แต่ละ agent (เปลี่ยน `<placeholder>` ตาม issue + path ที่ resolver คืนมา):

```
You are implementing a fix in an isolated git worktree.

## PROJECT CONTEXT (resolved — authoritative, do NOT rediscover)
- Working tree: <WORKTREE_DIR>   (work ONLY here — never touch code outside it)
- Branch: <BRANCH>   ·   Submodule/repo: <SUBMODULE or main>   (omit if single-repo)
- GitHub issue: https://github.com/<REPO>/issues/<NN>
- VAULT_ABS: <resolved vault path>   (fix-log + test-plan TEXT notes only)
- FIX_DIR: <resolved $FIX_DIR>   ·   TEST_DIR: <resolved $TEST_DIR>
- EVIDENCE_DIR: <absolute path ที่ orchestrator resolve แล้ว, เช่น /repo/test-artifacts/2026-06-02/fix-62-foo>
  🔴 เขียน evidence binary ทุกไฟล์ลง **EVIDENCE_DIR ตรง ๆ (absolute เท่านั้น)** — ห้ามสร้าง subdir ซ้ำ, ห้ามใช้ relative `test-artifacts/...`
  (คุณอยู่ใน worktree — relative path จะตกไปที่ worktree/root project แล้วหายตอน cleanup; EVIDENCE_DIR นี้อยู่ใต้ MAIN_ROOT แล้ว)
- RULES(coding) / RULES(testing): <named rule file(s), or "(none)">   (Read each — they OVERRIDE generic agent guidance)
- You have no bash tool — this block is your only context channel; if it is absent, STOP.

## What to do (in order)

1. **Read issue** — use the `gh-issue` agent on #<NN> to get full body + image observations. Authoritative bug description.

2. **Diagnose root cause** — work inside `<WORKTREE_DIR>` only. Read code, grep, identify file:line.

3. **Create fix-log** at `<FIX_DIR>/<YYYY-MM-DD-HHMM>-<NN>-<slug>.md` using the /ow-fix template.
   Add to frontmatter:
   ```yaml
   github_issue: https://github.com/<REPO>/issues/<NN>
   worktree: <WORKTREE_DIR>
   branch: <BRANCH>
   status: in-progress
   ```

4. **Write test FIRST** (test-first mandate — Working Standard):
   - **Bootstrap `$EVIDENCE_DIR/EVIDENCE.md`** จาก `.ow/templates/evidence/EVIDENCE.md` **ก่อน** capture แรก — กรอก front-matter (`source: fix`, `slug: <NN>-<slug>`, `issue: #<NN>`, `doc: "[[<test-plan slug>]]"`, `captured:`) + ตารางว่าง `| ID | File | TC | State | Type |`. จากนั้นเพิ่ม 1 แถว **ทุกครั้งที่ capture** ไฟล์ (manifest = keep-list; ไฟล์ที่ไม่อยู่ในตารางจะถูก /ow-evidence ย้ายไป `_archive/`)
   - Locate test dir for the stack (web: src/__tests__/, api: *.Tests/, app: test/)
   - Add a test that reproduces the bug → must FAIL before fix
   - Capture failure to `$EVIDENCE_DIR/before-test-output.txt`   (EVIDENCE_DIR = absolute path จาก context block; ห้ามเติม subdir) + add row to EVIDENCE.md

5. **Before screenshot** (UI bug) — prefer ดึงจาก issue (เร็ว + ตรงกับ reporter):
   1. จาก issue attachment (default) — gh-issue agent ดาวน์โหลดไว้ที่ /tmp/gh-issue-<NN>/01.png → copy ไป `$EVIDENCE_DIR/before-<slug>.png` + note "from issue attachment"
   2. ถ้า issue ไม่มีภาพ → capture เองผ่าน test-runner convention (playwright/maestro) — เริ่มที่หน้าที่เกิด bug ตรงๆ → save `$EVIDENCE_DIR/before-<slug>.png`
   3. ถ้าไม่ใช่ UI bug → skip screenshot, ใช้ error log ใน `$EVIDENCE_DIR/before-test-output.txt`

6. **Apply minimum correct fix** — Working Standard: smallest change that satisfies Success Criteria. ทุก changed line trace กลับ Success Criteria.
   - No unrelated refactor/format churn: รัน formatter/linter เฉพาะไฟล์ที่ fix นี้แก้ (`<fmt> <files>`) — ห้าม whole-tree `--fix`/`--write` (whole-tree = read-only `--check`)
   - 🔴 revert churn นอก scope = surgical **Edit** เฉพาะไฟล์ที่ fix แก้เอง — **ห้าม `git checkout`/`git restore`/`git stash`/`git clean`** (ลบ uncommitted ทั้งไฟล์ ไม่ใช่แค่ format; แม้อยู่ใน worktree ก็ลบงานของ agent เอง)

7. **Re-run test** — must PASS now. Capture to `$EVIDENCE_DIR/after-test-output.txt`.

8. **After screenshot** (UI bug) — 🔴 **บังคับ ถ้า step 5 มี before-<slug>.png** — capture **เองผ่าน test-runner convention** (playwright/maestro) ที่ **หน้า/route + viewport เดียวกับ before** เพื่อเทียบกันได้ → save `$EVIDENCE_DIR/after-<slug>.png` showing fixed state
   - ❌ ห้ามใช้ภาพจาก issue เป็น after — after ต้องมาจาก build ที่ fix แล้วเท่านั้น (no-fake-evidence)
   - skip ได้เฉพาะกรณีเดียว: step 5 skip (ไม่ใช่ UI bug) → note "non-UI, after = after-test-output.txt"
   - 🔴 **Pairing invariant:** before-<slug>.png exists ⇒ after-<slug>.png MUST exist — มี before แต่ไม่มี after = evidence ไม่ครบ (step 13 fail)

9. **Regression check (scoped)** — รัน test เฉพาะ role/area ที่เกี่ยวข้องกับ issue เท่านั้น ห้ามทดสอบทุก role.
   Document scope ใน EVIDENCE.md `## Regression check` (role/area ที่เทส + เหตุผลที่ skip)

10. **Create TestPlan vault file** at `<TEST_DIR>/<YYYY-MM-DD-HHMM>-<NN>-<slug>.md` (flat — ไม่มี `<slug>/` folder):
    frontmatter (tags: [type/test-plan], links → fix-log + github_issue) + Scope + Test Cases (TC-01..) layer/role/steps/expected/actual/evidence-path.
    🔴 **TestPlan เก็บแค่ TEXT** — ไม่ฝัง evidence index ใน vault. evidence index อยู่ใน **`$EVIDENCE_DIR/EVIDENCE.md` manifest** (step 13) ซึ่งชี้กลับ test-plan ผ่าน field `doc:`. ใส่แค่ pointer line ใน test-plan: `Evidence: $EVIDENCE_DIR/EVIDENCE.md`.
    Link back from fix-log: add `test_plan:` field.

11. **Update fix-log:** set `status: fixed`, tick Success Criteria + Test Cases checkboxes (ยกเว้นขั้นที่เป็นงาน user เช่น push), add `test_plan:` field.

12. **Commit in worktree (NO PUSH):**
    ```bash
    cd <WORKTREE_DIR>
    git add -A
    git commit -m "fix(<scope>): <one-line> (#<NN>)

    Closes #<NN>

    Co-Authored-By: <AI signature per project convention>"
    ```
    🔴 DO NOT push — no-auto-push rule. STOP after commit.
    (`Closes #NN` สำคัญ — `/ow-git --bump` ใช้บรรทัดนี้หา issue เพื่อ comment version + flip label หลัง push)

13. **Evidence bundle** ใน `$EVIDENCE_DIR/` (absolute path จาก context block — ห้ามสร้าง subdir `fix-<NN>-<slug>` ซ้ำ; EVIDENCE_DIR encode ชื่อนี้อยู่แล้ว) — ต้องมี (ห้ามขาด):
    - before-test-output.txt (Step 4) — FAIL ก่อน fix
    - before-<slug>.png (Step 5) — UI bug state (skip ถ้าไม่ใช่ UI + note)
    - after-test-output.txt (Step 7) — PASS หลัง fix
    - after-<slug>.png (Step 8) — UI fixed state, **captured from fixed build** (NOT from issue)
    - build-output.txt — build log (full stdout+stderr)
    - EVIDENCE.md — **canonical manifest** จาก `.ow/templates/evidence/EVIDENCE.md`. สร้าง **ตั้งแต่เริ่ม capture** (step 4) แล้วเติมแถวระหว่างทำงาน — front-matter: `source: fix`, `slug: <NN>-<slug>`, `issue: #<NN>`, `doc: "[[<test-plan slug>]]"`, `captured:`, `build:`, `test:`; ตาราง `| ID | File | TC | State | Type |` 1 แถว/artifact; + prose Quality / Before / After / Regression / Success-criteria→Evidence
    🔴 EVIDENCE.md ห้ามขาด — /ow-evidence + /ow-verify อ่านไฟล์นี้ตรงๆ; no file = reviewer assumes "not verified"
    🔴 **before/after pairing:** มี before-<slug>.png ⇒ ต้องมี after-<slug>.png คู่เสมอ — มี before อย่างเดียว = ขาด evidence, agent ต้องวน step 8 ให้ครบก่อน return

14. **Vault sync** — only if fix changed documented behavior (UI label, API contract, permission, master-data). Otherwise skip — vault sync เฉพาะ documented behavior ที่เปลี่ยนจริง.

## What you MUST NOT do
- ❌ DO NOT push to remote
- ❌ DO NOT change label on GitHub issue (orchestrator does that)
- ❌ DO NOT comment on / close the GitHub issue
- ❌ DO NOT modify files outside <WORKTREE_DIR> except vault + evidence
- ❌ DO NOT touch other worktrees (parallel agents working)
- ❌ DO NOT skip test creation — required per the test-first mandate

## Output
Return structured summary:
- ✅/❌ per step 1-13
- Commit hash, files changed (paths within worktree)
- Test result (before fail → after pass)
- Evidence dir path, vault files synced
- Any blockers (if blocked: leave fix-log status: in-progress, do NOT commit broken state)
```

### 4.2 Wait for all agents

ทุก agent done → รวบรวม output → ตรวจ commit hash ครบ? test pass? evidence dir ครบ?
🔴 **ตรวจ evidence landing (กัน leak ออก root/worktree):** evidence ต้องอยู่ใน `$EVIDENCE_DIR` (ใต้ `$MAIN_ROOT/test-artifacts/`) เท่านั้น — ยืนยัน:
```bash
ls "$EVIDENCE_DIR"/ >/dev/null 2>&1 || echo "⚠️ #$NN — EVIDENCE_DIR ว่าง/ไม่มี (agent อาจเขียน relative ผิดที่)"
# ตรวจไม่มี evidence หลงไปที่ root project หรือ worktree root
git -C "$MAIN_ROOT" status --porcelain | grep -E '(before|after)-.*\.(png|txt)$|/EVIDENCE\.md$' \
  && echo "🛑 #$NN — เจอ evidence นอก test-artifacts (root/worktree) → ย้ายเข้า $EVIDENCE_DIR + ห้าม commit ติดไปกับ fix"
```
ถ้าเจอ evidence ที่ root/worktree → ย้ายเข้า `$EVIDENCE_DIR` ก่อน (อย่าให้ติด commit / อย่าให้หายตอน cleanup worktree)
🔴 **ตรวจ before/after pairing:** ถ้า evidence dir มี `before-*.png` แต่ไม่มี `after-*.png` → evidence ไม่ครบ ส่ง agent กลับไป capture after (step 8) ก่อน mark fixed — ห้าม mark fixed ทั้งที่ขาด after screenshot
ถ้า agent fail → keep `in progress` label + รายงาน user

---

## Phase 5 — Auto-Merge to base branch (serial within submodule, LOCAL only)

หลัง agents เสร็จ (status: fixed) → merge fix branch เข้า base branch ของแต่ละ submodule **local** (ไม่ push)

> Base branch ต่อ submodule = `${FIX[base_branch]}` (จาก config, Phase 3.2). 🔴 ห้าม hardcode

### 5.1 Pre-merge guard
```bash
git -C "$TARGET_REPO" log "${FIX[base_branch]}..$BRANCH" --oneline | head -1 || {
  echo "Skip $BRANCH — no new commits"; continue;
}
```

### 5.2 Serial merge loop (ภายใน submodule — ห้าม parallel)
```bash
for FIX in "${FIXES[@]}"; do
  TARGET_REPO="${FIX[repo]}"           # submodule path or main root
  BASE="${FIX[base_branch]}"           # from config
  BRANCH="${FIX[branch]}"
  NN="${FIX[nn]}"; TITLE="${FIX[title]}"

  cd "$TARGET_REPO"
  git checkout "$BASE" || { report "Cannot checkout $BASE in $TARGET_REPO"; exit; }
  git pull --ff-only origin "$BASE" || { report "$TARGET_REPO/$BASE pull failed (diverged?) — user resolve"; exit; }

  git merge --no-ff "$BRANCH" -m "Merge fix #$NN: $TITLE

Closes #$NN

Co-Authored-By: <AI signature per project convention>"

  if [ $? -ne 0 ]; then
    report "🛑 Merge conflict on #$NN ($TARGET_REPO/$BASE)"
    report "Worktree + branch เก็บไว้ที่: ${FIX[worktree]}"
    report "User resolve เอง: cd $TARGET_REPO && git status"
    exit   # หยุดเฉพาะ submodule นี้ — submodule อื่นทำต่อ
  fi
done
```

🔴 **ไม่มี `git push` ใน Phase 5** — merge local แล้วจบ; push ทำผ่าน `/ow-git`
🛑 **Conflict = STOP ทันที** (เฉพาะ submodule นั้น) — fix ถัดไปใน submodule เดียวกัน hold; submodule อื่น continue

### 5.3 Cleanup worktrees (เฉพาะตัวที่ merge สำเร็จ)
```bash
for FIX in "${MERGED[@]}"; do
  git -C "${FIX[repo]}" worktree remove "${FIX[worktree]}" || \
    git -C "${FIX[repo]}" worktree remove --force "${FIX[worktree]}"
  git -C "${FIX[repo]}" branch -d "${FIX[branch]}"
done
```

### 5.4 Update fix-log
อัปเดต frontmatter `fixed_commit:` ให้เป็น **merge commit hash บน base branch** (ไม่ใช่ fix branch commit) — เพราะ revert ใช้ merge hash. (`fixed_in_version` ยังว่าง — `/ow-git --bump` stamp ให้ตอน push)

---

## Phase 6 — Handoff Report (🔴 STOP ที่นี่ — ไม่ push)

```
✅ Parallel fix + auto-merge (local) complete — base branches ready for /ow-test + /ow-git

| # | Title                       | Submodule | Base    | Merge commit | Status      |
|---|-----------------------------|-----------|---------|--------------|-------------|
| 62| <title>                     | web       | develop | abc1234      | ✅ merged   |
| 63| <title>                     | web       | develop | def5678      | ✅ merged   |
| 74| <title>                     | app       | master  | 1357ace      | ✅ merged   |
| 67| <title>                     | web       | develop | —            | ❌ test fail (worktree เหลือไว้) |

📎 Fix-logs: $FIX_DIR
📂 Evidence: <MAIN_ROOT>/test-artifacts/<DATE>/fix-<NN>-<slug>/   (gitignored — ไม่ติด commit)

📦 Base branches updated LOCALLY (ยังไม่ push):
  <web>/develop  (#62, #63)
  <app>/master   (#74)

🎯 Next step (user trigger):
  1. /ow-test               # smoke เฉพาะ area/role ที่ fix แตะ (จาก fix-log + reporter)
  2. /ow-git --bump patch   # push + bump + 🟢 AUTO comment "fixed in vX.Y.Z" + flip label `ready for test`
                              #   ต่อทุก issue ที่ commit มี `Closes #NN` (ปิด auto ด้วย --no-ready-for-test)
  3. หลัง tester verify ผ่าน → user/tester close issue เอง

🛑 Manual follow-up:
  - #67 (test fail) — worktree เหลือไว้ที่ worktrees/web-67-<slug>/
    User เข้าไป diagnose ต่อ หรือ `git worktree remove --force` ถ้าเลิก
```

---

## Phase 7 — Failure Handling

ถ้า agent fail (test fail / cannot reproduce / blocked):
- Keep `in progress` label (ห้าม rollback เป็น `bug` เฉยๆ — สับสน)
- fix-log status: `in-progress` (ไม่ใช่ `fixed`)
- ไม่ commit ใน worktree (keep dirty เพื่อ user ดูเอง)
- รายงาน user ระบุ blocker

User: เข้า worktree แก้ต่อ + commit เอง / หรือ `git -C <repo> worktree remove <path> --force`

---

## Rules

### Mode
- 🌟 **Default = Auto-Discover** — ไม่มี args → Phase 0.5 (discover + per-group approval + parallel Stage A/B)
- **Specific** — มี `#NN` → ข้าม Phase 0.5 + ข้าม approval gate (invoke = approval) → Phase 1
- **Dry-run** — `--dry-run` ใช้ได้ทั้ง 2 modes (default: queue plan แล้วจบ / specific: resolved issues + planned worktree แล้วจบ)

### Scope (ทำได้ในรอบ invoke เดียว)
- ✅ Auto-discover real-bugs จาก GitHub (default)
- ✅ Per-group approval gate (default)
- ✅ Parallel implement ทุก approved group (Stage A, cap N agents)
- ✅ Commit ใน fix branch (agent ทำใน worktree)
- ✅ **Merge เข้า base branch LOCAL** — serial ภายใน submodule, parallel ข้าม submodule (Stage B)
- ✅ Worktree + fix branch cleanup หลัง merge สำเร็จ
- ✅ อัปเดต fix-log + label `in progress` บน GitHub

### สิ่งที่ command นี้ **ไม่ทำ** (handoff กลับ user)
- 🔴 **ห้าม push** — `/ow-git` เท่านั้น (version bump + cross-submodule coordination)
- 🔴 **ห้าม flip `ready for test`** — เป็น post-push state; `/ow-git --bump` flip ให้หลัง push (ผ่าน `Closes #NN`)
- 🔴 **ห้าม comment GitHub** — comment "fixed in vX.Y.Z" เกิดที่ `/ow-git --bump` หลัง push เท่านั้น (version จริงรู้ตอนนั้น)
- 🔴 **ห้าม close issue** — tester verify ก่อน user/tester close (แม้หลัง push ก็ไม่ close)
- 🔴 **ห้ามรัน `/ow-test` smoke เอง** — user trigger (test serial, port ชน, อาจต้อง emulator)

### Safety stops
- 🛑 **Agent test FAIL** → ทิ้ง worktree dirty + ไม่ enter merge queue — group อื่นทำต่อ
- 🛑 **Merge conflict ใน Stage B** → หยุด merge queue ของ submodule นั้น — submodule อื่นทำต่อ — user resolve แล้ว `/ow-git` เอง
- 🛑 **`git pull --ff-only` fail** (base diverged) → หยุด merge worker ของ submodule นั้น

### Implementation constraints
- 🔴 **Submodule worktree เท่านั้น** (เลี่ยง submodule init recursion)
- 🔴 **Cross-submodule fix → serial fallback** (ไม่ auto parallel)
- 🔴 **Test creation บังคับ** — agent ห้ามข้าม test-first mandate
- 🔴 **Worktree dir ใน `worktrees/`** (gitignored)
- 🔴 **Merge --no-ff เสมอ** (รักษา fix branch history → revert ง่าย)
- 🔴 **Base branch อ่านจาก config** — ห้าม hardcode `develop`/`master`
- 🔴 **Evidence → `$EVIDENCE_DIR` (absolute, ใต้ `$MAIN_ROOT/test-artifacts/`) เท่านั้น** — orchestrator resolve จาก MAIN_ROOT (ไม่ใช่ worktree) แล้วส่งค่า absolute เข้า agent; ห้าม agent ใช้ relative `test-artifacts/...` (จะตกที่ worktree/root project แล้วหายตอน cleanup) + ห้ามสร้าง subdir `fix-<NN>-<slug>` ซ้ำ
- **Max N global parallel agents** (default 7) — rate limit + output อ่านทัน
- **Commit message:** Conventional Commits + `Closes #<NN>` + Co-Authored-By footer (`Closes #NN` = hook ที่ `/ow-git --bump` ใช้ comment + flip label หลัง push)
- **Fix-log `fixed_commit` = merge commit บน base branch** (revert ใช้ merge hash)
- **No-fake-evidence:** commit hash / merge hash / test result ต้องมาจาก git/test จริง — ห้ามแต่ง

## Output (3 หัวข้อบังคับ)

1. **Result** — merge result table (issue → submodule / base / merge commit / status) + fix-log + test-plan files ที่สร้าง
2. **Verification / Evidence** — commands ที่รันจริง (`gh issue list/view/edit`, `git worktree add/remove`, `git merge --no-ff`, test commands per agent) + before→after test outputs + evidence dir paths + `EVIDENCE.md` ต่อ fix — hash/ผล test มาจาก git/test จริงเท่านั้น
3. **Limitations / Next steps** — partial/failed groups + conflict ที่ค้าง + "ยังไม่ push — รัน `/ow-test` แล้ว `/ow-git --bump patch` (auto comment version + flip `ready for test` ผ่าน `Closes #NN`); close issue หลัง tester verify"

## ห้าม

- ห้าม push ไป remote — push เป็นงาน `/ow-git` เท่านั้น (no auto-push rule)
- ห้าม flip `ready for test` / comment GitHub จาก command นี้ — version comment + label flip เป็นงาน `/ow-git --bump` หลัง push (ผ่าน `Closes #NN`)
- ห้าม close issue ในทุก mode — tester verify ก่อน user/tester close
- ห้าม hardcode base branch (`develop`/`master`) — อ่านจาก `.ow.yml` `submodules[].branch` เสมอ
- ห้ามใช้ `isolation: "worktree"` flag ใน agent — เราจัด worktree เอง (Phase 3)
- ห้ามแก้ไฟล์นอก worktree (ยกเว้น vault + evidence) — agent อื่นทำงานขนานอยู่
- ห้ามเก็บ evidence ที่ root project / worktree root — ต้องลง `$EVIDENCE_DIR` (absolute, ใต้ `$MAIN_ROOT/test-artifacts/`) ที่ orchestrator resolve ให้ (resolver root ที่ worktree = path ผิด → evidence หายตอน cleanup)
- ห้ามข้าม test creation — production code change ต้องมี test ก่อน commit (test-first mandate)
- ห้าม commit broken state — agent fail = leave worktree dirty + fix-log status: in-progress
- ห้ามแต่ง commit hash / merge hash / test result (no-fake-evidence)
- ห้าม merge ต่อใน submodule ที่เกิด conflict — STOP เฉพาะ submodule นั้น รายงาน user
