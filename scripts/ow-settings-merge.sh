#!/usr/bin/env bash
# obsidian-workflow — .claude/settings.json MERGE (canonical definition of what obsidian-workflow owns)
# ─────────────────────────────────────────────────────────────────────────────
# settings.json is TEAM-SHARED and git-tracked: obsidian-workflow must be able to update the
# permission surface it ships, while everything the consumer wrote survives every
# upgrade. A wholesale `cp` cannot do both — it destroys permissions.deny,
# permissions.ask, PreToolUse/PostToolUse hooks, MCP grants and env additions, and a
# file-granularity backup cannot bring back keys obsidian-workflow never authored.
#
# OWNERSHIP — key-granular, not file-granular:
#   obsidian-workflow owns ...... "$schema"                  (seeded when absent)
#                        permissions.allow          (UNION with the consumer's entries)
#                        env.OW_* keys        (retired ones withdrawn)
#   obsidian-workflow preserves . every other key, verbatim and in place — permissions.deny,
#                        permissions.ask, permissions.defaultMode,
#                        permissions.additionalDirectories, hooks, non-OW_* env,
#                        model, statusLine, outputStyle, MCP keys, and any key a
#                        future Claude Code release adds (unknown keys pass through).
#
# permissions.allow is a UNION: a consumer entry is NEVER taken away. The single
# exception is the LEGACY signature — the exact blanket set obsidian-workflow shipped through
# v0.5.1 — replaced wholesale precisely BECAUSE an unmodified list proves the file is
# obsidian-workflow's own and was never curated. A consumer who edited the list keeps it, and
# is warned if a bare "Bash" (auto-approves every shell command) is among it.
#
# Portable: bash 3.2 (no declare -A / mapfile) + BSD userland. JSON handling uses
# python3 — the SAME optional dependency install.sh + upgrade.sh already use for the
# .ow.yml migrations — so no jq requirement is introduced. python3 absent, file
# unparseable, or python failing ⇒ the existing file is LEFT UNCHANGED and a warning
# is printed: degrade, never destroy. Always returns 0 so a `set -e` caller survives.
#
# API:
#   ow_settings_merge <shipped.json> <target.json>   → merge in place; always rc 0

# The blanket allow-list obsidian-workflow shipped through v0.5.1. Retired: a bare "Bash" entry
# auto-approves EVERY shell command, including ones that reach outside the project, and
# it overrides the scoped Bash(...) grants in every .claude/agents/*.md frontmatter.
OW_SETTINGS_LEGACY_ALLOW='Bash Read Edit Write WebFetch'

# env keys obsidian-workflow used to ship and now withdraws, each with the exact value it
# shipped. Withdrawn ONLY when the value still matches — a consumer who changed it
# meant it. Format: key<TAB>shipped-value, one per line.
#   OW_VAULT — read by nothing, and "docs" contradicts vault_path's default
#                    docs/obsidian-vault (.ow.yml:40).
#   OW_ROOT  — "." equals the resolver's own default (ow-paths.sh:44) and, as a
#                    settings.json env value, shadows the `export OW_ROOT=<root>`
#                    recovery path the resolver prints (ow-paths.sh:108).
ow_settings_retired_env() {
  printf '%s\t%s\n' 'OW_VAULT' 'docs'
  printf '%s\t%s\n' 'OW_ROOT' '.'
}

ow_settings_merge() {
  local shipped="$1" target="$2" out
  [ -f "$shipped" ] || return 0

  # No existing file ⇒ nothing to preserve; a plain copy IS the merge.
  if [ ! -f "$target" ]; then
    if mkdir -p "$(dirname "$target")" && cp "$shipped" "$target"; then
      printf '  settings.json: installed (no existing file to merge)\n'
    else
      printf '  settings.json: install FAILED — nothing was written (check permissions and free space)\n' >&2
    fi
    return 0
  fi

  # Byte-identical ⇒ nothing to do (keeps the merge idempotent and quiet).
  cmp -s "$shipped" "$target" && return 0

  if ! command -v python3 >/dev/null 2>&1; then
    printf '  settings.json: python3 not found — LEFT UNCHANGED (never overwritten blind);\n' >&2
    printf '    new obsidian-workflow permission rules were NOT applied. Install python3 and re-run.\n' >&2
    return 0
  fi

  out="$(OW_LEGACY_ALLOW="$OW_SETTINGS_LEGACY_ALLOW" OW_RETIRED_ENV="$(ow_settings_retired_env)" \
    python3 - "$shipped" "$target" <<'PYEOF'
import json, os, sys
ship_p, targ_p = sys.argv[1], sys.argv[2]
legacy = set(os.environ.get("OW_LEGACY_ALLOW", "").split())
retired_env = []
for line in os.environ.get("OW_RETIRED_ENV", "").splitlines():
    if "\t" in line:
        k, v = line.split("\t", 1)
        retired_env.append((k, v))
with open(ship_p) as f: ship = json.load(f)
try:
    with open(targ_p) as f: cur = json.load(f)
except Exception:
    sys.stdout.write("PARSE_FAIL\n"); sys.exit(0)
if not isinstance(cur, dict):
    sys.stdout.write("PARSE_FAIL\n"); sys.exit(0)
notes = []
# $schema — seeded only when absent; a consumer who pinned one keeps it.
if "$schema" not in cur and "$schema" in ship:
    cur["$schema"] = ship["$schema"]; notes.append("seeded $schema")
# permissions.allow — union, with a one-time replacement of the legacy blanket set.
ship_allow = (ship.get("permissions") or {}).get("allow") or []
if ship_allow:
    perms = cur.get("permissions")
    if not isinstance(perms, dict):
        perms = {}; cur["permissions"] = perms
    have = perms.get("allow")
    if not isinstance(have, list): have = []
    if have and set(have) == legacy:
        perms["allow"] = list(ship_allow)
        notes.append("replaced the unmodified legacy blanket allow-list with the scoped set")
    else:
        seen = set(have)
        added = [r for r in ship_allow if r not in seen]
        perms["allow"] = have + added
        if added:
            notes.append("added %d allow rule(s): %s" % (len(added), ", ".join(added)))
        if "Bash" in perms["allow"]:
            notes.append("KEPT your own bare \"Bash\" allow - it auto-approves EVERY shell command; consider scoped Bash(...) rules")
# env — withdraw retired OW_* keys still holding the value obsidian-workflow shipped.
env = cur.get("env")
if isinstance(env, dict):
    for k, v in retired_env:
        if k in env and env[k] == v:
            del env[k]; notes.append("removed dead env.%s" % k)
    if not env:
        del cur["env"]; notes.append("removed the now-empty env block")
tmp = targ_p + ".tmp"
with open(tmp, "w") as f:
    json.dump(cur, f, indent=2, ensure_ascii=False); f.write("\n")
os.replace(tmp, targ_p)
for n in notes: sys.stdout.write("NOTE\t" + n + "\n")
PYEOF
  )" || { printf '  settings.json: merge failed — LEFT UNCHANGED\n' >&2; return 0; }

  case "$out" in
    *PARSE_FAIL*) printf '  settings.json: not valid JSON — LEFT UNCHANGED (fix it, then re-run)\n' >&2; return 0 ;;
  esac

  printf '%s\n' "$out" | while IFS="$(printf '\t')" read -r tag note; do
    [ "$tag" = "NOTE" ] || continue
    printf '  settings.json: %s\n' "$note"
  done
  return 0
}
