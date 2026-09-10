---
description: Execute an approved plan file — implement inline or delegate, run build/test, sync vault
---

<!--
Obsidian behaviour this command must honour:
- Read `$IMPL_STATUS` (00-Index/IMPLEMENTATION-STATUS.md) FIRST
- The run's record goes into the plan file under `$PLAN_DIR` (Phase 6.2: Implementation Result),
  and `$IMPL_STATUS` is reconciled in the same phase — its prose is in `$VAULT_LANG` (Phase 0);
  headings, frontmatter, and IDs stay English
-->


# /ow-implement — execute the plan

Execute an approved plan file: do the work — **inline yourself or delegated to a subagent, your call** — and prove it with a real build/test run

Mode-gated detail lives in `_shared/` fragments. 🔴 **Read a fragment the moment its phase says so** — it is
authoritative for what it covers and this file never restates it:

| Fragment | Read when |
|---|---|
| `.ow/commands/_shared/worktree.md` | `WT_MODE=on` — Phases 2.7 · 6.4 · 7 |
| `.ow/commands/_shared/delegation.md` | the 3.0 judgment lands on a subagent — Phase 3.2 |
| `.ow/commands/_shared/build-test.md` | always — Phase 5.0 |
| `.ow/commands/_shared/fixlog-close.md` | the run is fix-escalated (`source_fix:` / `--from-fix`) — Phase 6.5 |
| `.ow/commands/_shared/vault-doc-style.md` | a vault doc outside `$PLAN_DIR`/`$FIX_DIR`/`$TEST_DIR`/`$HANDOFF_DIR` is written — Phases 2 · 6.2 |

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding)
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
/ow-implement <vault>/80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md
/ow-implement <slug>      # auto-locate by slug
/ow-implement <plan> --worktree      # force the build into a separate git worktree (even when the plan frontmatter has no worktree:) (#31)
/ow-implement <plan> --no-worktree   # force the build into the main tree (overrides a plan carrying worktree: true)
/ow-implement --from-fix <vault>/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md   # P2 minor + P3 polish — skips the plan; closes this fix-log itself when done (6.5)
```

Empty → ask (render in `$PROJECT_LANG`) which plan, and list the 5 most recent plans with `status: approved`

> `--from-fix` accepts only a fix-log with `severity: P2` or `P3` — `/ow-fix` Phase 4 is the caller, after the auto-fix gate passes. **P0/P1 → always `/ow-plan fix:<slug>`** (`--from-fix` must refuse)
>
> In this mode the **fix-log is the unit of work** (there is no separate plan): Phase 1 skips the `status: approved` gate (invoking it = approval); the build-test/coverage/discipline gates (5.0/5.2/5.3) + the open-checkbox gate (6.0) run against the fix-log; Phase 6 closes the fix-log as `status: fixed` via Phase 6.5

## Phase 1 — Validate

1. Read the plan file
2. **Refuse** if `status != approved` → tell the user to set the status first
3. **Refuse** if it is already `status: done` → tell the user
4. Check that `Implementation Steps` is complete + `subagent_target` is set (it names the **area** whose rules/gates apply — not an order to spawn, see 3.0)
5. Show task + submodule + step count → ask (render in `$PROJECT_LANG`): "Start now?"
6. If `Doc Gaps Found` is non-empty → go to Phase 2 first

### 1.1 `--from-fix` gate (fix-log mode)

Target = fix-log → skip item 2 (invoking = approval) and enforce severity instead:

```bash
SEV=$(grep -m1 '^severity:' "$PLAN_PATH" | sed -E 's/^severity:[[:space:]]*//; s/[[:space:]]*—.*$//' | tr -d '"')
case "$SEV" in
  P2|P3) ;;
  *) echo "🛑 STOP: --from-fix accepts only P2/P3 (this fix-log = ${SEV:-unset}) → /ow-plan fix:<slug>"; exit 1 ;;
esac
```

🔴 Empty/unreadable severity = **refuse** (fail-closed) — never assume it is P3

### 1.2 Resume gate — progress markers (when present)

Either section means an earlier run of this same target died before finishing:

| section | written by | unit |
|---|---|---|
| `## Chunk Progress` | a delegated run — `_shared/delegation.md` §6 | `chunk <n>/<N> · steps <a>-<b>` |
| `## Step Progress` | an inline run — 3.3 | `steps <a>-<b>` (plan) · a file path (`--from-fix`) |

1. Read every `- [x] …` line under **both** sections → the first unit not yet covered = the starting point
   (both present — a run that started delegated and resumed inline, or the reverse → take the **union**;
   the resume point is the first unit no marker covers)
