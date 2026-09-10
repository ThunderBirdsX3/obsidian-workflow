---
description: Vault-first research + create implementation plan file (no code touch)
---

<!--
Obsidian behaviour this command must honour:
- Read `$IMPL_STATUS` (00-Index/IMPLEMENTATION-STATUS.md) FIRST — it is the status source of truth
- Wikilink every vault doc the plan relies on, so the link graph stays intact
-->


# /ow-plan — Plan a task (no code)

Read vault → clarify → create plan file → **always stop before touching code**

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
/ow-plan <task description>
/ow-plan <task> --worktree   # opt-in: implement+test run in a separate git worktree + auto-merge when tests PASS (#31)
/ow-plan fix:<slug>          # plan escalated from a fix-log — ingest + bind the link both ways (#30)
/ow-plan --from-fix <vault>/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md   # same as fix: but with the full path
/ow-plan <task> --revise <vault>/80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md
/ow-plan <task> --budget <n>  # Phase 1 vault read-set ceiling in tokens (default 40000)
```

Empty → ask (render in `$PROJECT_LANG`): "What task should I plan?"

## `--worktree` mode (opt-in — set once at plan time, inherited by the whole flow — #31)

`/ow-plan <task> --worktree` → writes `worktree: true` into the plan frontmatter (Phase 3). That field makes
**the whole flow run in a separate git worktree** without retyping the flag:

- `/ow-implement <plan>` → creates worktree `worktrees/plan-<slug>` + branch `plan/<slug>` (branched off current HEAD),
  then implements + commits **in there** — the main working tree is untouched (parallel uncommitted work stays safe)
- `/ow-test <plan>` → runs tests in the worktree → **PASS = auto-merge back to the base branch (local, no push) + cleanup**;
  FAIL = keeps the worktree for further fixing

🔴 **`/ow-plan` never creates the worktree itself** — it only records the intent; the worktree is created by `/ow-implement` (a plan is always text only)
🔴 overridable per command: `/ow-implement <plan> --no-worktree` (force in-tree) / `--worktree` (force on even when the frontmatter lacks it)

## `--revise` mode

1. Read existing plan file
2. Re-run Phase 1 (the vault may have changed)
3. Skip Phase 2 if the task description is unchanged
4. **Update in-place** — never create a new file
5. Show the diff → STOP and wait for user review

## `fix:` / `--from-fix` source mode (escalated from /ow-fix — #30)

When a plan is escalated from `/ow-fix` → build the plan from the fix-log + bind the link **both ways** so `/ow-implement` closes the fix-log automatically when the plan is done (never left stuck at `in-progress`)

1. **Resolve fix-log** — `fix:<slug>` → find `<slug>.md` in `$FIX_DIR`; `--from-fix <path>` → use the path directly. Not found → STOP + tell the user (never guess)
2. **Ingest (pre-fill, never re-ask)** — read the fix-log: `Symptom` / `Root Cause` → Task · `Affected Files` → Affected Files · `Success Criteria` → Success Criteria · `Test Cases` → Test Plan
3. **Link plan → fix** — write `source_fix: "[[<fix-log-slug>]]"` into the plan frontmatter (structured, machine-readable — `/ow-implement` uses it to close the fix-log, `/ow-git --bump` uses it to stamp the version)
4. **Link fix → plan (back-link)** — after the plan file is written (Phase 3), write `related_plan: "[[<plan-slug>]]"` back into the fix-log frontmatter (replacing `none`/a stale value)

🔴 Both `source_fix:` (plan) **and** `related_plan:` (fix-log) must be written — they bind the relation in both directions, otherwise the fix-log is orphaned (#30)
🔴 escalation is **1:1** — 1 fix-log ↔ 1 plan (`fix:<slug>` takes a single slug); a second bug → its own new fix-log + its own `/ow-plan fix:<slug2>` (never cram 2 fix-logs into one plan — closure closes one `source_fix` at a time)

## Phase 1 — Read vault context (mandatory, budgeted)

1. Read `<vault>/00-Index/IMPLEMENTATION-STATUS.md`
2. **FR coverage check** — grep `FR-[0-9]+` from the relevant PRD/SRS, then check which FRs are:
   - **orphan** — no plan step or task ID bound to it → warn the user in the output
   - **underspecified** — no acceptance criteria → suggest `/ow-clarify` before planning
   - Never block on this — just surface it to the user before the plan is written
3. **Build the read set — select before opening anything**
   - **ALWAYS** — the PRD/FEAT/FN the task names, plus the existing code + tests the plan will mirror
   - **CONDITIONAL** — apply the include-when table in `.ow/commands/_shared/context-refs.md`
     (`REF-APIIntegration` · `REF-AuthorizationMatrix` · `REF-TechStack` · `FLOW-*` · `30-Roles/<platform>/<role>/`).
     🔴 That file is the **single source of truth** — never copy the table here (a duplicated table = silent drift)
   - **Design system** → `<vault>/70-Reference/DesignSystem/` — always for a frontend/mobile task
   - 🔴 **Uncertain ⇒ include.** Skipping is the only move that loses information
4. **Measure the read set before opening it** — never estimate by eye:

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$VAULT_ABS" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
BUDGET=40000        # vault reads ONLY. The spec, the code, the output and the thinking all
                    # come out of the same window. `--budget <n>` overrides.
est_read_set() {    # usage: est_read_set <file>...  — count WHOLE files: Read loads whole files
  local est=0 b f
  for f in "$@"; do
    b=$(wc -c <"$f" 2>/dev/null || echo 0)
    case "$f" in
      *.md) est=$(( est + b / 2 ))     ;;   # vault markdown — Thai-heavy, ~2 bytes/token
      *)    est=$(( est + b * 2 / 7 )) ;;   # code — ~3.5 bytes/token
    esac
  done
  echo "$est"
}
```

   - `est <= BUDGET` → read the whole set
   - `est > BUDGET` → **never silently drop a doc.** In this order: (a) drop conditionals the
     include-when table did not require · (b) `/ow-clarify` if the task is two features wearing one
     name · (c) still over → write the plan with `split_advised: true` in frontmatter and tell the
     user to run `/ow-split`. **Never truncate a doc to fit** — a half-read spec is worse than a named gap
   - 🔴 The byte→token ratios are a heuristic, not a tokenizer measurement — say so whenever you report a number
