#!/usr/bin/env bash
# obsidian-workflow — .claude/ ownership manifest + shim generation (shared install/upgrade)
# ─────────────────────────────────────────────────────────────────────────────
# Defines EXACTLY what obsidian-workflow owns under .claude/ so install/upgrade can do a
# per-file selective merge instead of rm -rf'ing the whole tree. The old wholesale
# replace destroyed user-owned files obsidian-workflow never ships: settings.local.json,
# hook scripts, MCP permission grants, and project-enabled agents (backend/frontend/
# mobile/...). See issues #3 (selective merge) + #8 (override-first shim generation).
#
# obsidian-workflow OWNS (and may overwrite) only:
#   - .claude/commands/<verb>.md   — generated shims, one per verb spec
#   - .ow/subagents/<a>.md         — the always-on agents below (NOT specialized ones).
#                                    Source of truth for EVERY agent body; committed, so a
#                                    clone gets them. .claude/agents/<a>.md is only a relative
#                                    symlink to it (ow_link_agents) — Claude Code reads that path.
#   - .claude/settings.json        — KEYS ONLY: $schema, permissions.allow,
#                                    env.OW_*. Merged by ow-settings-merge.sh;
#                                    every other key is the consumer's.
# Everything else under .claude/ is left untouched.

# The ONLY agent docs obsidian-workflow ships. Specialized agents (backend/frontend/mobile/
# design/test-runner and any project-invented name) are CREATED per-project by
# /ow-agent create against that project's real stack, and must NEVER be deleted or
# overwritten by install/upgrade.
OW_ALWAYS_ON_AGENTS="docs verifier security gh-issue"

# ow_is_owned_agent <file> — true when obsidian-workflow authored this agent file. Ownership is
# proven by CONTENT, never by filename: a project may own a .claude/agents/backend.md and
# install/upgrade must keep it. Two strings identify a obsidian-workflow agent and obsidian-workflow is the
# only writer of either: the marker at the top of every shipped agent, and the §0
# injected-context header /ow-agent writes into every agent it generates.
# Keep byte-identical with _agent_is_ow_owned in scripts/conformance-lint.sh.
ow_is_owned_agent() {
  grep -q '^<!-- obsidian-workflow:agent' "$1" && return 0
  grep -qF '## §0. Context (injected — authoritative)' "$1"
}

# Where every agent body lives. .claude/agents/ holds symlinks into it, so the bodies survive
# a clone that gitignores .claude/ and are readable by any front-end, not only Claude Code.
OW_SUBAGENTS_DIR=".ow/subagents"

# ow_agent_file <root> <name> — the editable file for an agent: the .ow/subagents source, else a
# real project-owned .claude/agents file. Prints nothing (rc 1) when neither exists.
ow_agent_file() {
  local root="${1:-.}" n="$2"
  if [ -f "$root/$OW_SUBAGENTS_DIR/$n.md" ]; then printf '%s\n' "$root/$OW_SUBAGENTS_DIR/$n.md"
  elif [ -f "$root/.claude/agents/$n.md" ]; then printf '%s\n' "$root/.claude/agents/$n.md"
  else return 1; fi
}

