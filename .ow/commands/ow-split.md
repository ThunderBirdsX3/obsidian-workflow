---
description: Split a large plan into self-contained sub-plans, each runnable in its own session (no code touch)
---

# /ow-split — split a large plan into executable units (no code)

Split one plan that is too large — or spans several areas — into **sub-plan files that stand on their own**:
small enough for a fresh session (or a 200K local model) to finish without investigating anything itself.
Each unit does only its own work, syncs only its own docs, and coordinates with its siblings through one
small CONTRACT file. **Never touches code.**

Why it exists: a single session accumulates the context of every area the plan touches. That both breaks a
small-context model and makes the run expensive — cost grows with accumulated context, so N short sessions
cost far less than one long one. 🔴 The saving only materialises when the user runs `/clear` between units;
the Phase 6 STOP message must say so.

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

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal: `$VAULT_ABS $PLAN_DIR
$PRD_DIR $FEAT_DIR $FN_DIR $REF_DIR $IMPL_STATUS $PROJECT_LANG $VAULT_LANG $COMMAND_PREFIX`. A later phase runs in a
FRESH SHELL — Phase 0's exports are gone — so it re-hydrates first, then asserts:
`. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"` followed by
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-split <plan-file-path>
/ow-split <plan> --by area|feature|file   # force the axis (default: auto — Phase 2)
/ow-split <plan> --max <N>                # max units, default 8
/ow-split <plan> --budget <tokens>        # per-unit context budget, default 120000
```

Empty → ask (render in `$PROJECT_LANG`) which plan, and list the 5 most recent files in `$PLAN_DIR`

🔴 The argument must be a plan file that **actually exists** under `$PLAN_DIR` — not found → **STOP**, never guess
🔴 The plan is already small enough (one area, ≤ ~8 steps, no cross-area dependency) → **do not split**: tell
the user and stop. Over-splitting pays a cold-context start per unit for nothing.

`--by`: `area` = by `subagent_target` · `feature` = by feature/screen (a web plan with many screens becomes
many units) · `file` = by file group (broad refactors) · auto = pick what the parent's real shape calls for.

## Phase 1 — Read the parent plan + vault

1. Read the parent plan in full — keep: Affected Files, Implementation Steps, Test Plan, Success Criteria,
   `related_docs`, `worktree:`, `submodule_target`, `subagent_target`
2. Read the vault docs the parent names (`related_docs`) only as far as needed to draw unit boundaries and
   assign per-unit doc ownership
3. The parent is not approved yet (`status` is neither `approved` nor `planning`) → splitting is still allowed,
   but warn the user that the sub-plans inherit `status: planning`
4. The parent already has a `## Sub-Plans (execution units)` section → **incremental re-run**, go to Phase 5.5

## Phase 2 — Design the split

🔴 **The axis is not fixed.** `api` / `web` / `mobile` is only an easy-to-read example. One sub-plan =
**one concern that executes to a verifiable end on its own** — whatever that is for the work at hand:

| Work | Units that should come out |
|---|---|
| multi-repo, all three stacks touched | `a-api` · `b-web` · `c-mobile` |
| single-repo, too many web screens | `a-api-patient-endpoints` · `b-web-patient-list` · `c-web-patient-detail` · `d-web-admin-settings` |
| single-repo, no stack split at all | `a-db-migration` · `b-domain-model` · `c-worker-queue` · `d-report-export` |

1. **Name each unit after what it changes**, never after a stack. One stack may become several units — the
   criterion is the budget (Phase 2.5) plus "finishes on its own", not the number of stacks.
2. 🔴 **One unit = one `subagent_target`** — a unit boundary must never straddle an area (same rule as
   `_shared/delegation.md` §2: a chunk boundary must never straddle agents). `submodule_target` is metadata
   inherited from the parent (a single-repo project may have none) — 🔴 it does **not** define a unit.
3. **Extract the Shared Contract** — every value used across units (field name + type, JSON/DTO key,
   response shape, master-data shape, enum, label string, UI order, naming). Each row gets an id (`R1`, `R2`),
   one `producer` unit, and its `consumers`. Values live in **one CONTRACT file** (Phase 4.1);
   🔴 a sub-plan references an id, it never redefines the value.
4. **Build the dependency order** — a unit needing another unit's contract row gets `depends_on:`. Foundations
   (the producers) come first: letters `a`, `b`, `c`… follow the recommended implement order.
5. **Distribute** the parent's Affected Files, Steps, Tests, Success Criteria and doc-sync duties across units
   **without overlap**.

> 🔴 Golden rule: every Affected File and every doc of the parent belongs to **exactly one** unit — none
> orphaned, none in two units (double-edit and merge-conflict risk).

🔴 Never cut through the middle of: a refactor spread over many files · a migration together with the code that
uses the new schema · a test paired with the same production change.

## Phase 2.5 — Size each unit against the context budget (measure, never estimate by eye)

