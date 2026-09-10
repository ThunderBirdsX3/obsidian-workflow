# `_shared/build-test.md` — run the build/test and report what really happened

Mechanics for running the project's own build/test command, capturing its output outside the
context window, and parsing the real pass/fail counts. The **gates** that decide whether the work
may be marked done (coverage audit, discipline audit, open-checkbox) stay in the verb spec — this
file only produces the run results those gates read.

> The heart of it: a result must come from a command that **actually ran** — never from a claim
> alone, an agent's or your own.
> 🔴 **No run = the work is not done** — never flip `status: done`.

Prereq: Phase 0 loaded (`$MAIN_ROOT`, `$WORK_ROOT`, `$PLAN_PATH` resolved).

## 1. Run build + test per submodule/area touched

Capture stdout+stderr into a file outside the repo — never stream it into context:

```bash
PLAN_SLUG=$(basename "$PLAN_PATH" .md)
RUN_DIR="${TMPDIR:-/tmp}/ow-run-$PLAN_SLUG"; mkdir -p "$RUN_DIR"
START=$(date +%s)
# 🔴 build/test runs at $WORK_ROOT (worktree mode = worktree code; normal = main tree)
( cd "$WORK_ROOT" && { <build-or-test-cmd> 2>&1; echo "EXIT=$?"; } ) > "$RUN_DIR/build-output.txt"
echo "DURATION=$(($(date +%s)-START))s" >> "$RUN_DIR/build-output.txt"
```

🔴 **The build/test command comes from config / repo convention — never hardcoded**
- monorepo: use the script the repo actually has (`package.json`/`Makefile`/`pyproject.toml` …)
- multi-repo: run per submodule touched (read `.ow.yml` `submodules:`) — a submodule not touched is
  marked `not-touched`

Rules: build/test **fails → record EXIT, do not stop** (the failure is the result) · at least 1 area must actually run.

🔴 `$RUN_DIR` is scratch, not a deliverable: it is never committed, never copied into the vault, and
nothing downstream may depend on it surviving. Everything that matters goes into the results table below.

## 2. Results table + parse pass/fail (🔴 mandatory)

Parse the pass/fail counts from the real stdout (regex per the test runner used, e.g.
`Passed: \d+, Failed: \d+` / `Tests \d+ passed` / `\d+ passed`).

🔴 **cannot parse → put `?/?` + `parse-failed: true` — never guess the numbers**

Write this block straight into the plan/fix log — it is the direct input to `Implementation Result`:

```markdown
## Build/Test Result — <plan-slug>

- Plan: [[<slug>]]   · Run at: YYYY-MM-DD HH:mm   · Areas touched: <list>

| Area | Build | Duration | Test | Duration |
|---|---|---|---|---|
| <area1> | ✅ EXIT=0 | 12s | ✅ 23/23 | 4s |
| <area2> | not-touched | — | not-touched | — |

- Total: N | Passed: N | Failed: 0 | Build: all-pass
- Notes: <anomalies — new tests, migration re-seed, parse-failed flags>

## Test Coverage Added (🔴 mandatory — list every test file added/changed)
| Layer | File | Behavior covered |
|---|---|---|
| Unit | <path> | <behavior> |
| Integration | <path> | <behavior> |
| E2E | <path> | <behavior> |

Total test files added/modified: N
(if skipped — list the files + untestable reason 1–6; otherwise write "All changes covered.")
```

🔴 Quote failing output **verbatim** from `$RUN_DIR/build-output.txt` (trim to the relevant lines) —
never paraphrase a failure into a pass, and never write a number no run produced.
