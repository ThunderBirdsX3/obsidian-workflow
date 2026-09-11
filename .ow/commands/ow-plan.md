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
/ow-plan <task> --phase-budget <n>   # per-phase EXECUTOR context ceiling (default 120000) — Phase 2.5
/ow-plan <task> --max-phases <N>     # max phases, default 8 — Phase 2.5
/ow-plan <task> --no-phases          # force one flat plan even when 2.5 would break it into phases
```

🔴 `--budget` and `--phase-budget` are different knobs: `--budget` caps what **this** command reads from the
vault (Phase 1); `--phase-budget` caps what **`/ow-implement`** will have to read per phase (Phase 2.5).

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

### 🔴 Phase protection on a revise (a phased plan — Phase 2.5)

- **Rewrite `status: planning` phases and nothing else.** Everything else is protected (`in-progress`,
  `done`, anything unrecognized), as is any phase named by a `## Step Progress` / `## Chunk Progress` resume
  marker whatever its status. Fail-safe on purpose: `/ow-implement` stamps a phase row `in-progress` before
  its first code change, so a phase whose run **died mid-way** sits at `in-progress` with real work in the
  tree, and its marker records how far it got — a rewrite throws both away. 🔴 A stuck `in-progress` row is
  never cleared on the user's behalf — but **say how to clear it**: "phase `<id>` is `in-progress` (a run
  died there); set its `status` cell back to `planning` and re-run this revise to regenerate it, or
  `/ow-implement <plan> --phase <id>` to finish it." Protected is not the same as stuck with no way out
- A `planning` phase → rewrite it from the `## Shared Contract` **as it stands now**: a row already at
  `state: actual` supplies the starting value, never the stale `planned` one
- Report which phases were regenerated and which were skipped, and why — the user decides whether a skipped
  phase gets finished or deliberately reset

This is how a contract change propagates and how the remaining work gets re-partitioned — there is no separate
mode for either.

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
     name · (c) still over → read the docs one phase's worth at a time and write the plan **phased**
     (Phase 2.5), so no single read set ever has to hold all of them. **Never truncate a doc to fit** —
     a half-read spec is worse than a named gap
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

## Phase 2.5 — Break the work into phases (only when it earns it)

A **phase** = one concern that executes to a verifiable end on its own, small enough that a fresh session
(or a 200K local model) can finish it without investigating anything itself. `/ow-implement <plan> --phase P2`
runs exactly one; with no flag it runs them all in order.

🔴 **Do not phase a plan that does not need it.** One area, ≤ ~8 steps, no cross-area dependency ⇒ write the
flat plan (no `## Phases` section) and move on. Over-phasing pays a cold-context start per phase for nothing.
`--no-phases` forces flat regardless.

Why phases exist: one session accumulates the context of every area the plan touches. That both breaks a
small-context model and makes the run expensive — cost grows with accumulated context, so N short sessions
cost far less than one long one. 🔴 The saving only materialises when the user runs `/clear` between phases;
the Phase 5 STOP message must say so.

### 2.5.1 Design the breakdown

🔴 **The axis is not fixed.** `api` / `web` / `mobile` is only an easy-to-read example:

| Work | Phases that should come out |
|---|---|
| multi-repo, all three stacks touched | `P1 api` · `P2 web` · `P3 mobile` |
| single-repo, too many web screens | `P1 api-patient-endpoints` · `P2 web-patient-list` · `P3 web-patient-detail` |
| single-repo, no stack split at all | `P1 db-migration` · `P2 domain-model` · `P3 worker-queue` · `P4 report-export` |

1. **Name each phase after what it changes**, never after a stack. One stack may become several phases — the
   criterion is the budget (2.5.2) plus "finishes on its own", not the number of stacks
2. 🔴 **One phase = one `area`** (`backend | frontend | mobile | docs | design`) — a phase boundary must never
   straddle an area (same rule as `_shared/delegation.md` §2: a chunk boundary never straddles agents)
3. **Extract the Shared Contract** — every value used across phases (field name + type, JSON/DTO key, response
   shape, master-data shape, enum, label string, UI order, naming). Each row gets an id (`R1`, `R2`), one
   `producer` phase, and its `consumers`. 🔴 A phase references an id — it never redefines the value
4. **Build the dependency order** — a phase needing another phase's contract row gets `depends_on:`.
   Producers come first: `P1`, `P2`, `P3`… follow the recommended implement order
5. **Distribute** Affected Files, Steps, Tests, Success Criteria and doc-sync duties across phases
   **without overlap**

> 🔴 Golden rule: every Affected File and every doc belongs to **exactly one** phase — none orphaned, none in
> two phases (double-edit and merge-conflict risk).

🔴 Never cut through the middle of: a refactor spread over many files · a migration together with the code that
uses the new schema · a test paired with the same production change.

### 2.5.2 Size each phase against the executor's context budget (measure, never estimate by eye)

