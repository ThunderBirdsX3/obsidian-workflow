#!/usr/bin/env bash
# ow-upgrade — upgrade an existing obsidian-workflow install
#
# Usage from an INSTALLED project (no toolkit clone needed):
#   bash scripts/ow-upgrade.sh                    # upgrade this project
#   bash scripts/ow-upgrade.sh --dry-run
#   bash scripts/ow-upgrade.sh --rollback
#
# Usage from the toolkit source checkout:
#   bash scripts/ow-upgrade.sh /path/to/project [--dry-run|--rollback]
#
# When run from an installed project (no toolkit source next to the script),
# fetches the latest toolkit from GitHub automatically, then upgrades.
#
# Refreshes ONLY toolkit-owned paths:
#   .ow/STANDARD.md  .ow/{policies,checklists,templates,commands}
#   .claude/commands/ow-*.md   (REGENERATED from .ow/commands + .ow.yml model config)
#   .claude/agents/<ow-owned>.md  (user's custom agents untouched; `model:` synced
#                                  from .ow.yml subagents.<name>.model)
#   scripts/ow-*.sh
# Backfills new top-level blocks into .ow.yml (e.g. `commands:`) — never edits
# blocks/values the user already has.
# Never touches: CLAUDE.md, vault content, .ow/rules/ content.
# Backup of every replaced path lands in .ow-backup/<timestamp>/ (use --rollback).

set -euo pipefail

TOOLKIT_REPO="https://github.com/ThunderBirdsX3/obsidian-workflow.git"

# script lives in scripts/ — toolkit root is the parent
SRC="$(cd "$(dirname "$0")/.." && pwd)"

# detect: running from installed project (no toolkit source) → self-fetch
if [ ! -d "$SRC/.ow/commands" ]; then
  DEST="$SRC"  # the project this script lives in
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching latest obsidian-workflow..."
  git clone --depth=1 "$TOOLKIT_REPO" "$TMP/toolkit" 2>&1 | grep -v "^$" || true
  exec bash "$TMP/toolkit/scripts/ow-upgrade.sh" "$DEST" "$@"
fi

# running from toolkit source — original behaviour
DRY_RUN=0; ROLLBACK=0
DEST=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    *) DEST="$1"; shift ;;
  esac
done
[ -n "$DEST" ] || { echo "usage: bash scripts/ow-upgrade.sh /path/to/project [--dry-run|--rollback]" >&2; exit 1; }
DEST="$(cd "$DEST" 2>/dev/null && pwd)" || { echo "FATAL: target not found: $DEST"; exit 1; }

[ "$SRC" = "$DEST" ] && { echo "FATAL: target is the toolkit repo itself"; exit 1; }

# shared libs — shim generation + agent model sync + config block backfill
. "$SRC/scripts/ow-claude-manifest.sh"
. "$SRC/scripts/ow-config-merge.sh"

BACKUP_ROOT="$DEST/.ow-backup"

# toolkit-owned paths refreshed wholesale (relative to both roots)
OWNED_DIRS=(.ow/policies .ow/checklists .ow/templates .ow/commands)
OWNED_FILES=(.ow/STANDARD.md scripts/ow-paths.sh scripts/ow-claude-manifest.sh scripts/ow-config-merge.sh scripts/ow-upgrade.sh)

# ── rollback ──────────────────────────────────────────────────────────────────
if [ "$ROLLBACK" -eq 1 ]; then
  last="$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -1 || true)"
  [ -n "$last" ] || { echo "FATAL: no backup found under $BACKUP_ROOT"; exit 1; }
  echo "Rolling back from $last"
  (cd "$last" && find . -type f | while IFS= read -r f; do
    rel="${f#./}"
    mkdir -p "$DEST/$(dirname "$rel")"
    cp "$f" "$DEST/$rel"
    echo "  restored $rel"
  done)
  echo "✅ rollback done"
  exit 0
fi

# ── pre-flight ────────────────────────────────────────────────────────────────
[ -d "$DEST/.ow" ] || { echo "FATAL: $DEST has no .ow/ — run install.sh first"; exit 1; }
command -v yq >/dev/null 2>&1 || echo "WARN: yq not installed — model config from .ow.yml will fall back to built-in defaults"

