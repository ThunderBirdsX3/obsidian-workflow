#!/usr/bin/env bash
# obsidian-workflow test — smoke tests to verify the toolkit works correctly
#
# Usage:
#   bash scripts/test.sh               # run all tests
#   bash scripts/test.sh --verbose     # show details for each test
#   bash scripts/test.sh --filter <kw> # only tests matching keyword
#
# Exit code: 0 if all pass, 1 if any fail

set -uo pipefail   # not -e because we want to count failures
trap '' SIGPIPE 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

VERBOSE=0
FILTER=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -v|--verbose) VERBOSE=1; shift ;;
    --filter)     FILTER="$2"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -9; exit 0 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

declare -i PASS=0 FAIL=0 SKIP=0
FAILED_NAMES=()

c_bold='\033[1m'; c_reset='\033[0m'
c_green='\033[32m'; c_red='\033[31m'; c_dim='\033[2m'

# runs each test in a subshell with pipefail disabled so grep -q closing a pipe
# early (SIGPIPE in the producer) doesn't trip the test as failed.
run() {
  local name="$1" cmd="$2"
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
    SKIP+=1; return
  fi
  if ( set +o pipefail 2>/dev/null; eval "$cmd" ) >/tmp/ow-test-output.$$ 2>&1; then
    PASS+=1
    printf "  ${c_green}✓${c_reset} %s\n" "$name"
    [ "$VERBOSE" -eq 1 ] && sed 's/^/      /' /tmp/ow-test-output.$$
  else
    FAIL+=1
    FAILED_NAMES+=("$name")
    printf "  ${c_red}✗${c_reset} %s\n" "$name"
    sed 's/^/      /' /tmp/ow-test-output.$$ | head -5
  fi
  rm -f /tmp/ow-test-output.$$
}

section() { printf "\n${c_bold}%s${c_reset}\n" "$1"; }

# temp workspaces — cleaned on exit
TMP_TARGETS=()
mktarget() { local t; t="$(mktemp -d /tmp/ow-test-XXXXXX)"; TMP_TARGETS+=("$t"); printf '%s' "$t"; }
cleanup() { local t; for t in ${TMP_TARGETS[@]+"${TMP_TARGETS[@]}"}; do rm -rf "$t"; done; }
trap cleanup EXIT

# ═════════════════════════════════════════════════════════════════════════════
section "structure — required files"
run "CLAUDE.md exists"        "[ -f CLAUDE.md ]"
run "README.md exists"        "[ -f README.md ]"
run ".ow.yml exists"          "[ -f .ow.yml ]"
run "install.sh exists"       "[ -f install.sh ]"
run "STANDARD.md exists"      "[ -f .ow/STANDARD.md ]"
for d in policies checklists templates commands rules; do
  run ".ow/$d/ exists"        "[ -d .ow/$d ]"
done
for s in ow-paths.sh ow-claude-manifest.sh ow-config-merge.sh ow-upgrade.sh; do
  run "scripts/$s exists+x"   "[ -x scripts/$s ]"
done
run "vault skeleton exists"   "[ -d docs/vault/00-Index ]"
for s in ow-paths ow-claude-manifest ow-config-merge ow-upgrade; do
  run "bash -n scripts/$s.sh" "bash -n scripts/$s.sh"
done
run "bash -n install.sh"      "bash -n install.sh"

# ═════════════════════════════════════════════════════════════════════════════
section "config — .ow.yml"
run "yq parses .ow.yml"             "yq '.' .ow.yml >/dev/null"
run "subagents map form (model:)"   "yq -e '.subagents.docs.model' .ow.yml >/dev/null"
run "commands block present"        "yq -e '.commands.model' .ow.yml >/dev/null"
run "commands overrides present"    "yq -e '.commands.overrides.ow-plan' .ow.yml >/dev/null"
run "all subagent models valid"     "! yq -r '.subagents[] | .model // empty' .ow.yml | grep -vE '^(opus|sonnet|haiku|claude-.*)$'"
run "all command overrides valid"   "! yq -r '.commands.overrides[]' .ow.yml | grep -vE '^(opus|sonnet|haiku|inherit|claude-.*)$'"

