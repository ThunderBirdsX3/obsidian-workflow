#!/usr/bin/env bash
# obsidian-workflow — canonical PROTECTED / SAFE_PATHS set (single source of truth)
# ─────────────────────────────────────────────────────────────────────────────
# Sourced by scripts/upgrade.sh + scripts/install.sh (+ any future sync path) so
# the entry points cannot drift. Nothing that IS — or is nested under — one of
# these may ever be deleted or overwritten by upgrade/sync/install. Encodes epic
# constraint (b): config, project rules, override layers, the host project's own
# root VERSION, and the test-credentials env file are sacrosanct.
#
# Portable: bash 3.2 (no mapfile/readarray) + BSD userland (no `realpath -m`).
# Path comparison is lexical (entries are simple repo-relative paths), so it needs
# no filesystem access and works before a project is fully installed.
#
# API:
#   ow_safe_paths [env_file]          → print the protected set, one path per line
#   ow_path_is_safe <cand> <safe...>  → exit 0 if <cand> must NOT be wholesale-replaced
#   ow_nested_safe_subpaths <cand> <safe...> → print safe paths strictly nested under <cand>

# Lexical normalize: drop leading "./", collapse "//", strip trailing "/".
# (No ".." handling — the protected/replace sets are all simple relative names.)
_bsp_norm() {
  local p="${1#./}"
  while [ "$p" != "${p//\/\//\/}" ]; do p="${p//\/\//\/}"; done
  printf '%s' "${p%/}"
}

# Canonical protected set. Optional arg = the test-credentials env file (from
# ow-paths.sh TEST_ENV_FILE); when non-empty it joins the set so a project can
# relocate its credentials env file without losing protection.
ow_safe_paths() {
  local secrets="${1:-}"
  # NOTE: keep this list as the ONE definition. upgrade.sh + install.sh both read it.
  # "Protected" means NEVER WHOLESALE-REPLACED. It does not freeze a file that carries a
  # obsidian-workflow managed block: CLAUDE.md keeps its marked block refreshed by install/upgrade
  # (scripts/ow-claude-md.sh) while every line the host wrote outside the markers stays.
  printf '%s\n' \
    ".ow.yml" \
    ".ow/rules" \
    ".ow/local" \
    "commands" \
    "templates" \
    "docs" \
    "VERSION" \
    "CLAUDE.md" \
    "AGENTS.md" \
    "AI-README.md" \
    "README.md"
  [ -n "$secrets" ] && printf '%s\n' "$(_bsp_norm "$secrets")"
  return 0
}

# True (exit 0) when <cand> must NOT be wholesale-replaced because it IS a safe
# path or is nested UNDER one — the caller should skip it entirely.
# The reverse direction (a safe path nested under <cand>, i.e. an overlap) is NOT
# a skip: the caller replaces <cand> but preserves the sub-paths reported by
# ow_nested_safe_subpaths. Keeping the two directions separate is what lets a
# wholesale-replaced dir keep a user file nested inside it while updating siblings.
ow_path_is_safe() {
  local cand; cand="$(_bsp_norm "$1")"; shift
  local s n
  for s in "$@"; do
    n="$(_bsp_norm "$s")"
    [ -z "$n" ] && continue
    case "$cand/" in "$n/"*) return 0 ;; esac   # cand == safe OR nested under safe
  done
  return 1
}

# Print every safe path STRICTLY nested under <cand> (so a caller doing a wholesale
# replace of <cand> can stash+restore these and keep the user's files intact).
ow_nested_safe_subpaths() {
  local cand; cand="$(_bsp_norm "$1")"; shift
  local s n
  for s in "$@"; do
    n="$(_bsp_norm "$s")"
    [ -z "$n" ] && continue
    [ "$n" = "$cand" ] && continue
    case "$n/" in "$cand/"*) printf '%s\n' "$n" ;; esac
  done
}