2. 🔴 Run the `exit:` of the **last ticked** line before skipping past it — it fails (code reverted/lost) →
   **STOP**, ask a human · never trust the marker and skip work that actually vanished
3. It passes → report `resume from <unit>`, then continue by mode:
   - delegating → partition **only the remaining steps** (`_shared/delegation.md` §2)
   - inline → start at that unit and keep writing `## Step Progress` from there (3.3)

No such section → start normally

## Phase 2 — Fix doc gaps (when present)

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** before touching a doc — a
doc outside `$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now:
the gap is closed by **overwriting** the wrong text, never by appending "was X, now Y" under it.

Fix them **inline by default** — you already hold the plan; a spawn re-reads it from zero.
Delegate to the `docs` subagent only when the gap list is genuinely large or independent of the code work
(same judgment rule as 3.0). Rule either way: **fix factual discrepancies only — never change implementation intent.**

Done (or the agent returned) → Phase 2.7

## Phase 2.7 — Resolve mode + worktree (#31)

🔴 **2.7.1 always runs, in every mode** — it is the mode gate and it sets `WORK_ROOT`/`PLAN_PATH`/`MAIN_ROOT`
used by Phases 3-6.

### 2.7.1 Resolve mode (flag override > plan frontmatter > off)
```bash
[ -n "$VAULT_ABS" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# $ROOT from Phase 0 (--shell) = absolute project root. Fallback = git toplevel (the orchestrator is always
# in the main tree at this point — the worktree is not created yet), in case a separate bash block call
# did not persist $ROOT.
MAIN_ROOT="${ROOT:-$(git rev-parse --show-toplevel)}"
PLAN_PATH=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--(no-)?worktree//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
WT_MODE=off
grep -q '^worktree:[[:space:]]*true' "$PLAN_PATH" 2>/dev/null && WT_MODE=on   # plan frontmatter (from /ow-plan --worktree)
case " $ARGUMENTS " in *" --worktree "*)    WT_MODE=on ;;  esac               # explicit flag beats frontmatter
case " $ARGUMENTS " in *" --no-worktree "*) WT_MODE=off ;; esac               # --no-worktree wins over all
WORK_ROOT="$MAIN_ROOT"                                # default = build in the main tree (no worktree opened)
```
🔴 Every phase from here uses **`$PLAN_PATH`** (flag-stripped) as the plan file — never the raw `$ARGUMENTS`

### 2.7.2 Branch on the mode
- `WT_MODE=off` → **nothing else to do**: `WORK_ROOT=$MAIN_ROOT`, go to Phase 3
- `WT_MODE=on` → 🔴 **Read `.ow/commands/_shared/worktree.md` and follow it** (§1 create + §2 record;
  §3 feeds a delegated agent, §4 is the Phase 6.4 commit, §5 is the Phase 7 handoff)

## Phase 3 — Execute the plan (inline or delegated — your call)

### 3.0 Decide how to run it (your judgment — 🔴 no mandate either way)

`subagent_target` names the **area** the work belongs to ⇒ which rules and gates apply. It is **not** an
order to spawn:

| `subagent_target` | area rules — apply them inline, or spawn this agent |
|---|---|
| `backend` | `.claude/agents/backend.md` |
| `frontend` | `.claude/agents/frontend.md` |
| `mobile` | `.claude/agents/mobile.md` |
| `docs` | `.claude/agents/docs.md` |
| `design` | `.claude/agents/design.md` |
| `all` | the areas the plan actually touches, in order backend → frontend → mobile → docs |

🔴 **Only `docs` is guaranteed to exist.** Every other row is an agent this project creates with
`/ow-agent create <name>`; obsidian-workflow ships no body for it. The file is absent ⇒ **run inline** — that is the
normal case, not a failure, and the area rules below still apply in full. Mention once in the Phase 7 output
that `/ow-agent suggest` would say whether this area is worth an agent; never stop, and never spawn a name
with no file behind it.

Implement it inline yourself, or delegate it to that agent — **whichever actually fits this plan**. Nothing
here forces either one: judge it as you would any other task, with the real trade-off in view.

- a spawn **shares no context with you** — the agent starts from zero, re-reads the plan and the docs you are
  already holding, and pays a cold-cache write every time (a chunked delegation pays it once per chunk)
- what it buys back — a separate context budget, its own tool surface, and an area agent file already written
  for the job **when this project has created one**. That pays off on a large plan, on heavy self-contained
  area gates, or on a long isolated build/test loop; on a small or medium plan it usually does not
- one plan on one tree is **sequential work** ⇒ one worker at a time (inline, or one agent), never a fan-out

**Running it inline** — these come with it (the agent file would otherwise have carried them):
1. Read `.claude/agents/<area>.md` gates **if that file exists** + every file the resolver's `--rules <area>`
   names, before code
   (🔴 a rule registered in `.ow.yml` `rules.files` that fails to resolve is a STOP-RISK, not a silent skip:
   `bash scripts/ow-paths.sh --rules-validate`)
2. Read the plan's FN/FEAT docs, the existing code/tests it names, and the conditional refs the include-when
   table in `.ow/commands/_shared/context-refs.md` judges relevant (**uncertain ⇒ read it** — a wrong skip costs more)
   🔴 The plan carries `context_closed: true` (a `/ow-split` sub-plan) → its `context_refs:` list **is** the
   read set: skip the include-when resolution entirely, `/ow-split` already did it and measured the result
   against the session's context budget. Reading something outside the list stays allowed — report
   `context gap: <doc> — needed for <reason>` (the same escape hatch as `CONTEXT_SKIPPED`). No such field →
   unchanged: uncertain ⇒ read it
3. Follow the implementation rules (3.1) yourself — they are not agent-specific
4. Every gate in Phases 4/5/6 runs identically
5. 🔴 **Never chunk an inline run** — you can compact and see your own context; chunking exists only for agents
6. 🔴 **Write the `## Step Progress` marker as you go (3.3)** — the only state that outlives a dead session

