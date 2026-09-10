---
description: Create a Handoff Report for reviewer / exec / QA + update status
---

# /ow-handoff — Hand off work (Handoff Report)

Create a formal hand-off document for reviewer / exec / QA to read and approve

> Should run `/ow-verify` to a pass first, then `/ow-handoff`

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
/ow-handoff <plan-or-fix-path>     # hand off the work from the given plan/fix
/ow-handoff --feature <name>       # hand off the whole feature
/ow-handoff --since <ref>          # hand off everything in the diff range
```

Empty → ask (render in `$PROJECT_LANG`) what work to hand off + list the 5 most recent plans with `status: done`

## Phase 1 — Pre-flight check

1. Read the plan/fix file
2. **Warn** if `status != done` — recommend implementing first
3. **Warn** if `/ow-verify` has not been run — show the message but do not block (the user decides)
4. Read this work's verification record in the plan/fix-log (`Implementation Result` / `Build/Test Result`) —
   the pass/fail counts and commands quoted there are what the report cites; a claim with no run behind it
   is reported as `pending verification`, never as a pass

## Phase 2 — Create the Handoff Report

Path: `<vault>/95-Handoff/HOR-<YYYY-MM-DD>-<slug>.md`

Prose written into the file is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

```markdown
---
tags: [type/handoff]
date: YYYY-MM-DD HH:mm
title: <handoff title>
scope: <plan-slug | feature-name | diff-range>
status: ready-for-review     # ready-for-review | approved | deployed
audience: [executive, reviewer, qa]
recipient: <name it if there is a clear recipient>
---

# <Title>

## Summary
Summary of the completed work + business value + impact, in plain language (for exec/reviewer)

## What Changed
- Files changed: N (production: M, tests: K)
- New features: <list>
- Bugs fixed: <list>
- Docs updated: <list>

## Verification Results
- Tests: <N passed / M total> — command: <the test command that produced it>
- Build: <pass/fail>
- Lint: <pass/fail>
- Manual checks: <list — what was checked + observed>

## Design System Compliance
- Components used: <list from DS>
- New components added: <list>
- Violations: 0 / N

## Security Pre-flight
- Secret scan: <result>
- PII scan: <result>
- Screenshot masking: <result>
- Production guardrails: <result>

## Project rules applied
- .ow/rules/<area>.md
- (list the rule files the resolver actually returned for this work)

## Pipeline trace
- Understand: /ow-new / /ow-plan
- Plan: <vault>/80-ImplementPlan/<slug>.md
- Execute: /ow-implement → subagent <name>
- Verify: /ow-verify
- Handoff: this document (/ow-handoff)

## Commands run
- (list every slash command + bash command actually run across the pipeline)

## Sources
- <vault>/80-ImplementPlan/<slug>.md (plan, status: done)
- <vault>/85-FixLog/<slug>.md (fix-log, if this work came from one)
- Git commits: <commit hashes>

## Limitations / Risks / Next steps
- <known limitation>
- <risk + mitigation>
- <next step recommended>

## Rollback / Mitigation
- <if production-facing — rollback plan>

## Approval
- [ ] Reviewed by: <reviewer>
- [ ] Approved at: <YYYY-MM-DD HH:mm>
- [ ] Deployed to: <env>
```

## Phase 3 — Update status

1. Plan frontmatter: `status: handed-off`
2. `<vault>/00-Index/IMPLEMENTATION-STATUS.md` → mark scope `ready-for-review`

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-handoff answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). The HOR document **is** the main output — the summary only points to it:

- **What was handed off** — scope + status (done / what is left)
- **Handoff report** — path `HOR-<slug>.md` + the named reviewer
- **Verification** — the tests/checks cited in the report (cite real ones)
- **Next** — the reviewer fills in the Approval section

🔴 **Never fake a result** in the report · **Never approve your own work** — the Approval section is for the reviewer to fill in.

## Never

- Never fake a result in the handoff report
- Never approve your own work — the Approval section is for the reviewer to fill in
- Never push a handoff to a public repo if it contains customer PII
- Never create a handoff if the plan is not done — warn the user to finish it first
