#!/usr/bin/env bash
# ow-paths — Single source of truth for config + vault paths
# Resolves .ow.yml + sensible defaults
# Used by all commands (instead of grep-yaml-inline)
#
# Output modes:
#   --shell            eval-able shell vars (default)
#   --json             JSON object (for jq pipelines)
#   --paths-only       only path-related keys
#   --check <key>      print single value (e.g., --check VAULT_PATH)
#   --submodules       TSV: path<TAB>read_only<TAB>branch (one row per submodule; nothing if none)
#   --subagents        enabled subagent names (one per line)
#   --agent-model <name>  resolved AI model for one agent (config override > default)
#   --agent-models     TSV: name<TAB>model for every agent name obsidian-workflow knows a default for
#   --command-model <verb>  resolved AI model for one slash command (inherit ⇒ no pin)
#   --command-models   TSV: verb<TAB>model for every command spec
#   --rules <area>     resolved rule file paths for <area> (.ow/rules)
#   --rules-expected <area>  canonical expected rule path for <area> + present|absent,
#                            printed even when the file does not exist (TSV)
#   --rules-validate   assert every rule in .ow.yml rules.files resolves to a real
#                      file; non-zero exit + FAIL lines on any miss (#22)
#   --selftest         assert rooting + list/depth-4 reads + rules-validate; non-zero on failure
#   --help             show this
#
# v0.7: yq is a HARD prerequisite (no awk fallback). The resolver roots itself at
# the first ancestor containing .ow.yml and fails closed (non-zero exit)
# rather than emitting silent default paths from a mis-rooted run.

set -euo pipefail

# ── root resolution ──────────────────────────────────────────────────────────
# Project root = first ancestor containing .ow.yml (the real config anchor).
# Honors OW_ROOT; walk-up handles a nested subdir AND a submodule monorepo
# (config lives at the superproject root, not the submodule's git toplevel).
# git-toplevel is only a last-resort fallback before the fail-closed assert below.
resolve_root() {
  # Walk up FROM ${OW_ROOT:-$PWD} (OW_ROOT is a start hint, not a verbatim
  # override) so a relative OW_ROOT=. set in the env still resolves correctly
  # from a nested subdir. Always returns an ABSOLUTE path.
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
SHARED="${ROOT}/.ow.yml"

MODE="shell"
CHECK_KEY=""
RULES_AREA=""
AGENT_NAME=""
CMD_VERB=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --shell)      MODE=shell; shift ;;
    --json)       MODE=json; shift ;;
    --paths-only) MODE=paths; shift ;;
    --submodules) MODE=submodules; shift ;;
    --subagents)  MODE=subagents; shift ;;
    --agent-model)  MODE=agent_model; AGENT_NAME="${2:-}"; shift; [ "$#" -gt 0 ] && shift ;;
    --agent-models) MODE=agent_models; shift ;;
    --command-model)  MODE=command_model; CMD_VERB="${2:-}"; shift; [ "$#" -gt 0 ] && shift ;;
    --command-models) MODE=command_models; shift ;;
    --rules)      MODE=rules; RULES_AREA="${2:-}"; shift; [ "$#" -gt 0 ] && shift ;;
    --rules-expected) MODE=rules_expected; RULES_AREA="${2:-}"; shift; [ "$#" -gt 0 ] && shift ;;
    --rules-validate) MODE=rules_validate; shift ;;
    --selftest)   MODE=selftest; shift ;;
    --check)      MODE=check; CHECK_KEY="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | head -27; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── hard prerequisites (v0.7): yq + a locatable config ───────────────────────
# yq is a HARD prerequisite — the resolver parses YAML lists + nested keys the old
# awk fallback could not. Fail loudly rather than silently degrade. (--help exits
# above, before this gate, so docs stay reachable on a yq-less machine.)
if ! command -v yq >/dev/null 2>&1; then
  cat >&2 <<'YQERR'
FATAL: yq not found — obsidian-workflow v0.7 requires yq (YAML parser).
  Install: brew install yq  |  apt install yq  |  https://github.com/mikefarah/yq
  Without yq, list-shaped config (submodules, roles, verification_matrix) reads as
  empty, and even scalar keys (project.name, vault_path, ow.version) cannot be
  resolved reliably. This is a deliberate v0.7 breaking change (was: lossy awk fallback).
YQERR
  exit 3
