#!/usr/bin/env bash
# ow-paths — Single source of truth for config + vault paths
# Resolves .ow.yml + sensible defaults. Used by all /ow-* commands
# (instead of grep-yaml-inline).
#
# Output modes:
#   --shell            eval-able shell vars (default)
#   --json             JSON object (for jq pipelines)
#   --check <key>      print single value (e.g., --check VAULT_PATH)
#   --rules <area>     resolved rule file paths for <area> (project rules layer)
#   --subagents        enabled subagent names (one per line)
#   --agent-model <name>    resolved AI model for one subagent
#   --agent-models     TSV: name<TAB>model for every ow-owned agent
#   --command-model <verb>  resolved AI model for one slash command (inherit ⇒ no pin)
#   --command-models   TSV: verb<TAB>model for every command spec
#   --submodules       TSV: name<TAB>path<TAB>branch (nothing if none)
#   --selftest         assert rooting + vault dirs readable; non-zero on failure
#   --help             show this
#
# Evidence placeholders: set OW_EVIDENCE_SOURCE and OW_EVIDENCE_SLUG to expand
# {source}/{slug} in EVIDENCE_ROOT.
#
# yq is a HARD prerequisite. The resolver roots itself at the first ancestor
# containing .ow.yml and fails closed (non-zero exit) rather than emitting
# silent default paths from a mis-rooted run.

set -euo pipefail

# ── root resolution ──────────────────────────────────────────────────────────
# Project root = first ancestor containing .ow.yml (the real config anchor).
# Honors OW_ROOT as a start hint; git-toplevel only as last-resort fallback.
resolve_root() {
  local start="${OW_ROOT:-$PWD}"
  start="$(cd "$start" 2>/dev/null && pwd || printf '%s' "$start")"
  local d="$start"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -f "$d/.ow.yml" ] && { printf '%s\n' "$d"; return; }
    d="$(dirname "$d")"
  done
  [ -f "/.ow.yml" ] && { printf '%s\n' "/"; return; }
  git rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$start"
}
ROOT="$(resolve_root)"
CONFIG="${ROOT}/.ow.yml"

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

MODE="shell"; CHECK_KEY=""; RULES_AREA=""; AGENT_NAME=""; CMD_VERB=""
case "${1:-}" in
  --shell|"") MODE="shell" ;;
  --json) MODE="json" ;;
  --check) MODE="check"; CHECK_KEY="${2:?--check needs a key}" ;;
  --rules) MODE="rules"; RULES_AREA="${2:?--rules needs an area}" ;;
  --subagents) MODE="subagents" ;;
  --agent-model) MODE="agent_model"; AGENT_NAME="${2:?--agent-model needs a name}" ;;
  --agent-models) MODE="agent_models" ;;
  --command-model) MODE="command_model"; CMD_VERB="${2:?--command-model needs a verb}" ;;
  --command-models) MODE="command_models" ;;
  --submodules) MODE="submodules" ;;
  --selftest) MODE="selftest" ;;
  --help|-h) usage; exit 0 ;;
  *) echo "ow-paths: unknown flag: $1" >&2; usage >&2; exit 2 ;;
esac

# ── fail-closed prerequisites ────────────────────────────────────────────────
command -v yq >/dev/null 2>&1 || {
  echo "FATAL: yq not installed — ow-paths needs it (brew install yq)" >&2; exit 1; }
[ -f "$CONFIG" ] || {
  echo "FATAL: .ow.yml not found at or above $PWD — run /ow-init" >&2; exit 1; }