# ── dry-run ───────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN — would refresh in $DEST:"
  for d in "${OWNED_DIRS[@]}"; do
    if diff -rq "$SRC/$d" "$DEST/$d" >/dev/null 2>&1; then
      echo "  = $d (unchanged)"
    else
      echo "  ~ $d"
      diff -rq "$SRC/$d" "$DEST/$d" 2>/dev/null | sed 's/^/      /' | head -20 || true
    fi
  done
  for f in "${OWNED_FILES[@]}"; do
    if [ ! -f "$DEST/$f" ]; then echo "  + $f (new)"
    elif ! diff -q "$SRC/$f" "$DEST/$f" >/dev/null 2>&1; then echo "  ~ $f"
    else echo "  = $f (unchanged)"; fi
  done
  echo "  ~ .claude/commands/ow-*.md (regenerated from .ow/commands + .ow.yml)"
  echo "  ~ .claude/agents/*.md model: lines (synced from .ow.yml; ow-owned only)"
  echo "  + .ow.yml missing top-level blocks (additive backfill only)"
  exit 0
fi

echo "Upgrading obsidian-workflow → $DEST"

# ── backup ────────────────────────────────────────────────────────────────────
TS="$(date +%Y%m%d-%H%M%S)"
BK="$BACKUP_ROOT/$TS"
mkdir -p "$BK"
backup_path() { # backup_path <relative>
  local rel="$1"
  [ -e "$DEST/$rel" ] || return 0
  mkdir -p "$BK/$(dirname "$rel")"
  cp -R "$DEST/$rel" "$BK/$rel"
}
for d in "${OWNED_DIRS[@]}"; do backup_path "$d"; done
for f in "${OWNED_FILES[@]}"; do backup_path "$f"; done
backup_path .ow.yml
# generated shims + ow-owned agents (per manifest)
while IFS= read -r rel; do backup_path "$rel"; done < <(ow_owned_claude_manifest "$SRC/.ow/commands")
echo "  backup: $BK"

# ── apply: toolkit core ───────────────────────────────────────────────────────
for d in "${OWNED_DIRS[@]}"; do
  rm -rf "${DEST:?}/$d"
  mkdir -p "$DEST/$(dirname "$d")"
  cp -R "$SRC/$d" "$DEST/$d"
done
cp "$SRC/.ow/STANDARD.md" "$DEST/.ow/STANDARD.md"
mkdir -p "$DEST/.ow/rules"
[ -f "$DEST/.ow/rules/README.md" ] || cp "$SRC/.ow/rules/README.md" "$DEST/.ow/rules/" 2>/dev/null || true
echo "  refreshed .ow/ owned dirs"

# ── apply: resolver + libs ────────────────────────────────────────────────────
mkdir -p "$DEST/scripts"
for f in scripts/ow-paths.sh scripts/ow-claude-manifest.sh scripts/ow-config-merge.sh scripts/ow-upgrade.sh; do
  cp "$SRC/$f" "$DEST/$f"; chmod +x "$DEST/$f"
done
echo "  refreshed scripts/ow-*.sh"

# ── apply: config block backfill (additive only) ─────────────────────────────
if [ -f "$DEST/.ow.yml" ]; then
  merge_config_blocks "$DEST/.ow.yml" "$SRC/.ow.yml"
else
  cp "$SRC/.ow.yml" "$DEST/.ow.yml"
  echo "  created .ow.yml (was missing)"
fi

# ── apply: agents — always-on refreshed; specialized never overwritten ───────
copy_agents "$SRC" "$DEST"

# ── apply: shims (regenerated) + model sync from .ow.yml ─────────────────────
generate_shims "$DEST/.ow/commands" "$DEST"
echo "  regenerated .claude/commands/ow-*.md shims (model from .ow.yml commands:)"
apply_agent_models "$DEST"

# ── prune old backups — keep only this run's ─────────────────────────────────
ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | sed '$d' | while IFS= read -r old; do
  rm -rf "$old"
done

echo ""
echo "✅ upgrade done — rollback available: bash scripts/ow-upgrade.sh $DEST --rollback"
