---
description: Auto smoke test changed surface — detect diff → spin servers → run the smoke tests (inline or via test-runner)
---

# /ow-test — Smoke test changed surface

Detect diff → spin up only the servers needed → run the smoke tests (inline, or delegated to the `test-runner` agent — your call) → report

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble. Step 1 (resolver eval + assert + export) is byte-identical in every command and conformance-lint check 8 fails on any drift. Step 2 is per-command only in its `--rules <area>` argument (/ow-fix-issue extends it for multi-area + rules-validate). Do NOT edit anything else per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/<prefix>-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
OW_ROOT="$(git rev-parse --show-toplevel)"; OW_ENV="$OW_ROOT/.ow/local/paths.env"
mkdir -p "$OW_ROOT/.ow/local"
bash "$OW_ROOT/scripts/ow-paths.sh" --shell > "$OW_ENV.tmp" && mv "$OW_ENV.tmp" "$OW_ENV" || {
  echo "FATAL: obsidian-workflow resolver missing/failed — run /<prefix>-init"; exit 1; }
. "$OW_ENV"
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules testing)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $FN_DIR $PHASE_DIR $FLOW_DIR
$REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $TEMPLATE_CHAIN
$GUARDRAILS_JSON $COMMAND_PREFIX`. A later phase runs in a
FRESH SHELL — Phase 0's exports are gone — so it re-hydrates first, then asserts:
`. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"` followed by
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-test                    # auto-detect from git diff
/ow-test web                # force web
/ow-test app                # force mobile — default scope = unit + integration only (no emu/sim)
/ow-test app --e2e          # mobile + E2E (Maestro) — boots emulator/simulator
/ow-test api                # force backend (unit + integration)
/ow-test <plan-file>        # use the plan's scope
/ow-test <test-plan-file>   # systematic role-by-role test plan
/ow-test --since <ref>      # diff since ref (default HEAD)
/ow-test <plan> --no-merge  # worktree mode: test in the worktree but NEVER auto-merge (keep the worktree)
/ow-test <plan> --no-worktree  # force testing on the main tree (override a plan that has a worktree)
```

🔴 **Mobile default = no emulator/simulator (#32).** `app` (auto or forced) runs **unit + integration** only
(host-side — `flutter test`, `dart test`, `./gradlew test`, `xcodebuild test -only-testing:...Logic`, `jest`, etc. —
no device required). **E2E (Maestro / instrumented / on-device integration) requires `--e2e`** — that flag boots the
emulator/simulator in Phase 2 and adds the Maestro flow to the Phase 3 tasks. No `--e2e` → e2e scope = `NOT_RUN`
(reason: "no --e2e flag" — not a fake fail).

## Phase 0 — Detect mode

| `$ARGUMENTS` | Mode |
|---|---|
| empty | **Auto** — Phase 1 → 3 |
| `web` / `app` / `api` | **Forced** — Phase 2 → 3 |
| path under `90-TestPlan/` | **Test Plan** — Phase T |
| path under `80-ImplementPlan/` | **Plan scope** — Phase 2 → 3 (infer target from the plan) |

## Phase 0.5 — Resolve worktree + WORK_ROOT (always runs — #31)

🔴 **Always runs, in every mode** — sets the `WORK_ROOT` that Phase 1/2/3/7 use. normal mode → `WT_MODE=off`, `WORK_ROOT=$MAIN_ROOT`
(test on the main tree, no Phase 7). worktree mode → resolve the worktree fields, then tests run **inside it** + auto-merge on PASS.

If the task was built in a worktree (`/ow-implement` in worktree mode) → tests must run in that worktree (server/build from the new code):

```bash
MAIN_ROOT="${ROOT:-$(git rev-parse --show-toplevel)}"
ARGS=" $ARGUMENTS "
PLAN_PATH=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--(no-merge|no-worktree|worktree|e2e)//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
NO_MERGE=0; case "$ARGS" in *" --no-merge "*) NO_MERGE=1 ;; esac
E2E=0; case "$ARGS" in *" --e2e "*) E2E=1 ;; esac   # mobile only (#32) — no-op for web/api

WT_MODE=off; PLAN_FILE=""; WT=""; BR=""; BASE=""; REPO="$MAIN_ROOT"
# (1) explicit plan arg with worktree_status: built  (2) bare run → the most recent plan that is built
if [ -f "$PLAN_PATH" ] && grep -q '^worktree_status:[[:space:]]*built' "$PLAN_PATH" 2>/dev/null; then
  PLAN_FILE="$PLAN_PATH"; WT_MODE=on