# ═════════════════════════════════════════════════════════════════════════════
section "command inventory — specs ↔ shims"
run "22 command specs"  "[ \$(ls .ow/commands/ow-*.md | wc -l) -eq 22 ]"
run "22 command shims"  "[ \$(ls .claude/commands/ow-*.md | wc -l) -eq 22 ]"
run "shim ↔ spec 1:1"   "diff <(ls .ow/commands | sort) <(ls .claude/commands/ow-*.md | xargs -n1 basename | sort)"
run "every shim exactly one @-include"  "! grep -c '^@' .claude/commands/ow-*.md | grep -v ':1\$'"
run "every shim @ points at its spec"   "for f in .claude/commands/ow-*.md; do v=\$(basename \"\$f\" .md); grep -qx \"@.ow/commands/\$v.md\" \"\$f\" || { echo \"\$f\"; exit 1; }; done"
run "OW-PHASE0 marker in all 22 specs"  "[ \$(grep -l 'OW-PHASE0:' .ow/commands/ow-*.md | wc -l) -eq 22 ]"
# conformance: PHASE0 preamble identical across specs. Allowed variation: the
# `--rules <area>` arg. Exempt: ow-init (the one command that runs before config
# exists — its PHASE0 must not STOP on resolver failure).
run "PHASE0 preamble identical across specs (modulo rules area; ow-init exempt)" \
    "[ \$(ls .ow/commands/ow-*.md | grep -v ow-init | while read -r f; do sed -n '/OW-PHASE0:/,/^\`\`\`\$/p' \"\$f\" | sed 's/--rules [a-z-]*/--rules AREA/' | md5; done | sort -u | wc -l) -eq 1 ]"

# ═════════════════════════════════════════════════════════════════════════════
section "agents"
run "9 agent files"  "[ \$(ls .claude/agents/*.md | wc -l) -eq 9 ]"
run "agent frontmatter: name+description+model+tools" \
    "for f in .claude/agents/*.md; do for k in name description model tools; do grep -q \"^\$k:\" \"\$f\" || { echo \"\$f missing \$k\"; exit 1; }; done; done"
run "agent models match resolver" \
    "bash scripts/ow-paths.sh --agent-models | while IFS=\$'\t' read -r n m; do grep -q \"^model: \$m\$\" \".claude/agents/\$n.md\" || { echo \"\$n: file != \$m\"; exit 1; }; done"

# ═════════════════════════════════════════════════════════════════════════════
section "resolver — ow-paths.sh"
run "--shell evals clean"        "eval \"\$(bash scripts/ow-paths.sh --shell)\" && [ -n \"\$VAULT_ABS\" ]"
run "--selftest passes"          "bash scripts/ow-paths.sh --selftest"
run "--subagents lists 4 always-on" "[ \$(bash scripts/ow-paths.sh --subagents | wc -l) -eq 4 ]"
run "--agent-models 9 rows, valid"  "[ \$(bash scripts/ow-paths.sh --agent-models | grep -cE '	(opus|sonnet|haiku|claude-.*)\$') -eq 9 ]"
run "--command-models 22 rows"   "[ \$(bash scripts/ow-paths.sh --command-models | wc -l) -eq 22 ]"
run "--command-model override (ow-plan=opus)"  "[ \"\$(bash scripts/ow-paths.sh --command-model ow-plan)\" = opus ]"
run "--command-model default (ow-doc=inherit)" "[ \"\$(bash scripts/ow-paths.sh --command-model ow-doc)\" = inherit ]"
run "--agent-model docs=sonnet"  "[ \"\$(bash scripts/ow-paths.sh --agent-model docs)\" = sonnet ]"
T_CFG="$(mktarget)"
cat > "$T_CFG/.ow.yml" <<'EOF'
project: { name: t, slug: t }
vault_path: docs/vault
subagents:
  docs: true
  verifier: { enabled: true, model: gpt-5 }
commands:
  model: inherit
  overrides: { ow-x: gpt-5 }