For each unit, the **read set** = the files that unit's executor must open: the code it changes, the tests it
touches, the FN/FEAT docs it needs, the rules for its area. Measure them:

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
BUDGET=120000        # 200K local model x 0.6 — leaves room for output, tool results and the conversation
FLOOR=15000          # below this a unit is not worth its own cold-context start
MAX_UNITS=8
# --budget / --max override BUDGET / MAX_UNITS when given.

# Count the WHOLE file, never a line range — the Read tool loads whole files.
est_read_set() {                     # usage: est_read_set <file> [file...]
  local est=0 b f
  for f in "$@"; do
    b=$(wc -c <"$f" 2>/dev/null || echo 0)
    case "$f" in
      *.md) est=$(( est + b / 2 ))     ;;   # vault markdown — Thai-heavy, ~2 bytes/token
      *)    est=$(( est + b * 2 / 7 )) ;;   # code — ~3.5 bytes/token
    esac
  done
  echo $(( est + 25000 ))            # fixed: system prompt + Phase 0 + rules + agent file + the sub-plan
}
```

- `est > BUDGET` → split that unit further, then measure again
- `est < FLOOR` → **merge it into a sibling**
- unit count `> MAX_UNITS` → merge the smallest units
- 🔴 Merging (either case) is allowed **only between units with the same `subagent_target`** — merging across
  areas breaks rule 2 above and grows the read set across stacks. No same-area sibling to merge with → leave
  the count over `MAX_UNITS` and say so in the Phase 6 output.
- Split as far as it goes and a unit still exceeds `BUDGET` → write it anyway and **warn** in Phase 6 that this
  unit will not fit a 200K model (the user may run it on a larger one). Never block.
- 🔴 The byte→token ratios are a heuristic, not a tokenizer measurement — say so whenever you report a number.

Record the result as `context_est_tokens:` in each sub-plan.

## Phase 3 — Clarify (only when a boundary is genuinely ambiguous — one batch)

Ask once, in a single message, only what the parent and the vault do not answer:
- which axis, when auto is not obvious?
- a file used by several concerns — which unit owns it?
- any release/dependency ordering constraint?

The parent already answers it → do not ask.

## Phase 4 — Write the files

All files are flat in `$PLAN_DIR`, named from the parent's basename so they sort next to it and the existing
slug lookup keeps working:

```
<parent-basename>.md                        # the parent, edited in place (Phase 5)
<parent-basename>-CONTRACT.md               # Phase 4.1
<parent-basename>-<letter>-<unit-slug>.md   # Phase 4.2, letters in implement order
```

`<unit-slug>` describes **what the unit changes**, not a stack name.

### 4.1 The CONTRACT file

Its prose is `$VAULT_LANG`; headings, frontmatter, ids and file paths stay English.

```markdown
---
tags: [type/plan, plan/contract]
date: YYYY-MM-DD HH:mm
parent_plan: "[[<parent-basename>]]"
---

# Shared Contract — <parent title>

🔴 The single source of truth for every value shared across units.
🔴 The producer writes `actual` back here when it implements · every consumer follows `actual`.

| id | key | planned | actual | state | producer | consumers |
|---|---|---|---|---|---|---|
| R1 | `Patient` PK field | `hn` | | planned | a-api | b-web, c-mobile |
| R2 | `GET /patients` response shape | `{items,total}` | | planned | a-api | b-web, c-mobile |
```

`state` is `planned` or `actual` — nothing else. `planned` = the split's assumption, the producer has not run.
`actual` = the producer implemented it and filled the `actual` column with the real value.

### 4.2 Each sub-plan

Prose in `$VAULT_LANG`; frontmatter, headings, ids and paths English.

```markdown
---
tags: [type/plan, plan/sub]
date: YYYY-MM-DD HH:mm
title: "<letter> — <unit-slug>: <what it does>"
status: planning
submodule_target: <inherited from the parent — omit on a single-repo project>
subagent_target: <backend | frontend | mobile | docs | design>   # exactly one — a unit never straddles areas
parent_plan: "[[<parent-basename>]]"
contract_file: "[[<parent-basename>-CONTRACT]]"
split_index: <a|b|c…>
depends_on: ["[[<sibling-basename>]]"]        # [] when none
context_closed: true
context_refs:
  - <exact path of every file this unit must read>
context_est_tokens: <number from Phase 2.5>
worktree: true                                # only when the parent carries it
estimate_hours: <number>
risk_level: <low | medium | high>
---

# <letter> — <unit-slug>: <title>

> **Parent:** [[<parent-basename>]] · **Contract:** [[<parent-basename>-CONTRACT]]
> **Boundary:** change only the files in this plan · never touch another unit's files or docs
> 🔴 Everything needed is in this file plus the CONTRACT — **you do not need to open the parent**

## Contract Keys (🔴 the CONTRACT wins)

| id | key | value when this plan was written |
|---|---|---|
| R1 | `Patient` PK field | `hn` |

🔴 Step 0 reads the CONTRACT first. A value there that differs from this table → **use the CONTRACT value**
everywhere in this file (code snippets, Affected Files, steps). Do not stop, do not ask — just substitute.

## Context (read-only)
<3-8 lines: enough that the executor never has to go investigating>