# yq helper: returns default when key absent/null
cfg() { # cfg <yq-path> <default>
  local v
  v="$(yq -r "$1 // \"\"" "$CONFIG" 2>/dev/null || true)"
  [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"
}

# ── core values ──────────────────────────────────────────────────────────────
PROJECT_NAME="$(cfg '.project.name' 'project')"
PROJECT_SLUG="$(cfg '.project.slug' 'project')"
LANGUAGE="$(cfg '.project.language' 'th')"
TIMEZONE="$(cfg '.project.timezone' 'Asia/Bangkok')"
VAULT_PATH="$(cfg '.vault_path' 'docs/vault')"
case "$VAULT_PATH" in
  /*) VAULT_ABS="$VAULT_PATH" ;;
  *)  VAULT_ABS="${ROOT}/${VAULT_PATH}" ;;
esac

# vault dir names (numbered defaults, overridable via vault_dirs:)
vdir() { cfg ".vault_dirs.$1" "$2"; }
D_INDEX="$(vdir index '00-Index')"
D_PRD="$(vdir prd '10-PRD')"
D_FEAT="$(vdir features '20-Features')"
D_ROLE="$(vdir roles '30-Roles')"
D_FN="$(vdir functions '40-Functions')"
D_PHASE="$(vdir phases '50-Phases')"
D_FLOW="$(vdir flows '60-Flows')"
D_REF="$(vdir reference '70-Reference')"
D_PLAN="$(vdir plans '80-ImplementPlan')"
D_FIX="$(vdir fixlog '85-FixLog')"
D_TEST="$(vdir testplan '90-TestPlan')"
D_HANDOFF="$(vdir handoff '95-Handoff')"

INDEX_DIR="$VAULT_ABS/$D_INDEX";   PRD_DIR="$VAULT_ABS/$D_PRD"
FEAT_DIR="$VAULT_ABS/$D_FEAT";     ROLE_DIR="$VAULT_ABS/$D_ROLE"
FN_DIR="$VAULT_ABS/$D_FN";         PHASE_DIR="$VAULT_ABS/$D_PHASE"
FLOW_DIR="$VAULT_ABS/$D_FLOW";     REF_DIR="$VAULT_ABS/$D_REF"
PLAN_DIR="$VAULT_ABS/$D_PLAN";     FIX_DIR="$VAULT_ABS/$D_FIX"
TEST_DIR="$VAULT_ABS/$D_TEST";     HANDOFF_DIR="$VAULT_ABS/$D_HANDOFF"
DS_DIR="$REF_DIR/DesignSystem"
IMPL_STATUS="$INDEX_DIR/IMPLEMENTATION-STATUS.md"

# template chain (first match wins), absolute, colon-separated
TEMPLATE_CHAIN=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  case "$t" in /*) p="$t" ;; *) p="$ROOT/$t" ;; esac
  TEMPLATE_CHAIN="${TEMPLATE_CHAIN:+$TEMPLATE_CHAIN:}$p"
done < <(yq -r '.template_lookup[]? // empty' "$CONFIG" 2>/dev/null)
[ -n "$TEMPLATE_CHAIN" ] || TEMPLATE_CHAIN="$ROOT/.ow/templates"

# guardrails as compact JSON
GUARDRAILS_JSON="$(yq -o=json -I=0 '.guardrails // {}' "$CONFIG" 2>/dev/null || echo '{}')"

# evidence root: expand {date}/{source}/{slug}
EVIDENCE_TEMPLATE="$(cfg '.evidence.root_template' 'test-artifacts/{date}/{source}-{slug}')"
DATE_FMT="$(cfg '.evidence.date_format' '%Y-%m-%d')"
EVIDENCE_DATE="$(date +"$DATE_FMT")"
EVIDENCE_ROOT="${EVIDENCE_TEMPLATE//\{date\}/$EVIDENCE_DATE}"
# {source}/{slug} stay literal until OW_EVIDENCE_SOURCE/SLUG are set by the caller
[ -n "${OW_EVIDENCE_SOURCE:-}" ] && EVIDENCE_ROOT="${EVIDENCE_ROOT//\{source\}/$OW_EVIDENCE_SOURCE}"
[ -n "${OW_EVIDENCE_SLUG:-}" ] && EVIDENCE_ROOT="${EVIDENCE_ROOT//\{slug\}/$OW_EVIDENCE_SLUG}"
case "$EVIDENCE_ROOT" in /*) : ;; *) EVIDENCE_ROOT="$ROOT/$EVIDENCE_ROOT" ;; esac

# ── output modes ─────────────────────────────────────────────────────────────
emit_shell() {
  for k in ROOT PROJECT_NAME PROJECT_SLUG LANGUAGE TIMEZONE VAULT_PATH VAULT_ABS \
           INDEX_DIR PRD_DIR FEAT_DIR ROLE_DIR FN_DIR PHASE_DIR FLOW_DIR REF_DIR \
           DS_DIR PLAN_DIR FIX_DIR TEST_DIR HANDOFF_DIR IMPL_STATUS \
           TEMPLATE_CHAIN GUARDRAILS_JSON EVIDENCE_ROOT EVIDENCE_DATE; do
    printf "export %s=%q\n" "$k" "${!k}"
  done
}

emit_json() {
  jq -n \
    --arg root "$ROOT" --arg name "$PROJECT_NAME" --arg slug "$PROJECT_SLUG" \
    --arg lang "$LANGUAGE" --arg tz "$TIMEZONE" --arg vp "$VAULT_PATH" \
    --arg va "$VAULT_ABS" --arg impl "$IMPL_STATUS" --arg tc "$TEMPLATE_CHAIN" \
    --arg ev "$EVIDENCE_ROOT" --arg ed "$EVIDENCE_DATE" \
    --argjson guardrails "$GUARDRAILS_JSON" \
    '{root:$root, project:{name:$name, slug:$slug, language:$lang, timezone:$tz},
      vault_path:$vp, vault_abs:$va, impl_status:$impl, template_chain:$tc,
      evidence_root:$ev, evidence_date:$ed, guardrails:$guardrails}'
}

emit_rules() {
  # project rules layer: .ow/rules/<area>.md + any rules.files with matching
  # applies_to frontmatter. Prints existing files only, one per line.
  local dir; dir="$(cfg '.rules.dir' '.ow/rules')"
  case "$dir" in /*) : ;; *) dir="$ROOT/$dir" ;; esac
  local found=0
  if [ -d "$dir" ]; then
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      # match: filename == area, or applies_to contains area or '*'
      if [ "$(basename "$f" .md)" = "$RULES_AREA" ] ||
         grep -qE "applies_to:.*(\[|, |: )('|\")?(\*|$RULES_AREA)" "$f" 2>/dev/null ||
         awk '/^applies_to:/{f=1;next} f&&/^[^- ]/{exit} f&&/^ *- /{print $2}' "$f" 2>/dev/null \
           | grep -qxE "('|\")?(\*|$RULES_AREA)('|\")?"; then
        printf '%s\n' "$f"; found=1
      fi
    done
  fi
  return 0
}

emit_subagents() {
  yq -r '.subagents // {} | to_entries[] | select(.value == true or .value.enabled == true) | .key' "$CONFIG"
}

# ── agent model resolution ───────────────────────────────────────────────────
# Resolve the AI model each ow-owned agent runs on. Values are FAMILY ALIASES
# (opus|sonnet|haiku) — no version pin, so each tracks the latest of its family.
# Override per agent in .ow.yml via the map form `subagents.<name>.model: <alias>`.
# Built-in defaults: heavy-reasoning agents → opus, doc/verify/test → sonnet,
# the read-only issue reader → haiku.
OW_OWNED_AGENTS="docs verifier security gh-issue design backend frontend mobile test-runner"

_default_agent_model() {
  case "$1" in
    backend|frontend|mobile|security|design) echo opus ;;
    docs|verifier|test-runner)               echo sonnet ;;
    gh-issue)                                echo haiku ;;
    *)                                       echo sonnet ;;
  esac
}

# Accept the three family aliases or any full `claude-*` model id; reject the rest.
_valid_model() {
  case "$1" in
    opus|sonnet|haiku) return 0 ;;
    claude-*)          return 0 ;;
    *)                 return 1 ;;
  esac
}

# resolve_agent_model <name> — config override > built-in default.
# An invalid configured value is ignored (default wins) with a stderr note.
resolve_agent_model() {
  local name="$1" v
  v="$(cfg ".subagents.\"$name\".model" '')"
  if [ -n "$v" ]; then
    if _valid_model "$v"; then echo "$v"; return; fi
    echo "WARN: subagents.$name.model='$v' is not a valid model (opus|sonnet|haiku|claude-*) — using default" >&2
  fi
  _default_agent_model "$name"
}

# TSV: name<TAB>resolved-model for every ow-owned agent (drives apply_agent_models).
emit_agent_models() {
  local a
  for a in $OW_OWNED_AGENTS; do
    printf '%s\t%s\n' "$a" "$(resolve_agent_model "$a")"
  done
}

# ── command (slash-command) model resolution ─────────────────────────────────
# The model each /ow-* slash command runs on. Injected into the GENERATED shim
# frontmatter (.claude/commands/<verb>.md) by generate_shims — NOT into the spec.
# Default `commands.model` (inherit ⇒ emit no `model:` line, command follows the
# session model) with per-command `commands.overrides.<verb>`.
# Valid values: the family aliases, a full claude-* id, or the literal `inherit`.
_valid_command_model() { case "$1" in inherit) return 0 ;; *) _valid_model "$1" ;; esac; }

resolve_command_model() {
  local verb="$1" v
  v="$(cfg ".commands.overrides.\"$verb\"" '')"
  [ -n "$v" ] || v="$(cfg '.commands.model' '')"
  [ -n "$v" ] || v="inherit"          # built-in default: follow the session model
  if _valid_command_model "$v"; then echo "$v"; return; fi
  echo "WARN: command model '$v' for '$verb' invalid (opus|sonnet|haiku|claude-*|inherit) — using inherit" >&2
  echo inherit
}

# TSV: verb<TAB>resolved-model for every command spec under .ow/commands/.
emit_command_models() {
  local f verb
  for f in "$ROOT/.ow/commands"/*.md; do
    [ -e "$f" ] || continue
    verb="$(basename "$f" .md)"
    printf '%s\t%s\n' "$verb" "$(resolve_command_model "$verb")"
  done
}

emit_submodules() {
  yq -r '.submodules[]? | [.name // "", .path // "", .branch // ""] | @tsv' "$CONFIG"
}

selftest() {
  local fail=0
  [ -f "$CONFIG" ] || { echo "FAIL: config missing"; fail=1; }
  [ -d "$VAULT_ABS" ] || { echo "FAIL: vault dir missing: $VAULT_ABS (run /ow-init)"; fail=1; }
  for d in "$INDEX_DIR" "$PRD_DIR" "$PLAN_DIR" "$FIX_DIR"; do
    [ -d "$d" ] || { echo "WARN: vault subdir missing: $d"; }
  done
  command -v jq >/dev/null 2>&1 || echo "WARN: jq not installed (--json mode unavailable)"
  [ "$fail" -eq 0 ] && echo "OK: ow-paths selftest passed ($ROOT)"
  return "$fail"
}

case "$MODE" in
  shell) emit_shell ;;
  json) emit_json ;;
  check) v="${!CHECK_KEY:-}"; [ -n "$v" ] && printf '%s\n' "$v" || { echo "unknown key: $CHECK_KEY" >&2; exit 2; } ;;
  rules) emit_rules ;;
  subagents) emit_subagents ;;
  agent_model) resolve_agent_model "$AGENT_NAME" ;;
  agent_models) emit_agent_models ;;
  command_model) resolve_command_model "$CMD_VERB" ;;
  command_models) emit_command_models ;;
  submodules) emit_submodules ;;
  selftest) selftest ;;
esac