EOF
run "scalar subagent → default model"     "[ \"\$(OW_ROOT=$T_CFG bash scripts/ow-paths.sh --agent-model docs)\" = sonnet ]"
run "invalid agent model → default+WARN"  "out=\$(OW_ROOT=$T_CFG bash scripts/ow-paths.sh --agent-model verifier 2>&1); echo \"\$out\" | grep -q WARN && echo \"\$out\" | tail -1 | grep -qx sonnet"
run "invalid command model → inherit+WARN" "out=\$(OW_ROOT=$T_CFG bash scripts/ow-paths.sh --command-model ow-x 2>&1); echo \"\$out\" | grep -q WARN && echo \"\$out\" | tail -1 | grep -qx inherit"

# ═════════════════════════════════════════════════════════════════════════════
section "manifest — shim gen + model sync"
T_GEN="$(mktarget)"
mkdir -p "$T_GEN/.ow" "$T_GEN/scripts"
cp -R .ow/commands "$T_GEN/.ow/commands"
cp .ow.yml "$T_GEN/.ow.yml"
cp scripts/ow-paths.sh "$T_GEN/scripts/"
run "regen shims == committed shims (no drift)" \
    ". scripts/ow-claude-manifest.sh; generate_shims '$T_GEN/.ow/commands' '$T_GEN' && diff -r .claude/commands '$T_GEN/.claude/commands'"
T_AGT="$(mktarget)"
mkdir -p "$T_AGT/scripts" "$T_AGT/.claude"
cp -R .claude/agents "$T_AGT/.claude/agents"
cp .ow.yml "$T_AGT/.ow.yml"
cp scripts/ow-paths.sh "$T_AGT/scripts/"
run "apply_agent_models idempotent (no changes on synced tree)" \
    ". scripts/ow-claude-manifest.sh; out=\$(apply_agent_models '$T_AGT'); [ -z \"\$out\" ]"
run "apply_agent_models syncs a drifted model line" \
    "sed -i '' 's/^model: sonnet/model: haiku/' '$T_AGT/.claude/agents/docs.md'; . scripts/ow-claude-manifest.sh; apply_agent_models '$T_AGT' | grep -q 'docs → sonnet' && grep -q '^model: sonnet' '$T_AGT/.claude/agents/docs.md'"
run "--apply CLI runs end-to-end"  "bash scripts/ow-claude-manifest.sh --apply '$T_GEN' >/dev/null && [ \$(ls '$T_GEN/.claude/commands' | wc -l) -eq 22 ]"
run "--manifest lists owned paths" "[ \$(bash scripts/ow-claude-manifest.sh --manifest | wc -l) -eq 31 ]"

# ═════════════════════════════════════════════════════════════════════════════
section "config-merge — additive backfill"
T_MRG="$(mktarget)"
printf 'project:\n  name: keep-me\n\nsubagents:\n  docs: true\n' > "$T_MRG/old.yml"
run "missing blocks appended"   ". scripts/ow-config-merge.sh; merge_config_blocks '$T_MRG/old.yml' .ow.yml | grep -q '+ commands' && yq -e '.commands.model' '$T_MRG/old.yml' >/dev/null"
run "existing block untouched"  "yq -r '.project.name' '$T_MRG/old.yml' | grep -qx keep-me && yq -r '.subagents.docs' '$T_MRG/old.yml' | grep -qx true"
run "merge idempotent"          ". scripts/ow-config-merge.sh; out=\$(merge_config_blocks '$T_MRG/old.yml' .ow.yml); [ -z \"\$out\" ]"

