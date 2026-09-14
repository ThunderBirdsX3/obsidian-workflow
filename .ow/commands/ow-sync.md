---
description: Sync the obsidian-workflow snapshot (commands, templates) from the obsidian-workflow repo into .ow/ and bump the pinned version
---

# ow-sync — Sync the obsidian-workflow snapshot

Pull the latest snapshot from the **obsidian-workflow repo** (`ThunderBirdsX3/obsidian-workflow`) → update the `.ow/` snapshot + bump the pinned version

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

## What the snapshot holds

```
obsidian-workflow repo (ThunderBirdsX3/obsidian-workflow)
        ↓ (/ow-sync pulls from here)
user project ─── .ow/ (snapshot copy: commands, templates)
```

The snapshot is versioned by one marker only: `ow.version` in `.ow.yml`. Everything a
project actually decides — requirements, design, rules — lives in the Obsidian vault and in
`.ow/rules/`, both of which `/ow-sync` never touches.

## Trigger

```
/ow-sync                       # interactive — show diff + ask confirm
/ow-sync --check               # check version difference, no download
/ow-sync --to <version>        # pin to a specific ow version (e.g. v0.4.0)
/ow-sync --dry-run             # show changes without applying them
/ow-sync --force               # skip confirmation
```

## Phase 1 — Read current pinned

```bash
current_ow_spec=$(yq '.ow.version' .ow.yml 2>/dev/null || echo "0.0.0")   # framework version
echo "Currently pinned:"
echo "  obsidian-workflow: $current_ow_spec   (framework — from .ow.yml)"
```

## Phase 2 — Fetch latest from obsidian-workflow repo

```bash
# obsidian-workflow repo is the source (ow.source; legacy fallback: standard.source)
source_url=$(yq '.ow.source // .standard.source' .ow.yml)
# Default: https://github.com/ThunderBirdsX3/obsidian-workflow

repo_slug=$(printf '%s' "$source_url" | sed -E 's#^(https?://github\.com/|git@[^:]+:)##; s#\.git$##')

# The source repo may be private. raw.githubusercontent.com answers 404 (not 403) to an
# unauthenticated request, so a missing token is indistinguishable from a deleted file —
# read through gh (already logged in) or an explicit token, and never accept an empty body.
gh_fetch() {   # $1 = path inside the repo
  if command -v gh > /dev/null 2>&1; then
    gh api "repos/$repo_slug/contents/$1?ref=main" -H "Accept: application/vnd.github.raw"
  elif [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: token $GITHUB_TOKEN" "https://raw.githubusercontent.com/$repo_slug/main/$1"
  else
    curl -fsSL "https://raw.githubusercontent.com/$repo_slug/main/$1"
  fi
}

# latest framework version = newest git tag on the source repo
latest_ow_spec=$(git ls-remote --tags "$source_url" 'v*' 2>/dev/null | awk -F/ '{print $NF}' | grep -E '^v?[0-9]' | sort -V | tail -1 | sed 's/^v//')

# STOP rather than report a phantom "already up to date" built on an empty read
[ -n "$latest_ow_spec" ] || { echo "STOP: cannot read tags from $source_url (private repo without auth returns 404) — run 'gh auth login' or export GITHUB_TOKEN" >&2; exit 1; }

# sanity-check read access to the snapshot itself before staging anything
gh_fetch ".ow/commands/ow-sync.md" > /dev/null || { echo "STOP: cannot read .ow/ from $source_url" >&2; exit 1; }

echo "Latest available (from obsidian-workflow main):"
echo "  obsidian-workflow: $latest_ow_spec   (latest git tag)"
```

Private repo → `gh auth login`, or a `GITHUB_TOKEN` env var with `repo` scope

## Phase 3 — Diff

```bash
# Fetch tree of .ow/ from obsidian-workflow repo (same auth ladder as Phase 2)
if command -v gh > /dev/null 2>&1; then
  tree_json=$(gh api "repos/$repo_slug/git/trees/main?recursive=1")
else
  tree_json=$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: token $GITHUB_TOKEN"} \
    "https://api.github.com/repos/$repo_slug/git/trees/main?recursive=1")
fi
tree=$(printf '%s' "$tree_json" | jq '[.tree[] | select(.path | startswith(".ow/"))]')
[ "$(printf '%s' "$tree" | jq 'length')" -gt 0 ] || { echo "STOP: empty .ow/ tree from $repo_slug — auth or repo problem, not an empty snapshot" >&2; exit 1; }

# Compare each blob hash against the local snapshot
# (implementation: sha1 of the local file vs blob.sha)
```