## Affected Files (this unit only)
- `path:120-145 @ "funcName"` — <the change, with a snippet concrete enough to apply> · [fact]

## Implementation Steps
0. [gate] Read `<CONTRACT path>`. For every row whose `consumers` include this unit:
   - `state: planned` → 🛑 **STOP**: "`<producer unit>` is not done — run `/ow-implement <producer>` first."
     Never implement against a value that is still an assumption.
   - `state: actual` → use the `actual` column in place of the Contract Keys table everywhere.
   (`depends_on: []` → this step is omitted from the file entirely.)
1. … (3-8 steps, each with an exact anchor and proof, same rules as /ow-plan)
N. [contract] Write back to `<CONTRACT path>`: for every row whose `producer` is this unit, fill `actual`
   from the code just written (quote the grep that proves it) and set `state: actual`.
   (A unit that produces no row omits this step entirely.)

## Test Plan
- <the test layer this unit owns>

## Success Criteria
- [ ] <observable, really checkable>
- [ ] Every CONTRACT row with `producer` = this unit has `state: actual` and a non-empty `actual` column
      (omitted for a unit that produces no row)

## Verification
- map each Success Criterion back to a real result

## Own-Doc Sync (these docs only)
- <the vault docs this unit owns>
- ❗ do not touch <docs owned by another unit>

## Risks
- <dependency + contract risk>
```

🔴 The write-back and the gate need **no change to `/ow-implement`**: step N is an ordinary Implementation
Step paired with a Success Criteria checkbox, so the Phase 6.0 open-checkbox gate already forces it before
`status: done`.
🔴 Every sub-plan must be self-contained: exact paths, line anchors, snippets, tests, criteria.
🔴 The same Affected File must never appear in two sub-plans.

## Phase 5 — Rewrite the parent as an orchestrator (in place — no new file)

Edit the parent plan (never create a copy). Insert these two sections before `## Doc Gaps Found`, or at the
end of the body:

```markdown
## Shared Contract
→ [[<parent-basename>-CONTRACT]] — 🔴 change a value there and nowhere else; sub-plans never redefine one

## Sub-Plans (execution units)

| id | file | area | what it does | depends_on | est tokens |
|---|---|---|---|---|---|
| a | [[<parent-basename>-a-api-patient-endpoints]] | backend | … | — | 74k |
| b | [[<parent-basename>-b-web-patient-list]] | frontend | … | a | 61k |

Implement order: a → b → …
Rules: each unit does only its own work · syncs only its own docs · reads siblings read-only.
Execution detail lives in the sub-plans — the sections above stay as the overview.
```

`## Sub-Plans (execution units)` is the marker `/ow-verify` and the Phase 5.5 re-run both look for.

## Phase 5.5 — Incremental re-run (the parent already has `## Sub-Plans`)

- 🔴 **Rewrite `status: planning` units and nothing else** — everything else is protected (`approved`,
  `in-progress`, `done`, anything unrecognized), as is any unit carrying a `## Step Progress` /
  `## Chunk Progress` resume marker whatever its status. Fail-safe on purpose: `/ow-implement` goes
  `approved` → `done` and never stamps `in-progress`, so a unit whose run **died mid-way** sits at `approved`
  with real work in the tree and a marker recording how far it got — a rewrite throws both away
- A `planning` unit → rewrite it from the CONTRACT as it stands now: a row already at
  `state: actual` supplies the starting value for that unit's Contract Keys table
- Report which units were regenerated and which were skipped, and why — the user decides whether a skipped
  unit gets finished or deliberately reset

This is how a contract change propagates and how the remaining work gets re-partitioned — there is no separate
mode for either.

## Phase 6 — Output (short bullets, in `$PROJECT_LANG`) + STOP

Show the files created and then stop:

- **What was split** — parent → N units + CONTRACT, with the tree and `est tokens` per unit
- **Order** — a → b → c, and what each unit depends on
- **Coverage proof** — the file→unit mapping table (proves nothing is orphaned or duplicated)
- **Warnings** — only if any: a unit over budget, unit count over `MAX_UNITS`, the parent not yet approved
- **Next**:
  > 🔴 Run one unit per session and `/clear` between them — without `/clear` there is no token saving at all.
  > Review each unit → set `status: approved` → `/ow-implement <unit a>`
  > All units done → `/ow-verify <parent>`

🔴 Always state that `context_est_tokens` is a byte-based heuristic, not a tokenizer measurement.

## Never

- Never touch code · never run build/test/lint
- Never set `status: approved` — that is the user's call
- Never start implementing
- Never split a plan that is already small enough — say so and stop
- Never assign the same Affected File to two sub-plans, and never leave one unassigned
- Never redefine a Shared Contract value inside a sub-plan — reference the id
- Never overwrite a sub-plan on a re-run unless it is `status: planning` — and never one carrying a
  `## Step Progress` / `## Chunk Progress` resume marker, at any status (5.5)
- Never merge two units with different `subagent_target`
- Never report an `est tokens` figure as a measured token count