A phase's **read set** = what `/ow-implement` must open to run it: the code it changes, the tests it touches,
the FN/FEAT docs it needs, the rules for its area — plus **its own slice of this plan**, not the whole file.
🔴 A phased plan is read selectively (`_shared/phases.md` §1.5: the shared header + this phase's section
only), so charging the whole file here would price in 7 sections nobody opens — and charging a flat constant
would under-price a plan whose phase count grew. Count the slice.

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
PHASE_BUDGET=120000   # 200K local model x 0.6 — leaves room for output, tool results and the conversation
FLOOR=15000           # below this a phase is not worth its own cold-context start
MAX_PHASES=8
# --phase-budget / --max-phases override PHASE_BUDGET / MAX_PHASES when given.
# 🔴 A later phase runs in a FRESH SHELL, so Phase 1's est_read_set() is gone — re-define it here.
#    SESSION_FIXED covers what every run pays regardless of the plan: system prompt + Phase 0 + rules +
#    agent file. The plan's own cost is NOT in it — it is the slice, added per phase below.
SESSION_FIXED=20000
est_read_set() {                     # usage: est_read_set <file>...  — count WHOLE files
  local est=0 b f
  for f in "$@"; do
    b=$(wc -c <"$f" 2>/dev/null || echo 0)
    case "$f" in
      *.md) est=$(( est + b / 2 ))     ;;   # vault markdown — Thai-heavy, ~2 bytes/token
      *)    est=$(( est + b * 2 / 7 )) ;;   # code — ~3.5 bytes/token
    esac
  done
  echo $(( est + SESSION_FIXED ))
}
# phase total = est_read_set <this phase's code+doc files> + (shared header + this phase's section)/2 bytes
```

- `est > PHASE_BUDGET` → break that phase further, then measure again
- `est < FLOOR` → **merge it into a sibling**
- phase count `> MAX_PHASES` → merge the smallest phases
- 🔴 Merging (either case) is allowed **only between phases with the same area** — merging across areas breaks
  rule 2 and grows the read set across stacks. No same-area sibling → leave the count over `MAX_PHASES` and say so
- Broken down as far as it goes and a phase still exceeds `PHASE_BUDGET` → write it anyway and **warn** in
  Phase 5 that it will not fit a 200K model (the user may run it on a larger one). Never block
- 🔴 The byte→token ratios are a heuristic, not a tokenizer measurement — say so whenever you report a number

Record the result as the `est tokens` column of each `## Phases` row.

🔴 **Re-measure once the file exists.** Until Phase 3 writes it, the plan's own slices are an estimate of an
unwritten document — the one place this phase would otherwise be guessing. After the file is written, take the
real slice sizes and correct the column:

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
PLAN="$PLAN_DIR/<the file just written>"
HDR=$(awk '/^### Phase /{exit} {print}' "$PLAN" | wc -c | tr -d ' ')   # shared header, read by every phase
awk -v h="$HDR" '
  /^### Phase /{ if (id) printf "%s\t%d tok\n", id, (h + n) / 2; id=$3; n=0 }
  id { n += length($0) + 1 }
  END { if (id) printf "%s\t%d tok\n", id, (h + n) / 2 }' "$PLAN"
# → add each phase’s code/doc read set + SESSION_FIXED to these, then write the totals into the table
```

A corrected number that now exceeds `PHASE_BUDGET` → say so in the Phase 5 warning; never silently keep the
optimistic figure.

### 2.5.3 Clarify a boundary (only when genuinely ambiguous — folded into the Phase 2 batch)

Only what the vault and the task do not answer: which axis, when auto is not obvious · a file used by several
concerns, which phase owns it · any release/dependency ordering constraint.

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
context_closed: true                        # ⬅ include ONLY on a phased plan (Phase 2.5) — every phase carries its own
                                            #    context_refs, so /ow-implement + delegation take that list as the whole
                                            #    read set and skip include-when resolution. Flat plan ⇒ drop this field
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

### Phased layout (only when Phase 2.5 produced phases)

Everything above stays, with one change: `## Affected Files` · `## Implementation Steps` · `## Test Plan` ·
`## Success Criteria` **move inside each phase** (they are per-phase work) and these sections take their place,
inserted after `## Doc Gaps Found`. `## Design System Compliance` · `## Design Additions` · `## Verification` ·
`## Risks` · `## Approvals` stay at the top level, covering the plan as a whole.