# ═════════════════════════════════════════════════════════════════════════════
section "install — end to end"
T_INS="$(mktarget)"
run "install.sh completes"      "bash install.sh '$T_INS'"
run "installed: 22 shims"       "[ \$(ls '$T_INS/.claude/commands/'ow-*.md | wc -l) -eq 22 ]"
run "installed: 9 agents"       "[ \$(ls '$T_INS/.claude/agents/'*.md | wc -l) -eq 9 ]"
run "installed: opus pinned on ow-plan shim"  "grep -q '^model: opus' '$T_INS/.claude/commands/ow-plan.md'"
run "installed: no model line on ow-doc shim" "! grep -q '^model:' '$T_INS/.claude/commands/ow-doc.md'"
run "installed: selftest passes" "OW_ROOT='$T_INS' bash '$T_INS/scripts/ow-paths.sh' --selftest"
run "installed: gitignore block" "grep -q '^.ow-backup/' '$T_INS/.gitignore'"
run "reinstall keeps .ow.yml"    "yq -i '.project.name = \"mine\"' '$T_INS/.ow.yml' && bash install.sh '$T_INS' >/dev/null && [ \"\$(yq -r '.project.name' '$T_INS/.ow.yml')\" = mine ]"

# ═════════════════════════════════════════════════════════════════════════════
section "upgrade — end to end"
T_UPG="$(mktarget)"
bash install.sh "$T_UPG" >/dev/null 2>&1
# simulate legacy install: bool subagents, no commands block, stale shim,
# customized specialized agent, user's own agent
cat > "$T_UPG/.ow.yml" <<'EOF'
project: { name: legacy, slug: legacy }
vault_path: docs/vault
subagents:
  docs: true
  verifier: true
  security: true
  gh-issue: true
submodules: []
EOF
echo stale > "$T_UPG/.claude/commands/ow-plan.md"
echo "CUSTOM-MARK" >> "$T_UPG/.claude/agents/backend.md"
printf -- '---\nname: my-own\nmodel: opus\n---\nmine\n' > "$T_UPG/.claude/agents/my-own.md"
run "--dry-run makes no changes"   "bash scripts/ow-upgrade.sh '$T_UPG' --dry-run >/dev/null && grep -q stale '$T_UPG/.claude/commands/ow-plan.md' && ! yq -e '.commands' '$T_UPG/.ow.yml' >/dev/null 2>&1"
run "upgrade completes"            "bash scripts/ow-upgrade.sh '$T_UPG'"
run "upgrade: commands block backfilled"   "yq -e '.commands.overrides.ow-plan' '$T_UPG/.ow.yml' >/dev/null"
run "upgrade: legacy values kept"          "[ \"\$(yq -r '.project.name' '$T_UPG/.ow.yml')\" = legacy ]"
run "upgrade: stale shim regenerated"      "grep -q '^model: opus' '$T_UPG/.claude/commands/ow-plan.md'"
run "upgrade: customized specialized agent kept" "grep -q CUSTOM-MARK '$T_UPG/.claude/agents/backend.md'"
run "upgrade: user custom agent untouched" "grep -q mine '$T_UPG/.claude/agents/my-own.md'"
run "upgrade: backup created"              "[ \$(ls -d '$T_UPG/.ow-backup/'*/ | wc -l) -eq 1 ]"
run "rollback restores pre-upgrade state"  "bash scripts/ow-upgrade.sh '$T_UPG' --rollback >/dev/null && grep -qx stale '$T_UPG/.claude/commands/ow-plan.md' && ! yq -e '.commands' '$T_UPG/.ow.yml' >/dev/null 2>&1"
run "second upgrade idempotent"            "bash scripts/ow-upgrade.sh '$T_UPG' >/dev/null && out=\$(bash scripts/ow-upgrade.sh '$T_UPG'); ! echo \"\$out\" | grep -qE '  \+ |model: .* → '"

# ═════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}ผลรวม:${c_reset} ${c_green}%d pass${c_reset}" "$PASS"
[ "$FAIL" -gt 0 ] && printf " ${c_red}%d fail${c_reset}" "$FAIL"
[ "$SKIP" -gt 0 ] && printf " ${c_dim}%d skipped (filter)${c_reset}" "$SKIP"
printf "\n"
if [ "$FAIL" -gt 0 ]; then
  printf "${c_red}failed:${c_reset}\n"
  for n in "${FAILED_NAMES[@]}"; do printf "  - %s\n" "$n"; done
  exit 1
fi
exit 0