elif [ -z "$PLAN_PATH" ]; then
  PLAN_FILE=$(grep -lE '^worktree_status:[[:space:]]*built' "$PLAN_DIR"/*.md 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1)
  [ -n "$PLAN_FILE" ] && WT_MODE=on
fi
case "$ARGS" in *" --no-worktree "*) WT_MODE=off ;; esac     # override: force testing on the main tree

if [ "$WT_MODE" = on ]; then
  WT=$(grep -m1   '^worktree_dir:'    "$PLAN_FILE" | sed -E 's/^worktree_dir:[[:space:]]*//')
  BR=$(grep -m1   '^worktree_branch:' "$PLAN_FILE" | sed -E 's/^worktree_branch:[[:space:]]*//')
  BASE=$(grep -m1 '^worktree_base:'   "$PLAN_FILE" | sed -E 's/^worktree_base:[[:space:]]*//')
  REPO=$(grep -m1 '^worktree_repo:'   "$PLAN_FILE" | sed -E 's/^worktree_repo:[[:space:]]*//'); REPO="${REPO:-$MAIN_ROOT}"
  [ -d "$WT" ] || { echo "ℹ️ worktree gone: $WT (already merged/cleaned up?) → falling back to testing on the main tree"; WT_MODE=off; }
fi
WORK_ROOT="$MAIN_ROOT"; [ "$WT_MODE" = on ] && WORK_ROOT="$WT"
```

🔑 **WORK_ROOT contract** (same as /ow-implement): **server/build/test/`git diff`** → `$WORK_ROOT`; the vault report → absolute MAIN_ROOT.
`WT_MODE=off` → WORK_ROOT = MAIN_ROOT (test on the main tree, no Phase 7).

## Phase 1 — Detect scope (Auto only)

```bash
if [ "$WT_MODE" = on ]; then
  # worktree mode: the changes are already committed on the feature branch (implement Phase 6.4) → diff vs base
  changed=$(git -C "$WORK_ROOT" diff --name-only "$BASE"...HEAD)
else
  changed=$(git diff --name-only HEAD; git diff --name-only --cached; git ls-files --others --exclude-standard)
fi
```

Check where the changes are:
- API/backend folders → `api`, `server`, `backend`, `*.controller.*`
- Web → `web`, `client`, `frontend`, `*.tsx`, `*.vue`, `*.svelte`
- Mobile → `app`, `mobile`, `*.dart`, `*.swift`, `*.kt`

| Changed | Action |
|---|---|
| API only | unit + integration tests (no UI) |
| Web (±API) | smoke the web surface — target=web |
| Mobile (±API) | smoke the mobile surface — target=app, test types=unit+integration (+e2e if `--e2e`, #32) |
| Web + Mobile | both, one after the other |
| Nothing | Exit — "no diff" |

## Phase 2 — Spin up servers (only what is needed + shut down whatever you started)

🔴 **Leak guard:** reuse a healthy one (never start a duplicate = stacked processes eating the machine every round) + shut down
everything you started. Kill only the PIDs/udids you tracked — **never a broad `pkill`** (`pkill node` etc. kills the user's work).

- resolve **`READY_URL`** per target (base/health URL — **a different port per app**: next 3000, vite 5173,
  expo 8081, api 8080, flutter web = random). **Do not assume `:3000`.**
- Web/API → `curl -sf "$READY_URL"` passes = reuse; fails → spin it up. **Delegating (3.0) → hand spin+teardown to test-runner**
  (pass the serve cmd + `READY_URL` + `WORK_ROOT` into the Phase 3 prompt — the runner captures the PID + `trap EXIT` and shuts it down itself).
- Mobile → **no emulator/simulator when `E2E=0`** (default) — unit/integration run purely on the host. Only `E2E=1`
  (`--e2e`) → whoever runs Phase 3 records which devices the user already had running, boots only the missing ones + shuts down only the ones it booted.
- spinning one up yourself (inline path) → **capture the PID** (`<serve> & PID=$!`, not a `( ... & )`
  subshell orphan) + `trap 'kill $PID 2>/dev/null; pkill -P $PID 2>/dev/null' EXIT` to shut it down after Phase 3 returns.

🔴 **worktree mode → spin server/build from `$WORK_ROOT`** (`cd "$WORK_ROOT" && <serve cmd> & PID=$!`) —
test **the worktree's new code**, not the main tree. A main-tree server still running → **kill the old one first** (remember its PID)
then start from the worktree — do not leave them stacked.

If servers need credentials/secrets that are unavailable → blocker → STOP + tell the user.
A missing/incomplete **test user** specifically (login for a role, not a server secret) →
🔴 **read `.ow/commands/_shared/test-credentials.md` and follow it** — `$TEST_ENV_FILE` is the
source, and a blank role there means ask the user, never invent one to unblock the run.

## Phase 3 — Run the smoke tests (inline or via test-runner)

### 3.0 Decide how to run it (your judgment — 🔴 no mandate either way)

Run the tasks below yourself, or delegate them to the `test-runner` agent — **whichever fits this run**.
Same trade-off as `/ow-implement` 3.0, nothing here forces either one:

🔴 `test-runner` is **created per project**, not shipped — `.claude/agents/test-runner.md` absent ⇒ run
inline. That is the normal case on a project that has not run `/ow-agent create test-runner`, not a
failure: the tasks and gates below are identical either way.

- a spawn shares no context with you — the agent starts from zero and pays a cold-cache write; on a short
  smoke run (a few unit/integration commands you can invoke directly) that is cost with little gained
- what it buys back — a separate context budget for noisy output (long logs, console + network capture,
  screenshot loops), its own tool surface, and the testing rules already written for the job
- either way the tasks and the gates are identical, and the results must come from commands that actually ran

🔴 Delegated → the PROJECT CONTEXT block below is **mandatory** (the agent has no bash tool — without it, it
STOPs per §0). Inline → skip the block, you already hold that context; tasks 1-8 are yours to carry.

**Delegated — prepend the authoritative PROJECT CONTEXT block** to the prompt (assemble from the Phase-0
resolved vars exactly as `/ow-implement` Phase 3 — `VAULT_ABS`, `TEST_DIR`,
`GUARDRAILS_JSON`, `LANG` / `VAULT_LANG`, `--rules testing`, and a `SUBMODULES` line only if
multi-repo). The block is inherited unchanged — this command defines no language of its own;
test-runner reports results back in `LANG` and never writes vault docs itself.

Prompt — delegated mode. 🔴 **Inline: tasks 1-7 are your own list** (same gates; the
`Working dir` / `READY_URL` values are already resolved in your own context):
```
<PROJECT CONTEXT block from above>

Target: <web | app | api>
Scope: <files changed | plan file>
Test types (mobile only, #32): <unit,integration | unit,integration,e2e — per $E2E>
  🔴 $E2E=0 (default) → run unit+integration only, NEVER boot an emulator/simulator; e2e scope = NOT_RUN
  (reason "no --e2e flag"). $E2E=1 → run unit+integration+e2e (emulator/simulator already booted in Phase 2)
Working dir: <WORK_ROOT — worktree mode = worktrees/plan-<slug>/ ; otherwise = repo root>
  🔴 run test/serve from this dir (worktree mode = test the worktree's new code, not the main tree)
READY_URL: <base/health URL per target — **never hardcode :3000** (a different port per app); reuse if already healthy>
Serve cmd (if a spin is needed): <serve cmd from the project — the runner captures the PID + trap EXIT and shuts it down at the end (Phase 7.5)>
Vault context: $TEST_DIR (read what is relevant)

Tasks:
1. Run smoke tests for the changed surface
2. Capture console + network output into the scratch run dir (never stream long logs into context)
3. Quote the failing lines verbatim in the report — never paraphrase a failure into a pass
4. Detect PII/secrets in anything you quote → mask before it reaches the report
5. Mark route source trace for each check:
   VISIBLE_MENU / DIRECT_URL_USER / DIRECT_URL_TECHNICAL
6. Report: PASS / FAIL / BLOCKED per scenario + the real pass/fail counts
7. 🔴 Teardown (Phase 7.5): shut down only the server/emulator/sim you started yourself (tracked PID/udid) — never a broad `pkill`
```

## Phase T — Test Plan mode

Read the test plan at `90-TestPlan/TP-*.md` — run a systematic test covering:
- each role in the plan
- each scenario
- record per-scenario result + the observed behaviour
- Status taxonomy: PASS / FAIL / INFO / LIMITED / PASS_NO_MUTATION / BLOCKED_* / NOT_RUN

## Phase 4 — Record what the run observed

Test output is **transient**: capture it into the scratch run dir
(`${TMPDIR:-/tmp}/ow-run-<slug>/`), read what you need from it, and report the results.
Nothing from that dir is committed, copied into the vault, or depended on later.

```
${TMPDIR:-/tmp}/ow-run-<slug>/
├── test-output.txt      # test/smoke stdout+stderr + EXIT
├── console.log
└── network.log
```

For each scenario record, in the report: scenario/step · page/URL · expected/actual ·
console summary · network summary.

🔴 **The report must come from a run that actually happened** — quote failing output verbatim
(trimmed) and never write a pass/fail number no run produced. Cannot run it (no server, missing
credential, no device) → status `BLOCKED_*` / `NOT_RUN` + the reason, never a guessed PASS.

🔴 Mask any PII/secret in anything you quote into the report or the vault.

## Phase 5 — Visible-menu rule

> Gate (#13): the visible-menu default follows `guardrails.visible_menu_default != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.visible_menu_default // true'` (default true). When
> `false`, direct-URL navigation is allowed without the visible-menu-first requirement.

UI tests must start from **visible menu navigation** by default

If the menu is skipped → state:
- `DIRECT_URL_USER` (a user-facing URL) — must explain why
- `DIRECT_URL_TECHNICAL` (for tech checks only) — label it clearly

Never claim a user journey through a hidden route

## Phase 6 — Output report

Show (render in `$PROJECT_LANG`):
```
Test summary
============
Target: web
Scenarios: 5 (PASS: 4, FAIL: 1, BLOCKED: 0)

[FAIL] TC-003 — Search returns empty when DB has results
  Page: /search
  Console: TypeError: cannot read 'items' of undefined
  Expected: 12 results · Actual: empty list

Next: run /ow-fix "search returns empty..." → diagnose
```

Test Plan mode (Phase T) → write the full execution report into the vault under `90-TestPlan/`, following
`.ow/templates/test-scenario-report.md` (text only). Auto mode = the terminal summary above is enough.

Prose written into the vault is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

## Phase 7 — Auto-merge on PASS (worktree mode only — #31)

Runs only when **`WT_MODE=on` AND every scenario PASS AND no `--no-merge`** → merge the feature branch back into the base branch
**local only (no push)** + cleanup the worktree.

🔴 **Skip Phase 7 (no merge, keep the worktree) when:**
- any scenario FAIL/BLOCKED → the user enters the worktree (`$WT`), fixes on, then re-runs `/ow-test`
- `--no-merge` → the user reviews first and merges themselves
- `WT_MODE=off` → no worktree (ends at the normal Output)

It runs → 🔴 **Read `.ow/commands/_shared/worktree-merge.md` and follow it** — that file owns the whole
merge step (pre-merge guards 7.1 · non-destructive `--no-ff` merge 7.2 · submodule-safe cleanup gate 7.3 ·
handoff text 7.4) and every safety ban that goes with it. Nothing about the merge is restated here.

<!-- the merge/cleanup bash lives in _shared/worktree-merge.md — read it there, never inline it back here -->

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-test answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — the surface tested + result (status taxonomy: PASS/FAIL/BLOCKED count)
- **Results** — pass/fail counts as the run reported them
- **Risks / open** — only if any: flaky tests · blocked scenarios · suggested fix-log
- **Next** — worktree mode: merge result → `/ow-git --bump` (PASS) or "worktree kept at … fix on there" (FAIL/conflict)

🔴 **Never fabricate** console/network output · never claim PASS without actually running = mark `NOT_RUN_RISK` · PII must be masked first.

## Never

- Never fabricate console logs, network logs or pass/fail counts
- 🔴 Never treat the `test-runner` agent as mandatory — how Phase 3 runs is a judgment call (3.0); the tasks and gates are identical either way (and delegating never means skipping the PROJECT CONTEXT block)
- Never run tests against a production env
- Never claim PASS if the test did not actually run — mark `NOT_RUN_RISK` instead
- Never write unmasked PII into the vault or the report
- 🔴 `/ow-test` **never push**es, in any mode — pushing is `/ow-git`'s job
- 🔴 **Never auto-merge if any scenario is FAIL/BLOCKED** or `--no-merge` is set — keep the worktree to fix on (this gate decides whether Phase 7 runs at all)
- 🔴 Merging a worktree back → the bans that protect the user's parallel uncommitted work and the unpushed submodule commits (no force-merge, no delete before the gate passes) live in `_shared/worktree-merge.md` — Phase 7 reads it **before** touching git, never from memory