# ow_adopt_agents <root> — one-time migration of the old layout: an obsidian-workflow-owned REAL file in
# .claude/agents/ moves into .ow/subagents/ (the link goes back in ow_link_agents). Ownership is
# by content (ow_is_owned_agent); a project's own agent stays where it is. Never overwrites.
ow_adopt_agents() {
  local root="${1:-.}" f n
  for f in "$root"/.claude/agents/*.md; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    ow_is_owned_agent "$f" || continue
    n="$(basename "$f")"
    [ -e "$root/$OW_SUBAGENTS_DIR/$n" ] && continue
    mkdir -p "$root/$OW_SUBAGENTS_DIR" && mv "$f" "$root/$OW_SUBAGENTS_DIR/$n"
  done
  return 0
}

# ow_link_agents <root> — make .claude/agents/<n>.md a RELATIVE symlink to .ow/subagents/<n>.md for
# every body there; drop links whose body is gone. A real file that differs (a project's own
# agent under the same name) is kept and named, never replaced. rc 1 if any was kept.
ow_link_agents() {
  local root="${1:-.}" src n dst tgt rc=0
  [ -d "$root/$OW_SUBAGENTS_DIR" ] || return 0
  mkdir -p "$root/.claude/agents" || return 1
  for src in "$root/$OW_SUBAGENTS_DIR"/*.md; do
    [ -f "$src" ] || continue
    n="$(basename "$src")"; dst="$root/.claude/agents/$n"; tgt="../../$OW_SUBAGENTS_DIR/$n"
    if [ -L "$dst" ]; then ln -sfn "$tgt" "$dst"
    elif [ ! -e "$dst" ]; then ln -s "$tgt" "$dst"
    elif cmp -s "$src" "$dst"; then rm -f "$dst"; ln -s "$tgt" "$dst"
    else
      echo "WARN: .claude/agents/$n is a real file that differs from $OW_SUBAGENTS_DIR/$n — kept; delete it to link" >&2
      rc=1
    fi
  done
  for dst in "$root"/.claude/agents/*.md; do
    if [ -L "$dst" ] && [ ! -e "$dst" ]; then
      case "$(readlink "$dst")" in "../../$OW_SUBAGENTS_DIR/"*) rm -f "$dst" ;; esac
    fi
  done
  return $rc
}

# Shim EMITTERS (generate_shims / generate_skills / generate_router) live in
# scripts/ow-shims.sh — they are shared by every AI front-end kind, not just
# Claude Code, and all of them must use the SAME override resolver. Sourced from
# this file's own directory so both install (fetched template) and upgrade (staged
# tree) get the emitters just by sourcing this manifest, as they always have.
_bcm_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$_bcm_dir/ow-shims.sh" ]; then
  . "$_bcm_dir/ow-shims.sh"
fi
unset _bcm_dir

# Built-in default model map — the SAME defaults as ow-paths.sh _default_agent_model,
# duplicated here so apply_agent_models still works when the resolver/config/yq is
# unavailable (fresh clone, yq-less machine, mis-rooted run). Keep the two in sync.
# Format: name<TAB>model, one per line.
ow_default_agent_models() {
  cat <<'EOF'
docs	sonnet
verifier	sonnet
security	opus
gh-issue	haiku
design	sonnet
backend	sonnet
frontend	sonnet
mobile	sonnet
test-runner	sonnet
EOF
}

# ── specialized agents: created on demand, never shipped ─────────────────────
# obsidian-workflow ships exactly the four always-on bodies above. Every specialized agent —
# backend/frontend/mobile/design/test-runner, or any name a project invents — is
# GENERATED by `/ow-agent create <name>` against that project's real stack and lives
# only in .ow/subagents/ (linked from .claude/agents/). There is therefore no library to install and no back-fill
# source: "enabled in .ow.yml", "present in .ow/subagents/" and "spawnable by
# Claude Code" collapse into ONE condition, and /ow-agent is its only writer.
#
# ow_default_agent_models still names the five well-known specializations so a created
# agent resolves a sane default model without the project having to spell one out.

# ow_enabled_agents <root> — names whose subagents.<name> is on in .ow.yml.
# Resolver first (it understands both the scalar and the map config form); the per-name
# grep fallback keeps this working on a machine with no yq. Names come from
# ow_default_agent_models so there is no second copy of the owned-agent list.
ow_enabled_agents() {
  local root="${1:-.}" out="" a
  if [ -f "$root/scripts/ow-paths.sh" ] && command -v yq >/dev/null 2>&1; then
    out="$(OW_ROOT="$root" bash "$root/scripts/ow-paths.sh" --subagents 2>/dev/null || true)"
  fi
  if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  for a in $(ow_default_agent_models | cut -f1); do
    grep -qE "^[[:space:]]+$a:[[:space:]]*(true|[{][^}]*enabled:[[:space:]]*true)" \
      "$root/.ow.yml" 2>/dev/null && printf '%s\n' "$a"
  done
  return 0
}

# verify_enabled_agents <root>
# Report every agent the config marks enabled that has NO body under .ow/subagents/.
# That combination is the one lie this area can still tell — the config promises an agent
# Claude Code cannot spawn — so it is always named, never skipped in silence. It is a
# WARNING and not a hard failure: since specialized bodies are created on demand, an
# enabled-but-absent name means "not created yet", and the fix is a single command that
# install/upgrade must not pre-empt. Returns non-zero when at least one is missing so the
# caller can surface it in its own voice.
verify_enabled_agents() {
  local root="${1:-.}" a missing=""
  for a in $(ow_enabled_agents "$root"); do
    [ -n "$a" ] || continue
    ow_agent_file "$root" "$a" >/dev/null || missing="$missing $a"
  done
  [ -n "$missing" ] || return 0
  echo "WARN: subagents enabled in .ow.yml with no body in .ow/subagents/:$missing" >&2
  echo "      they cannot be spawned — create each with: /ow-agent create <name>" >&2
  return 1
}

# apply_agent_models <target_root>
# Sync each agent file's `model:` frontmatter line to the value resolved by
# ow-paths.sh (config override > built-in default). Surgical: rewrites ONLY the
# first `model:` line of each EXISTING agent file — never creates files, never
# touches a user's custom agent (only the names ow_default_agent_models emits).
# An agent with no file under .ow/subagents/ is skipped — that is either a DISABLED
# agent or a specialized one not created yet; verify_enabled_agents is what reports the
# second case instead of letting it pass as the first.
# Idempotent: a file already on the resolved model is left untouched.
# Called post-merge by install/upgrade/sync so config drives the model with no yq -i.
# Fail-safe: if the resolver can't run (no config/yq), falls back to the built-in
# defaults above so a fresh tree still gets correct models.
apply_agent_models() {
  local root="${1:-.}"
  local paths_sh="$root/scripts/ow-paths.sh"
  local models="" name model f cur tmp
  # primary source: resolver (honors config overrides). May emit nothing / fail if
  # config or yq is missing — fall back to the built-in defaults below.
  if [ -f "$paths_sh" ] && command -v yq >/dev/null 2>&1; then
    models="$(OW_ROOT="$root" bash "$paths_sh" --agent-models 2>/dev/null || true)"
  fi
  [ -n "$models" ] || models="$(ow_default_agent_models)"
  while IFS=$'\t' read -r name model; do
    [ -n "$name" ] && [ -n "$model" ] || continue
    f="$(ow_agent_file "$root" "$name")" || continue
    cur="$(awk -F': *' '/^model:/{print $2; exit}' "$f")"
    [ "$cur" = "$model" ] && continue
    tmp="$f.tmp.$$"
    # rewrite the FIRST model: line only (the frontmatter one); leave the body intact
    awk -v m="$model" 'BEGIN{done=0} /^model:/ && !done {print "model: " m; done=1; next} {print}' "$f" > "$tmp" \
      && mv "$tmp" "$f" \
      && printf '  model: %s → %s\n' "$name" "$model"
  done <<EOF
$models
EOF
}