Show the diff:
```
Files to add:    3
Files to update: 5
Files to remove: 0

Detail:
+ .ow/commands/ow-newverb.md
~ .ow/commands/ow-plan.md (changed: lines 12-15)
~ .ow/templates/handoff.md (template format updated)
- (none)
```

## Phase 4 — Confirm

Unless `--force` or `--dry-run` → ask the user to confirm (render in `$PROJECT_LANG`)

```
Update the .ow snapshot from obsidian-workflow 0.4.0 → 0.4.3?
  Files to update: 5
  Files to add: 3
  Breaking changes? See CHANGELOG.

[y/N]:
```

## Phase 5 — Download + replace (SCOPE: .ow/ only)

> ⚠️ **Scope guard** — `/ow-sync` touches `.ow/` only
> Never overwrite `templates/`, `commands/`, `.claude/`, `docs/`, `.ow.yml`,
> `.ow/local/` under any circumstances
> `.ow/rules/` is the project's own — it is NOT part of the snapshot and is never replaced
> If the template structure changes → only flag it for the user to review in Phase 7

```bash
# Pre-flight: verify nothing owned by the project is touched
PROTECTED=(
  templates                       # project-level template overrides
  commands                        # project-level command overrides (optional, layered over .ow/commands/)
  .claude
  docs
  # AI front-end assets — MUST stay in sync with scripts/ow-frontends.sh
  # (ow_frontend_all_paths). gpt/ and glm/ were missing here for several releases.
  codex
  gemini
  gpt
  glm
  cline
  kimi
  prompts
  .agents
  AGENTS.md
  bin
  scripts                         # ow-paths.sh + upgrade.sh
  .ow.yml
  .ow/local
  CLAUDE.md
  AI-README.md
  README.md
)
# NOTE: /ow-sync REPLACES .ow/commands/ and .ow/templates/ —
# these are the synced snapshot. Agent bodies are NOT snapshot (see SNAPSHOT_PATHS below).
# User keeps customizations in root commands/ and templates/ (PROTECTED above).
echo "Protected paths (will not be touched): ${PROTECTED[*]}"

# Stage download from obsidian-workflow repo
STAGE=$(mktemp -d -t ow-sync-XXXXXX)
trap "rm -rf $STAGE" EXIT

# Option A (preferred): shallow clone + extract .ow/
git clone --depth 1 --branch "${TARGET_VER:-main}" \
  "https://github.com/ThunderBirdsX3/obsidian-workflow.git" "$STAGE/repo" >/dev/null 2>&1

# Verify source has expected structure (FLAT layout under .ow/)
test -d "$STAGE/repo/.ow/commands" || { echo "ERROR: obsidian-workflow repo missing .ow/commands/"; exit 1; }

# Snapshot paths that get synced (FLAT under .ow/) — REPLACE list matches the note above
SNAPSHOT_PATHS=(templates commands)
# No `agents` entry: obsidian-workflow ships no specialized agent body to snapshot. The four always-on
# bodies are refreshed under .claude/agents/ by install/upgrade (by SIGNATURE, see
# ow-claude-manifest.sh), and every specialized body is written by `/ow-agent create <name>`
# against this project's own stack — syncing would overwrite a project's own agent with a
# generic one. The consumer's .claude/agents/ is PROTECTED above and never touched here.
snapshot_src() { echo ".ow/$1"; }

# Atomic swap — back up the current state (all of .ow/ except local/ + *.backup-*)
backup_ts=$(date +%Y%m%d-%H%M%S)
backup_dir=".ow.backup-$backup_ts"
mkdir -p "$backup_dir"
for sp in "${SNAPSHOT_PATHS[@]}"; do
  [ -e ".ow/$sp" ] && cp -R ".ow/$sp" "$backup_dir/"
done

# Replace per snapshot path (leaves .ow/local/ — per-machine runtime state — untouched)
for sp in "${SNAPSHOT_PATHS[@]}"; do
  src="$(snapshot_src "$sp")"
  [ -e "$STAGE/repo/$src" ] || continue
  rm -rf ".ow/$sp"
  cp -R "$STAGE/repo/$src" ".ow/$sp"
done

# Verify
test -d .ow/commands && test -d .ow/templates && echo OK

# Verify: no file may show up in another folder (compare file counts pre/post)
for p in "${PROTECTED[@]}"; do
  [ -e "$p" ] || continue
  before=$(find "$p" -type f 2>/dev/null | wc -l)   # captured before the swap (compute in pre-flight + keep it)
  after=$(find "$p" -type f 2>/dev/null | wc -l)
  if [ "$before" -ne "$after" ]; then
    echo "⚠️ PROTECTED PATH MODIFIED: $p ($before → $after files)"
    echo "ABORTED — restoring backup"
    for sp in "${SNAPSHOT_PATHS[@]}"; do
      [ -e "$backup_dir/$sp" ] && { rm -rf ".ow/$sp"; cp -R "$backup_dir/$sp" ".ow/$sp"; }
    done
    exit 2
  fi
done
```