### 3.1 Implementation rules (apply inline · paste verbatim into a delegated prompt)

```
1. Read the full plan before touching code — especially Success Criteria and Implementation Steps
   (CHUNK block present → read `READ_FULL` + `READ_NAMED`; a doc summarized in `DIGEST` need not be re-read unless in doubt)
2. Follow Implementation Steps in order — minimum correct change only
   (CHUNK block present → do only the `STEPS:` range named, **never spill** into the next step)
3. Every changed line must trace back to a plan step, a success criterion, or a verification
4. Never add an abstraction/config/dependency/feature outside the plan's scope
5. Never refactor / reformat files outside the task's scope — and when "clearing churn", stay safe:
   - formatter/linter: run only on the files the task itself changed (`<fmt> <changed-files>`) — never whole-tree
     `--fix`/`--write` (whole-tree is fine only for a read-only `--check`)
   - 🔴 **Never `git checkout`/`git restore`/`git stash`/`git clean`** on files the task did not create/change itself —
     the working tree may hold uncommitted work from a parallel `/ow-fix`/`/ow-implement`; these commands delete
     **the whole file** = data loss (#29). Forbidden inside a worktree too (it deletes the agent's own work)
   - revert an out-of-scope hunk = a **surgical Edit**, on files the task owns only, on the excess hunk only
   - 🔴 a file **already dirty before you started that the task did not touch** → leave it alone: never revert, edit,
     or stage it. The same file the task truly must change → Edit **only the task's own hunk**, keep every other hunk
6. Follow the repo's existing patterns before inventing a new one
7. Enforce the agent's gates (test creation, design system compliance, security)
8. When done: map the verification back to Success Criteria one by one
9. Update the vault per the plan's Vault Update Checklist — always write to `VAULT_ABS` (absolute, in MAIN_ROOT);
   worktree mode → **never write docs/ inside the worktree** (it would ride into the commit + collide on merge)
10. Report: files changed (production vs test), vault docs updated
10.1 If you must read a doc listed in `CONTEXT_SKIPPED` → you may, but report `context gap: <doc> — needed for <reason>`
     (never read it silently)
11. Never fake a result — if a test does not pass, state the blocker
```

### 3.2 Delegated mode

🔴 Delegating → **read `.ow/commands/_shared/delegation.md` and follow it** — CONTEXT_REFS resolution,
chunk partition, the PROJECT CONTEXT / CHUNK blocks, the spawn prompt, and the chunk loop all live there.
Running inline → skip it entirely.

### 3.3 `## Step Progress` — resume marker (inline runs only)

A delegated run records progress per chunk; an inline run never chunks, so this is its only state that
outlives the session. Without it a fresh session re-derives "how far did it get" from `git diff` and guesses —
far more expensive, and a wrong guess redoes or double-applies work.

**Append one line the moment a group of steps passes its own cheap assert** — never when the code is merely
written:

```markdown
## Step Progress (written by /ow-implement — resume marker)
- [x] steps 1-3 · 2026-08-07 14:20 · exit: `pnpm test src/api/cart` passes
- [x] steps 4-6 · 2026-08-07 14:48 · exit: `tsc --noEmit` clean
```

