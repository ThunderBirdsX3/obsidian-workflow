#!/usr/bin/env bash
# obsidian-workflow — canonical .gitignore managed block (single source of truth)
# ─────────────────────────────────────────────────────────────────────────────
# Sourced by scripts/install.sh + scripts/upgrade.sh (+ /ow-sync) so the entry
# points cannot drift. obsidian-workflow OWNS ONLY the marked block below — it injects /
# refreshes that block and NEVER touches any other line the user added. This is
# why a brownfield install no longer clobbers an existing .gitignore.
#
# Scope rule (decided 2026-06-01): the block holds ONLY obsidian-workflow-internal paths
# (config/cache, worktrees, sync/migration backups, local Claude settings).
# Stack/OS/editor ignores (node_modules, dist, .env, .DS_Store, .vscode, …) are
# the host project's responsibility — obsidian-workflow does not impose them.
#
# Portable: bash 3.2 + BSD userland (awk-based rewrite, no `sed -i`).
#
# API:
#   ow_gitignore_block               → print the managed block (with markers)
#   ow_gitignore_merge <path>        → idempotently inject/refresh the block

OW_GI_START='# >>> obsidian-workflow managed (auto-updated by install/upgrade — do not edit inside) >>>'
OW_GI_END='# <<< obsidian-workflow managed end <<<'

# Emit the canonical managed block, markers included. ONE definition — both
# install and upgrade read this, so the shipped block can never diverge.
ow_gitignore_block() {
  printf '%s\n' "$OW_GI_START"
  printf '%s\n' \
    "# Per-machine runtime state (resolver env cache, install markers) — never commit" \
    ".ow/local/" \
    ".ow/cache/" \
    ".ow.cache/" \
    ".ow/.last-sync" \
    "# Worktree staging — isolated git worktrees for /ow-fix-issue + plan→implement→test --worktree" \
    "worktrees/" \
    "# Sync/migration backups" \
    "*.md.new" \
    "*.md.bak" \
    "*.md.orig" \
    "# upgrade/rollback safety backups (auto-pruned to latest by scripts/upgrade.sh)" \
    ".ow.backup-*/" \
    "# pre-rollback snapshot — the only copy of anything written after the last upgrade" \
    ".ow.rollback-*/" \
    "# install/adopt safety backups (pre-overwrite copies written by scripts/install.sh)" \
    ".ow/backups/" \
    "# Local Claude settings (per-machine)" \
    ".claude/settings.local.json"
  printf '%s\n' "$OW_GI_END"
}

# Idempotent merge of the managed block into <gitignore_path>:
#   • file absent     → create it containing only the block
#   • markers present → replace the marked region in place (user lines untouched)
#   • markers absent   → append the block, preserving everything already there
# Returns 0 always; prints nothing (callers log their own status).
ow_gitignore_merge() {
  local gi="$1"
  local tmpblock; tmpblock="$(mktemp)"
  ow_gitignore_block > "$tmpblock"

  if [ ! -f "$gi" ]; then
    cp "$tmpblock" "$gi"; rm -f "$tmpblock"; return 0
  fi

  if grep -qF "$OW_GI_START" "$gi" 2>/dev/null; then
    # Replace the marked region (start..end inclusive) with the fresh block.
    # The block is fed via a temp FILE (read with getline), not `awk -v` — BSD awk
    # rejects literal newlines in a -v value, which would silently no-op the refresh.
    # Markers are matched by exact line equality so user content can never collide.
    awk -v start="$OW_GI_START" -v end="$OW_GI_END" -v bf="$tmpblock" '
      $0 == start {
        while ((getline line < bf) > 0) print line
        close(bf)
        skip = 1; next
      }
      skip && $0 == end { skip = 0; next }
      skip { next }
      { print }
    ' "$gi" > "$gi.tmp" && mv "$gi.tmp" "$gi"
  else
    # Append — ensure a blank-line separator if the file does not already end in one.
    if [ -s "$gi" ] && [ -n "$(tail -c1 "$gi" 2>/dev/null)" ]; then
      printf '\n' >> "$gi"
    fi
    printf '\n' >> "$gi"
    cat "$tmpblock" >> "$gi"
  fi
  rm -f "$tmpblock"
  return 0
}
