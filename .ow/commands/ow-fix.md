---
description: Diagnose bug + create fix-log with a verified RED baseline (no code change)
---

<!--
Obsidian behaviour this command must honour:
- Read `$IMPL_STATUS` (00-Index/IMPLEMENTATION-STATUS.md) FIRST
- Root cause + fix summary + regression check go into the fix-log under `$FIX_DIR`,
  following `.ow/templates/fix-log.md`
-->


# /ow-fix — Diagnose bug (no code change)

Diagnose + prepare the fix-log + record the RED baseline only
**every code change must go through `/ow-implement`** — never edit code directly in /ow-fix

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding,testing)
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
/ow-fix <bug description>
/ow-fix <bug> --update <vault>/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md
```

Empty → ask (render in `$PROJECT_LANG`): "What's the bug?"

## Phase 1 — Detect mode

| Arg | Mode |
|---|---|
| free text | **New** fix-log |
| `--update <path>` | **Append** a section in the existing fix-log |

## Phase 2 — Diagnose (read-only)

Before writing any file:
1. Identify the submodule/area (api / web / mobile / cross)
2. Reproduce if possible (start a dev server only as far as needed; preferred: read code)
3. Find the root cause via grep/Read — **never edit code**
4. Draft **Success Criteria** (fixed behavior + regressions that must not break + out-of-scope) → map them to the test cases that will prove the bug is gone

Bug unclear → ask 1-3 questions **in a single message**

## Phase 2.5 — RED baseline (🔴 prove the bug reproduces — still diagnose-only)

Record the state in which the bug **still exists**, so `/ow-implement` can prove red→green (RED here / GREEN at implement time)

> Still **never edit code** — this phase is *observe + record*, not fix, not write new tests

```bash
# context already loaded in Phase 0. The run output is scratch — it is read, quoted into the
# fix-log, and never committed or copied into the vault.
NN=$(echo "$ARGUMENTS" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
TS=$(date +%Y%m%d%H%M)
SLUG="${NN:-$TS}-<short-bug-slug>"
RUN_DIR="${TMPDIR:-/tmp}/ow-run-fix-$SLUG"; mkdir -p "$RUN_DIR"
```

Establish at least one of the following (depending on bug type):
1. **A reproduce test already exists** → run it and show FAIL: `{ <test-cmd> 2>&1; echo "EXIT=$?"; } > "$RUN_DIR/before-test-output.txt"`
2. **UI bug** → the observed wrong state on the screen where the bug occurs (what is on screen vs what should be)
3. **Not UI / no test yet** → error log / console output / stack trace proving the bug reproduces

🔴 State in the fix-log `## RED baseline` what was observed, quoting the real output (trimmed) — nothing
reproducible = `pending verification` (never fabricate)

🔴 **Writing the actual reproduce test is `/ow-implement`'s job** — the fix-log only *names* the test case that must go FAIL→PASS (see Test Cases in the template)

## Phase 3 — Create the fix-log

🔴 **Read `.ow/commands/_shared/coding-discipline.md` §1** before writing `## Success Criteria` —
it is the contract for what a criterion must be (checkable, paired with a regression, mapped to a Test Case)

Path: `<vault>/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md`

Prose written into the file is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

```markdown
---
tags: [type/fix-log]
date: YYYY-MM-DD HH:mm
title: <one-line bug title>
status: in-progress         # in-progress | fixed | wont-fix | regressed
severity: P1                # P0 blocker | P1 major | P2 minor | P3 polish
area: <api | web | mobile | cross>
reported_by: <user | qa | self | customer>
related_plan: <"[[plan-slug]]" or none>   # /ow-fix→/ow-plan path: /ow-plan fix: writes the back-link; closed automatically by /ow-implement (#30)
# fixed_commit / fixed_in_version — filled in automatically on close (/ow-fix path: /ow-git --bump · /ow-fix-issue path: closes + stamps itself in Phase 8.5)
---

# <Bug title>

## Symptom
<what user sees / what's broken>

## Reproduction
1. <step 1>
2. <step 2>
3. <expected vs actual>

## Success Criteria
<!-- Contract: `_shared/coding-discipline.md` §1 — what must become correct again + what must not break (regression). Map to Test Cases one by one -->
- [ ] <fixed behavior — symptom gone> — verify via TC-01
- [ ] <regression: adjacent feature X still works> — verify via TC-02
- [ ] Out of scope: <unrelated refactor/cleanup this fix "will not do">

## Root Cause
<technical cause — file path, function, line — from grep/read>

## Vault Context Read
- <vault>/40-Functions/FN-<related>.md
- <vault>/70-Reference/REF-AuthorizationMatrix.md (if auth-related)
- <vault>/85-FixLog/<previous-similar>.md (if there was a prior regression)

## RED baseline
<!-- Text only — quote the real output, trimmed to the relevant lines. The vault holds no binaries -->
- Reproduce test: <test-cmd> → FAIL / EXIT≠0 — or `pending verification`
```
<the failing output, verbatim + trimmed>
```
- Observed wrong state (UI bug): <what is on screen vs what should be> — or N/A (not a UI bug)

## Fix Approach
<paragraph describing the fix that will be made — not code yet>

## Affected Files
- `path/file1.ts` — <what to change>
- `path/file2.ts` — <what to change>

## Test Cases (prove red→green — `/ow-implement` runs this list)
<!-- Mandatory: ≥1 reproduce test (FAIL before the fix) + ≥1 regression test; state the layer -->
- [ ] TC-01: <layer (unit/integration/e2e)> — <reproduce scenario + expected> — must FAIL before the fix → PASS after the fix
- [ ] TC-02: (regression) <layer> — <adjacent feature that must keep working>

## Risk
- Risk of this fix + mitigation

## AI Usage
<!-- Fill in when closing the fix-log -->
- Tool: Claude Code   · Model: <model id>   · Usage level: <None|Low|Medium|High>
- Used for: <bullets — diagnose/test design/etc>
- Human verification: <Yes — how | No — reason>
- AI limitation/risk: <qualitative + mitigation | ->

## Next
- [ ] Run `/ow-plan fix:<slug>` — create the plan + wire the two-way link (`source_fix:` ↔ `related_plan:`)
- [ ] Run `/ow-implement <plan-path>` to apply the real fix (prove red→green with a real run)
- [ ] Close the fix-log: `status: fixed` + tick checkboxes — 🤖 **automatic via `/ow-implement` when the plan is done**; `fixed_in_version`/`fixed_commit` filled in by `/ow-git --bump` (no manual work — #30)
```

## Phase 4 — Auto-fix gate + choose the next path

### 4.1 Evaluate the auto-fix gate (before asking)

A small bug should not force the user to type a second command. Evaluate against the fix-log just written — **every row must pass**:

| Gate | Passes when |
|---|---|
| severity | `P2` or `P3` only |
| blast radius | `Affected Files` ≤ 5 files |
| scope | touches a **single** submodule/area |
| schema | does not touch DB migration / schema change |
| security surface | does not touch auth / permission / secret / payment |
| proof | has a reproduce test (FAIL before the fix) + ≥1 regression in `Test Cases` |

🔴 severity is set in Phase 3 from the real symptom — **never lower severity to pass this gate**.
P0/P1 = wide blast radius, a human must always review the plan, no exceptions

### 4.2 Ask (gate passed)

Ask (render in `$PROJECT_LANG`):

> Fix-log created: `<vault>/85-FixLog/2026-05-20-1530-search-not-returning-results.md`
> severity: P2 · area: web · affected: 2 files
>
> **Fix now?**
> - **`y`** → run the pipeline right away (every gate passed — see 4.4)
> - **`plan`** → `/ow-plan fix:<slug>` → pre-fill the plan + wire the two-way link (`source_fix:` ↔ `related_plan:`) → fix-log closes automatically (`status: fixed`) when the plan is `done` (#30)
> - **`pause`** → keep `status: in-progress`

### 4.3 Ask (gate failed)

Never offer `y` at all — state the failing reason plainly. Ask (render in `$PROJECT_LANG`):

> ⛔ auto-fix not allowed: severity `P1` (feature broken, wide user impact)
> Choose: **`plan`** → `/ow-plan fix:<slug>` · **`pause`** → `status: in-progress`

### 4.4 Run auto-fix (user answered `y`)

Follow `.ow/commands/ow-implement.md` mode `--from-fix` **in full, from Phase 2.7 onward**,
using the fix-log as the work unit (never copy phases back into this file — a second copy will drift)

🔴 `y` **does not mean `/ow-fix` edits the code itself** — it invokes `/ow-implement`'s pipeline, in which
every gate still runs in full: build/test run (5.0) · coverage audit (5.2) · discipline audit (5.3) ·
open-checkbox (6.0) · close the fix-log (6.5). The only thing skipped is **typing a second command**, not a gate

🔴 `y` / `plan` → no need to close the fix-log by hand (`status: fixed` + checkboxes are automatic via `/ow-implement`;
`fixed_in_version`/`fixed_commit` via `/ow-git --bump`). `pause` → stays `in-progress` until it is escalated

## Phase 5 — Update mode (`--update`)

Read the existing fix-log → append a new section (prose in `$VAULT_LANG`; headings stay English):
- Investigation update
- New findings
- Status change (e.g. `in-progress` → `regressed` with the reason)

Does not overwrite existing content

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-fix, answer in **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **Problem** — 1-2 lines: symptom + root cause (real, verified at the source)
- **Proof** — the source location that confirms the root cause + the RED baseline (if any)
- **Fix-log** — path created (severity + area)
- **Next** — gate passed → ask (render in `$PROJECT_LANG`) "Fix now?" with options `y` / `plan` / `pause`; gate failed → state the failing reason + offer `plan` / `pause`

🔴 Code is changed only after the user answers `y` — and it is changed through **`/ow-implement`'s pipeline** (every gate), not by `/ow-fix` itself
🔴 **Never fabricate** error/stack/RED output — cannot reproduce = `pending verification`.

## Severity guide

| Level | Use when |
|---|---|
| P0 — blocker | prod down / data loss / security breach |
| P1 — major | feature broken with wide user impact, workaround exists |
| P2 — minor | edge case / wrong behavior, easy workaround |
| P3 — polish | cosmetic / copy / a11y / small UX |

## Never

- Never let `/ow-fix` edit code itself — every code change goes only through `/ow-implement`'s pipeline (every gate). Phase 1–3 = always diagnose-only; Phase 4.4 = **invokes** that pipeline, it does not fix anything itself
- Never lower severity to pass the auto-fix gate (4.1) — P0/P1 must always go through `/ow-plan`
- Never offer `y` when the gate fails — state the failing reason, then let the user choose `plan` / `pause`
- Never guess the root cause without verifying at the source (grep/read)
- Never fabricate error messages / stack traces / RED output — if it cannot be reproduced, write `pending verification`
- Never skip Success Criteria + Test Cases — a reproduce test (FAIL before the fix) + ≥1 regression test are required before auto-fix or routing to `/ow-implement`
- Never `--update` as an overwrite — append in `## 📝 Updates` / the Updates section only
