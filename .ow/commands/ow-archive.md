---
description: Archive plan/fix-log files into an archive/ subfolder inside 80-ImplementPlan or 85-FixLog
---

# /ow-archive — archive plan/fix-log files

Moves finished plan and fix-log files out of the working list into
`$PLAN_DIR/archive/<name>/` or `$FIX_DIR/archive/<name>/`, keeping the vault's
active folders short without deleting history.

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules docs)
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
/ow-archive                          # archive EVERY file in $PLAN_DIR + $FIX_DIR, folder = today ($TODAY)
/ow-archive <name>                   # same, custom subfolder, e.g. phase1, 2026-Q3, released-v2
/ow-archive --into <name>            # explicit flag form of the same
```

Only argument accepted is the destination subfolder name — no file selection, no filtering.
Every file directly under `$PLAN_DIR` and `$FIX_DIR` (excluding anything already under `archive/`) is moved.

## Phase 1 — Resolve target list

List every file directly under `$PLAN_DIR` and `$FIX_DIR`, excluding anything already under an `archive/` subfolder (skip those — already archived). Empty result (nothing to archive) → say so, stop, no prompt.

## Phase 2 — Resolve subfolder name

| Condition | Subfolder |
|---|---|
| `<name>` or `--into <name>` given | Sanitize to `[a-z0-9-]` (lowercase, spaces → `-`); reject empty after sanitizing |
| Not given | `$TODAY` (`YYYY-MM-DD`, from Phase 0) |

Target dir: `$PLAN_DIR/archive/<name>/` for plan files, `$FIX_DIR/archive/<name>/` for fix-logs — each file goes to the archive dir matching the folder it currently lives in. Create the dir if missing.

## Phase 3 — Move + confirm

Show the resolved file list + destination, ask **y/n** once (render in `$PROJECT_LANG`) before moving — this is a bulk, unfiltered move, always confirm.

Then, per file:
1. `git mv <file> <dest>/<same-basename>` (falls back to `mv` + `git add`/`git rm` if the file is untracked)
2. Leave file content untouched — no frontmatter rewrite, no status change (archiving is not a status transition; if the user also wants `status: done`, they say so separately)

## Phase 4 — Fix links

After moving:
1. `grep -rl "<old-relative-path>"` across `$VAULT_ABS` (MOCs, `00-Index/IMPLEMENTATION-STATUS.md`, other plans/fix-logs that reference this one) → update each match to the new path
2. If nothing references the file, skip silently

## Output (short bullets, in `$PROJECT_LANG`)

- **Archived** — file → new path, one line per file
- **Subfolder** — name used (`$TODAY` or `--into` value)
- **Links fixed** — files whose reference was updated, or "none"

## Never

- Never archive a file outside `$PLAN_DIR` / `$FIX_DIR`
- Never delete a file — archive only moves it
- Never rewrite file content or bump frontmatter `version`/`status` — archiving is a location change only
- Never silently overwrite an existing file at the destination — if the basename already exists there, **STOP** and ask