fi

# Fail-closed root assert: never emit silent default paths from a mis-rooted run.
if [ ! -f "$SHARED" ]; then
  cat >&2 <<EOF
FATAL: .ow.yml not found (mis-rooted resolver).
  Searched up from: $PWD
  Resolved root:    $ROOT
  Run /<prefix>-init at the project root, or export OW_ROOT=<project-root>.
EOF
  exit 2
fi

# ── helpers ──────────────────────────────────────────────────────────────────

yget() {
  # yget <file> <yaml-path>  (e.g., yget .ow.yml project.name)
  # yq is guaranteed present by the v0.7 hard-gate above — no awk fallback.
  local file="$1" path="$2"
  [ -f "$file" ] || { echo ""; return; }
  local v
  v=$(yq ".$path // \"\"" "$file" 2>/dev/null | tr -d '"')
  [ "$v" = "null" ] && v=""
  echo "$v"
}

# .ow.yml value, else default
get() {
  local key="$1" default="$2" v
  v="$(yget "$SHARED" "$key" 2>/dev/null || echo "")"
  if [ -n "$v" ]; then echo "$v"; else echo "$default"; fi
}

# Portable lexical abspath (BSD has no `realpath -m`): resolve relative-to-ROOT,
# normalize ./ .. // — no symlink resolution, no existence requirement. Used by the
# template-chain de-duplication.
_abspath() {
  local p="$1"
  case "$p" in /*) ;; *) p="$ROOT/$p" ;; esac
  printf '%s' "$p" | awk 'BEGIN{RS="/"}
    { if($0==""||$0=="."){next} if($0==".."){if(n>0)n--; next} a[n++]=$0 }
    END{ s=""; for(i=0;i<n;i++) s=s"/"a[i]; if(s=="")s="/"; print s }'
}

# ── resolve all paths ────────────────────────────────────────────────────────

PROJECT_NAME=$(get "project.name" "unknown-project")
PROJECT_SLUG=$(get "project.slug" "unknown-project")
PROJECT_LANG=$(get "project.language" "th")
# Vault document language. Unset ⇒ inherits PROJECT_LANG (already resolved above),
# so a project that never sets the key keeps its existing behaviour.
VAULT_LANG=$(get "project.vault_language" "$PROJECT_LANG")
PROJECT_TZ=$(get "project.timezone" "Asia/Bangkok")

MODE_VAL=$(get "mode" "standalone")

# vault_path may be relative to the repo root or absolute (a vault outside the repo)
VAULT_PATH=$(get "vault_path" "docs/obsidian-vault")

# Absolute vault path
if [[ "$VAULT_PATH" = /* ]]; then VAULT_ABS="$VAULT_PATH"; else VAULT_ABS="$ROOT/$VAULT_PATH"; fi

# obsidian-workflow metadata (v0.4.1+: was under `standard.*`; legacy keys still readable via fallback)
OW_VERSION=$(yget "$SHARED" "ow.version")
[ -z "$OW_VERSION" ] && OW_VERSION=$(yget "$SHARED" "standard.ow_version")     # legacy
OW_SOURCE=$(yget "$SHARED" "ow.source")
[ -z "$OW_SOURCE" ] && OW_SOURCE=$(yget "$SHARED" "standard.source")                 # legacy
OW_LAST_SYNC=$(yget "$SHARED" "ow.last_synced")
[ -z "$OW_LAST_SYNC" ] && OW_LAST_SYNC=$(yget "$SHARED" "standard.last_synced")      # legacy

# Common derived paths — vault_dirs.<key> overrides the default folder name (#16);
# an empty/absent vault_dirs map reproduces the v0.6 numbered defaults exactly.
vdir() { local v; v=$(get "vault_dirs.$1" ""); echo "${v:-$2}"; }
IDX_DIR="$VAULT_ABS/$(vdir index 00-Index)"
IMPL_STATUS="$IDX_DIR/IMPLEMENTATION-STATUS.md"
PRD_DIR="$VAULT_ABS/$(vdir prd 10-PRD)"
FEAT_DIR="$VAULT_ABS/$(vdir features 20-Features)"
ROLE_DIR="$VAULT_ABS/$(vdir roles 30-Roles)"
FN_DIR="$VAULT_ABS/$(vdir functions 40-Functions)"
PHASE_DIR="$VAULT_ABS/$(vdir phases 50-Phases)"
FLOW_DIR="$VAULT_ABS/$(vdir flows 60-Flows)"
REF_DIR="$VAULT_ABS/$(vdir reference 70-Reference)"
DS_DIR="$REF_DIR/DesignSystem"
PLAN_DIR="$VAULT_ABS/$(vdir plans 80-ImplementPlan)"
FIX_DIR="$VAULT_ABS/$(vdir fixes 85-FixLog)"
TEST_DIR="$VAULT_ABS/$(vdir tests 90-TestPlan)"
HANDOFF_DIR="$VAULT_ABS/$(vdir handoffs 95-Handoff)"

# Today's date (generic — log/folder naming, etc.)
TODAY=$(date +%Y-%m-%d)

# Templates lookup chain (v0.4+: the shipped snapshot lives under .ow/)
# Backward-compat: if a legacy layout (root `standards/`) still exists, fall back to it
# so projects installed before v0.4 keep working until they run migration
TEMPLATES_PROJECT="$ROOT/templates"
# Resolve TEMPLATES_SNAPSHOT via fallback chain (newest layout first)
if [ -d "$ROOT/.ow/templates" ]; then
  TEMPLATES_SNAPSHOT="$ROOT/.ow/templates"            # v0.4 current (flat)
elif [ -d "$ROOT/.ow/standards/templates" ]; then
  TEMPLATES_SNAPSHOT="$ROOT/.ow/standards/templates"  # v0.4-intermediate legacy
elif [ -d "$ROOT/standards/templates" ]; then
  TEMPLATES_SNAPSHOT="$ROOT/standards/templates"            # pre-v0.4 legacy
else
  TEMPLATES_SNAPSHOT="$ROOT/.ow/templates"            # default for fresh install
fi

# Commands lookup chain (v0.4.1+: commands moved into .ow/)
# Order: project override (root) → .ow/commands → legacy fallback
# COMMANDS_DIR_PRIMARY: where AI shims should @-reference (the canonical source)
# COMMANDS_DIR_OVERRIDE: optional user override layer (root commands/)
if [ -d "$ROOT/.ow/commands" ]; then
  COMMANDS_DIR_PRIMARY="$ROOT/.ow/commands"   # v0.4.1 current
elif [ -d "$ROOT/commands" ]; then
  COMMANDS_DIR_PRIMARY="$ROOT/commands"             # pre-v0.4.1 legacy
else
  COMMANDS_DIR_PRIMARY="$ROOT/.ow/commands"   # default for fresh install
fi
COMMANDS_DIR_OVERRIDE="$ROOT/commands"

# ── guardrails block as compact JSON (#10; consumers gate on it in #13) ───────
GUARDRAILS_JSON=$(yq -o=json -I=0 '.guardrails // {}' "$SHARED" 2>/dev/null || echo '{}')
if [ -z "$GUARDRAILS_JSON" ] || [ "$GUARDRAILS_JSON" = "null" ]; then GUARDRAILS_JSON='{}'; fi

# ── command prefix (#10; shim-filename rename itself is deferred → P2) ────────
COMMAND_PREFIX=$(get "command_prefix" "ow")

# ── new optional config blocks (#16) — empty/absent ⇒ v0.6 behavior ──────────
# Emitted as compact JSON so consumers gate on them; an absent block ⇒ "{}"/"[]".
_json_block() { local v; v=$(yq -o=json -I=0 "$2 // $3" "$1" 2>/dev/null || echo "$3"); [ -z "$v" ] || [ "$v" = "null" ] && v="$3"; printf '%s' "$v"; }
VERIFICATION_MATRIX_JSON=$(_json_block "$SHARED" '.verification_matrix' '[]')   # empty ⇒ repo-convention build/test
INTEGRITY_GATE_JSON=$(_json_block "$SHARED" '.integrity_gate' '{}')
TEST_CREDENTIALS_JSON=$(_json_block "$SHARED" '.test_credentials' '{}')         # SCHEMA only — values live in the env file
VERSION_BUMP_JSON=$(_json_block "$SHARED" '.version_bump' '{}')
# multi-person git sync (auto_sync / strategy / auto_resolve / push_retry) — absent
# block ⇒ "{}" and scripts/ow-git-sync.sh falls back to its built-in defaults
GIT_SYNC_JSON=$(_json_block "$SHARED" '.git' '{}')
# test-credentials redaction + env file (schema-level)
TEST_ENV_FILE=$(get "test_credentials.env_file" "")
CRED_REDACT=$(get "test_credentials.redact" "true")

# ── template chain (#10): ordered, de-duplicated, legacy-path-normalized ──────
# Built from template_lookup: when present, else the default 2-tier chain. The
# legacy `.ow/standards/templates` entry normalizes to `.ow/templates`
# (newest flat layout). Colon-separated, highest priority first.
_TC=""
_add_tc() {
  local d="$1"
  case "$d" in */.ow/standards/templates) d="${d%/standards/templates}/templates" ;; esac
  d="$(_abspath "$d")"
  case ":$_TC:" in *":$d:"*) ;; *) _TC="${_TC:+$_TC:}$d" ;; esac
}
_tl_count=$(yq '(.template_lookup // []) | length' "$SHARED" 2>/dev/null || echo 0)
if [ "${_tl_count:-0}" != "0" ]; then
  while IFS= read -r _entry; do
    [ -n "$_entry" ] && _add_tc "$ROOT/$_entry"
  done < <(yq -r '.template_lookup[]?' "$SHARED" 2>/dev/null)