5. Read every doc **in the selected set** in full (never just skim) — a doc that made the set is never skimmed
6. List in the plan file: every doc actually read **and** every doc the budget excluded, with the reason
7. **Consistency check** — the plan must not contradict the vault it was read from, nor any rule the resolver returned (`ow-paths.sh --rules <area>`). Every claim of a result must name the check behind it — a step that cannot be verified yet is written as `pending verification`, never as a done state. If the task has an irreversible/destructive step → flag it + require explicit approval via `risk_level: high` in the plan frontmatter

> **The vault already answers it → never ask the user again**

## Phase 2 — Clarifying questions (1 batch)

After reading the vault, ask every question **in a single message** — never drip-feed them.
Questions are shown to the user → render them in `$PROJECT_LANG` (Phase 0).

Ask only what the vault does not answer:
- Which roles are involved?
- Edge cases beyond the spec?
- Submodule scope (api / web / mobile / all)?
- Constraints (deadline, which components must be reused, etc.)?
- Does the design system still need a new component?

## Phase 3 — Create the plan file

Path: `<vault>/80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md`

(slug = kebab-case, ≤ 5 words)

### 🔴 Language split — this command does BOTH in one run

The plan file is a vault document; the summary at the end is chat. They are **not the same language knob**:

| What | Language | Where |
|---|---|---|
| Prose written into the plan file (Problem, Task, Goals, Non-goals, Steps, Risks, Success Criteria …) | `$VAULT_LANG` | Phase 3 (this phase) |
| Headings, frontmatter keys+values, paths, IDs (`FR-###`, `T###`), code, proof commands | English — always | Phase 3 |
| Questions asked to the user, the Phase 5 STOP message, the `## Output` summary | `$PROJECT_LANG` | Phase 2 · Phase 5 · `## Output` |

`$VAULT_LANG` unset in config ⇒ the resolver returns `$PROJECT_LANG`, so a project that never
sets it keeps a single language everywhere. Never swap the two: a plan written in `$PROJECT_LANG`
when the vault is `$VAULT_LANG` is a defect, and so is a summary answered in `$VAULT_LANG`.

### Plan precision contract (🔴 write this into every plan — /ow-implement executes faster + a wrong plan is caught)

A good plan = the subagent never has to investigate or guess at runtime, **but** it must catch the case where the plan contradicts the real code. Three rules:

1. **fact + proof, never a bare fact** — every verifiable step/affected-file carries the proving command + the expected result:
   `` remove import X — proof: `grep -rn X lib/` → 1 consumer (this file) = orphan ``
   `/ow-implement` runs the proof **once** and compares: match → execute; mismatch → STOP (plan stale). A cheap O(1) assert that guards against a wrong plan
2. **content-anchor, never a bare line number** — `` `path:LINES @ "unique-string"` `` (e.g. `` `dashboard.dart:56-67 @ "_fetchPatientRecordName"` ``).
   Code shifts → implement re-locates via the anchor string instead of breaking silently
3. **confidence tag per step** — `[fact]` = confirmed by grep/code (implement executes it directly, no re-check) · `⚠[verify]` = the plan guessed/inferred without running it (implement checks this one step before doing it)

🔴 **resolve the investigation at plan time, never hand it to implement** — run grep/orphan-check/"is it still there" while writing the plan and record the result as fact+proof; never write a step whose action is a bare "check/confirm" (= implement re-investigates, wasting time)
🔴 **Not provable at plan time** (needs real runtime) → tag `⚠[verify]` so implement knows it must check — never write it as `[fact]`

Template:
```markdown
---
tags: [type/plan]
date: YYYY-MM-DD HH:mm
title: <one-line task title>
status: planning            # planning | approved | in-progress | done | abandoned
submodule_target: <api | web | mobile | docs | all>
subagent_target: <backend | frontend | mobile | docs | design | all>   # the AREA whose rules/gates apply — /ow-implement decides inline vs delegated itself
worktree: true                              # ⬅ include ONLY when invoked with --worktree (otherwise drop this field) — implement+test inherit (#31)
source_fix: <"[[fix-log-slug]]" or none>   # set when /ow-plan fix:<slug> — /ow-implement closes this fix-log when the plan is done (#30)
related_docs:
  - <vault>/10-PRD/PRD-xxx.md
  - <vault>/20-Features/FEAT-xxx.md
  - <vault>/40-Functions/FN-xxx.md
estimate_hours: <number>
risk_level: <low | medium | high>
---

# <Task title>

## Problem
<2-4 sentences of plain human prose in $VAULT_LANG: what the problem/gap is (symptom, why it
 hurts) → what outcome is wanted. A reader must understand "what is being fixed and why" without
 reading code — not a task list (tasks are below)>

## Vault Context Read
- <vault>/00-Index/IMPLEMENTATION-STATUS.md
- <vault>/10-PRD/PRD-xxx.md (section: ...)
- <vault>/20-Features/FEAT-xxx.md (FR-001, FR-002)
- <vault>/40-Functions/FN-xxx.md
- <vault>/70-Reference/REF-TechStack.md
- <vault>/70-Reference/DesignSystem/DS-Components.md  ← if frontend/mobile

## Task
<clear one-paragraph task description>

## Goals
- [ ] Goal 1
- [ ] Goal 2

## Non-goals
- What this plan **will not** do

## Doc Gaps Found
- (list vault inconsistencies found while reading here — /ow-implement fixes them first)

## Affected Files
- `path/to/file.ts:120-145 @ "funcName"` — <what changes> · [fact]
- `path/to/orphan.tsx` — remove import Y; proof: `grep -rn Y src/` → 1 consumer = orphan · [fact]

## Implementation Steps
1. [fact] <action> — proof: `<cheap assert>` → expected `<result>`
2. [fact] <action already confirmed by code — anchor: `file:LINES @ "sym"`>
3. ⚠[verify] <action the plan guessed — implement must check `<what>` before doing it>
... (5-15 steps for medium task; 3-5 for small · resolve grep/orphan at plan time → write it as proof, never leave it as a "check" step)

## Design System Compliance (if frontend/mobile)
- [ ] Use tokens from `DS-Tokens.md` only (color/font/spacing)
- [ ] Use components from `DS-Components.md` (Button, Input, etc.)
- [ ] A new component needed → log it under "Design Additions" first
- [ ] WCAG AA contrast passes in every state

## Design Additions (if any)
- <New component or token to add — triggers /ow-design before /ow-implement>

## Test Plan
- [ ] Unit/Widget that `/ow-implement` closes itself: <X>
- [ ] Integration (in-process) for <Y>
- process check (order/grep/orphan) → **not a checkbox** — resolve it into fact+proof in Implementation Steps
- live-E2E (Playwright/Maestro/emulator/live backend) → **hand off to `/ow-test`** — never put it in as an implement done-gate checkbox (it bloats implement time)

## Success Criteria
- [ ] <falsifiable observable outcome — e.g. "createMedicalRecord returns an id + DoctorName=null really persisted in the DB", "endpoint answers 200", "UI renders component Y"> — the safety net against a wrong step (check the result, not the process)
- [ ] <criterion 2>

## Verification
- map back to each Success Criterion with the real result

## Risks
- <risk 1> → mitigation: <plan>
- <risk 2> → mitigation: <plan>

## Approvals
- [ ] Requested by: <user>
- [ ] Reviewed by: <reviewer>
- [ ] Approved (set status: approved before /ow-implement)
```

