#!/usr/bin/env bash
# obsidian-workflow upgrade — bump obsidian-workflow itself (commands/scripts/standards skeleton)
#                    keeps templates/, docs/, .ow.yml safe
#
# OW-UPGRADE-HANDOFF-CONTRACT: v1
#   Re-exec-safe self-update: an older installed bootstrap fetches the new version, then
#   `exec`s THIS staged script with OW_UPGRADE_HANDOFF=1, the consumer root in
#   OW_UPGRADE_ROOT, and the fetched tree in OW_UPGRADE_STAGE. Because the staged copy
#   sources its OWN helpers (SCRIPT_DIR = stage/scripts), the NEWEST migration logic always
#   runs in ONE pass — no "run upgrade twice" to pick up new config blocks / knobs / shim
#   fields / steps. A staged version missing this marker → bootstrap falls back to a legacy
#   in-place upgrade (the one-time transition cost when adopting this contract).
#
# Usage:
#   bash scripts/upgrade.sh                  # pull latest from configured source
#   bash scripts/upgrade.sh --source <path>  # use local checkout
#   bash scripts/upgrade.sh --version <tag>  # pin to specific version
#   bash scripts/upgrade.sh --dry-run        # show diff, don't apply
#   bash scripts/upgrade.sh --rollback       # restore from last backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When re-exec'd by an older bootstrap (handoff), SCRIPT_DIR points at the STAGED tree — so the
# `. "$SCRIPT_DIR/ow-*.sh"` sources below load the NEW migration logic automatically — while the
# consumer project to upgrade is passed in via OW_UPGRADE_ROOT. Normal run: root = parent dir.
ROOT="${OW_UPGRADE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
cd "$ROOT"

# Load config (best-effort — resolver may fail-closed if yq absent; SECRETS_FILE
# is used only to extend the protected set, so a miss just omits that one entry)
eval "$(bash "$SCRIPT_DIR/ow-paths.sh" --shell)" 2>/dev/null || true

# Canonical protected/SAFE_PATHS set — shared with install.sh (single source of truth)
. "$SCRIPT_DIR/ow-safe-paths.sh"
# .claude/ ownership manifest + shim generator — shared with install.sh (#3/#8)
. "$SCRIPT_DIR/ow-claude-manifest.sh"
# Canonical AI front-end registry — shared with install.sh (single source of truth).
# Every AI-list below derives from it; hardcoded copies are how gpt/glm silently fell
# out of the diff report and the /ow-sync protected set.
. "$SCRIPT_DIR/ow-frontends.sh"
# additive .ow.yml block merge (backfills new config blocks, preserves user values)
. "$SCRIPT_DIR/ow-config-merge.sh"
# Canonical .gitignore managed-block — shared with install.sh (single source of truth)
[ -f "$SCRIPT_DIR/ow-gitignore.sh" ] && . "$SCRIPT_DIR/ow-gitignore.sh"

SOURCE="${OW_SOURCE:-https://github.com/ThunderBirdsX3/obsidian-workflow.git}"
VERSION="main"
DRY_RUN=0
ROLLBACK=0
ORIGINAL_ARGS=("$@")   # preserved verbatim → forwarded to the staged upgrader on handoff

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── colors ──
c_bold='\033[1m'; c_reset='\033[0m'
c_blue='\033[34m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'
log()  { printf "${c_blue}[upgrade]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}  ⚠${c_reset} %s\n" "$*" >&2; }
err()  { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }

# ── rollback ──
# Wholesale-owned paths — safe to rm -rf + restore (obsidian-workflow owns the whole dir/file).
# scripts/ and bin/ are NOT here: they are mixed-ownership, restored PER-FILE below so
# a host's custom scripts (never backed up because never touched) are not wiped.
ROLLBACK_PATHS=(
  .ow/commands .claude/commands .claude/agents .claude/settings.json
  .ow/templates
  # retired paths — listed so a --rollback after the removal migration puts them back
  .ow/workflows
  .ow/STANDARD.md .ow/UPDATE-POLICY.md .ow/VERSION
  .ow/policies .ow/checklists .ow/agents
  .ow.local.yml.example
  .ow.local.yml             # restored only if backed up (= local-config backfill ran); SAFE_PATHS otherwise untouched
  .ow.yml                   # restored only if backed up (= version bump / config backfill ran)
  VERSION                         # host project's own root VERSION (backed up before any migration; see #2)
  CLAUDE.md                       # restored only if backed up (= the managed block was merged); the host's prose outside the markers rides along
)
# AI front-end assets — restored only if backed up (i.e. were refreshed). Derived from
# the registry so a newly registered front-end is rollback-safe with no edit here.
# Excluded: .claude (its owned subpaths are listed above) and AGENTS.md, which upgrade
# never overwrites. CLAUDE.md is listed above instead: upgrade rewrites its managed block,
# so a --rollback has to be able to restore the pre-upgrade file exactly.
while IFS= read -r _aip; do
  case "$_aip" in
    .claude|CLAUDE.md|AGENTS.md|"") continue ;;
  esac
  ROLLBACK_PATHS+=("$_aip")
