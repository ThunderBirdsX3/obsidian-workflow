#!/usr/bin/env bash
# obsidian-workflow — canonical OWNED-FILES manifest (single source of truth)
# ─────────────────────────────────────────────────────────────────────────────
# The files obsidian-workflow ships into a consumer project under scripts/ and bin/.
# Sourced by scripts/install.sh + scripts/upgrade.sh so the two entry points can
# never drift on what they install vs. refresh.
#
# WHY THIS EXISTS: scripts/ and bin/ are MIXED-ownership dirs — a host project may
# drop its own custom scripts there. upgrade must therefore refresh ONLY these
# owned files per-file and NEVER `rm -rf scripts/` / `rm -rf bin/`, or a user's
# custom scripts would be destroyed on every upgrade.
#
# API:
#   ow_owned_scripts        → print owned files under scripts/, one per line
#   ow_owned_bin            → print owned files under bin/, one per line
#   ow_source_only_scripts  → scripts that must NEVER live in a consumer (removed
#                              on upgrade if a legacy install left them behind)
#   ow_tombstones           → retired paths, as <path><TAB><since-version><TAB><reason>
#   ow_tombstone_pending V  → the tombstone rows not yet applied on a consumer at
#                              version V (V="0.0.0" / omitted ⇒ every row)

ow_owned_scripts() {
  printf '%s\n' \
    "ow-paths.sh" \
    "ow-safe-paths.sh" \
    "ow-gitignore.sh" \
    "ow-claude-md.sh" \
    "ow-git-sync.sh" \
    "ow-version.sh" \
    "ow-owned.sh" \
    "ow-frontends.sh" \
    "ow-shims.sh" \
    "ow-claude-manifest.sh" \
    "ow-settings-merge.sh" \
    "ow-config-merge.sh" \
    "conformance-lint.sh" \
    "ow-verify-vault-lang.sh" \
    "ow-verify-vault-style.sh" \
    "upgrade.sh"
}

ow_owned_bin() {
  printf '%s\n' \
    "ow"
}

# install.sh / test.sh are obsidian-workflow source-repo tooling — never installed into a
# consumer. Listed so upgrade can clean up a pre-v0.4 install that copied them.
ow_source_only_scripts() {
  printf '%s\n' \
    "install.sh" \
    "test.sh"
}

# ── tombstones: paths obsidian-workflow ONCE owned and must now DELETE ─────────────────
# ow_owned_scripts / ow_owned_bin only describe what to ADD or REFRESH, so deleting a
# name from them leaves the stale file on every consumer forever — v1.3.0 dropped
# ow-rollup.sh and ccusage-daily.sh and both still sit in projects installed before it.
# This list is the retirement record scripts/upgrade.sh acts on.
#
# RELEASE-TIME PROCEDURE — a HUMAN appends here, in the same commit as the deletion.
# Removing a file from ow_owned_scripts / ow_owned_bin ⇒ add exactly one row:
#   field 1  path    repo-relative, and ONLY under scripts/ or bin/ — those are the dirs
#                    --rollback restores per-file, so a path anywhere else would be
#                    deleted with no way back (upgrade.sh refuses such a row).
#   field 2  since   the ow version that SHIPS this row (the release being cut) —
#                    NOT the version that dropped the file. upgrade.sh applies a row only
#                    while the consumer sits BELOW `since`, which is what makes it run
#                    once; a row backdated to the old release would never fire for anyone
#                    already past it.
#   field 3  reason  one line, printed to the user when the file is removed.
# A path listed here must be absent from ow_owned_scripts / ow_owned_bin (scripts/test.sh
# guards both directions), and rows are never deleted — an old consumer may still need one.
#
# upgrade.sh removes a listed file ONLY when it still carries obsidian-workflow's `# obsidian-workflow `
# header signature (line ≤3), and backs it up into .ow.backup-* first.
ow_tombstones() {
  printf '%s\t%s\t%s\n' \
    "scripts/ow-rollup.sh"    "1.0.0" "phase-checkbox rollup for a daily-log set obsidian-workflow does not ship — removed if carried over from an earlier toolkit" \
    "scripts/ccusage-daily.sh" "1.0.0" "ccusage usage-meter wrapper obsidian-workflow does not ship — removed if carried over from an earlier toolkit" \
    "scripts/upload-evidence.sh" "1.0.0" "evidence finalizer for an evidence/upload subsystem obsidian-workflow does not ship — removed if carried over from an earlier toolkit"
}

# Strictly-older dotted-version compare. bash 3.2 + BSD sort (no `sort -V`).
# Each component is reduced to its leading digits FIRST, so a pre-release or build suffix
# ("1.8.1-rc1", "1.9.0+build") compares on its numeric part alone. Without that reduction BSD
# sort falls through to a whole-line tiebreak and "1.8.1-rc1" sorts NEWER than "1.8.1", which
# would silently skip every tombstone on a consumer whose version file carries a suffix — and
# get_ow_spec_ver's legacy fallback reads the HOST project's own VERSION file, where suffixes
# are ordinary. A missing or wholly non-numeric component reduces to 0, which can only make a
# row apply, never skip it.
_ow_ver_lt() {
  local a b lo
  a="$(_ow_ver_norm "$1")"; b="$(_ow_ver_norm "$2")"
  [ "$a" = "$b" ] && return 1
  lo="$(printf '%s\n%s\n' "$a" "$b" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)"
  [ "$lo" = "$a" ]
}

# Reduce a version to exactly three numeric components: strip a leading v, keep only the
# leading digits of each of the first three fields, default a missing field to 0.
_ow_ver_norm() {
  printf '%s' "${1#v}" | awk -F. '{
    for (i = 1; i <= 3; i++) { c = $i; sub(/[^0-9].*$/, "", c); if (c == "") c = 0; printf "%s%s", (i > 1 ? "." : ""), c + 0 }
  }'
}

# Rows whose `since` is NEWER than <current_version> — i.e. not yet applied here. An
# unknown version ("0.0.0", the get_ow_spec_ver fallback) yields every row, which is the
# right default: the header-signature check in upgrade.sh is what keeps that safe.
ow_tombstone_pending() {
  local cur="${1:-0.0.0}" tab
  tab="$(printf '\t')"
  # `|| :` keeps the loop body's status at 0 when a row does NOT apply. Without it the last
  # iteration's false `&&` becomes the pipeline's status, so "nothing pending" — the permanent
  # steady state once a release ships past every `since` — reads as a failure to a `set -e` caller.
  ow_tombstones | while IFS="$tab" read -r _tsp _tsv _tsr; do
    [ -n "$_tsp" ] || continue
    _ow_ver_lt "$cur" "$_tsv" && printf '%s\t%s\t%s\n' "$_tsp" "$_tsv" "$_tsr" || :
  done
  return 0
}