### Phase 3.5 — Write back-link to fix-log (fix-source mode only — #30)

In `fix:` / `--from-fix` mode → after the plan file is written (the plan slug is known), write `related_plan:` back into the fix-log:

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
PLAN_SLUG="<basename of the plan file just created, without .md>"
FIXLOG="$FIX_DIR/<fix-log-slug>.md"        # = fix:<slug> / --from-fix resolved in source mode
[ -f "$FIXLOG" ] || { echo "FATAL: fix-log missing: $FIXLOG"; exit 1; }
```

Edit the `related_plan:` frontmatter of `$FIXLOG` with **Edit (surgical)** → `"[[<PLAN_SLUG>]]"` (replacing `none`/a stale value) — never touch any other field of the fix-log

## Phase 4 — Doc gap detection

During Phase 1, if you find:
- A doc referenced in the PRD with no file
- Information contradicting between docs (e.g. role A in the PRD does not match AuthorizationMatrix)
- A related function spec that does not exist yet

→ List it under `Doc Gaps Found` in the plan file
→ The plan file states that `/ow-implement` Phase 2 fixes them first — inline by default, `docs` subagent only when the gap list earns one

## Phase 5 — STOP

Show the plan file created + this message (render in `$PROJECT_LANG`):

> Plan created: `<vault>/80-ImplementPlan/2026-05-20-1430-add-search-feature.md`
>
> Next:
> - Review the plan + set `status: approved` in the frontmatter
> - Change/extend → `/ow-plan <task> --revise <path>`
> - Once approved → `/ow-implement <path>`
> - The plan spans several areas, or runs past ~15 steps → `/ow-split <path>` first: it becomes sub-plans
>   that each fit one session (and one small-context model), run in order

If the plan has `worktree: true` → add a line:
> 🌳 **Worktree mode** — `/ow-implement` builds in a separate worktree (the main tree is untouched),
> `/ow-test` **auto-merges back to the current branch when tests pass** (local, no push)

**Never** let /ow-plan start implementing · **Never** let /ow-plan create a worktree (that is /ow-implement's job)

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-plan answer with **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from the Phase 0 resolver — th default; `en` → answer in English). Only:

- **Problem** — 1 line: what is broken/missing (taken from the plan's `## Problem` — restate it in `$PROJECT_LANG`; the plan file itself stays `$VAULT_LANG`)
- **What gets fixed** — 1-3 bullets: goal + the main changes (files/areas)
- **Plan file** — the path created
- **Risks / good to know** — only when there are any (`risk_level` ≥ medium, or a doc gap found); none → drop the bullet
- **Next** — review + set `status: approved` → `/ow-implement <path>`

The doc list and plan path already live in the plan file — never repeat them in the summary.

## Never

- Never touch code, never run build/test/lint in /ow-plan
- Never spawn a subagent — the plan file is text only
- Never set `status: approved` on the user's behalf — the user must do it
- Never add Implementation Steps outside the requested scope (no speculative abstraction/refactor)
- Success Criteria must be observable outcomes that can really be checked, not broad goals
- Never leave a step whose action is a bare "check/confirm/grep" for implement to investigate — resolve it at plan time → write it as fact+proof
- Never put live-E2E (Playwright/Maestro/emulator) in as a Test Plan checkbox — hand it to `/ow-test` (implement done-gate = unit/widget + outcome only)
- Every verifiable step must carry proof + the `[fact]` tag; guessed/inferred → `⚠[verify]` (never leave a step untagged)
- Never write the plan file body in `$PROJECT_LANG` when `$VAULT_LANG` differs, and never answer the user in `$VAULT_LANG` — the two knobs are independent
