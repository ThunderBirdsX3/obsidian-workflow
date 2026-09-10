#!/usr/bin/env bash
# obsidian-workflow — canonical CLAUDE.md managed block (single source of truth)
# ─────────────────────────────────────────────────────────────────────────────
# Sourced by scripts/install.sh + scripts/upgrade.sh so the entry points cannot
# drift. obsidian-workflow OWNS ONLY the marked block inside CLAUDE.md — it injects /
# refreshes that block and NEVER touches any other line, so a host project keeps
# its own instructions in the same file, right beside the workflow contract.
#
# The block CONTENT lives in the shipped CLAUDE.md, not in a heredoc here: the
# prose then has exactly ONE copy (the file obsidian-workflow's own authors read), and
# whatever sits OUTSIDE the markers there is source-repo-only — it can never
# reach a consumer, because only the marked span is ever copied.
#
# Markers are matched by PREFIX, never by a full literal line. A full-line match
# turns into a silent no-op the moment the block id changes, and a frozen
# CLAUDE.md on every installed machine is the failure that follows.
#
# Portable: bash 3.2 + BSD userland. The replacement block reaches awk through a
# temp FILE read with getline — BSD awk aborts on a literal newline inside an
# `awk -v` value, so a multi-line -v substitution never runs on macOS.
#
# API:
#   ow_claude_md_block  <src>          → print <src>'s marked block (markers included)
#   ow_claude_md_marker <target>       → print the START marker line <target> carries
#   ow_claude_md_merge  <target> <src> → inject/refresh; echoes created|refreshed|appended
#                                         exit 1 = <src> has no block · exit 2 = <target>
#                                         has a START marker with no END (never guessed) ·
#                                         exit 3 = the write FAILED and <target> is unchanged.
#                                         Every write branch reports 3 rather than its own name:
#                                         a caller that logs success for a write that never
#                                         landed is worse than no merge at all.

OW_CM_START='<!-- OW START: workflow -->'
OW_CM_END='<!-- OW END: workflow -->'
OW_CM_START_PREFIX='<!-- OW START'
OW_CM_END_PREFIX='<!-- OW END'

# Print the marked block of <src>, markers included. Exit 1 when the block is
# absent or unterminated — fail-closed, so no caller writes half a block over a
# host's file.
ow_claude_md_block() {
  local src="$1"
  [ -f "$src" ] || return 1
  awk -v s="$OW_CM_START_PREFIX" -v e="$OW_CM_END_PREFIX" '
    index($0, s) == 1        { inb = 1 }
    inb                      { print }
    inb && index($0, e) == 1 { seen = 1; exit }
    END { exit (seen ? 0 : 1) }
  ' "$src"
}

# Print the START marker line <target> actually carries (empty when none), so a
# caller can tell a current block from an older, narrower one.
ow_claude_md_marker() {
  [ -f "$1" ] || return 0
  awk -v s="$OW_CM_START_PREFIX" 'index($0, s) == 1 { print; exit }' "$1" 2>/dev/null
}

# True when <target> has BOTH a START and a following END marker, i.e. a span the
# refresh can replace without swallowing the rest of the file.
_ow_cm_has_span() {
  [ -f "$1" ] || return 1
  awk -v s="$OW_CM_START_PREFIX" -v e="$OW_CM_END_PREFIX" '
    index($0, s) == 1        { inb = 1; next }
    inb && index($0, e) == 1 { seen = 1; exit }
    END { exit (seen ? 0 : 1) }
  ' "$1"
}

# Idempotent merge of <src>'s block into <target>:
#   • <src> has no block          → nothing written, exit 1
#   • target absent               → create it containing only the block
#   • target has a complete span  → replace that span (every other line untouched)
#   • target has no marker at all → append the block, preserving what is there
#   • target has START but no END → nothing written, exit 2 (never guess a span)
# Echoes created|refreshed|appended so the caller can log precisely.
ow_claude_md_merge() {
  local target="$1" src="$2" _cm_failed=0
  local tmpblock; tmpblock="$(mktemp)"
  if ! ow_claude_md_block "$src" > "$tmpblock" || [ ! -s "$tmpblock" ]; then
    rm -f "$tmpblock"; return 1
  fi

  if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")" && cp "$tmpblock" "$target" || _cm_failed=1
    rm -f "$tmpblock"
    [ "$_cm_failed" = 1 ] && return 3
    printf 'created\n'; return 0
  fi

  if _ow_cm_has_span "$target"; then
    # Replace the marked region (start..end inclusive) with the fresh block. The
    # scratch file is *.md.new — already covered by the managed .gitignore block,
    # so a failed rewrite never pollutes git status.
    awk -v s="$OW_CM_START_PREFIX" -v e="$OW_CM_END_PREFIX" -v bf="$tmpblock" '
      index($0, s) == 1 {
        while ((getline line < bf) > 0) print line
        close(bf)
        skip = 1; next
      }
      skip && index($0, e) == 1 { skip = 0; next }
      skip { next }
      { print }
    ' "$target" > "$target.new" && mv "$target.new" "$target" || _cm_failed=1
    rm -f "$tmpblock" "$target.new"
    # A failed awk or mv leaves <target> exactly as it was; saying "refreshed" there would
    # report a change that never happened, and both callers print a success line from it.
    [ "$_cm_failed" = 1 ] && return 3
    printf 'refreshed\n'; return 0
  fi

  if [ -n "$(ow_claude_md_marker "$target")" ]; then
    rm -f "$tmpblock"; return 2
  fi

  # Append — every line the host already wrote stays exactly where it is.
  {
    if [ -s "$target" ] && [ -n "$(tail -c1 "$target" 2>/dev/null)" ]; then
      printf '\n' >> "$target"
    fi
    printf '\n' >> "$target" && cat "$tmpblock" >> "$target"
  } || _cm_failed=1
  rm -f "$tmpblock"
  [ "$_cm_failed" = 1 ] && return 3
  printf 'appended\n'; return 0
}