else
  _add_tc "$TEMPLATES_PROJECT"; _add_tc "$TEMPLATES_SNAPSHOT"
fi
TEMPLATE_CHAIN="$_TC"

# Subagents (enabled list). Two config shapes are accepted, per agent:
#   scalar:  subagents.<name>: true              (v0.6 form — model from built-in default)
#   map:     subagents.<name>: {enabled: true, model: opus}   (v0.8 form — model override)
ENABLED_AGENTS=""
for a in docs verifier security gh-issue design backend frontend mobile test-runner; do
  val=$(yget "$SHARED" "subagents.$a")              # 'true' for scalar form; multiline for map
  en=$(yget "$SHARED" "subagents.$a.enabled")       # 'true' only for map form
  if [ "$val" = "true" ] || [ "$en" = "true" ]; then ENABLED_AGENTS="${ENABLED_AGENTS}${a} "; fi
done
ENABLED_AGENTS="${ENABLED_AGENTS% }"

# ── submodules accessor ──────────────────────────────────────────────────────
# Emit `path<TAB>read_only<TAB>branch` TSV, one row per submodule. `branch` is the
# submodule's own configured mainline (.ow.yml submodules[].branch, e.g.
# develop/master) that worktree-mode merges + pushes target (#31); empty if unset.
# Single-repo (submodules: []) emits nothing and exits 0 — so callers stop
# parsing YAML inline with jq (which silently no-ops on YAML; see issue #4).
emit_submodules() {
  [ -f "$SHARED" ] || return 0
  yq -r '.submodules[]? | [.path, (.read_only // false), (.branch // "")] | @tsv' "$SHARED" 2>/dev/null || true
}