| target | unit to anchor on | where `exit:` comes from |
|---|---|---|
| plan (`$PLAN_DIR/…`) | `steps <a>-<b>` — the plan's numbered Implementation Steps | that step's own `proof:` — the plan already carries one per step |
| fix-log (`--from-fix`) | one `## Affected Files` path — a fix-log has **no** numbered steps | the `## Test Cases` TC that covers that file, else the cheapest assert proving its change works |

🔴 Rules (the same contract `## Chunk Progress` runs under — `_shared/delegation.md` §6) — it goes in
`$PLAN_PATH`, under the vault-write rule 3.1 rule 9 already states (worktree mode included):
- Write `- [x]` **only**, never `- [ ]` → the Phase 6.0 gate (`grep -c "- [ ]"` must = 0) keeps its meaning
- Write it **after the `exit:` actually ran and passed** — one written on faith is a lie 1.2 will believe,
  and it will skip work that never happened (no fake results)
- Group so a line lands **every 2-4 steps**, not every step — a 15-step plan wants ~4-5 lines
- 🔴 Never tick Goals / Success Criteria / Test Plan / Design System Compliance early to stand in for this —
  those are gated by Phases 5/6
- Leave the section in place when the run finishes — it is the run's history, and Phase 6.0 ignores `- [x]`

## Phase 4 — Design system gate (when present)

If `<vault>/70-Reference/DesignSystem/` exists and `subagent_target` is `frontend` or `mobile`
(applies the same inline or delegated — the gate is on the work, not on who does it):

Before any UI code is written — by you or by the agent:
1. Read `DS-Tokens.md`, `DS-Components.md`, `DS-Patterns.md`
2. Use the existing tokens/components
3. If a new component is needed → STOP, tell the user to run `/ow-design` to add that component first

## Phase 5 — Verify + integrity audit (🔴 before marking done)

### 5.0 Run the build/test (🔴 never skip)

🔴 **Read `.ow/commands/_shared/build-test.md` and run it** — it runs build+test at `$WORK_ROOT`
into a captured file and produces the results table (pass/fail parsed from real stdout; cannot parse →
`?/?` + `parse-failed: true`).

**No run = the work is not done** — never flip `status: done`. Its `## Test Coverage Added` table is the
direct input to `Implementation Result` (6) and to the audit below.

### 5.2 Coverage audit — STOP gate (🔴 before marking done)

```bash
# production files vs test files in the diff (adjust the extension/path pattern to the repo's stack)
# 🔴 diff at $WORK_ROOT — worktree mode = the changes live in the worktree (committed on the feature branch, or working);
#    `git -C "$WORK_ROOT" diff --name-only HEAD` sees uncommitted; if the agent already committed, use `HEAD~1` / `$BASE...HEAD`
PROD=$(git -C "$WORK_ROOT" diff --name-only HEAD | grep -vE '(test|spec|__tests__|/tests/|\.spec\.|\.test\.|/e2e/|\.md$)' | grep -E '\.[a-zA-Z]+$' | wc -l | tr -d ' ')
TEST=$(git -C "$WORK_ROOT" diff --name-only HEAD | grep -E '(test|spec|__tests__|/tests/|\.spec\.|\.test\.|/e2e/)' | wc -l | tr -d ' ')
```

- `PROD>0 && TEST==0` → **🛑 STOP** — either justify with a **specific untestable reason** (the list is in
  the fragment below — not "no logic"), or write the test first (inline; delegate only under the 3.0 rule)
- `PROD>0 && TEST>0` → pass; log the ratio · `PROD==0` → pass; note "docs-only / config-only"

🔴 **Read `.ow/commands/_shared/coding-discipline.md` §3** for the untestable list (1–6) — it is the
only acceptable set of reasons, and "hard / time-consuming" is not on it

### 5.3 Coding-discipline audit (🔴 before marking done)

🔴 **Read `.ow/commands/_shared/coding-discipline.md` and run its §4 audit** against `git diff HEAD`
— success-criteria check map, changed-line traceability, no speculative addition, no unrelated churn,
and the §3 test contract. That file is authoritative; this phase adds no rule of its own.

Any item fails → **fix it before marking done** — scope discipline is this task's job, never punted to a
follow-up — reverting with the safe method in rule 5 of 3.2 (surgical Edit on files this task owns)

## Phase 6 — Update the plan

