#!/usr/bin/env bash
# obsidian-workflow — regenerate AI front-end command files from .ow/commands (offline)
# ─────────────────────────────────────────────────────────────────────────────
# For a machine that cloned a project whose generated front-end dirs (.claude/commands,
# .agents/skills, <folder>/prompts/router.md) are gitignored. Reads `ai_agents` from
# .ow.yml and emits only what those front-ends read. No network, no version bump, never
# touches .ow/, .ow.yml or user-owned files (same emitters + ownership checks as upgrade).
#
# Agent bodies are NOT regenerated: .ow/subagents/ is their committed source, and for claude this
# script only (re)creates the .claude/agents/ symlinks that point at it.
#
# Usage (from the project root):  bash scripts/ow-regen.sh   |   ow regen
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

[ -f .ow.yml ]      || { echo "ow regen: no .ow.yml in $ROOT" >&2; exit 1; }
[ -d .ow/commands ] || { echo "ow regen: no .ow/commands — commit .ow/ or run 'ow upgrade'" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "ow regen: yq is required (brew install yq)" >&2; exit 1; }

. "$SCRIPT_DIR/ow-frontends.sh"
. "$SCRIPT_DIR/ow-shims.sh"
. "$SCRIPT_DIR/ow-claude-manifest.sh"

ais="$(yq '.ai_agents[]' .ow.yml 2>/dev/null | tr -d '"' || true)"
[ -n "$ais" ] || ais="claude"   # same default as a legacy project: Claude Code only

skills_done=0
for ai in $ais; do
  ow_frontend_valid "$ai" || { echo "  skipped unknown front-end: $ai" >&2; continue; }
  case "$(ow_frontend_kind "$ai")" in
    commands) generate_shims .ow/commands . ow;  echo "  $ai: .claude/commands/"
              ow_link_agents . && echo "  $ai: .claude/agents/ -> .ow/subagents/" \
                || echo "  $ai: .claude/agents/ linked, some project-owned files kept (see WARN)" ;;
    skills)   [ "$skills_done" = 1 ] || { generate_skills .ow/commands .; skills_done=1; }
              echo "  $ai: .agents/skills/" ;;
    router)   generate_router .ow/commands . "$(ow_frontend_folder "$ai")" "$(ow_frontend_label "$ai")"
              echo "  $ai: $(ow_frontend_folder "$ai")/prompts/router.md" ;;
  esac
done
# Refresh the Phase 0 cache (resolved paths + OW_USER) — a fresh clone has none yet.
mkdir -p .ow/local
if bash "$SCRIPT_DIR/ow-paths.sh" --shell > .ow/local/paths.env.tmp 2>/dev/null; then
  mv .ow/local/paths.env.tmp .ow/local/paths.env && echo "  cache: .ow/local/paths.env"
else
  rm -f .ow/local/paths.env.tmp; echo "  cache: .ow/local/paths.env not refreshed (next /ow-* Phase 0 writes it)" >&2
fi
echo "ow regen: done ($(echo $ais | tr '\n' ' '))"