# ── selftest ─────────────────────────────────────────────────────────────────
# Prove the resolver can (a) locate .ow.yml via walk-up, (b) read a list,
# (c) read a depth-4 key — the three things the old awk fallback could not do.
# Exits non-zero on any failure. (Mis-root already exits 2 before reaching here.)
run_selftest() {
  local fail=0
  [ -f "$SHARED" ] || { echo "SELFTEST FAIL: .ow.yml not located (root=$ROOT)" >&2; fail=1; }
  yq '.' "$SHARED" >/dev/null 2>&1 || { echo "SELFTEST FAIL: cannot parse $SHARED" >&2; fail=1; }
  # (b) list read — submodules must parse as a sequence or be absent/null
  local t; t=$(yq '.submodules | type' "$SHARED" 2>/dev/null || echo err)
  case "$t" in "!!seq"|"!!null") : ;; *) echo "SELFTEST FAIL: .submodules not a list (got: $t)" >&2; fail=1 ;; esac
  # (c) depth-4 capability via an isolated fixture (config may have no depth-4 key)
  local tf; tf="$(mktemp)"
  printf 'a:\n  b:\n    c:\n      d: deep-ok\n' > "$tf"
  local d4; d4=$(yq '.a.b.c.d' "$tf" 2>/dev/null || echo "")
  rm -f "$tf"
  [ "$d4" = "deep-ok" ] || { echo "SELFTEST FAIL: depth-4 read returned '$d4' (expected deep-ok)" >&2; fail=1; }
  # (d) every registered rule resolves to a real file (#22)
  validate_rules || { echo "SELFTEST FAIL: a registered rule in .ow.yml rules.files does not resolve" >&2; fail=1; }
  if [ "$fail" -ne 0 ]; then exit 1; fi
  echo "SELFTEST PASS: root=$ROOT  config=$SHARED  (walk-up + lists + depth-4 + rules-registry readable)"
}