### 6.0 Open-checkbox gate (🔴 before flipping status: done)
```bash
grep -c "\- \[ \]" "$PLAN_PATH"   # must = 0  (plan file in the MAIN_ROOT vault — flag-stripped, Phase 2.7.1)
```
If >0 → finish the outstanding items first (inline, or the `docs` agent under the 3.0 rule) — never flip the status

🔴 **`status: done` must pass all of:** 5.0 build/test run + 5.2 coverage audit + 5.3 discipline audit + 6.0 open-checkbox = 0

1. Plan frontmatter: `status: done`, `completed_at: YYYY-MM-DD HH:mm`
2. Append a section to the plan (its prose is in `$VAULT_LANG`; headings, frontmatter, IDs, and file paths stay English):
   ```markdown
   ## Implementation Result
   - Files changed (prod / test): <list>
   - Tests added: <list from the Test Coverage Added table>
   - Success criteria → check map: <from 5.3>
   - Build/test result: <the 5.0 results table — pass/fail as the run reported it>
   - Executed by: inline | subagent `<name>`   · Time: <duration>
   ```
3. Update `$IMPL_STATUS` to mark the feature/phase done

🔴 Step 3 writes into `00-Index`, so it follows `_shared/vault-doc-style.md` (read at Phase 2): the
plan carries the before/after, `$IMPL_STATUS` carries only the row that is true now — never both.

### 6.4 Commit in the worktree (worktree mode only — #31)

`WT_MODE=on` → all gates passed (5.0/5.2/5.3/6.0) ⇒ commit the code in the worktree per
`_shared/worktree.md` §4 (**no push, no merge** — `/ow-test` merges it when smoke passes)

### 6.5 Close the source fix-log (🔴 fix-escalated runs only — #30)

The plan carries `source_fix:` (it came from `/ow-plan fix:<slug>`), **or** the run was `/ow-implement --from-fix <fix-log>`
→ 🔴 **read `.ow/commands/_shared/fixlog-close.md` and follow it** — the fix-log must never be left at
`in-progress` once the work that owns it is done. Neither case → skip silently.

## Phase 7 — Output (short bullets, in `$PROJECT_LANG`)

Answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — the main change + files/area + how it ran (inline, or subagent `<name>`)
- **Verification** — the test/build actually run + its result (pass/fail count from stdout; cannot parse = `?/?` + `parse-failed: true`)
- **Risks / open / next** — only if any (e.g. "manual UAT not done yet"), plus any `context gap:` collected

🔴 **Never fabricate** a count / path / sha — no real value = `pending verification`

`WT_MODE=on` → append the worktree handoff from `_shared/worktree.md` §5

## Never

- Never implement if the plan is not `approved` · never change scope without revising the plan first (`/ow-plan --revise`)
- 🔴 Never read `subagent_target` as an order to spawn — it names the **area's rules**; how the work runs is a judgment call (3.0), and no phase may make either mode mandatory
- 🔴 Never drop an area gate because the work ran inline — inline means **you** read `.claude/agents/<area>.md` + its rules and enforce them (3.0)
- 🔴 Never chunk an inline run · never fan out parallel agents for one plan on one tree
- 🔴 Never run an inline plan without writing `## Step Progress` as you go (3.3) — a dead session then leaves zero recoverable state
- 🔴 Never resume from a progress marker without first re-running the `exit:` of the last ticked line (1.2) — a marker whose code was reverted is worse than no marker
- 🔴 Never `git checkout`/`git restore`/`git stash`/`git clean` on files the task did not create/change itself — it deletes a parallel task's uncommitted work (data loss, #29); revert churn = a surgical Edit on files the task owns only
- Never fake a test/build result — the pass/fail count must parse from real stdout; cannot parse → `?/?` + `parse-failed: true`, never guess
- 🔴 Never flip `status: done` unless all four pass: 5.0 build/test run · 5.2 coverage (`PROD>0 && TEST==0` = STOP, write a test or map to untestable 1–6 — "hard" is not one) · 5.3 discipline · 6.0 open-checkbox = 0
- 🔴 Never flip a plan `done` while it has `source_fix:` but the source fix-log is not closed (6.5) — a `source_fix:` pointing at a missing file = **STOP**, never silent
- Never deliver work without a verification map back to the success criteria · never touch a shared/production env without confirming
- 🔴 Worktree mode → the orchestrator **must not merge** (that is `/ow-test`'s job) · **must not push** · the agent must not commit/merge itself · a create failure = **STOP**, never a silent fallback to the main tree
- 🔴 Never trust a delegated `STATUS: DONE` without running `EXIT_STATE` yourself · `BLOCKED` → stop, ask a human, never auto-retry
