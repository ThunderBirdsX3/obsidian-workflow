#!/usr/bin/env bash
# install.sh — copy the obsidian-workflow toolkit into a target project
#
# Usage:
#   bash install.sh /path/to/target-project
#
# Copies: .ow/ , .claude/commands/ow-*.md , .claude/agents/ ,
#         scripts/ow-paths.sh , .ow.yml (if absent) , vault skeleton (if absent)
# Never overwrites: .ow.yml, CLAUDE.md, existing vault content, anything outside its list.
# After install: open the target in Claude Code and run /ow-init

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?usage: bash install.sh /path/to/target-project}"
DEST="$(cd "$DEST" 2>/dev/null && pwd)" || { echo "FATAL: target not found: $1"; exit 1; }

[ "$SRC" = "$DEST" ] && { echo "FATAL: target is the toolkit repo itself"; exit 1; }
command -v yq >/dev/null 2>&1 || echo "WARN: yq not installed — commands will fail until you install it (brew install yq)"

# shared libs — shim generation + agent model sync + config block backfill
. "$SRC/scripts/ow-claude-manifest.sh"
. "$SRC/scripts/ow-config-merge.sh"

echo "Installing obsidian-workflow → $DEST"

# 1) toolkit core (.ow/) — refresh owned files; project's own rules/ content survives
mkdir -p "$DEST/.ow"
cp -R "$SRC/.ow/STANDARD.md" "$DEST/.ow/"
for d in policies checklists templates commands; do
  rm -rf "$DEST/.ow/$d"
  cp -R "$SRC/.ow/$d" "$DEST/.ow/$d"
done
mkdir -p "$DEST/.ow/rules"
[ -f "$DEST/.ow/rules/README.md" ] || cp "$SRC/.ow/rules/README.md" "$DEST/.ow/rules/"

# 2) claude agents — always-on (docs/verifier/security/gh-issue) refreshed;
#    specialized (backend/frontend/mobile/design/test-runner) copied only if absent
mkdir -p "$DEST/.claude/commands"
copy_agents "$SRC" "$DEST"

# 3) resolver + shared libs
mkdir -p "$DEST/scripts"
for f in scripts/ow-paths.sh scripts/ow-claude-manifest.sh scripts/ow-config-merge.sh; do
  cp "$SRC/$f" "$DEST/$f"
  chmod +x "$DEST/$f"
done

# 4) config — never overwrite an existing one; backfill missing blocks only
if [ -f "$DEST/.ow.yml" ]; then
  echo "  keep existing .ow.yml (backfilling new blocks if any)"
  merge_config_blocks "$DEST/.ow.yml" "$SRC/.ow.yml"
else
  cp "$SRC/.ow.yml" "$DEST/.ow.yml"
  echo "  created .ow.yml — edit project.name/slug (or run /ow-init)"
fi

# 4b) shims — GENERATED from .ow/commands + .ow.yml model config (not copied),
#     then sync agent `model:` frontmatter from .ow.yml subagents.<name>.model
generate_shims "$DEST/.ow/commands" "$DEST"
echo "  generated .claude/commands/ow-*.md shims (model from .ow.yml commands:)"
apply_agent_models "$DEST"

# 5) CLAUDE.md — never overwrite
if [ -f "$DEST/CLAUDE.md" ]; then
  echo "  CLAUDE.md exists — append the obsidian-workflow section yourself or let /ow-init ask"
else
  cp "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
fi

# 6) vault skeleton — only if the configured vault doesn't exist yet
VAULT_PATH="$(yq -r '.vault_path // "docs/vault"' "$DEST/.ow.yml" 2>/dev/null || echo docs/vault)"
case "$VAULT_PATH" in /*) VAULT_ABS="$VAULT_PATH" ;; *) VAULT_ABS="$DEST/$VAULT_PATH" ;; esac
if [ -d "$VAULT_ABS" ]; then
  echo "  vault exists: $VAULT_ABS (untouched)"
else
  mkdir -p "$VAULT_ABS"
  cp -R "$SRC/docs/vault/." "$VAULT_ABS/"
  echo "  created vault skeleton: $VAULT_ABS"
fi

# 7) gitignore block
if ! grep -q '^test-artifacts/' "$DEST/.gitignore" 2>/dev/null; then
  cat >> "$DEST/.gitignore" <<'EOF'

# obsidian-workflow — local artifacts
test-artifacts/
worktrees/
.ow-backup/
.obsidian/workspace*
EOF
  echo "  appended .gitignore block"
fi

echo ""
echo "✅ done — next: open the project in Claude Code and run /ow-init"