# ── rules accessor (#10) ─────────────────────────────────────────────────────
# Print rule file paths for <area> from .ow/rules/, one per line. Binds both by filename (<area>.md) and by `applies_to`
# front-matter (area or '*'). Prints nothing + exits 0 when none exist (#17 builds
# the full taxonomy on top of this accessor).
_applies_to() {
  local f="$1" area="$2" fm
  fm=$(awk 'NR==1&&/^---[[:space:]]*$/{f=1;next} f&&/^---[[:space:]]*$/{exit} f{print}' "$f")
  [ -n "$fm" ] || return 1
  printf '%s\n' "$fm" | yq -r '[.applies_to] | flatten | .[]' 2>/dev/null | grep -qxF "$area" && return 0
  printf '%s\n' "$fm" | yq -r '[.applies_to] | flatten | .[]' 2>/dev/null | grep -qxF '*' && return 0
  return 1
}
emit_rules() {
  local area="$1"; [ -n "$area" ] || return 0
  local d="$ROOT/.ow/rules" f
  # 1) direct <area>.md
  [ -f "$d/$area.md" ] && printf '%s\n' "$d/$area.md"
  # 2) any other rule file whose applies_to includes the area or '*'
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -e "$f" ] || continue
    [ "$f" = "$d/$area.md" ] && continue
    _applies_to "$f" "$area" && printf '%s\n' "$f"
  done
  return 0
}

# ── rules expected-path (#22) ────────────────────────────────────────────────
# Print the canonical expected rule path for <area> + present|absent, ALWAYS — even
# when the file does not exist. Lets a command NAME the specific file (not just the
# directory) and surface "create this to add project <area> conventions".
emit_rules_expected() {
  local area="$1"; [ -n "$area" ] || return 0
  local rdir; rdir=$(yget "$SHARED" "rules.dir"); rdir="${rdir:-.ow/rules}"
  local p="$rdir/$area.md"
  printf '%s\t%s\n' "$p" "$([ -f "$ROOT/$p" ] && echo present || echo absent)"
}