## Phase 6 — Update .ow.yml

```yaml
ow:
  version: "0.4.3"                                       # bumped to obsidian-workflow release that brought this snapshot
  source: "https://github.com/ThunderBirdsX3/obsidian-workflow"
  last_synced: "2026-05-25"
```

**Migration:** if a legacy `standard:` block is found in `.ow.yml`, migrate its fields then delete the block:
```bash
# Move standard.source → ow.source (if not set yet)
if [ -z "$(yq '.ow.source // ""' .ow.yml)" ]; then
  src=$(yq '.standard.source' .ow.yml)
  yq -i ".ow.source = $src" .ow.yml
fi
# Drop every deprecated field
yq -i 'del(.standard)' .ow.yml
```

## Phase 7 — Conformance lint (🔴 HARD GATE, #14) + impact check

🔴 **Run the conformance lint and REFUSE to finalize the sync if it fails** — the synced
snapshot must satisfy the read-mechanism contract (Phase 0 preamble in every command, §0 in
every agent, no obsidian-vault runtime literal in executable blocks, no jq/yq submodule-list
read, no binary write under the vault). On failure, restore the pre-sync backup and STOP.

```bash
if ! bash "$(git rev-parse --show-toplevel)/scripts/conformance-lint.sh"; then
  echo "FATAL: conformance lint failed — sync NOT finalized; restore the backup and report a bug"; exit 1
fi
```

**Re-sync AI models from `.ow.yml`** (read-only on config). Two parts, both
idempotent: (1) `subagents.<name>.model` → each agent's `model:` frontmatter; (2)
`commands.model` / `commands.overrides.<verb>` → regenerated command-shim frontmatter.
`inherit` ⇒ shim gets no `model:` line (command follows the session model).

`generate_shims` writes a shim for every command this sync **adds**, then prunes the shim of every
command this sync **removes** (spec gone + no `commands/<verb>.md` override backing it). A shim the
user wrote themselves carries no generated signature → it is left untouched:

```bash
ROOT="$(git rev-parse --show-toplevel)"
. "$ROOT/scripts/ow-claude-manifest.sh"
command -v apply_agent_models >/dev/null 2>&1 && apply_agent_models "$ROOT"
command -v generate_shims    >/dev/null 2>&1 && generate_shims "$ROOT/.ow/commands" "$ROOT" "ow"
```

After the update:
- Check that the command/template paths the user overrides in `templates/` still match the new schema
- If the template structure changed → flag the user to review the project-level overrides
- If a command gained or lost a phase → show a summary of what changed
- If the ow version is newer than the user's commands → also recommend running `bash scripts/upgrade.sh`

## Phase 8 — Changelog

Create `.ow/SYNC-HISTORY.md` (append-only):
```markdown
## 2026-05-25 — obsidian-workflow 0.4.0 → 0.4.3
- Updated by: <user>
- Source: ThunderBirdsX3/obsidian-workflow
- Reason: routine sync / fixing X
- Changes: ~5 files, +3 files
- Breaking: none / list
- Reviewed by: <reviewer>
```

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-sync, answer in **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — which version → which (scope: `.ow/` only)
- **Result** — the new pinned version, diff summary (+add/~update/-remove), protected paths untouched
- **Risks / next** — template overrides in `templates/` that may be outdated, breaking changes that require updating commands; if the ow version changed too → `scripts/upgrade.sh`

## Never

- Never sync without backing up `.ow/`
- Never edit `.ow/` by hand — a sync overwrites it; send the change to the obsidian-workflow repo instead
- Never put a project template into `.ow/templates/` — put it in `templates/` instead
- **Never touch any other folder, under any circumstances** — if a sync overwrites root `templates/`, root `commands/` (override layers), `.claude/`, `docs/`, `scripts/`, or the user's config → abort + restore the backup immediately
- Never touch `.ow/rules/` — those are the project's own rules, not part of the snapshot
- Never edit `.ow.yml` (only `ow.version` + `ow.last_synced` may change, via Phase 6)
- Never delete `.ow.backup-*` without telling the user — keep at least the 3 most recent backups