```markdown
## Shared Contract

🔴 The single source of truth for every value shared across phases.
🔴 The producer writes `actual` back here when it implements · every consumer follows `actual`.

| id | key | planned | actual | state | producer | consumers |
|---|---|---|---|---|---|---|
| R1 | `Patient` PK field | `hn` | | planned | P1 | P2, P3 |
| R2 | `GET /patients` response shape | `{items,total}` | | planned | P1 | P2, P3 |

`state` is `planned` or `actual` — nothing else. `planned` = the plan's assumption, the producer has not run.
`actual` = the producer implemented it and filled `actual` with the real value.
(A plan whose phases share no value omits this section entirely.)

## Phases

| id | name | area | depends_on | est tokens | status |
|---|---|---|---|---|---|
| P1 | api-patient-endpoints | backend | — | 74k | planning |
| P2 | web-patient-list | frontend | P1 | 61k | planning |

Order: P1 → P2 · per-phase `status` is `planning | in-progress | done`, moved by `/ow-implement`
(`in-progress` is stamped when a phase starts — it is what marks "died mid-run, work in the tree")
🔴 Run **one phase per session with `/clear` between them** — without `/clear` there is no token saving at all

### Phase P1 — api-patient-endpoints

- **area:** backend · **depends_on:** — · **est tokens:** 74k (byte-based heuristic)
- **context_refs:** `src/api/patients.ts` · `src/api/__tests__/patients.test.ts` · `<vault>/40-Functions/FN-Patient.md`
  🔴 the exact path of every file this phase must read — this list **is** the read set
- **contract keys:** R1 (consumer) · R2 (producer)
- **owns docs:** `<vault>/40-Functions/FN-Patient.md` — ❗ never touch a doc another phase owns

#### Affected Files
- `src/api/patients.ts:120-145 @ "listPatients"` — <the change> · [fact]

#### Implementation Steps
1. [gate] Read `## Shared Contract` above. Every row whose `consumers` include this phase:
   `state: planned` → 🛑 **STOP**: "`<producer phase>` is not done — run `/ow-implement <plan> --phase <producer>` first."
   `state: actual` → use the `actual` column. (`depends_on: —` ⇒ omit this step.)
2. [fact] <action> — proof: `<cheap assert>` → expected `<result>`
   … (3-8 steps, same anchor/proof/tag rules as the flat plan)
N. [contract] Write back to `## Shared Contract`: every row whose `producer` is this phase gets its `actual`
   filled from the code just written (quote the grep that proves it) and `state: actual`.
   (A phase that produces no row omits this step.)

#### Test Plan
- [ ] <the test layer this phase owns>

#### Success Criteria
- [ ] <observable, really checkable>
- [ ] Every Shared Contract row with `producer` = this phase has `state: actual` and a non-empty `actual`

### Phase P2 — web-patient-list
… same shape
```

🔴 The contract write-back and the gate need **no extra machinery**: step N is an ordinary Implementation Step
paired with a Success Criteria checkbox, so `/ow-implement`'s open-checkbox gate already forces it.
🔴 Every phase must be self-contained: exact paths, line anchors, snippets, tests, criteria — the executor of
one phase never has to read another phase's section to do its work.
🔴 The same Affected File must never appear in two phases.

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

The plan is phased (Phase 2.5) → add, with the phase table and its `est tokens` per phase:
> 📐 **N phases** — P1 → P2 → … · coverage proof: the file→phase mapping (proves nothing is orphaned or duplicated)
> 🔴 Run **one phase per session and `/clear` between them** — without `/clear` there is no token saving at all:
> `/ow-implement <path> --phase P1`, then `/clear`, then `--phase P2` …
> All phases at once (small plan, or a large context) → `/ow-implement <path>` with no flag
> Warn here — and only here — if a phase is over `PHASE_BUDGET` or the count is over `MAX_PHASES`

If the plan has `worktree: true` → add a line:
> 🌳 **Worktree mode** — `/ow-implement` builds in a separate worktree (the main tree is untouched),
> `/ow-test` **auto-merges back to the current branch when tests pass** (local, no push)

**Never** let /ow-plan start implementing · **Never** let /ow-plan create a worktree (that is /ow-implement's job)

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-plan answer with **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from the Phase 0 resolver — th default; `en` → answer in English). Only:

- **Problem** — 1 line: what is broken/missing (taken from the plan's `## Problem` — restate it in `$PROJECT_LANG`; the plan file itself stays `$VAULT_LANG`)
- **What gets fixed** — 1-3 bullets: goal + the main changes (files/areas)
- **Plan file** — the path created
- **Phases** — only when the plan is phased: `P1 → P2 → …` with area + `est tokens` each, and any warning from 2.5.2; flat plan → drop the bullet
- **Risks / good to know** — only when there are any (`risk_level` ≥ medium, or a doc gap found); none → drop the bullet
- **Next** — review + set `status: approved` → `/ow-implement <path>` (phased → `--phase P1`, `/clear`, `--phase P2`, …)

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
- Never phase a plan that is already small enough (one area, ≤ ~8 steps, no cross-area dependency) — write it flat
- Never assign the same Affected File to two phases, and never leave one unassigned
- Never let a phase straddle two areas, and never merge two phases with different areas
- Never redefine a Shared Contract value inside a phase — reference the id
- Never rewrite a phase on `--revise` unless it is `status: planning` — and never one named by a `## Step Progress` / `## Chunk Progress` resume marker, at any status
- Never report an `est tokens` figure as a measured token count