# ── rules registry validator (#22) ───────────────────────────────────────────
# A rule registered in .ow.yml rules.files MUST resolve to a real file. A
# registered-but-unresolved rule means a project's load-bearing convention is being
# silently dropped — fail loud (non-zero + FAIL lines) instead. Empty list ⇒ pass.
validate_rules() {
  local rdir; rdir=$(yget "$SHARED" "rules.dir"); rdir="${rdir:-.ow/rules}"
  local fail=0 entry path
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in
      /*) path="$entry" ;;                       # absolute as-is
      "$rdir"/*) path="$ROOT/$entry" ;;          # already rules-dir-relative to root
      *) path="$ROOT/$rdir/$entry" ;;            # bare filename → under rules.dir
    esac
    if [ ! -f "$path" ]; then
      echo "FAIL: registered rule '$entry' does not resolve (expected: $path)" >&2
      fail=1
    fi
  done < <(yq -r '.rules.files[]?' "$SHARED" 2>/dev/null)
  [ "$fail" -eq 0 ] || return 1
  return 0
}

# ── subagents accessor (#10) ─────────────────────────────────────────────────
emit_subagents() { local a; for a in $ENABLED_AGENTS; do printf '%s\n' "$a"; done; }

# ── agent model resolution ───────────────────────────────────────────────────
# Resolve the AI model an agent runs on. The names below are the ones obsidian-workflow knows a
# default for — the always-on four it ships, plus the five well-known specializations
# /ow-agent create writes per project. Any other name falls through to sonnet.
# Values are FAMILY ALIASES
# (opus|sonnet|haiku) — no version pin, so each tracks the latest of its family.
# Override per agent in .ow.yml via the map form `subagents.<name>.model: <alias>`.
# Built-in defaults: the security scanner → opus (a
# missed secret/PII leak costs more than the model does), every code/doc/verify/test
# agent → sonnet, the read-only issue reader → haiku.
_default_agent_model() {
  case "$1" in
    security)                                echo opus ;;
    backend|frontend|mobile|design)          echo sonnet ;;
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

# resolve_agent_model <name> — .ow.yml override > built-in default.
# An invalid configured value is ignored (default wins) with a stderr note.
resolve_agent_model() {
  local name="$1" v
  v="$(yget "$SHARED" "subagents.$name.model")"
  if [ -n "$v" ]; then
    if _valid_model "$v"; then echo "$v"; return; fi
    echo "WARN: subagents.$name.model='$v' is not a valid model (opus|sonnet|haiku|claude-*) — using default" >&2
  fi
  _default_agent_model "$name"
}

# TSV: name<TAB>resolved-model for every obsidian-workflow-owned agent (drives apply_agent_models).
emit_agent_models() {
  local a
  for a in docs verifier security gh-issue design backend frontend mobile test-runner; do
    printf '%s\t%s\n' "$a" "$(resolve_agent_model "$a")"
  done
}

# ── command (slash-command) model resolution ─────────────────────────────────
# The model each /<prefix>-* slash command runs on. Injected into the GENERATED shim
# frontmatter (.claude/commands/<verb>.md) by generate_shims — NOT into the verb spec.
# Default `commands.model` (inherit ⇒ emit no `model:` line, command follows the session
# model) with per-command `commands.overrides.<verb>`.
# Valid values: the family aliases, a full claude-* id, or the literal `inherit`.
_valid_command_model() { case "$1" in inherit) return 0 ;; *) _valid_model "$1" ;; esac; }

resolve_command_model() {
  local verb="$1" v
  v="$(yget "$SHARED" "commands.overrides.$verb")"
  [ -n "$v" ] || v="$(yget "$SHARED" "commands.model")"
  [ -n "$v" ] || v="inherit"          # built-in default: follow the session model
  if _valid_command_model "$v"; then echo "$v"; return; fi
  echo "WARN: command model '$v' for '$verb' invalid (opus|sonnet|haiku|claude-*|inherit) — using inherit" >&2
  echo inherit
}

# TSV: verb<TAB>resolved-model for every verb spec under .ow/commands/.
emit_command_models() {
  local f verb
  for f in "$ROOT/.ow/commands"/*.md; do
    [ -e "$f" ] || continue
    verb="$(basename "$f" .md)"
    printf '%s\t%s\n' "$verb" "$(resolve_command_model "$verb")"
  done
}

# ── output ───────────────────────────────────────────────────────────────────

print_var() {
  printf "%s=%s\n" "$1" "$(printf %q "$2")"
}

case "$MODE" in
  shell)
    print_var ROOT             "$ROOT"
    print_var PROJECT_NAME     "$PROJECT_NAME"
    print_var PROJECT_SLUG     "$PROJECT_SLUG"
    print_var PROJECT_LANG     "$PROJECT_LANG"
    print_var VAULT_LANG       "$VAULT_LANG"
    print_var PROJECT_TZ       "$PROJECT_TZ"
    print_var MODE_VAL         "$MODE_VAL"
    print_var VAULT_PATH       "$VAULT_PATH"
    print_var VAULT_ABS        "$VAULT_ABS"
    print_var OW_VERSION    "$OW_VERSION"
    print_var OW_SOURCE     "$OW_SOURCE"
    print_var OW_LAST_SYNC  "$OW_LAST_SYNC"
    print_var IMPL_STATUS      "$IMPL_STATUS"
    print_var PRD_DIR          "$PRD_DIR"
    print_var FEAT_DIR         "$FEAT_DIR"
    print_var FN_DIR           "$FN_DIR"
    print_var PHASE_DIR        "$PHASE_DIR"
    print_var FLOW_DIR         "$FLOW_DIR"
    print_var REF_DIR          "$REF_DIR"
    print_var DS_DIR           "$DS_DIR"
    print_var PLAN_DIR         "$PLAN_DIR"
    print_var FIX_DIR          "$FIX_DIR"
    print_var TEST_DIR         "$TEST_DIR"
    print_var HANDOFF_DIR      "$HANDOFF_DIR"
    print_var TODAY            "$TODAY"
    print_var TEMPLATES_PROJECT "$TEMPLATES_PROJECT"
    print_var TEMPLATES_SNAPSHOT "$TEMPLATES_SNAPSHOT"
    print_var COMMANDS_DIR_PRIMARY  "$COMMANDS_DIR_PRIMARY"
    print_var COMMANDS_DIR_OVERRIDE "$COMMANDS_DIR_OVERRIDE"
    print_var ENABLED_AGENTS   "$ENABLED_AGENTS"
    print_var GUARDRAILS_JSON       "$GUARDRAILS_JSON"
    print_var TEMPLATE_CHAIN        "$TEMPLATE_CHAIN"
    print_var COMMAND_PREFIX        "$COMMAND_PREFIX"
    print_var VERIFICATION_MATRIX_JSON "$VERIFICATION_MATRIX_JSON"
    print_var INTEGRITY_GATE_JSON   "$INTEGRITY_GATE_JSON"
    print_var TEST_CREDENTIALS_JSON "$TEST_CREDENTIALS_JSON"
    print_var VERSION_BUMP_JSON     "$VERSION_BUMP_JSON"
    print_var GIT_SYNC_JSON         "$GIT_SYNC_JSON"
    print_var TEST_ENV_FILE         "$TEST_ENV_FILE"
    print_var CRED_REDACT           "$CRED_REDACT"
    ;;
  json)
    cat <<EOF
{
  "root": "$ROOT",
  "project": {"name":"$PROJECT_NAME","slug":"$PROJECT_SLUG","language":"$PROJECT_LANG","vault_language":"$VAULT_LANG","timezone":"$PROJECT_TZ"},
  "mode": "$MODE_VAL",
  "vault": {"path":"$VAULT_PATH","abs":"$VAULT_ABS"},
  "paths": {
    "impl_status":"$IMPL_STATUS",
    "prd":"$PRD_DIR","features":"$FEAT_DIR","functions":"$FN_DIR",
    "phases":"$PHASE_DIR","flows":"$FLOW_DIR","reference":"$REF_DIR",
    "design_system":"$DS_DIR",
    "plans":"$PLAN_DIR","fixes":"$FIX_DIR","tests":"$TEST_DIR","handoffs":"$HANDOFF_DIR"
  },
  "templates": {"project":"$TEMPLATES_PROJECT","snapshot":"$TEMPLATES_SNAPSHOT"},
  "template_chain": "$TEMPLATE_CHAIN",
  "commands": {"primary":"$COMMANDS_DIR_PRIMARY","override":"$COMMANDS_DIR_OVERRIDE"},
  "command_prefix": "$COMMAND_PREFIX",
  "guardrails": $GUARDRAILS_JSON,
  "verification_matrix": $VERIFICATION_MATRIX_JSON,
  "integrity_gate": $INTEGRITY_GATE_JSON,
  "test_credentials": $TEST_CREDENTIALS_JSON,
  "version_bump": $VERSION_BUMP_JSON,
  "git": $GIT_SYNC_JSON,
  "ow": {"version":"$OW_VERSION","source":"$OW_SOURCE","last_synced":"$OW_LAST_SYNC"},
  "subagents_enabled": "$ENABLED_AGENTS",
  "today": "$TODAY"
}
EOF
    ;;
  paths)
    for k in IMPL_STATUS PRD_DIR FEAT_DIR FN_DIR PLAN_DIR FIX_DIR TEST_DIR HANDOFF_DIR DS_DIR TODAY; do
      print_var "$k" "$(eval echo \$$k)"
    done
    ;;
  check)
    eval echo "\${$CHECK_KEY}"
    ;;
  submodules)
    emit_submodules
    ;;
  subagents)
    emit_subagents
    ;;
  agent_model)
    [ -n "$AGENT_NAME" ] || { echo "Usage: --agent-model <name>" >&2; exit 1; }
    resolve_agent_model "$AGENT_NAME"
    ;;
  agent_models)
    emit_agent_models
    ;;
  command_model)
    [ -n "$CMD_VERB" ] || { echo "Usage: --command-model <verb>" >&2; exit 1; }
    resolve_command_model "$CMD_VERB"
    ;;
  command_models)
    emit_command_models
    ;;
  rules)
    emit_rules "$RULES_AREA"
    ;;
  rules_expected)
    emit_rules_expected "$RULES_AREA"
    ;;
  rules_validate)
    validate_rules
    ;;
  selftest)
    run_selftest
    ;;
esac
