#!/usr/bin/env bash
# ow-claude-manifest — .claude/ ownership manifest + shim generation
# ─────────────────────────────────────────────────────────────────────────────
# Defines EXACTLY what obsidian-workflow owns under .claude/ so install/upgrade
# can do a per-file selective refresh instead of wholesale replace. Shared lib,
# sourced by install.sh and scripts/ow-upgrade.sh; also runnable directly:
#
#   bash scripts/ow-claude-manifest.sh --apply [root]
#       regenerate .claude/commands/ow-*.md shims + sync agent `model:`
#       frontmatter from .ow.yml — run after editing subagents.*.model or
#       commands.* in .ow.yml
#
# obsidian-workflow OWNS (and may overwrite) only:
#   - .claude/commands/ow-<verb>.md  — generated shims, one per .ow/commands spec
#   - .claude/agents/<a>.md          — the ow-shipped agents below
# Everything else under .claude/ is left untouched.

# Always-on agents are toolkit-owned: install/upgrade may OVERWRITE them.
# Specialized agents are copied when absent but NEVER overwritten — projects
# customize them. apply_agent_models touches only the `model:` line of either set.
OW_ALWAYS_ON_AGENTS="docs verifier security gh-issue"
OW_MANIFEST_AGENTS="docs verifier security gh-issue design backend frontend mobile test-runner"

# copy_agents <src_root> <target_root>
# Shared install/upgrade agent copy honoring the ownership split above.
copy_agents() {
  local src="$1" root="$2" f base a owned
  mkdir -p "$root/.claude/agents"
  for f in "$src"/.claude/agents/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    owned=0
    for a in $OW_ALWAYS_ON_AGENTS; do [ "$base" = "$a.md" ] && owned=1 && break; done
    if [ "$owned" -eq 1 ] || [ ! -f "$root/.claude/agents/$base" ]; then
      cp "$f" "$root/.claude/agents/$base"
    else
      echo "  keep existing agent: .claude/agents/$base (specialized — not overwritten)"
    fi
  done
}

# generate_shims <verb_specs_dir> <target_root>
# Write one resolved @-include shim per verb into <target_root>/.claude/commands/.
# The command's AI model comes from .ow.yml (commands.model + commands.overrides)
# via ow-paths.sh --command-model; `inherit` ⇒ no model line (follows the session).
# Fail-safe: resolver/yq/config unavailable ⇒ omit the line.
generate_shims() {
  local specs="$1" root="$2"
  local dst="$root/.claude/commands"
  mkdir -p "$dst"
  local vf verb model
  for vf in "$specs"/*.md; do
    [ -e "$vf" ] || continue
    verb="$(basename "$vf" .md)"
    model=""
    if [ -f "$root/scripts/ow-paths.sh" ] && command -v yq >/dev/null 2>&1; then
      model="$(OW_ROOT="$root" bash "$root/scripts/ow-paths.sh" --command-model "$verb" 2>/dev/null || true)"
    fi
    {
      printf -- '---\n'
      printf 'description: obsidian-workflow /%s — see .ow/commands/%s.md\n' "$verb" "$verb"
      [ -n "$model" ] && [ "$model" != inherit ] && printf 'model: %s\n' "$model"
      printf -- '---\n\n'
      printf '@.ow/commands/%s.md\n' "$verb"
    } > "$dst/$verb.md"
  done
}

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
design	opus
backend	opus
frontend	opus
mobile	opus
test-runner	sonnet
EOF
}

# apply_agent_models <target_root>
# Sync each agent file's `model:` frontmatter line to the value resolved by
# ow-paths.sh (config override > built-in default). Surgical: rewrites ONLY the
# first `model:` line of each EXISTING agent file — never creates files, never
# touches a user's custom agent (only the ow-owned names are emitted).
# Idempotent: a file already on the resolved model is left untouched.
apply_agent_models() {
  local root="${1:-.}"
  local paths_sh="$root/scripts/ow-paths.sh"
  local models="" name model f cur tmp
  if [ -f "$paths_sh" ] && command -v yq >/dev/null 2>&1; then
    models="$(OW_ROOT="$root" bash "$paths_sh" --agent-models 2>/dev/null || true)"
  fi
  [ -n "$models" ] || models="$(ow_default_agent_models)"
  while IFS=$'\t' read -r name model; do
    [ -n "$name" ] && [ -n "$model" ] || continue
    f="$root/.claude/agents/$name.md"
    [ -f "$f" ] || continue
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

# ow_owned_claude_manifest <verb_specs_dir>
# Print the relative .claude/ paths obsidian-workflow owns — the exact set
# install/upgrade may overwrite.
ow_owned_claude_manifest() {
  local specs="${1:-}"
  local a vf verb
  for a in $OW_MANIFEST_AGENTS; do printf '.claude/agents/%s.md\n' "$a"; done
  if [ -n "$specs" ] && [ -d "$specs" ]; then
    for vf in "$specs"/*.md; do
      [ -e "$vf" ] || continue
      verb="$(basename "$vf" .md)"
      printf '.claude/commands/%s.md\n' "$verb"
    done
  fi
}

# ── CLI entry: --apply [root] — resync shims + agent models from .ow.yml ─────
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --apply)
      root="${2:-$PWD}"
      root="$(cd "$root" && pwd)"
      [ -d "$root/.ow/commands" ] || { echo "FATAL: $root/.ow/commands not found — not an ow project?" >&2; exit 1; }
      echo "Applying .ow.yml model config → $root/.claude/"
      generate_shims "$root/.ow/commands" "$root"
      echo "  shims regenerated: .claude/commands/ow-*.md"
      apply_agent_models "$root"
      echo "done"
      ;;
    --manifest)
      root="${2:-$PWD}"
      ow_owned_claude_manifest "$root/.ow/commands"
      ;;
    *)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 2
      ;;
  esac
fi