done < <(ow_frontend_all_paths)
if [ "$ROLLBACK" -eq 1 ]; then
  latest_backup=$(ls -td .ow.backup-* 2>/dev/null | head -1 || true)
  [ -z "$latest_backup" ] && { err "No backup found"; exit 1; }
  log "Rolling back from: $latest_backup"
  # Snapshot the CURRENT tree first. The restore below is a wholesale `rm -rf` + `cp -R` of
  # each rollback path, which is right for "return to the pre-upgrade state" — but anything
  # written AFTER that backup was taken is not in it: an agent from `/ow-agent create`, a
  # body from `enable`, the project's own slash command, a hook added to settings.json, a
  # paragraph added to CLAUDE.md. Without this snapshot those are destroyed with no copy
  # anywhere. Rollback must be reversible too, or it is just a second way to lose work.
  rb_snapshot=".ow.rollback-$(date +%Y%m%d-%H%M%S)"
  rb_saved=0
  for item in "${ROLLBACK_PATHS[@]}"; do
    [ -e "./$item" ] || continue
    mkdir -p "$rb_snapshot/$(dirname "$item")"
    cp -R "./$item" "$rb_snapshot/$item" 2>/dev/null && rb_saved=$((rb_saved+1))
  done
  if [ "$rb_saved" -gt 0 ]; then
    ok "Saved the current state of $rb_saved path(s) → $rb_snapshot (anything written since the upgrade lives only here)"
  else
    rm -rf "$rb_snapshot"
  fi
  restored=0
  for item in "${ROLLBACK_PATHS[@]}"; do
    if [ -e "$latest_backup/$item" ]; then
      rm -rf "./$item"
      mkdir -p "$(dirname "./$item")"
      cp -R "$latest_backup/$item" "./$item"
      ok "Restored: $item"
      restored=$((restored+1))
    fi
  done
  # scripts/ + bin/ — per-file restore (overwrite only what was backed up; leave custom files)
  for d in scripts bin; do
    [ -d "$latest_backup/$d" ] || continue
    for f in "$latest_backup/$d"/*; do
      [ -f "$f" ] || continue
      mkdir -p "$d"; cp "$f" "$d/$(basename "$f")"
      ok "Restored: $d/$(basename "$f")"; restored=$((restored+1))
    done
  done
  [ "$restored" -eq 0 ] && warn "Backup empty/incompatible — nothing restored"
  ok "Rollback complete from $latest_backup ($restored items)"
  [ "$rb_saved" -gt 0 ] && log "Pre-rollback state kept at $rb_snapshot — recover anything the rollback undid from there, then delete it"
  exit 0
fi

# ── pre-flight ──
# obsidian-workflow own version lives in .ow.yml (v0.4+); fallback chain for legacy installs
get_ow_spec_ver() {
  local f="$1"
  if [ -f "$f/.ow.yml" ]; then
    # Simple grep: ow.version key (v0.4+)
    local v
    v=$(awk '/^ow:/{in_b=1;next} /^[a-zA-Z_]/{in_b=0} in_b && /^  version:/{gsub(/^[^"]*"|"[^"]*$/,""); print; exit}' "$f/.ow.yml" 2>/dev/null)
    [ -n "$v" ] && echo "$v" && return
  fi
  # Legacy fallbacks
  [ -f "$f/.ow/VERSION" ] && cat "$f/.ow/VERSION" 2>/dev/null && return  # v0.4-intermediate
  [ -f "$f/VERSION" ] && cat "$f/VERSION" 2>/dev/null && return                       # pre-v0.4
  echo "0.0.0"
}
current_version=$(get_ow_spec_ver "$ROOT")
log "Current ow version: $current_version"

# ── fetch helper (used only by the bootstrap branch below) ──
fetch_into_stage() {
  local dest="$1"
  if [ -d "$SOURCE" ]; then
    log "Using local source"
    cp -R "$SOURCE/." "$dest/"
  elif [[ "$SOURCE" =~ ^https?:// ]]; then
    log "Cloning $SOURCE @ $VERSION"
    command -v git >/dev/null || { err "git not found"; exit 1; }
    git clone --depth 1 --branch "$VERSION" "$SOURCE" "$dest" >/dev/null 2>&1
  else
    err "Invalid source: $SOURCE"; exit 1
  fi
}

# ── re-exec handoff (Tier 2 — see OW-UPGRADE-HANDOFF-CONTRACT in the header) ──
# Root cause this fixes: the installed (possibly OLD) upgrade.sh must not run OLD migration
# logic against NEW content (config backfill, per-agent/command shim fields, safe-paths set,
# nested-knob registry, brand-new steps). So the bootstrap fetches the target, then re-execs
# the STAGED (NEW) upgrade.sh, which sources its OWN new helpers and applies to the consumer
# ROOT passed via env. Net effect: the newest migration logic always runs — a single pass.
if [ "${OW_UPGRADE_HANDOFF:-0}" = "1" ]; then
  # ── worker ── we ARE the handed-off NEW upgrader, executing from the staged tree.
  # SCRIPT_DIR=stage/scripts ⇒ the helpers sourced at the top are already the new ones.
  STAGE="${OW_UPGRADE_STAGE:?OW_UPGRADE_STAGE missing in handoff}"
  trap 'rm -rf "$STAGE"' EXIT
  new_version=$(get_ow_spec_ver "$STAGE")
  log "Staged upgrader active (v$new_version) — applying to $ROOT"
else
  # ── bootstrap ── possibly an OLD installed copy. Fetch, then hand off to the staged
  # upgrader if it understands the contract; otherwise fall through to legacy in-place.
  log "Source:  $SOURCE"
  log "Target:  $VERSION"
  STAGE=$(mktemp -d -t obsidian-workflow-upgrade-XXXXXX)
  fetch_into_stage "$STAGE"
  new_version=$(get_ow_spec_ver "$STAGE")
  if grep -q 'OW-UPGRADE-HANDOFF-CONTRACT' "$STAGE/scripts/upgrade.sh" 2>/dev/null; then
    log "New version: $new_version — handing off to staged upgrader (newest migration logic runs)"
    export OW_UPGRADE_HANDOFF=1 OW_UPGRADE_STAGE="$STAGE" OW_UPGRADE_ROOT="$ROOT"
    # `exec` overlays this process, so its EXIT handling is bypassed and STAGE survives for the
    # worker (which adopts it + sets its own cleanup trap). No trap is set on this path.
    exec bash "$STAGE/scripts/upgrade.sh" ${ORIGINAL_ARGS[@]+"${ORIGINAL_ARGS[@]}"}
    err "Handoff exec failed"; exit 1
  fi
  # Staged version predates the contract (e.g. --version pinned to an old tag): legacy path —
  # this OLD in-process logic is the best we can do, and this process owns STAGE cleanup.
  trap 'rm -rf "$STAGE"' EXIT
  warn "Staged v$new_version predates the handoff contract — running legacy in-place upgrade"
fi

# Owned-file manifest — sourced from the freshly staged template (the consumer's
# own scripts/ may predate it on the first upgrade to a version that ships it).
[ -f "$STAGE/scripts/ow-owned.sh" ] && . "$STAGE/scripts/ow-owned.sh"

# .claude/settings.json owned-key merge — sourced from the STAGED template for the same
# reason as the manifest above: on the first upgrade to a version that ships it, the
# consumer's own scripts/ does not have it yet.
[ -f "$STAGE/scripts/ow-settings-merge.sh" ] && . "$STAGE/scripts/ow-settings-merge.sh"

# .claude/ ownership manifest + shim emitters — RE-sourced from the STAGED template for
# the same reason: the copy loaded at the top came from the consumer's own scripts/, i.e.
# the version being replaced, so a helper introduced by THIS release would be missing for
# one more cycle and every `command -v`-guarded path would skip in silence.
[ -f "$STAGE/scripts/ow-claude-manifest.sh" ] && . "$STAGE/scripts/ow-claude-manifest.sh"


# ── diff ──
log "Computing diff..."
DIFF_REPORT=$(mktemp)
{
  # AI front-end dirs come from the registry — the old literal listed only
  # `codex gemini prompts`, so gpt/ and glm/ changes never showed up in the report.
  _diff_ai=""
  while IFS= read -r _aip; do
    case "$_aip" in .claude|CLAUDE.md|AGENTS.md|"") continue ;; esac
    _diff_ai="$_diff_ai $_aip"
  done < <(ow_frontend_all_paths)
  # shellcheck disable=SC2086
  for item in .ow/commands .claude/commands .claude/agents .ow/templates scripts bin $_diff_ai; do
    if [ -d "$STAGE/$item" ]; then
      if [ -d "./$item" ]; then
        diff -rq "./$item" "$STAGE/$item" 2>/dev/null || true
      else
        echo "Only in $STAGE/$item: (new directory)"
      fi
    fi
  done
} > "$DIFF_REPORT"

diff_lines=$(wc -l < "$DIFF_REPORT")
log "Diff: $diff_lines changes"
head -20 "$DIFF_REPORT" | sed 's/^/  /'

# ── safe paths ──
# Canonical protected set (single source of truth in scripts/ow-safe-paths.sh).
# Now ENFORCED in the apply loop below (was previously logged-only). Adds the
# epic-required entries over the old list: .ow/rules, root VERSION, and the
# configured secrets env file.
SAFE_PATHS=()
while IFS= read -r _sp; do [ -n "$_sp" ] && SAFE_PATHS+=("$_sp"); done < <(ow_safe_paths "${SECRETS_FILE:-}")
log "Safe paths (protected — never replaced): ${SAFE_PATHS[*]}"

# Paths that GET replaced wholesale (v0.4.1 layout — all obsidian-workflow machinery under .ow/):
# NOTE: .claude/commands + .claude/agents are NOT here — they are handled by a per-file
# SELECTIVE MERGE after apply (#3) so user settings/hooks/MCP perms/project-enabled
# agents survive. Wholesale rm -rf of those dirs is forbidden.
REPLACE_PATHS=(
  .ow/commands            # was: root commands/ (pre-v0.4.1)
  .ow/templates
  .ow.local.yml.example   # shipped reference template (owned). The real .ow.local.yml
                                # is protected via SAFE_PATHS — only the .example is refreshed, so
                                # config-schema cleanups reach existing projects on upgrade.
)
# NOTE: scripts/ + bin/ are NOT here — mixed-ownership dirs refreshed PER-FILE from the
# owned-file manifest (ow-owned.sh) so a host's custom scripts survive.
# NOTE: AI frontend dirs (codex/gemini/gpt/glm) are NOT here either — they are refreshed
# ONLY for the AIs this project actually enabled (ai_agents in .ow.yml), so a
# claude-only project never gets other-AI folders dropped in on upgrade. The shared
# per-KIND assets — prompts/ (router) and .agents/ (skills) — are MIXED ownership and
# stay out of that wholesale refresh too; they are backfilled/regenerated per-file.

# Enabled-AI → frontend-dir mapping. Reads ai_agents from .ow.yml (authoritative);
# when that key is absent (legacy install) it falls back to whatever AI dirs already exist.
# claude is intentionally NOT mapped here — its .claude/ is handled by the selective merge.
# Router front-ends enabled for this project. The prompts/ backfill is gated on this, and so
# is its --dry-run preview — one definition, so the preview cannot promise work the apply path
# skips. Same two-branch shape as ai_frontend_dirs() below (registry-driven, legacy fallback).
router_frontends() {
  local out="" ai
  if grep -q '^ai_agents:' .ow.yml 2>/dev/null; then
    while IFS= read -r ai; do
      [ -n "$ai" ] || continue
      [ "$(ow_frontend_kind "$ai")" = router ] || continue
      out="$out $ai"
    done < <(yq '.ai_agents[]' .ow.yml 2>/dev/null | tr -d '"')
  else
    for ai in $(ow_frontends); do
      [ "$(ow_frontend_kind "$ai")" = router ] || continue
      [ -d "$(ow_frontend_folder "$ai")" ] || continue
      out="$out $ai"
    done
  fi
  echo "$out"
}

ai_frontend_dirs() {
  local dirs="" ai
  if grep -q '^ai_agents:' .ow.yml 2>/dev/null; then
    # Registry-driven: a front-end's OWN folder only. The shared assets of a kind
    # (router → prompts/, skills → .agents/) are MIXED ownership — a team edits the
    # paste material in place and keeps its own skills beside the generated ones — so
    # they are excluded here and handled per-file after this loop. claude is handled by
    # the .claude selective merge, and the protected root entry points are never refreshed.
    while IFS= read -r ai; do
      [ -n "$ai" ] || continue
      while IFS= read -r p; do
        case "$p" in .claude|CLAUDE.md|AGENTS.md|.agents|prompts|"") continue ;; esac
        case " $dirs " in *" $p "*) continue ;; esac
        dirs="$dirs $p"
      done < <(ow_frontend_paths "$ai")
    done < <(yq '.ai_agents[]' .ow.yml 2>/dev/null | tr -d '"')
  else
    # Legacy (no ai_agents key) — refresh the front-end dirs already present.
    while IFS= read -r p; do
      case "$p" in .claude|CLAUDE.md|AGENTS.md|.agents|prompts|"") continue ;; esac
      case " $dirs " in *" $p "*) continue ;; esac
      [ -d "$p" ] && dirs="$dirs $p"
    done < <(ow_frontend_all_paths)
  fi
  echo "$dirs"
}
# claude enabled? (drives whether the .claude/ selective merge runs). Legacy / an
# existing .claude/ counts as enabled so we never stop refreshing what's already there.
claude_is_enabled() {
  if grep -q '^ai_agents:' .ow.yml 2>/dev/null; then
    yq '.ai_agents[]' .ow.yml 2>/dev/null | tr -d '"' | grep -qx claude && return 0
    [ -d .claude ] && return 0
    return 1
  fi
  return 0
}

# ── dry-run ──
if [ "$DRY_RUN" -eq 1 ]; then
  log "Dry-run — no changes will be applied"
  for p in "${REPLACE_PATHS[@]}"; do
    if [ -e "$STAGE/$p" ]; then
      printf "  would replace: %s\n" "$p"
    fi
  done
  if claude_is_enabled; then
    printf "  would selectively merge: .claude/commands (regenerated shims + prune shims of removed commands), .claude/agents (always-on only: %s), .claude/settings.json (owned keys merged: \$schema + permissions.allow + env.OW_*; your hooks/deny/ask/env kept)\n" "$OW_ALWAYS_ON_AGENTS"
  else
    printf "  would SKIP .claude/ (claude not in ai_agents)\n"
  fi
  _aid="$(ai_frontend_dirs)"
  printf "  would refresh AI frontends (enabled only):%s\n" "${_aid:-  (none — claude-only)}"
  if [ -n "$(router_frontends | tr -d ' ')" ] && [ -d "$STAGE/prompts" ]; then
    printf "  would backfill NEW files into prompts/ only — an existing file is never overwritten (same rule as install.sh + /ow-sync)\n"
  else
    if [ -d "$STAGE/prompts" ]; then
      printf "  would not touch prompts/ (no router front-end enabled)\n"
    else
      printf "  would not touch prompts/ (the staged release ships none)\n"
    fi
  fi
  if command -v ow_owned_scripts >/dev/null 2>&1; then
    printf "  would refresh per-file (owned only): scripts/{%s}, bin/{%s}\n" \
      "$(ow_owned_scripts | tr '\n' ',' | sed 's/,$//')" "$(ow_owned_bin | tr '\n' ',' | sed 's/,$//')"
  fi
  if command -v ow_tombstone_pending >/dev/null 2>&1; then
    # Run the applier's OWN filters, not just the version gate: a path must be on disk, live
    # under scripts/ or bin/, and still carry obsidian-workflow's header signature. Anything else the
    # real run keeps — and a preview saying "signature-checked" without checking the signature
    # is the same false claim in the one output whose whole job is to state what will happen.
    _tp_list=""; _tp_kept=""
    while IFS= read -r _tp; do
      [ -n "$_tp" ] || continue
      case "$_tp" in scripts/*|bin/*) ;; *) _tp_kept="$_tp_kept $_tp(not-scripts/bin)"; continue ;; esac
      [ -f "$_tp" ] || continue
      if head -3 "$_tp" | grep -c '^# obsidian-workflow ' >/dev/null; then
        _tp_list="$_tp_list $_tp"
      else
        _tp_kept="$_tp_kept $_tp(no-signature)"
      fi
    done < <(ow_tombstone_pending "$current_version" | cut -f1)
    _tp_list="${_tp_list# }"; _tp_kept="${_tp_kept# }"
    [ -n "$_tp_kept" ] && printf "  would KEEP (tombstoned but not obsidian-workflow's): %s\n" "$_tp_kept"
    [ -n "$_tp_list" ] \
      && printf "  would retire (obsidian-workflow no longer owns, signature-checked): %s\n" "$_tp_list" \
      || printf "  no tombstoned file to retire (rows pending for v%s: %s)\n" \
           "$current_version" "$(ow_tombstone_pending "$current_version" | wc -l | tr -d ' ')"
  fi
  if [ -f .ow.yml ] && [ -f "$STAGE/.ow.yml" ] && command -v merge_config_blocks >/dev/null 2>&1; then
    # preview against a COPY so the real .ow.yml is untouched in dry-run
    _tmp_cfg="$(mktemp)"; cp .ow.yml "$_tmp_cfg"
    _miss="$(merge_config_blocks "$_tmp_cfg" "$STAGE/.ow.yml")"; rm -f "$_tmp_cfg"
    [ -n "$_miss" ] && printf "  would backfill .ow.yml blocks (values preserved):\n%s\n" "$_miss" \
      || printf "  .ow.yml — no new config blocks to backfill\n"
  fi
  if [ -e .ow/agents ] && command -v _ow_ver_lt >/dev/null 2>&1 \
     && _ow_ver_lt "$current_version" "1.10.0"; then
    printf "  would RETIRE .ow/agents/ (specialized bodies now come from /ow-agent create) — backed up, rollback-able\n"
  fi
  printf "  would preserve: .claude/settings.local.json, hooks, MCP perms, project-enabled agents, custom scripts/ + bin/ files, non-enabled AI dirs\n"
  exit 0
fi

# ── backup ──
BACKUP_DIR=".ow.backup-$(date +%Y%m%d-%H%M%S)"
log "Creating backup: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
backed_up=0
for p in "${REPLACE_PATHS[@]}"; do
  if [ -e "$p" ]; then
    # Preserve relative path under BACKUP_DIR (mkdir parent first — fixes nested paths like .ow/commands)
    dest="$BACKUP_DIR/$p"
    mkdir -p "$(dirname "$dest")"
    cp -R "$p" "$dest" && backed_up=$((backed_up+1))
  fi
done
# Back up .ow.yml + .ow.local.yml PRISTINE (before the config-block backfills below)
# so --rollback restores the exact pre-upgrade config. Both are otherwise protected/untouched.
if [ -f .ow.yml ]; then cp .ow.yml "$BACKUP_DIR/.ow.yml" && backed_up=$((backed_up+1)); fi
if [ -f .ow.local.yml ]; then cp .ow.local.yml "$BACKUP_DIR/.ow.local.yml" && backed_up=$((backed_up+1)); fi
# CLAUDE.md is SAFE_PATHS (never wholesale-replaced) but its managed block IS rewritten
# below — back it up pristine so --rollback restores the host's file exactly as it was.
if [ -f CLAUDE.md ]; then cp CLAUDE.md "$BACKUP_DIR/CLAUDE.md" && backed_up=$((backed_up+1)); fi
ok "Backup: $BACKUP_DIR ($backed_up items)"

# ── apply ──
log "Applying upgrade..."
for p in "${REPLACE_PATHS[@]}"; do
  if [ -e "$STAGE/$p" ]; then
    # ENFORCE protected set: never wholesale-replace a path that IS or is nested
    # under a SAFE_PATHS member (realpath-prefix containment, not exact-string).
    if ow_path_is_safe "$p" "${SAFE_PATHS[@]}"; then
      warn "Protected — skipped (user-owned): $p"
      continue
    fi
    # Ensure parent dir exists (needed for nested paths like .ow/standards)
    parent="$(dirname "./$p")"
    [ -d "$parent" ] || mkdir -p "$parent"
    if [ -d "$STAGE/$p" ]; then
      # Overlap case: a SAFE_PATHS entry nested UNDER this dir must survive the
      # wholesale replace — stash it, replace, then restore over the fresh copy.
      _preserve=""
      while IFS= read -r sub; do
        [ -n "$sub" ] && [ -e "./$sub" ] || continue
        [ -n "$_preserve" ] || _preserve="$(mktemp -d)"
        mkdir -p "$_preserve/$(dirname "$sub")"
        cp -R "./$sub" "$_preserve/$sub"
      done < <(ow_nested_safe_subpaths "$p" "${SAFE_PATHS[@]}")
      rm -rf "./$p"
      cp -R "$STAGE/$p" "./$p"
      if [ -n "$_preserve" ]; then
        while IFS= read -r sub; do
          [ -n "$sub" ] && [ -e "$_preserve/$sub" ] || continue
          rm -rf "./$sub"; mkdir -p "$(dirname "./$sub")"; cp -R "$_preserve/$sub" "./$sub"
          ok "Preserved nested user path: $sub"
        done < <(ow_nested_safe_subpaths "$p" "${SAFE_PATHS[@]}")
        rm -rf "$_preserve"
      fi
    else
      cp "$STAGE/$p" "./$p"
    fi
    ok "Updated: $p"
  fi
done

# ── selective .claude merge (#3) — only when claude is an enabled AI ──
# Overwrite ONLY obsidian-workflow-owned files (generated shims + always-on agents); settings.json
# is MERGED key-by-key, never overwritten. NEVER rm -rf .claude/* — preserve
# settings.local.json, hooks, MCP permission files, and project-enabled agent docs.
if claude_is_enabled; then
  log "Merging .claude/ (selective — preserves user settings/hooks/specialized agents)..."
  # Back up everything we touch — all three are in ROLLBACK_PATHS, so --rollback works
  for p in .claude/commands .claude/agents .claude/settings.json; do
    if [ -e "$p" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$p")"
      cp -R "$p" "$BACKUP_DIR/$p"
    fi
  done
  mkdir -p .claude/commands .claude/agents
  # commands: regenerate shims override-first from the just-applied verb specs
  if [ -d ".ow/commands" ] && command -v generate_shims >/dev/null 2>&1; then
    generate_shims ".ow/commands" "." "ow"
    ok "Regenerated .claude/commands shims (override-first; shims of removed commands pruned)"
  fi
  # always-on agents: overwrite only the ones obsidian-workflow wrote, decided by signature and never
  # by filename — a project's own agent under a shipped name is kept and reported.
  for a in $OW_ALWAYS_ON_AGENTS; do
    [ -f "$STAGE/.claude/agents/$a.md" ] || continue
    if [ -e ".claude/agents/$a.md" ] && ! ow_is_owned_agent ".claude/agents/$a.md"; then
      warn "kept project-owned .claude/agents/$a.md — obsidian-workflow's not installed"
      continue
    fi
    cp "$STAGE/.claude/agents/$a.md" ".claude/agents/$a.md"
  done
  ok "Updated always-on agents ($OW_ALWAYS_ON_AGENTS); specialized/project agents left untouched"
  # Specialized bodies are created per-project by /ow-agent, never shipped, so there is
  # nothing to refresh here — only the one lie left to catch: a config that enables an
  # agent with no body behind it. Name it; the fix is a command upgrade must not run for
  # the user (a generated body must be written against a stack, not a template).
  if command -v verify_enabled_agents >/dev/null 2>&1; then
    verify_enabled_agents "." \
      || warn "an enabled subagent has no body — create it with /ow-agent create <name>"
  fi
  # settings.json: team-shared, but only SOME KEYS are obsidian-workflow's. Merge those ($schema,
  # permissions.allow, env.OW_*) and leave the consumer's hooks, permissions.deny/ask
  # and env additions in place. settings.local.json is NEVER touched.
  if [ -f "$STAGE/.claude/settings.json" ]; then
    if command -v ow_settings_merge >/dev/null 2>&1; then
      ow_settings_merge "$STAGE/.claude/settings.json" ".claude/settings.json"
    elif [ ! -f ".claude/settings.json" ]; then
      cp "$STAGE/.claude/settings.json" ".claude/settings.json"
    else
      warn "settings merge helper unavailable — .claude/settings.json left unchanged"
    fi
  fi
  # per-agent AI model: sync each agent's model: frontmatter from .ow.yml
  # (config override > built-in default). Runs AFTER the agent files are in place so
  # both refreshed always-on and untouched specialized agents honor the config.
  if command -v apply_agent_models >/dev/null 2>&1; then
    apply_agent_models "." && ok "Synced per-agent AI models from .ow.yml"
  fi
else
  log "Skipped .claude/ — claude is not an enabled AI for this project (ai_agents)"
fi

# ── AI frontend dirs — refresh ONLY enabled AIs (codex/gemini/gpt/glm/prompts) ──
# A claude-only project must NOT get other-AI folders dropped in. Each enabled dir is
# obsidian-workflow-owned content → wholesale refresh (backed up first for --rollback).
_ai_dirs="$(ai_frontend_dirs)"
if [ -n "$(echo $_ai_dirs | tr -d ' ')" ]; then
  log "Refreshing AI frontends (enabled only:$_ai_dirs)..."
  for d in $_ai_dirs; do
    [ -d "$STAGE/$d" ] || continue
    [ -e "$d" ] && { mkdir -p "$BACKUP_DIR/$d"; cp -R "$d/." "$BACKUP_DIR/$d/" 2>/dev/null || true; }
    rm -rf "./$d"; cp -R "$STAGE/$d" "./$d"
    ok "Refreshed AI frontend: $d"
  done
else
  log "No non-claude AI frontends enabled — none installed (correct for a claude-only project)"
fi

# ── skills bundle (.agents/) + routers — REGENERATED, never wholesale-copied ──
# .agents/skills is MIXED ownership: a user may keep their own skills beside the
# generated ow-* ones, so it must never enter the rm -rf refresh loop above.
# generate_skills writes per-file and prune_orphan_skills removes only directories
# carrying the generated signature.
_skills_enabled=0
# ONE definition, shared with the --dry-run preview above, so the preview can never promise
# prompts/ work the apply path skips.
_routers="$(router_frontends)"
if grep -q '^ai_agents:' .ow.yml 2>/dev/null; then
  while IFS= read -r ai; do
    [ -n "$ai" ] || continue
    [ "$(ow_frontend_kind "$ai")" = skills ] && _skills_enabled=1
  done < <(yq '.ai_agents[]' .ow.yml 2>/dev/null | tr -d '"')
else
  # Legacy (no ai_agents key) — regenerate only what is already on disk.
  [ -d .agents ] && _skills_enabled=1
fi

if [ "$_skills_enabled" -eq 1 ] && [ -d ".ow/commands" ] && command -v generate_skills >/dev/null 2>&1; then
  [ -e .agents ] && { mkdir -p "$BACKUP_DIR/.agents"; cp -R .agents/. "$BACKUP_DIR/.agents/" 2>/dev/null || true; }
  generate_skills ".ow/commands" "."
  ok "Regenerated .agents/skills/ (override-first; user-owned skills preserved)"
  # Shared entry point. AGENTS.md is in SAFE_PATHS, so a host that customized it keeps
  # theirs; it is only planted when absent.
  if [ ! -e AGENTS.md ] && [ -f "$STAGE/AGENTS.md" ]; then
    cp "$STAGE/AGENTS.md" AGENTS.md
    ok "Installed AGENTS.md (was missing)"
  fi
fi

if [ -n "$_routers" ] && [ -d ".ow/commands" ] && command -v generate_router >/dev/null 2>&1; then
  for ai in $_routers; do
    generate_router ".ow/commands" "." "$(ow_frontend_folder "$ai")" "$(ow_frontend_label "$ai")"
    ok "Regenerated $(ow_frontend_folder "$ai")/prompts/router.md (override-first)"
  done
fi

# ── prompts/ — shared router paste material (mixed ownership: backfill, never replace) ──
# Excluded from the wholesale refresh above for the same reason as .agents/: install.sh
# ("kept existing: prompts/ (not overwritten)") and /ow-sync (PROTECTED list) both treat
# it as the project's own, because it is paste material a team edits in place. Upgrade now
# holds the same contract — a file a release ADDS is backfilled, a file already on disk is
# never touched — so all three entry points agree and no upgrade can silently discard it.
if [ -n "$(printf '%s' "$_routers" | tr -d ' ')" ] && [ -d "$STAGE/prompts" ]; then
  _pnew=0
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    [ -e "prompts/$rel" ] && continue
    mkdir -p "prompts/$(dirname "$rel")"
    cp "$STAGE/prompts/$rel" "prompts/$rel"
    _pnew=$((_pnew+1))
  done < <(cd "$STAGE/prompts" && find . -type f | sed 's|^\./||')
  if [ "$_pnew" -gt 0 ]; then
    ok "Backfilled $_pnew new file(s) into prompts/ — existing files left untouched"
  else
    log "prompts/ already has every shipped file — nothing to backfill"
  fi
fi

# ── selective scripts/ + bin/ refresh (mixed-ownership — never rm -rf) ──
# Refresh ONLY the obsidian-workflow-owned files (from the manifest); a host's custom scripts
# under scripts/ or bin/ are left untouched. rm -f before cp so a file being read by
# THIS running process (e.g. upgrade.sh overwriting itself) keeps its old inode alive
# until the process exits, then a fresh inode takes the path — no mid-run corruption.
if command -v ow_owned_scripts >/dev/null 2>&1; then
  log "Refreshing owned scripts/ + bin/ (per-file; custom files preserved)..."
  mkdir -p scripts bin
  _refreshed=0
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$STAGE/scripts/$f" ] || continue
    mkdir -p "$BACKUP_DIR/scripts"; [ -f "scripts/$f" ] && cp "scripts/$f" "$BACKUP_DIR/scripts/$f"
    rm -f "scripts/$f"; cp "$STAGE/scripts/$f" "scripts/$f"; _refreshed=$((_refreshed+1))
  done < <(ow_owned_scripts)
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$STAGE/bin/$f" ] || continue
    mkdir -p "$BACKUP_DIR/bin"; [ -f "bin/$f" ] && cp "bin/$f" "$BACKUP_DIR/bin/$f"
    rm -f "bin/$f"; cp "$STAGE/bin/$f" "bin/$f"; chmod +x "bin/$f" 2>/dev/null || true
  done < <(ow_owned_bin)
  # Drop source-only scripts a legacy install may have copied (install.sh/test.sh).
  # Detect obsidian-workflow's OWN copy by its header SIGNATURE (`# obsidian-workflow ...` on line 2),
  # not a byte-identical diff — an OLD ow test.sh from a prior version differs
  # from the current one but is still obsidian-workflow's and must go (else it lingers in the
  # consumer and `./scripts/test.sh` runs the source-repo smoke test there, failing
  # on files that were never installed). A host's OWN scripts/test.sh (no obsidian-workflow
  # signature) is kept untouched.
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "scripts/$f" ] || continue
    if ! head -3 "scripts/$f" | grep -q '^# obsidian-workflow '; then
      warn "Kept scripts/$f — no obsidian-workflow signature (treated as host-owned, not removed)"
      continue
    fi
    mkdir -p "$BACKUP_DIR/scripts"; cp "scripts/$f" "$BACKUP_DIR/scripts/$f"; rm -f "scripts/$f"
    warn "Removed source-only scripts/$f (obsidian-workflow source-repo tooling — not for consumers)"
  done < <(ow_source_only_scripts)
  ok "Refreshed $_refreshed owned scripts + bin/ow; host custom scripts left untouched"
else
  warn "owned-file manifest unavailable — skipped scripts/bin refresh (run upgrade again)"
fi

# ── tombstones — delete files obsidian-workflow USED to own (see scripts/ow-owned.sh) ──
# The two loops above only ADD or REFRESH: a name dropped from the owned manifest leaves
# the stale file on every consumer forever, and the source-only prune covers exactly two
# hardcoded names. A tombstone row generalises that prune — it names the retired path, the
# release that retires it, and why. A row applies only while the consumer's PRE-upgrade
# version is older than that release (so it runs once), and only to a file that still
# carries obsidian-workflow's `# obsidian-workflow ` header signature, so a host file that later took the
# same name is kept. The file is copied into $BACKUP_DIR first ⇒ --rollback restores it
# through the same per-file scripts/ + bin/ loop that restores refreshed owned files.
if command -v ow_tombstone_pending >/dev/null 2>&1; then
  _tombed=0
  _TAB="$(printf '\t')"
  while IFS="$_TAB" read -r _tpath _tver _treason; do
    [ -n "$_tpath" ] || continue
    case "$_tpath" in
      scripts/*|bin/*) ;;
      *) warn "Tombstone ignored — only scripts/ + bin/ are --rollback-covered: $_tpath"; continue ;;
    esac
    [ -f "$_tpath" ] || continue
    if ! head -3 "$_tpath" | grep -q '^# obsidian-workflow '; then
      warn "Kept $_tpath — no obsidian-workflow signature (treated as host-owned, not removed)"
      continue
    fi
    mkdir -p "$BACKUP_DIR/$(dirname "$_tpath")"; cp "$_tpath" "$BACKUP_DIR/$_tpath"
    rm -f "$_tpath"; _tombed=$((_tombed+1))
    warn "Retired $_tpath (v$_tver — $_treason) — backed up in $BACKUP_DIR"
  done < <(ow_tombstone_pending "$current_version")
  [ "$_tombed" -gt 0 ] && ok "Retired $_tombed file(s) obsidian-workflow no longer owns — restorable via --rollback"
fi

# ── v0.4 / v0.4.1 migration cleanup ──
# Layout history:
#   pre-v0.4:           root standards/ + root VERSION + root commands/
#   v0.4-intermediate:  .ow/standards/ + .ow/VERSION (obsidian-workflow own) + root commands/
#   v0.4:               flat .ow/{STANDARD.md,policies,...} + .ow/VERSION + .ow.yml ow.version (obsidian-workflow own) + root commands/
#   v0.4.1:             commands/ moved into .ow/commands/ — all machinery in one place
#   current:            no shipped standard snapshot — .ow/{commands,templates,rules} only

# Retire the standard snapshot: STANDARD.md / UPDATE-POLICY.md / VERSION / policies/ / checklists/
# were a copy of an external standard that obsidian-workflow no longer ships. Version-gated like a
# tombstone row (runs only on the upgrade that CROSSES the cut, so a project that later creates
# its own .ow/policies/ is never touched again), backed up first, and listed in
# ROLLBACK_PATHS so --rollback puts them back.
if command -v _ow_ver_lt >/dev/null 2>&1 && _ow_ver_lt "$current_version" "1.9.0"; then
  for _retired in .ow/STANDARD.md .ow/UPDATE-POLICY.md .ow/VERSION \
                  .ow/policies .ow/checklists; do
    [ -e "$_retired" ] || continue
    mkdir -p "$BACKUP_DIR/$(dirname "$_retired")"
    cp -R "$_retired" "$BACKUP_DIR/$_retired" 2>/dev/null || true
    rm -rf "$_retired"
    warn "Retired $_retired (standard snapshot no longer shipped, v1.9.0) — backed up in $BACKUP_DIR"
  done
fi

# Retire the specialized-agent library: `.ow/agents/` existed so `/ow-agent enable
# <name>` could copy a SHIPPED specialized body offline. obsidian-workflow no longer ships one —
# backend/frontend/mobile/design/test-runner are now GENERATED by `/ow-agent create
# <name>` against the project's own stack — so the library is a stale copy of bodies
# nothing reads. Version-gated, backed up first, and in ROLLBACK_PATHS.
# 🔴 Only the library goes. A specialized agent the project actually enabled lives in
# .claude/agents/ and is never touched by upgrade, so a working setup survives this.
if command -v _ow_ver_lt >/dev/null 2>&1 && _ow_ver_lt "$current_version" "1.10.0"; then
  if [ -e .ow/agents ]; then
    mkdir -p "$BACKUP_DIR/.ow"
    cp -R .ow/agents "$BACKUP_DIR/.ow/agents" 2>/dev/null || true
    rm -rf .ow/agents
    warn "Retired .ow/agents/ (specialized bodies are created by /ow-agent create, v1.10.0) — backed up in $BACKUP_DIR"
  fi
fi

# Retire the workflow snapshot: `.ow/workflows/obsidian.md` was a copy of an external
# standard's workflow. It routed the AI to `commands/plan-work.md`, `commands/fix-bug.md`,
# `commands/verify-work.md` … — nine files obsidian-workflow has never shipped — and described a second
# vault layout (`00-Agent-Context.md`, `sessions/`, `test-reports/`) that no verb spec uses.
# The 21 verb specs own that ground now. Version-gated, backed up first, in ROLLBACK_PATHS.
# (Its three companion templates — init.md / obsidian-context.md / obsidian-work-note.md — need
# no row here: .ow/templates is replaced wholesale, so they leave with the refresh.)
if command -v _ow_ver_lt >/dev/null 2>&1 && _ow_ver_lt "$current_version" "2.1.0"; then
  if [ -e .ow/workflows ]; then
    mkdir -p "$BACKUP_DIR/.ow"
    cp -R .ow/workflows "$BACKUP_DIR/.ow/workflows" 2>/dev/null || true
    rm -rf .ow/workflows
    warn "Retired .ow/workflows/ (the 21 verb specs own the workflow, v2.1.0) — backed up in $BACKUP_DIR"
  fi
fi

# v0.4.1: legacy root commands/ — archive only if it has no customization vs new .ow/commands/
if [ -d "commands" ] && [ -d ".ow/commands" ]; then
  has_custom=0
  while IFS= read -r f; do
    rel="${f#commands/}"
    if [ ! -f ".ow/commands/$rel" ] || ! diff -q "$f" ".ow/commands/$rel" >/dev/null 2>&1; then
      has_custom=1
      break
    fi
  done < <(find commands -type f -name '*.md' 2>/dev/null)
  if [ "$has_custom" -eq 1 ]; then
    warn "Legacy root commands/ has customization — kept as override layer (lookup: root → .ow/commands/)"
  else
    bak="commands.bak-$(date +%Y%m%d-%H%M%S)"
    warn "Legacy root commands/ found (no customization) — moving to $bak (now under .ow/commands/)"
    mv commands "$bak"
  fi
fi

# Move legacy root standards/ aside (template provided fresh in .ow/)
if [ -d "standards" ]; then
  bak="standards.bak-$(date +%Y%m%d-%H%M%S)"
  warn "Legacy root standards/ found — moving to $bak"
  mv standards "$bak"
fi

# Move legacy .ow/standards/ aside (template provided flat in .ow/)
if [ -d ".ow/standards" ]; then
  bak=".ow/standards.bak-$(date +%Y%m%d-%H%M%S)"
  warn "Legacy .ow/standards/ found — moving to $bak (now flat under .ow/)"
  mv .ow/standards "$bak"
fi

# Root VERSION handling (#2 — data-loss fix).
# Many host projects keep their OWN root VERSION file. obsidian-workflow's own version now
# lives in .ow.yml ow.version, so a root VERSION is host-owned by default
# → PRESERVE it. Only a genuinely legacy obsidian-workflow marker (no ow: block yet AND a
# release-shaped value) is migrated, and even then: back up → persist → verify → only
# then delete. When in doubt, never delete.
if [ -f "VERSION" ]; then
  root_ver=$(cat VERSION 2>/dev/null | tr -d '[:space:]')
  # Always back up the root VERSION before any decision (recoverable via --rollback).
  cp VERSION "$BACKUP_DIR/VERSION" 2>/dev/null || true
  if [ -f .ow.yml ] && grep -q "^ow:" .ow.yml; then
    # .ow.yml already tracks obsidian-workflow's version → nothing to migrate. The root
    # VERSION is the HOST project's file → keep it untouched. (fixes skip-then-delete)
    warn "Root VERSION ($root_ver) preserved — .ow.yml already has ow.version (treated as host-owned)"
  elif printf '%s' "$root_ver" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+'; then
    # No ow: block yet AND a release-shaped value → plausible legacy marker.
    # Persist the value, VERIFY the write, confirm the backup exists, THEN delete.
    if [ -n "$root_ver" ] && [ -f .ow.yml ]; then
      printf '\now:\n  version: "%s"\n' "$root_ver" >> .ow.yml
    fi
    if grep -q "^ow:" .ow.yml 2>/dev/null \
       && grep -q "version: \"$root_ver\"" .ow.yml 2>/dev/null \
       && [ -f "$BACKUP_DIR/VERSION" ]; then
      rm -f VERSION
      warn "Legacy root VERSION ($root_ver) migrated into .ow.yml + backed up to $BACKUP_DIR/VERSION, then removed"
    else
      warn "Root VERSION ($root_ver) NOT removed — persist/verify/backup incomplete (file left intact)"
    fi
  else
    # No ow: block but value is not release-shaped → ambiguous → host-owned. Keep it.
    warn "Root VERSION ($root_ver) preserved — does not look like a obsidian-workflow release (treated as host-owned)"
  fi
fi

# Update ow.version + last_synced ใน .ow.yml (v0.4.1+ schema)
# Legacy installs ใช้ standard.* — migrate ตรงนี้ด้วย Python (works without yq)
if [ -f .ow.yml ] && command -v python3 >/dev/null 2>&1; then
  TODAY="$(date +%Y-%m-%d)" NEW_VER="$new_version" python3 - <<'PYEOF'
import os, re
p = '.ow.yml'
today = os.environ.get('TODAY', '')
new_ver = os.environ.get('NEW_VER', '').strip()
with open(p) as f: txt = f.read()

# 1) Extract source + last_synced from legacy standard: block (if exists)
m = re.search(r'(?ms)^standard:\s*\n((?:[ \t]+.+\n?)+)', txt)
src = sync = ''
if m:
    block = m.group(1)
    sm = re.search(r'^\s+source:\s*"?([^"\n]+)"?', block, re.M)
    if sm: src = sm.group(1).strip()
    sm = re.search(r'^\s+last_synced:\s*"?([^"\n]+)"?', block, re.M)
    if sm: sync = sm.group(1).strip()
    # Drop the standard: block entirely
    txt = re.sub(r'(?ms)^standard:\s*\n(?:[ \t]+.+\n?)+', '', txt)

# 2) Ensure ow: block exists + bump version + last_synced + carry source
bs_m = re.search(r'(?ms)^ow:\s*\n((?:[ \t]+.+\n?)+)', txt)
if bs_m:
    bs_block = bs_m.group(1)
    additions = ''
    if src and 'source:' not in bs_block:
        additions += f'  source: "{src}"\n'
    # Bump version → new_ver (the version of the upgrade just applied)
    if new_ver and new_ver != '0.0.0':
        if 'version:' in bs_block:
            bs_block = re.sub(r'^(\s+version:)\s*"?[^"\n]*"?', rf'\1 "{new_ver}"', bs_block, count=1, flags=re.M)
        else:
            additions += f'  version: "{new_ver}"\n'
    # Always (re)write last_synced to today
    if 'last_synced:' in bs_block:
        bs_block = re.sub(r'^(\s+last_synced:)\s*"?[^"\n]*"?', rf'\1 "{today}"', bs_block, count=1, flags=re.M)
    else:
        additions += f'  last_synced: "{today}"\n'
    txt = txt[:bs_m.start(1)] + bs_block + txt[bs_m.end(1):]
    if additions:
        bs_m2 = re.search(r'(?ms)^ow:\s*\n((?:[ \t]+.+\n?)+)', txt)
        txt = txt[:bs_m2.end()] + additions + txt[bs_m2.end():]
else:
    blk = 'ow:\n'
    if new_ver and new_ver != '0.0.0': blk += f'  version: "{new_ver}"\n'
    if src:  blk += f'  source: "{src}"\n'
    blk += f'  last_synced: "{today}"\n'
    txt = txt.rstrip() + '\n\n' + blk

with open(p, 'w') as f: f.write(txt)
PYEOF
  ok "Updated .ow.yml ow.version → $new_version + last_synced (+ migrated legacy standard.* if present)"
fi

# Backfill NEW top-level config blocks from the shipped template (additive — keeps every
# block + value the user already has; only appends what's missing). Surfaces newly-added
# config (e.g. commands:, model fields, optional v0.7 blocks) on upgrade without a hand edit.
if [ -f .ow.yml ] && [ -f "$STAGE/.ow.yml" ] && command -v merge_config_blocks >/dev/null 2>&1; then
  # (.ow.yml was already backed up pristine in the backup phase → --rollback safe)
  _added="$(merge_config_blocks ".ow.yml" "$STAGE/.ow.yml")"
  if [ -n "$_added" ]; then
    ok "Backfilled new .ow.yml config blocks (existing values preserved):"
    printf '%s\n' "$_added"
  else
    log ".ow.yml already has every shipped config block — nothing to backfill"
  fi
fi

# Backfill NEW per-machine knobs into the user's .ow.local.yml (additive — never overrides
# their existing values/comments). Surfaces newly-shipped per-machine knobs on upgrade.
# The real file is gitignored + SAFE_PATHS; we only APPEND.
if [ -f .ow.local.yml ] && [ -f "$STAGE/.ow.local.yml.example" ] && command -v merge_local_config >/dev/null 2>&1; then
  # (.ow.local.yml was backed up pristine above → --rollback safe)
  _ladded="$(merge_local_config ".ow.local.yml" "$STAGE/.ow.local.yml.example")"
  if [ -n "$_ladded" ]; then
    ok "Backfilled new .ow.local.yml knobs (existing values preserved):"
    printf '%s\n' "$_ladded"
  else
    log ".ow.local.yml already has every shipped knob — nothing to backfill"
  fi
fi

# ── CLAUDE.md managed block ──
# obsidian-workflow owns ONLY the marked block; every line the host wrote outside it survives.
# CLAUDE.md is in SAFE_PATHS — that bars a WHOLESALE replace, which a scoped block merge
# is not. Re-source from the just-applied scripts/ so the helper exists even on the first
# upgrade to a version that ships it (same reason as the .gitignore block below).
# Gated on claude being enabled — the same predicate the .claude/ merge uses, and the same
# contract install.sh holds (its merge lives inside the `claude` arm of the AI loop). A
# codex- or gemini-only project must never be handed a Claude Code workflow file.
if claude_is_enabled && [ -f scripts/ow-claude-md.sh ] && [ -f "$STAGE/CLAUDE.md" ]; then
  . scripts/ow-claude-md.sh
  if command -v ow_claude_md_merge >/dev/null 2>&1; then
    _cm_was="$(ow_claude_md_marker CLAUDE.md)"
    _cm_rc=0
    _cm_did="$(ow_claude_md_merge "CLAUDE.md" "$STAGE/CLAUDE.md")" || _cm_rc=$?
    case "$_cm_did" in
      created)   ok "Created CLAUDE.md (obsidian-workflow managed block only)" ;;
      refreshed) ok "Refreshed CLAUDE.md managed block (host prose outside the markers preserved)" ;;
      appended)  ok "Added the CLAUDE.md managed block (every line already in the file preserved)" ;;
      *)
        if [ "$_cm_rc" -eq 2 ]; then
          warn "CLAUDE.md has a OW START marker with no matching END — refusing to guess the span. Fix the markers by hand, then re-run upgrade"
        elif [ "$_cm_rc" -eq 3 ]; then
          warn "CLAUDE.md rewrite FAILED — the file is unchanged (check permissions and free space), and the managed block is stale"
        else
          warn "CLAUDE.md left untouched — the shipped CLAUDE.md carries no managed block"
        fi ;;
    esac
    if [ -n "$_cm_was" ] && [ "$_cm_was" != "$OW_CM_START" ]; then
      warn "CLAUDE.md carried a narrower block ($_cm_was) — obsidian-workflow prose that predates the widened block now sits OUTSIDE the markers; review CLAUDE.md and delete what is duplicated"
    fi
  fi
fi

# ── .gitignore managed block ──
# Refresh the obsidian-workflow-owned block ONLY (user lines untouched). Re-source from the
# just-applied scripts/ so the function exists even on the first upgrade to a version
# that ships ow-gitignore.sh (the pre-apply source at the top may have been a no-op).
if [ -f scripts/ow-gitignore.sh ]; then
  . scripts/ow-gitignore.sh
  if command -v ow_gitignore_merge >/dev/null 2>&1; then
    ow_gitignore_merge ".gitignore"
    ok "Refreshed .gitignore managed block (obsidian-workflow-internal paths; user lines preserved)"
  fi
fi

# ── verify ──
log "Running doctor..."
if [ -f bin/ow ]; then
  bash bin/ow doctor || warn "Doctor reported issues — review above"
fi

# Conformance lint (#14) — the upgrade just replaced commands/agents/scripts, so verify the
# new tree satisfies the read-mechanism contract. Non-fatal warn (the backup is intact and a
# user can --rollback), but loud so a bad release is caught.
if [ -f scripts/conformance-lint.sh ]; then
  log "Running conformance lint..."
  bash scripts/conformance-lint.sh "." || warn "Conformance lint FAILED — review above; bash scripts/upgrade.sh --rollback to revert"
fi

# ── prune old backups — keep ONLY this run's (latest) for --rollback ──
# Every upgrade makes a fresh .ow.backup-*; without pruning they pile up. Rollback
# only ever uses the most recent, so older ones are dead weight. The kept dir is gitignored
# (managed block) so it never pollutes git status / gets committed.
_pruned=0
for _b in .ow.backup-*; do
  [ -d "$_b" ] || continue
  [ "$_b" = "$BACKUP_DIR" ] && continue
  rm -rf "$_b" && _pruned=$((_pruned+1))
done
[ "$_pruned" -gt 0 ] && log "Pruned $_pruned old backup(s) — kept latest only"

# ── summary ──
echo ""
printf "${c_green}${c_bold}✓ Upgrade complete${c_reset}\n"
log "$current_version → $new_version"
log "Backup (latest, gitignored): $BACKUP_DIR — kept for rollback; safe to delete once verified"
log "Rollback: bash scripts/upgrade.sh --rollback"
log ""
log "Next:"
log "  • Health check: ow doctor   (or: bash scripts/conformance-lint.sh .)"
log "  • Check breaking changes ใน CHANGELOG.md"
log "  • รัน /ow-agent audit เพื่อตรวจ agent files"
# NOTE: do NOT suggest scripts/test.sh here — it is obsidian-workflow's SOURCE-repo smoke test
# (verifies the source tree's own structure) and is never shipped to a consumer.
