#!/usr/bin/env bash
# obsidian-workflow test — smoke tests to verify the system works correctly
#
# Usage:
#   bash scripts/test.sh              # run all tests
#   bash scripts/test.sh --verbose    # show details for each test
#   bash scripts/test.sh --filter <kw> # only tests matching keyword
#
# Exit code: 0 if all pass, 1 if any fail

set -uo pipefail   # not -e because we want to count failures
# allow grep -q to exit fast without SIGPIPE breaking upstream cmd
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
    -h|--help)
      grep '^#' "$0" | head -10; exit 0 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# ── tally ──
declare -i PASS=0 FAIL=0 SKIP=0
FAILED_NAMES=()

# ── colors ──
c_bold='\033[1m'; c_reset='\033[0m'
c_green='\033[32m'; c_red='\033[31m'; c_yellow='\033[33m'; c_dim='\033[2m'

# ── runner ──
# Note: runs each test in a subshell with pipefail DISABLED so that grep -q
# (which closes the pipe fast and causes SIGPIPE 141 in the producer) doesn't
# trip the test as failed. We only care about grep's own exit code.
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

# ════════════════════════════════════════════════════════════════════════════
# Test 1: Core files exist
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 1 — Core files${c_reset}\n"
run ".ow.yml exists"         '[ -f .ow.yml ]'
run ".gitignore exists"            '[ -f .gitignore ]'
run "CLAUDE.md exists"             '[ -f CLAUDE.md ]'
run "AGENTS.md exists"             '[ -f AGENTS.md ]'
run "AI-README.md exists"          '[ -f AI-README.md ]'
# Counts the SHIPPED body set. obsidian-workflow ships exactly the always-on four; every specialized
# agent is written per project by /ow-agent create, so this must stay 4 and AI-README must say so.
run "AI-README agent count synced" 'n=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d " "); grep -q "($n agents" AI-README.md'
run "README.md exists"             '[ -f README.md ]'

# ════════════════════════════════════════════════════════════════════════════
# Test 2: Folder structure
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 2 — Folder structure${c_reset}\n"
for d in .ow/commands .claude/commands .claude/agents .ow/templates .ow/rules scripts bin .agents/skills docs/obsidian-vault/00-Index docs/obsidian-vault/10-PRD docs/obsidian-vault/20-Features docs/obsidian-vault/30-Roles docs/obsidian-vault/40-Functions docs/obsidian-vault/50-Phases docs/obsidian-vault/60-Flows docs/obsidian-vault/70-Reference docs/obsidian-vault/80-ImplementPlan docs/obsidian-vault/85-FixLog docs/obsidian-vault/90-TestPlan docs/obsidian-vault/95-Handoff; do
  run "dir $d"                     "[ -d $d ]"
done
# v0.4: root `templates/` is OPTIONAL — only created when project customizes templates
# v0.4.1: root `commands/` is OPTIONAL — only created when project overrides specific verbs
# Sanity check just verifies it's a directory IF it exists (don't fail if absent)
[ -e templates ] && [ ! -d templates ] && echo "FAIL: templates exists but is not a directory"
[ -e commands ] && [ ! -d commands ] && echo "FAIL: commands exists but is not a directory"

# ════════════════════════════════════════════════════════════════════════════
# Test 3: Commands — source + shim integrity
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 3 — Commands${c_reset}\n"
for cmd_file in .ow/commands/ow-*.md; do
  cmd_name=$(basename "$cmd_file" .md)
  shim=".claude/commands/${cmd_name}.md"
  run "shim exists: $cmd_name"     "[ -f $shim ]"
  run "shim → source: $cmd_name"   "grep -q '@.ow/commands/${cmd_name}.md' $shim"
  run "frontmatter: $cmd_name"     "head -1 $cmd_file | grep -q '^---$'"
done

# ════════════════════════════════════════════════════════════════════════════
# Test 4: Commands contain required sections
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 4 — Command structure${c_reset}\n"
for cmd_file in .ow/commands/ow-*.md; do
  cmd_name=$(basename "$cmd_file" .md)
  # Output section + Never section
  run "Output section: $cmd_name"    "grep -q '^## .*Output (' $cmd_file"
  run "Never section: $cmd_name"     "grep -q '^## Never' $cmd_file"
done

# ════════════════════════════════════════════════════════════════════════════
# Test 5: Subagents
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 5 — Subagents${c_reset}\n"
for agent_file in .claude/agents/*.md; do
  agent_name=$(basename "$agent_file" .md)
  run "frontmatter: $agent_name"   "head -1 $agent_file | grep -q '^---$'"
  run "name field: $agent_name"    "grep -q '^name:' $agent_file"
  run "§5 Gates: $agent_name"      "grep -qE '^## ?§?5\.' $agent_file"
done

# ════════════════════════════════════════════════════════════════════════════
# Test 6: Shipped snapshot
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 6 — Shipped snapshot${c_reset}\n"
# the standard snapshot is retired — nothing under .ow/ may resurrect it
run "no STANDARD.md"               '[ ! -e .ow/STANDARD.md ]'
run "no UPDATE-POLICY.md"          '[ ! -e .ow/UPDATE-POLICY.md ]'
run "no .ow/VERSION"         '[ ! -e .ow/VERSION ]'
run "no policies/ dir"             '[ ! -d .ow/policies ]'
run "no checklists/ dir"           '[ ! -d .ow/checklists ]'
# .ow/local/ is gitignored per-machine runtime state; test.sh names the pattern itself
run "no upstream standard refs"    '! grep -rqE "OW AI Dev Standard|ow-ai-dev-standard" --exclude=test.sh .ow/commands .ow/templates .ow/rules scripts bin .claude'
for tpl in .ow/templates/*.md; do
  tn=$(basename "$tpl" .md)
  run "banner: templates/$tn"      "head -5 $tpl | grep -q 'READ-ONLY'"
done
# The README's file list is what a reader trusts when a template goes missing — pin it to the
# directory, or a retired template lives on in prose forever (init.md/obsidian-* did exactly that).
run "templates README lists exactly the shipped set" '
  listed=$(sed -n "/^## Files that should be here/,/^## Note/p" .ow/templates/README.md | grep -oE "^- [a-z0-9-]+\.md" | sed "s/^- //" | sort);
  actual=$(ls .ow/templates/*.md | xargs -n1 basename | grep -v "^README.md$" | sort);
  [ "$listed" = "$actual" ]'
# usage/ ↔ commands/ parity — a usage doc for a verb that no longer exists is a command the docs
# still advertise; a verb with no usage doc ships undocumented.
run "usage/ has exactly one doc per shipped verb" '
  verbs=$(ls .ow/commands/ow-*.md | xargs -n1 basename | sed "s/.md$//" | sort);
  docs=$(ls usage/ow-*.md | xargs -n1 basename | sed "s/.md$//" | sort);
  [ "$verbs" = "$docs" ]'

# ════════════════════════════════════════════════════════════════════════════
# Test 7: Scripts syntax
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 7 — Script syntax${c_reset}\n"
for s in scripts/*.sh bin/ow; do
  [ -f "$s" ] || continue
  run "bash syntax: $s"            "bash -n $s"
  run "executable: $s"             "[ -x $s ]"
done

# ════════════════════════════════════════════════════════════════════════════
# Test 8: Multi-AI shims
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 8 — Multi-AI integration${c_reset}\n"
# Claude (always)
run "Claude: .claude/ exists"      "[ -d .claude ]"
run "Claude: CLAUDE.md"            "[ -f CLAUDE.md ]"
# Codex
# Codex/Cline/Kimi share ONE neutral bundle: root AGENTS.md + .agents/skills/.
# (codex/AGENTS.md was Codex-only and pointed at seven .toml files that never existed.)
run "Neutral: root AGENTS.md"      "[ -f AGENTS.md ]"
run "Neutral: codex README points at AGENTS.md" "grep -q 'AGENTS.md' codex/README.md"
run "Neutral: maps ow-help"       "[ -f .agents/skills/ow-help/SKILL.md ]"
run "Neutral: maps ow-clarify"    "[ -f .agents/skills/ow-clarify/SKILL.md ]"
run "Neutral: maps ow-reverse-engineer" "[ -f .agents/skills/ow-reverse-engineer/SKILL.md ]"
run "Neutral: no stale codex .toml agents" "[ ! -d codex/agents ]"
# Google Gemini
run "Google: gemini/prompts/"      "[ -d gemini/prompts ]"
# GPT
run "GPT: gpt/prompts/system.md"   "[ -f gpt/prompts/system.md ]"
run "GPT: gpt/prompts/router.md"   "[ -f gpt/prompts/router.md ]"
# GLM
run "GLM: glm/prompts/system.md"   "[ -f glm/prompts/system.md ]"
run "GLM: glm/prompts/router.md"   "[ -f glm/prompts/router.md ]"
# Generic
run "Generic: prompts/general-ai/" "[ -d prompts/general-ai ]"
# Installer AI picker
run "install.sh --ai flag"         "grep -q 'AI_AGENTS' scripts/install.sh"
run "install.sh ai_validate"       "grep -q 'ai_validate' scripts/install.sh"

# ════════════════════════════════════════════════════════════════════════════
# Test 9: ow-paths.sh works
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 9 — ow-paths.sh${c_reset}\n"
if [ -x scripts/ow-paths.sh ]; then
  run "ow-paths --shell"          'bash scripts/ow-paths.sh --shell | grep -q VAULT_ABS='
  run "ow-paths --json"           'bash scripts/ow-paths.sh --json | grep -q "\"vault\""'
  run "ow-paths --check"          'bash scripts/ow-paths.sh --check PROJECT_NAME >/dev/null'
  # vault_language — vault doc language, separate from chat/report language
  run "shell emits VAULT_LANG"     'bash scripts/ow-paths.sh --shell | grep -q "^VAULT_LANG="'
  run "json emits vault_language"  'bash scripts/ow-paths.sh --json | grep -q "\"vault_language\""'
  run "vault_language unset ⇒ = language" '
    d=$(mktemp -d); printf "project:\n  language: \"ja\"\n" > "$d/.ow.yml";
    out=$( cd "$d" && OW_ROOT=. bash '"$PWD"'/scripts/ow-paths.sh --shell 2>/dev/null ); rm -rf "$d";
    printf "%s\n" "$out" | grep -q "^VAULT_LANG=ja$"'
  run "vault_language set ⇒ overrides"    '
    d=$(mktemp -d); printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > "$d/.ow.yml";
    out=$( cd "$d" && OW_ROOT=. bash '"$PWD"'/scripts/ow-paths.sh --shell 2>/dev/null ); rm -rf "$d";
    printf "%s\n" "$out" | grep -q "^VAULT_LANG=en$" && printf "%s\n" "$out" | grep -q "^PROJECT_LANG=th$"'
  run "config template ships vault_language" 'grep -q "^  vault_language:" .ow.yml'
fi

# ════════════════════════════════════════════════════════════════════════════
# Test 9b: ow-verify-vault-lang.sh — mechanical vault-language gate (#33)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 9b — vault-language gate (#33)${c_reset}\n"
if [ -x scripts/ow-verify-vault-lang.sh ]; then
  run "owned-files manifest lists the gate" 'grep -q "ow-verify-vault-lang.sh" scripts/ow-owned.sh'
  run "ow-secure wires Phase 2.5"          'grep -q "ow-verify-vault-lang.sh" .ow/commands/ow-secure.md'

  run "skip when vault_language == language" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "skip: vault_language == project.language"'

  run "pass on clean English vault prose" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# Fix log\n\nEnglish prose only.\n" > docs/obsidian-vault/85-FixLog/good.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "block on Thai prose leaking into en vault" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# Fix log\n\nนี่คือข้อความภาษาไทย\n" > docs/obsidian-vault/85-FixLog/bad.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "BLOCK"'

  run "scans notes whose name has a space or non-ASCII" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# n\n\nข้อความไทย\n" > "docs/obsidian-vault/85-FixLog/My Note.md";
    printf -- "---\ntitle: t\n---\n# n\n\nข้อความไทย\n" > "docs/obsidian-vault/85-FixLog/บันทึก.md";
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "My Note.md" && printf "%s" "$out" | grep -q "บันทึก.md"'

  run "English prose with an em dash is not Thai (C-locale byte-range trap)" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# Fix log\n\n- Search — fixed · verified ✓ → deployed\n" > docs/obsidian-vault/85-FixLog/dash.md;
    git add -A >/dev/null;
    out=$(LC_ALL=C OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "still blocks real Thai prose when started from the C locale" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# Fix log\n\nข้อความไทย — ปนมา\n" > docs/obsidian-vault/85-FixLog/th.md;
    git add -A >/dev/null;
    out=$(LC_ALL=C OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "BLOCK"'

  run "never re-flags pre-existing unmodified vault content" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/85-FixLog;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    printf -- "---\ntitle: t\n---\n# Fix log\n\nข้อความไทยเดิม\n" > docs/obsidian-vault/85-FixLog/old.md;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf "project:\n  language: \"th\"\n  vault_language: \"en\"\n" > .ow.yml;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-lang.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'
fi

# ════════════════════════════════════════════════════════════════════════════
# Test 9c: ow-verify-vault-style.sh — vault present-tense gate
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 9c — vault present-tense gate${c_reset}\n"
if [ -x scripts/ow-verify-vault-style.sh ]; then
  run "owned-files manifest lists the gate"  'grep -q "ow-verify-vault-style.sh" scripts/ow-owned.sh'
  run "ow-secure wires Phase 2.6"           'grep -q "ow-verify-vault-style.sh" .ow/commands/ow-secure.md'
  run "the contract fragment exists"         '[ -s .ow/commands/_shared/vault-doc-style.md ]'
  run "fragment names all 4 exempt folders"  '
    f=.ow/commands/_shared/vault-doc-style.md;
    grep -q "80-ImplementPlan" "$f" && grep -q "85-FixLog" "$f" && grep -q "90-TestPlan" "$f" && grep -q "95-Handoff" "$f"'
  # the script exempts by RESOLVER VAR, so prose and bash can only agree if both name the same four
  run "gate exempts the same 4 dirs as the fragment" '
    grep -q "PLAN_DIR" scripts/ow-verify-vault-style.sh && grep -q "FIX_DIR" scripts/ow-verify-vault-style.sh &&
    grep -q "TEST_DIR" scripts/ow-verify-vault-style.sh && grep -q "HANDOFF_DIR" scripts/ow-verify-vault-style.sh'
  run "every doc-writing verb points at it" '
    for v in ow-init ow-new ow-clarify ow-doc ow-reverse-engineer ow-implement; do
      grep -q "_shared/vault-doc-style.md" .ow/commands/$v.md || exit 1; done'

  run "pass on a present-tense spec doc" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/40-Functions;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# FN-Search\n\nSearch returns results within 5 days.\n" > docs/obsidian-vault/40-Functions/FN-Search.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "block on an edit narrated in a spec doc" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/40-Functions;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# FN-Search\n\nWindow is 5 days, changed from 3 days to 5 days.\n" > docs/obsidian-vault/40-Functions/FN-Search.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "BLOCK"'

  run "block on a Changelog section in a spec doc" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/20-Features;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# FEAT-Checkout\n\n## Revision History\n\nnone yet\n" > docs/obsidian-vault/20-Features/FEAT-Checkout.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "Revision History"'

  run "plan/fix/test/handoff folders stay exempt" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null;
    mkdir -p docs/obsidian-vault/80-ImplementPlan docs/obsidian-vault/85-FixLog docs/obsidian-vault/90-TestPlan docs/obsidian-vault/95-Handoff;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    for dir in 80-ImplementPlan 85-FixLog 90-TestPlan 95-Handoff; do
      printf -- "---\ntitle: t\n---\n# log\n\nTimeout changed from 3s to 5s.\n" > "docs/obsidian-vault/$dir/n.md"; done;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "quoted code fence is not narration" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/70-Reference;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# REF\n\nCurrent config below.\n\n\`\`\`\nchanged from 3 to 5\n\`\`\`\n" > docs/obsidian-vault/70-Reference/REF-Config.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "never re-flags pre-existing vault content" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/40-Functions;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    printf -- "---\ntitle: t\n---\n# FN-Old\n\nWindow changed from 3 days to 5 days.\n" > docs/obsidian-vault/40-Functions/FN-Old.md;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 0 ] && printf "%s" "$out" | grep -q "clean"'

  run "scans notes whose name has a space or non-ASCII" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/40-Functions;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# n\n\nWindow changed from 3 days to 5 days.\n" > "docs/obsidian-vault/40-Functions/My Note.md";
    printf -- "---\ntitle: t\n---\n# n\n\nคืนผลใน 5 วัน จากเดิม 3 วัน\n" > "docs/obsidian-vault/40-Functions/FN-ค้นหา.md";
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "My Note.md" && printf "%s" "$out" | grep -q "FN-ค้นหา.md"'

  run "catches the vault-language forms too (th)" '
    d=$(mktemp -d); cd "$d"; git init -q >/dev/null; mkdir -p docs/obsidian-vault/40-Functions;
    printf "project:\n  language: \"th\"\n" > .ow.yml;
    printf "worktrees/\n" > .gitignore;
    git add -A >/dev/null; git commit -qm init >/dev/null;
    printf -- "---\ntitle: t\n---\n# FN-Search\n\nคืนผลใน 5 วัน (จากเดิม 3 วัน)\n" > docs/obsidian-vault/40-Functions/FN-Search.md;
    git add -A >/dev/null;
    out=$(OW_ROOT="$d" bash '"$PWD"'/scripts/ow-verify-vault-style.sh 2>&1); rc=$?;
    cd '"$PWD"' >/dev/null; rm -rf "$d";
    [ "$rc" -eq 1 ] && printf "%s" "$out" | grep -q "BLOCK"'
fi

# ════════════════════════════════════════════════════════════════════════════
# Test 10: Doctor runs
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 10 — Doctor${c_reset}\n"
run "bin/ow doctor runs"     'bash bin/ow doctor 2>&1 | grep -q "commands"'

# ════════════════════════════════════════════════════════════════════════════
# Test 11: Sample vault references valid
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 11 — Sample vault (Library Book Tracker)${c_reset}\n"
run "IMPLEMENTATION-STATUS"        '[ -s docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md ]'
run "PRD file"                     'ls docs/obsidian-vault/10-PRD/PRD-*.md >/dev/null 2>&1'
run "Feature files"                'ls docs/obsidian-vault/20-Features/FEAT-*.md >/dev/null 2>&1'
run "Function files"               'find docs/obsidian-vault/40-Functions -name "FN-*.md" | head -1 | xargs test -f'
run "DesignSystem"                 '[ -d docs/obsidian-vault/70-Reference/DesignSystem ]'
run "DS preview.html"              '[ -f docs/obsidian-vault/70-Reference/DesignSystem/preview.html ]'

# ════════════════════════════════════════════════════════════════════════════
# Test 12: Template lookup chain integrity
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 12 — Template lookup chain${c_reset}\n"
for tpl in prd srs srs-module tech-spec adr feature function role flow phase plan fix-log handoff test-plan test-scenario-report checklist; do
  # at least one of: project / shipped snapshot (local is optional)
  run "template available: $tpl"    "[ -f templates/${tpl}.md ] || [ -f .ow/templates/${tpl}.md ]"
done
# Cited templates must resolve to a real file (no phantom citations in the 5-section trailer)
run "cited: test-scenario-report"  'grep -q "templates/test-scenario-report.md" .ow/commands/ow-test.md && [ -f .ow/templates/test-scenario-report.md ]'
run "cited: checklist template"    'grep -q "templates/checklist.md" .ow/commands/ow-checklist.md && [ -f .ow/templates/checklist.md ]'
run "template_lookup not legacy"   '! grep -q "standards/templates" .ow.yml'
run "resolver exposes snapshot slot" 'bash scripts/ow-paths.sh --shell | grep -q "^TEMPLATES_SNAPSHOT="'

# ════════════════════════════════════════════════════════════════════════════
# Test 13: Issue workflow commands + gh-issue agent
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 13 — Issue workflow (triage + fix-issue)${c_reset}\n"
run "command count = 20"           '[ "$(find .ow/commands -name "ow-*.md" | wc -l | tr -d " ")" -eq 20 ]'
run "spec: ow-triage-issues"      '[ -f .ow/commands/ow-triage-issues.md ]'
run "spec: ow-fix-issue"          '[ -f .ow/commands/ow-fix-issue.md ]'
run "shim: ow-triage-issues"      '[ -f .claude/commands/ow-triage-issues.md ]'
run "shim: ow-fix-issue"          '[ -f .claude/commands/ow-fix-issue.md ]'
run "gh-issue agent exists"        '[ -f .claude/agents/gh-issue.md ]'
run "gh-issue read-only"           'grep -q "READ ONLY\|read-only" .claude/agents/gh-issue.md'
run "fix-issue no-push rule"       'grep -q "Never push" .ow/commands/ow-fix-issue.md'
run "triage frozen pool"           'grep -q "Freeze snapshot" .ow/commands/ow-triage-issues.md'
run "triage no re-query rule"      'grep -q "Never re-run .gh issue list. after Phase 1.3" .ow/commands/ow-triage-issues.md'
run "fix-issue after from fixed build" 'grep -q "it must come from the fixed build only" .ow/commands/_shared/fix-issue-fix-flow.md'
run "fix-issue before/after pairing"   'grep -q "Pairing invariant" .ow/commands/_shared/fix-issue-fix-flow.md'
run "fix-issue ready-for-test mode"    'grep -q "Ready-for-Test Handoff" .ow/commands/ow-fix-issue.md'
run "fix-issue r4t verify pushed"      'grep -q "Verify pushed" .ow/commands/_shared/fix-issue-ready-for-test.md'
run "fix-issue r4t no-fake version"    'grep -q "Never fabricate the version" .ow/commands/ow-fix-issue.md && grep -qi "never fabricate the version" .ow/commands/_shared/fix-issue-ready-for-test.md'
run "git auto issue-handoff phase"     'grep -q "Auto issue-handoff" .ow/commands/ow-git.md'
run "git handoff gated on Closes"      'grep -q "Closes #NN" .ow/commands/ow-git.md'
run "git --no-ready-for-test opt-out"  'grep -q "no-ready-for-test" .ow/commands/ow-git.md'
run "git unified bump phase"           'grep -q "Resolve unified bump version" .ow/commands/ow-git.md'
run "git unified = max of repos"       'grep -q "max(current" .ow/commands/ow-git.md && grep -q "TARGET_VERSION" .ow/commands/ow-git.md'
run "git same tag all submodules"      'grep -q "v\$TARGET_VERSION" .ow/commands/ow-git.md'
run "version_bump.unified default"     'bash scripts/ow-paths.sh --json | jq -e ".version_bump.unified" >/dev/null'
run "yml documents unified bump"       'grep -q "unified: true" .ow.yml'
run "git default = no bump (opt-in)"   'grep -q "Default = no bump (opt-in)" .ow/commands/ow-git.md && grep -qF "Never add \`--bump\` yourself" .ow/commands/ow-git.md'
run "help has github-issue workflow"   'grep -q "workflow github-issue" .ow/commands/ow-help.md'
run "README has GitHub-issue workflow" 'grep -q "GitHub issues — triage" README.md'
run "fix-issue: red→green pairing gate" 'grep -q "red→green pairing" .ow/commands/ow-fix-issue.md'

# evidence/upload subsystem retired — nothing may reference it any more
run "command: ow-evidence.md removed"    '[ ! -f .ow/commands/ow-evidence.md ]'
run "command: ow-evidence shim removed"  '[ ! -f .claude/commands/ow-evidence.md ]'
run "command: ow-upload.md removed"      '[ ! -f .ow/commands/ow-upload.md ]'
run "script: upload-evidence.sh removed"  '[ ! -f scripts/upload-evidence.sh ]'
run "template: evidence/ removed"         '[ ! -d .ow/templates/evidence ]'
run "doc: EVIDENCE-PATHS.md removed"      '[ ! -f EVIDENCE-PATHS.md ]'
run "resolver: no EVIDENCE_RAW_ROOT"      '! grep -q "EVIDENCE_RAW_ROOT" scripts/ow-paths.sh'
run "resolver: no upload keys"            '! grep -q "UPLOAD_PROVIDER" scripts/ow-paths.sh'
run "config: no evidence block"           '! grep -qE "^evidence:" .ow.yml'
run "conformance check 6 present"         'grep -q "check 6" scripts/conformance-lint.sh'
run "check 6 guards the retirement"       'bash scripts/conformance-lint.sh 2>&1 | grep -q "check 6: no retired evidence/upload reference"'

# results are quoted into the vault doc, never stored as files
run "ow-test: scratch run dir only"           'grep -q "ow-run-" .ow/commands/ow-test.md'
run "ow-fix: RED baseline section"            'grep -q "RED baseline" .ow/commands/ow-fix.md'
run "fix-log template: RED + GREEN"            'grep -q "RED baseline" .ow/templates/fix-log.md && grep -q "GREEN result" .ow/templates/fix-log.md'
run "implement: runs build-test fragment"      'grep -q "_shared/build-test.md" .ow/commands/ow-implement.md'
# #29 — safe revert of format churn: scope formatter to changed files; never destructive git ops on un-owned files
run "implement: ban destructive git on churn (#29)"   'grep -qi "data loss" .ow/commands/ow-implement.md && grep -q "git restore" .ow/commands/ow-implement.md'
run "implement: formatter scoped (read-only --check)"  'grep -q -- "--check" .ow/commands/ow-implement.md && grep -q -- "<changed-files>" .ow/commands/ow-implement.md && grep -q "files the task itself changed" .ow/commands/ow-implement.md'
# the rule itself lives in coding-discipline.md (§2); the fix flow must reach it by citation.
# Assert BOTH sides — a citation with no rule behind it, or a rule nobody cites, both lose it.
run "fix-issue: safe revert, no git-restore churn"     'grep -q "coding-discipline.md" .ow/commands/_shared/fix-issue-fix-flow.md && grep -q "git restore" .ow/commands/_shared/coding-discipline.md'

# ════════════════════════════════════════════════════════════════════════════
# Test 15: v0.7.1 adoption follow-ups (#21 adoption UX / #22 rules / #23 local)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 15 — v0.7.1 adoption follow-ups (#21/#22/#23)${c_reset}\n"
# #22 — rules resolver: expected-path + registry validator + selftest wiring
run "rules-expected names file"    'bash scripts/ow-paths.sh --rules-expected backend | grep -q "rules/backend.md"'
run "rules-expected present/absent" 'bash scripts/ow-paths.sh --rules-expected backend | grep -qE "absent|present"'
run "rules-validate clean files:[]" 'bash scripts/ow-paths.sh --rules-validate'
run "selftest covers rules"        'bash scripts/ow-paths.sh --selftest | grep -q "rules-registry"'
run "rules-validate fails on bogus" '
  d=$(mktemp -d); printf "rules: { dir: \".ow/rules\", files: [\"nope.md\"] }\n" > "$d/.ow.yml"; mkdir -p "$d/.ow/rules";
  ( cd "$d" && OW_ROOT=. bash '"$PWD"'/scripts/ow-paths.sh --rules-validate ) >/dev/null 2>&1; rc=$?; rm -rf "$d"; [ "$rc" -ne 0 ]'
# #21 — conformance-lint scopes §0 to obsidian-workflow-owned agents only
run "lint owned-agent set"         'grep -q "OWNED_AGENTS=" scripts/conformance-lint.sh'
run "lint user agent → note not fail" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands" "$d/.claude/agents"; : > "$d/.ow.yml";
  printf "# no header\n" > "$d/.claude/agents/legacy.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-lint-u.$$ 2>&1; rc=$?; rm -rf "$d";
  { [ "$rc" -eq 0 ] && grep -q "user-owned agents without" /tmp/ow-lint-u.$$; }; r=$?; rm -f /tmp/ow-lint-u.$$; [ "$r" -eq 0 ]'
# #21 — installer prompts/keeps user-owned .claude
run "install: adopt prompt fn"     'grep -q "adopt_existing_claude()" scripts/install.sh'
run "install: rules in SAFE_ITEMS" 'grep -q "\.ow/rules\"" scripts/install.sh'
run "install: no --local mode"     '! grep -q "LOCAL_ONLY" scripts/install.sh && ! grep -q -- "--local)" bin/ow'
# v0.7.4 — bin shipped to consumers: source-only subcommands must fail gracefully
run "bin: source-only guard fn"        'grep -q "_require_source_script" bin/ow'
run "bin: init/update/test guarded"    'grep -q "_require_source_script install.sh init" bin/ow && grep -q "_require_source_script install.sh update" bin/ow && grep -q "_require_source_script test.sh test" bin/ow'
run "bin: sync no phantom script"      '! grep -q "sync-standards.sh" bin/ow'
run "bin: version reads .ow.yml" 'grep -q "ow.version" bin/ow || grep -q "ow:/" bin/ow; ! grep -q "cat \"\$OW_HOME/VERSION\"" bin/ow'
run "bin: doctor uses owned manifest"  'grep -q "ow_owned_scripts" bin/ow && ! grep -q "OK (7 runtime helpers)" bin/ow'
# #22 — commands name the rule file + fail loud
run "implement: rules-expected"    'grep -q "rules-expected" .ow/commands/_shared/delegation.md'
run "implement: STOP-RISK loud"    'grep -q "STOP-RISK" .ow/commands/ow-implement.md'
run "fix-issue: STOP-RISK loud"    'grep -q "STOP-RISK" .ow/commands/ow-fix-issue.md'

# ════════════════════════════════════════════════════════════════════════════
# Section 16 — .gitignore managed-block merge (brownfield no-clobber)
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 16 — .gitignore managed block${c_reset}\n"
run "gitignore: lib exists"        '[ -f scripts/ow-gitignore.sh ]'
run "gitignore: merge fn defined"  '. scripts/ow-gitignore.sh && command -v ow_gitignore_merge >/dev/null'
run "gitignore: NOT blind-copied"  '! grep -qE "^[[:space:]]*\"\.gitignore\"" scripts/install.sh'
run "gitignore: block is ow-only" '. scripts/ow-gitignore.sh && ! ow_gitignore_block | grep -qiE "node_modules|__pycache__|coverage/"'
run "gitignore: ignores backup dirs"  '. scripts/ow-gitignore.sh && ow_gitignore_block | grep -qF ".ow.backup-*/"'
run "install: merges gitignore"    'grep -q "ow_gitignore_merge" scripts/install.sh'
run "upgrade: refreshes gitignore" 'grep -q "ow_gitignore_merge" scripts/upgrade.sh'
run "gitignore: brownfield no-clobber + idempotent" '
  . scripts/ow-gitignore.sh
  d=$(mktemp -d); printf "node_modules/\nsecrets.json\n" > "$d/.gitignore"
  ow_gitignore_merge "$d/.gitignore"
  ow_gitignore_merge "$d/.gitignore"
  s=$(grep -cF ">>> obsidian-workflow managed" "$d/.gitignore")
  u=$(grep -cE "node_modules|secrets.json" "$d/.gitignore")
  rm -rf "$d"
  [ "$s" = "1" ] && [ "$u" = "2" ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 17 — owned-file manifest + selective scripts/bin (upgrade no-clobber)
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 17 — owned-file manifest (scripts/bin)${c_reset}\n"
run "manifest: lib exists"          '[ -f scripts/ow-owned.sh ]'
run "manifest: fns defined"         '. scripts/ow-owned.sh && command -v ow_owned_scripts >/dev/null && command -v ow_owned_bin >/dev/null && command -v ow_source_only_scripts >/dev/null'
run "manifest: lists itself"        '. scripts/ow-owned.sh && ow_owned_scripts | grep -qx "ow-owned.sh"'
run "manifest: source-only = install/test" '. scripts/ow-owned.sh && ow_source_only_scripts | grep -qx "install.sh" && ow_source_only_scripts | grep -qx "test.sh"'
run "manifest: source-only NOT in owned"   '. scripts/ow-owned.sh && ! ow_owned_scripts | grep -qxE "install.sh|test.sh"'
run "manifest: every owned script exists"  '. scripts/ow-owned.sh && ok=1; for s in $(ow_owned_scripts); do [ -f "scripts/$s" ] || ok=0; done; [ "$ok" = 1 ]'
run "manifest: owned bin exists"           '. scripts/ow-owned.sh && for b in $(ow_owned_bin); do [ -f "bin/$b" ] || exit 1; done'
# ── the install set must equal the NEEDED set, both directions (#37) ──
# Verified empirically on a real consumer install: removing any one owned script breaks a
# consumer entry point or silently disables a feature (ow-shims.sh absent ⇒ generate_shims
# vanishes with no error). These guards keep it that way: nothing unnecessary creeps into the
# manifest, and nothing necessary drops out of doctor's degraded-mode fallback.
run "install-set: doctor fallback == owned manifest" '
  . scripts/ow-owned.sh
  mf=$(ow_owned_scripts | sort | tr "\n" " ")
  fb=$(grep -o "owned_list=\"[^\"]*\"" bin/ow | tail -1 | sed "s/owned_list=\"//;s/\"//" | tr " " "\n" | sort | tr "\n" " ")
  [ "$mf" = "$fb" ]'
run "install-set: every owned script has a consumer-side caller" '
  . scripts/ow-owned.sh
  bad=""
  for s in $(ow_owned_scripts); do
    case "$s" in upgrade.sh|ow-paths.sh|ow-owned.sh) continue ;; esac
    grep -rqlF "scripts/$s" .ow/commands/ 2>/dev/null && continue
    grep -qlF "$s" scripts/upgrade.sh bin/ow 2>/dev/null && continue
    grep -lF "$s" scripts/*.sh 2>/dev/null | grep -vE "^scripts/($s|ow-owned\\.sh)$" | grep -q . && continue
    bad="$bad $s"
  done
  [ -z "$bad" ] || { echo "installed but nothing on a consumer calls it:$bad"; exit 1; }'
run "install-set: source-only never reaches the owned list" '
  . scripts/ow-owned.sh
  for s in $(ow_source_only_scripts); do ow_owned_scripts | grep -qx "$s" && exit 1; done; exit 0'
run "install-set: manifest covers every file in scripts/" '
  . scripts/ow-owned.sh
  known=" $(ow_owned_scripts | tr "\n" " ") $(ow_source_only_scripts | tr "\n" " ") "
  bad=""
  for f in scripts/*.sh; do b=$(basename "$f"); case "$known" in *" $b "*) ;; *) bad="$bad $b" ;; esac; done
  [ -z "$bad" ] || { echo "unclassified (neither owned nor source-only):$bad"; exit 1; }'
run "install: sources manifest"     'grep -q "ow_owned_scripts" scripts/install.sh'
run "install: installs owned bin"   'grep -q "ow_owned_bin" scripts/install.sh'
run "upgrade: scripts NOT wholesale REPLACE" '! awk "/^REPLACE_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -qE "^[[:space:]]*(scripts|bin)[[:space:]]*$"'
run "upgrade: selective per-file refresh"    'grep -q "ow_owned_scripts" scripts/upgrade.sh && grep -q "Refreshing owned scripts" scripts/upgrade.sh'
run "upgrade: rm -f before cp (inode-safe)"  'grep -q "rm -f \"scripts/\$f\"; cp" scripts/upgrade.sh'
run "upgrade: rollback per-file scripts/bin" 'awk "/scripts.*bin.*per-file restore/,/Rollback complete/" scripts/upgrade.sh | grep -q "for d in scripts bin"'
run "upgrade: rollback NOT wholesale scripts" '! awk "/^ROLLBACK_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -qE "scripts bin"'
run "upgrade: source-only removal signature-guarded" 'grep -q "head -3 \"scripts/\$f\" | grep -q ..# obsidian-workflow " scripts/upgrade.sh'
# AI-aware: only refresh the AIs the project enabled (no other-AI folders on a claude-only upgrade)
run "upgrade: AI frontend dirs fn"           'grep -q "ai_frontend_dirs()" scripts/upgrade.sh && grep -q "claude_is_enabled()" scripts/upgrade.sh'
run "upgrade: codex/gemini/prompts NOT wholesale" '! awk "/^REPLACE_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -qE "^[[:space:]]*(codex|gemini|gpt|glm|prompts)[[:space:]]*$"'
run "upgrade: .claude merge claude-guarded" 'grep -q "if claude_is_enabled; then" scripts/upgrade.sh'
run "upgrade: ai_frontend reads ai_agents" 'grep -q "ai_agents\[\]" scripts/upgrade.sh && grep -q "ow_frontend_paths " scripts/upgrade.sh'
# .agents/skills is MIXED ownership — it must be excluded from the rm -rf refresh
# loop and regenerated per-file instead, or a user's own skills are destroyed.
run "upgrade: .agents excluded from wholesale refresh" \
  'awk "/^ai_frontend_dirs\(\)/,/^}/" scripts/upgrade.sh | grep -q "\.agents"'
run "upgrade: regenerates skills bundle"   'grep -q "generate_skills \".ow/commands\" \".\"" scripts/upgrade.sh'
run "upgrade: regenerates routers"         'grep -q "generate_router \".ow/commands\" \".\"" scripts/upgrade.sh'

# ── AI front-end registry parity ────────────────────────────────────────────
# The registry is the single source of truth. Before it existed the same names were
# re-declared at 14 sites with no guard, and gpt/glm silently fell out of two of them.
# These assertions fail the moment a consumer stops deriving from the registry.
printf "\n${c_bold}Section 8b — AI front-end registry parity${c_reset}\n"
run "registry: file exists"                '[ -f scripts/ow-frontends.sh ]'
run "registry: is an owned script"         '. scripts/ow-owned.sh && ow_owned_scripts | grep -qx ow-frontends.sh'
run "registry: shims lib is an owned script" '. scripts/ow-owned.sh && ow_owned_scripts | grep -qx ow-shims.sh'
run "registry: every front-end has kind+folder+label" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do [ -n "$(ow_frontend_kind $f)" ] || exit 1; [ -n "$(ow_frontend_folder $f)" ] || exit 1; [ -n "$(ow_frontend_label $f)" ] || exit 1; done'
run "registry: kinds are known emitters" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do case "$(ow_frontend_kind $f)" in commands|skills|router) ;; *) exit 1 ;; esac; done'
run "registry: every folder ships in repo" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do [ -d "$(ow_frontend_folder $f)" ] || exit 1; done'
run "registry: every front-end has next-steps" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do [ -n "$(ow_frontend_nextsteps $f)" ] || exit 1; done'
run "registry: by_index covers whole table" \
  '. scripts/ow-frontends.sh; n=$(ow_frontend_count); i=1; while [ $i -le $n ]; do [ -n "$(ow_frontend_by_index $i)" ] || exit 1; i=$((i+1)); done'
run "registry: paths_for keeps the LAST name" \
  '. scripts/ow-frontends.sh; ow_frontend_paths_for "claude,kimi" | grep -qx kimi'
# Consumers must DERIVE, not re-declare
run "install: derives picker from registry" 'grep -q "ow-frontends.sh" scripts/install.sh && grep -q "ow_frontends" scripts/install.sh'
run "install: no hardcoded AI array"        '! grep -qE "^AI_AVAILABLE=\(claude" scripts/install.sh'
run "upgrade: sources registry"             'grep -q "ow-frontends.sh" scripts/upgrade.sh'
run "upgrade: rollback derives AI paths"    'grep -q "ow_frontend_all_paths" scripts/upgrade.sh'
run "ow-sync PROTECTED lists every folder" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do d=$(ow_frontend_folder $f); [ "$d" = ".claude" ] && continue; grep -qE "^[[:space:]]*$d([[:space:]]|$)" .ow/commands/ow-sync.md || exit 1; done'
run "ow-sync PROTECTED lists shared assets" \
  'grep -qE "^[[:space:]]*\.agents([[:space:]]|$)" .ow/commands/ow-sync.md && grep -qE "^[[:space:]]*AGENTS\.md([[:space:]]|$)" .ow/commands/ow-sync.md'
run "bin/ow help lists every front-end" \
  '. scripts/ow-frontends.sh; for f in $(ow_frontends); do grep -q "$f" bin/ow || exit 1; done'
run "safe-paths protects AGENTS.md"        '. scripts/ow-safe-paths.sh && ow_safe_paths "" | grep -qx AGENTS.md'

# ── skills bundle: schema both Cline and Kimi accept ────────────────────────
# Constraints are the INTERSECTION of the two validators. Any violation makes the
# skill silently unavailable in one of the two tools.
printf "\n${c_bold}Section 8c — .agents/skills schema${c_reset}\n"
run "skills: one dir per verb"             'a=$(ls .ow/commands/*.md | wc -l | tr -d " "); b=$(ls -d .agents/skills/*/ | wc -l | tr -d " "); [ "$a" = "$b" ]'
run "skills: every dir has SKILL.md"       'for d in .agents/skills/*/; do [ -f "$d/SKILL.md" ] || exit 1; done'
run "skills: name == directory name"       'for d in .agents/skills/*/; do v=$(basename "$d"); grep -qx "name: $v" "$d/SKILL.md" || exit 1; done'
run "skills: dir name is [a-z0-9-]{1,64}"  'for d in .agents/skills/*/; do v=$(basename "$d"); echo "$v" | grep -qE "^[a-z0-9-]{1,64}$" || exit 1; done'
run "skills: description present, <=1024"  'for d in .agents/skills/*/; do l=$(grep -m1 "^description: " "$d/SKILL.md") || exit 1; [ ${#l} -le 1037 ] || exit 1; done'
run "skills: body non-empty (Cline throws otherwise)" \
  'for d in .agents/skills/*/; do [ "$(awk "/^---$/{n++; next} n>=2" "$d/SKILL.md" | tr -d "[:space:]" | wc -c | tr -d " ")" -gt 0 ] || exit 1; done'
run "skills: delegates to a resolvable spec" \
  'for d in .agents/skills/*/; do v=$(basename "$d"); grep -q "commands/$v.md" "$d/SKILL.md" || exit 1; done'
run "skills: emitter is override-first"    'grep -q "ow_ref" scripts/ow-shims.sh && grep -q "commands/%s.md" scripts/ow-shims.sh'
run "skills: prune preserves user-owned"   'grep -q "_is_generated_skill" scripts/ow-shims.sh && grep -q "kept (user-owned, no spec): .agents/skills" scripts/ow-shims.sh'

# ── routers are generated, not static ──────────────────────────────────────
run "router: generated marker present"     'for f in gpt glm gemini; do grep -q "generated by scripts/ow-shims.sh" $f/prompts/router.md || exit 1; done'
run "router: every verb listed"            'n=$(ls .ow/commands/*.md | wc -l | tr -d " "); m=$(grep -c "^| .ow-" gpt/prompts/router.md); [ "$n" = "$m" ]'
run "router: system.md exists per router AI" 'for f in gpt glm gemini; do [ -f $f/prompts/system.md ] || exit 1; done'
run "upgrade: AI refresh enabled-only loop" 'grep -q "Refreshing AI frontends (enabled only" scripts/upgrade.sh'
run "upgrade: prunes old backups"          'grep -q "Pruned ._pruned old backup" scripts/upgrade.sh && grep -q "for _b in .ow.backup-" scripts/upgrade.sh'
run "upgrade: prune keeps latest only"     'grep -q "\[ \"\$_b\" = \"\$BACKUP_DIR\" \] && continue" scripts/upgrade.sh'

# ════════════════════════════════════════════════════════════════════════════
# Section 18 — per-agent AI model config (subagents.<name>.model)
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 18 — per-agent AI model config${c_reset}\n"

run "model: resolver --agent-models emits 9 rows" \
  '[ "$(bash scripts/ow-paths.sh --agent-models | grep -c .)" -eq 9 ]'
run "model: default backend=sonnet"      '[ "$(bash scripts/ow-paths.sh --agent-model backend)" = sonnet ]'
run "model: default security=opus"       '[ "$(bash scripts/ow-paths.sh --agent-model security)" = opus ]'
run "model: default docs=sonnet"         '[ "$(bash scripts/ow-paths.sh --agent-model docs)" = sonnet ]'
run "model: default gh-issue=haiku"      '[ "$(bash scripts/ow-paths.sh --agent-model gh-issue)" = haiku ]'
run "model: unknown agent → sonnet default" '[ "$(bash scripts/ow-paths.sh --agent-model nope)" = sonnet ]'
run "model: resolver validates alias|claude-*" \
  'grep -q "opus|sonnet|haiku) return 0" scripts/ow-paths.sh && grep -q "claude-\*)          return 0" scripts/ow-paths.sh'
run "model: enabled detection reads map .enabled" \
  'grep -q "subagents.\$a.enabled" scripts/ow-paths.sh'

# shipped agent frontmatter matches the documented defaults. Only the always-on four ship:
# backend/frontend/mobile/design/test-runner are written per project by /ow-agent create.
run "model: security.md ships opus"      'grep -qx "model: opus" .claude/agents/security.md'
run "model: docs.md ships sonnet"        'grep -qx "model: sonnet" .claude/agents/docs.md'
run "model: verifier.md ships sonnet"    'grep -qx "model: sonnet" .claude/agents/verifier.md'
run "model: gh-issue.md ships haiku"     'grep -qx "model: haiku" .claude/agents/gh-issue.md'
run "model: no pinned claude-sonnet-4-6 left in agents" \
  '! grep -rqx "model: claude-sonnet-4-6" .claude/agents/'

# apply_agent_models — function + wiring
run "model: apply_agent_models defined"  'grep -q "^apply_agent_models()" scripts/ow-claude-manifest.sh'
run "model: built-in fallback map defined" 'grep -q "^ow_default_agent_models()" scripts/ow-claude-manifest.sh'
run "model: install calls apply_agent_models"  'grep -q "apply_agent_models \"\$TARGET\"" scripts/install.sh'
run "model: upgrade calls apply_agent_models"  'grep -q "apply_agent_models \".\"" scripts/upgrade.sh'
run "model: ow-sync calls apply_agent_models" 'grep -q "apply_agent_models \"\$ROOT\"" .ow/commands/ow-sync.md'

# config override (map form) end-to-end in an isolated fixture
run "model: map-form override resolves (backend→opus)" '
  TD=$(mktemp -d); mkdir -p "$TD/scripts"
  cp scripts/ow-paths.sh "$TD/scripts/"
  printf "vault_path: docs/v\nsubagents:\n  backend: { enabled: true, model: opus }\n" > "$TD/.ow.yml"
  R=$(OW_ROOT="$TD" bash "$TD/scripts/ow-paths.sh" --agent-model backend)
  rm -rf "$TD"; [ "$R" = opus ]'
run "model: invalid value falls back + warns" '
  TD=$(mktemp -d); mkdir -p "$TD/scripts"
  cp scripts/ow-paths.sh "$TD/scripts/"
  printf "vault_path: docs/v\nsubagents:\n  backend: { enabled: true, model: bogus }\n" > "$TD/.ow.yml"
  OUT=$(OW_ROOT="$TD" bash "$TD/scripts/ow-paths.sh" --agent-model backend 2>&1)
  rm -rf "$TD"; echo "$OUT" | grep -q "^sonnet$" && echo "$OUT" | grep -q WARN'
run "model: apply falls back to defaults with no config" '
  TD=$(mktemp -d); mkdir -p "$TD/.claude/agents"
  printf -- "---\nname: backend\nmodel: claude-sonnet-4-6\n---\n" > "$TD/.claude/agents/backend.md"
  ( . scripts/ow-claude-manifest.sh; apply_agent_models "$TD" ) >/dev/null
  R=$(grep "^model:" "$TD/.claude/agents/backend.md"); rm -rf "$TD"; [ "$R" = "model: sonnet" ]'
run "model: fallback map matches resolver defaults" '
  A=$( . scripts/ow-claude-manifest.sh; ow_default_agent_models | sort )
  B=$(bash scripts/ow-paths.sh --agent-models | sort)
  [ "$A" = "$B" ]'
run "model: apply is surgical + idempotent" '
  TD=$(mktemp -d); mkdir -p "$TD/.claude/agents"
  printf -- "---\nname: docs\nmodel: opus\ntools: Read\n---\nbody line\n" > "$TD/.claude/agents/docs.md"
  ( . scripts/ow-claude-manifest.sh; apply_agent_models "$TD" ) >/dev/null
  SECOND=$( . scripts/ow-claude-manifest.sh; apply_agent_models "$TD" )
  OK=1
  grep -qx "model: sonnet" "$TD/.claude/agents/docs.md" || OK=0   # changed
  grep -qx "body line" "$TD/.claude/agents/docs.md" || OK=0       # body intact
  grep -qx "tools: Read" "$TD/.claude/agents/docs.md" || OK=0     # other frontmatter intact
  [ -z "$SECOND" ] || OK=0                                        # idempotent (no 2nd change)
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

run "model: .ow.yml shows model field (map form)" 'grep -qE "enabled: true, +model:" .ow.yml'
run "model: .ow.yml backend model visible"        'grep -qE "backend: +\{ *enabled: false, +model: sonnet" .ow.yml'

# ════════════════════════════════════════════════════════════════════════════
# Section 19 — per-command AI model config (commands.model + overrides.<verb>)
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 19 — per-command AI model config${c_reset}\n"

run "cmdmodel: resolver --command-models = one row per spec" \
  '[ "$(bash scripts/ow-paths.sh --command-models | grep -c .)" -eq "$(ls .ow/commands/*.md | wc -l | tr -d " ")" ]'
run "cmdmodel: ow-plan override = opus"     '[ "$(bash scripts/ow-paths.sh --command-model ow-plan)" = opus ]'
run "cmdmodel: ow-doc = inherit (default)" '[ "$(bash scripts/ow-paths.sh --command-model ow-doc)" = inherit ]'
run "cmdmodel: unknown verb = inherit default"  '[ "$(bash scripts/ow-paths.sh --command-model ow-nope)" = inherit ]'
run "cmdmodel: resolver allows inherit"      'grep -q "_valid_command_model" scripts/ow-paths.sh && grep -q "inherit) return 0" scripts/ow-paths.sh'

# verb specs no longer carry the dead pinned frontmatter model: (shim/config is single
# source). The only remaining ^model: is ow-agent.md's create-template body (legitimate).
run "cmdmodel: dead pinned model: removed from verb specs" \
  '! grep -rq "^model: claude-sonnet-4-6" .ow/commands/'
run "cmdmodel: only ow-agent template keeps a body model: line" \
  '[ "$(grep -l "^model:" .ow/commands/*.md)" = ".ow/commands/ow-agent.md" ]'

# .ow.yml carries the commands block + the 2 opus overrides (plan + secure)
run "cmdmodel: .ow.yml has commands.model inherit" 'grep -qE "^  model: inherit" .ow.yml'
run "cmdmodel: .ow.yml pins ow-plan opus"         'grep -qE "^    ow-plan: opus" .ow.yml'
run "cmdmodel: .ow.yml pins ow-implement sonnet"  'grep -qE "^    ow-implement: sonnet" .ow.yml'

# generated shims reflect the resolved model
run "cmdmodel: opus-group shim has model: opus"   'grep -qx "model: opus" .claude/commands/ow-plan.md'
run "cmdmodel: inherit shim has NO model line"    '! grep -q "^model:" .claude/commands/ow-doc.md'
run "cmdmodel: exactly 2 shims pinned to opus"    '[ "$(grep -lx "model: opus" .claude/commands/*.md | wc -l | tr -d " ")" -eq 2 ]'
run "cmdmodel: ow-secure override = opus"       '[ "$(bash scripts/ow-paths.sh --command-model ow-secure)" = opus ]'
run "cmdmodel: ow-implement override = sonnet"  '[ "$(bash scripts/ow-paths.sh --command-model ow-implement)" = sonnet ]'

# generate_shims injects model end-to-end in an isolated fixture
run "cmdmodel: generate_shims injects model from config" '
  TD=$(mktemp -d); mkdir -p "$TD/scripts" "$TD/.ow/commands"
  cp scripts/ow-paths.sh scripts/ow-claude-manifest.sh scripts/ow-shims.sh "$TD/scripts/"
  printf -- "---\ndescription: x\n---\nbody\n" > "$TD/.ow/commands/ow-plan.md"
  printf -- "---\ndescription: x\n---\nbody\n" > "$TD/.ow/commands/ow-doc.md"
  printf "vault_path: docs/v\ncommands:\n  model: inherit\n  overrides:\n    ow-plan: opus\n" > "$TD/.ow.yml"
  ( . "$TD/scripts/ow-claude-manifest.sh"; OW_ROOT="$TD" generate_shims "$TD/.ow/commands" "$TD" "ow" )
  OK=1
  grep -qx "model: opus" "$TD/.claude/commands/ow-plan.md" || OK=0     # opus pinned
  grep -q  "^model:"     "$TD/.claude/commands/ow-doc.md" && OK=0  # inherit ⇒ no line
  grep -q  "@.ow/commands/ow-plan.md" "$TD/.claude/commands/ow-plan.md" || OK=0  # @-include intact
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 20 — additive .ow.yml config-block merge on upgrade
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 20 — config-block merge (upgrade backfill)${c_reset}\n"

run "cfgmerge: lib exists + fn defined"   '[ -f scripts/ow-config-merge.sh ] && grep -q "^merge_config_blocks()" scripts/ow-config-merge.sh'
run "cfgmerge: registered in owned manifest" '. scripts/ow-owned.sh; ow_owned_scripts | grep -qx "ow-config-merge.sh"'
run "cfgmerge: upgrade sources the lib"   'grep -q "ow-config-merge.sh" scripts/upgrade.sh'
run "cfgmerge: upgrade calls merge_config_blocks" 'grep -q "merge_config_blocks \"\.ow.yml\" \"\$STAGE/.ow.yml\"" scripts/upgrade.sh'
run "cfgmerge: upgrade backs up .ow.yml pristine" 'grep -q "cp .ow.yml \"\$BACKUP_DIR/.ow.yml\"" scripts/upgrade.sh'
run "cfgmerge: rollback restores .ow.yml" 'grep -qE "^  \.ow\.yml " scripts/upgrade.sh'

# end-to-end behavior in a fixture: old config (no commands block) + custom values
run "cfgmerge: backfills missing block, preserves values, idempotent, valid YAML" '
  TD=$(mktemp -d)
  cp .ow.yml "$TD/template.yml"
  printf "project:\n  name: \"Real App\"\nmode: standalone\nsubagents:\n  backend: true\n" > "$TD/user.yml"
  ( . scripts/ow-config-merge.sh; merge_config_blocks "$TD/user.yml" "$TD/template.yml" ) >/dev/null
  OK=1
  grep -q "^commands:" "$TD/user.yml" || OK=0                        # missing block added
  grep -q "Real App" "$TD/user.yml" || OK=0                          # user value preserved
  grep -q "backend: true" "$TD/user.yml" || OK=0                     # user value preserved
  [ "$(yq ".commands.overrides.ow-plan" "$TD/user.yml")" = opus ] || OK=0  # added block parses
  yq "." "$TD/user.yml" >/dev/null 2>&1 || OK=0                      # whole file valid YAML
  SECOND=$( . scripts/ow-config-merge.sh; merge_config_blocks "$TD/user.yml" "$TD/template.yml" )
  [ -z "$SECOND" ] || OK=0                                           # idempotent
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

run "cfgmerge: existing block is never duplicated" '
  TD=$(mktemp -d)
  cp .ow.yml "$TD/template.yml"; cp .ow.yml "$TD/user.yml"
  ( . scripts/ow-config-merge.sh; merge_config_blocks "$TD/user.yml" "$TD/template.yml" ) >/dev/null
  N=$(grep -c "^commands:" "$TD/user.yml")
  rm -rf "$TD"; [ "$N" -eq 1 ]'

# config is .ow.yml only — no per-machine layer anywhere
run "noLocal: example retired"        '[ ! -e .ow.local.yml.example ]'
run "noLocal: resolver has no local layer" '! grep -qE "\.ow\.local\.yml|TEMPLATES_LOCAL|\.ow/local/(rules|templates)" scripts/ow-paths.sh'
run "noLocal: merge_local_config gone" '! grep -q "merge_local_config" scripts/ow-config-merge.sh scripts/upgrade.sh'
run "noLocal: upgrade retires example" 'grep -q "rm -f .ow.local.yml.example" scripts/upgrade.sh'

# ════════════════════════════════════════════════════════════════════════════
# Section 21 — re-exec handoff (one-pass upgrade; no "run upgrade twice")
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 21 — upgrade re-exec handoff${c_reset}\n"

run "handoff: contract sentinel present"             'grep -q "OW-UPGRADE-HANDOFF-CONTRACT" scripts/upgrade.sh'
run "handoff: bootstrap re-execs staged upgrader"    'grep -q "exec bash \"\$STAGE/scripts/upgrade.sh\"" scripts/upgrade.sh'
run "handoff: forwards root + stage via env"         'grep -q "export OW_UPGRADE_HANDOFF=1 OW_UPGRADE_STAGE=" scripts/upgrade.sh && grep -q "OW_UPGRADE_ROOT=\"\$ROOT\"" scripts/upgrade.sh'
run "handoff: worker root honors OW_UPGRADE_ROOT"   'grep -q "ROOT=\"\${OW_UPGRADE_ROOT:-" scripts/upgrade.sh'
run "handoff: worker adopts staged dir (no refetch)" 'grep -q "STAGE=\"\${OW_UPGRADE_STAGE:" scripts/upgrade.sh'
run "handoff: original args captured for re-exec"    'grep -q "ORIGINAL_ARGS=(\"\$@\")" scripts/upgrade.sh'

# end-to-end: an (old) bootstrap fetches a staged tree carrying the contract and re-execs IT,
# passing the consumer root + stage via env — proving the NEW upgrader runs in a SINGLE pass.
run "handoff: bootstrap fetches + re-execs staged upgrader with correct env" '
  TD=$(mktemp -d)
  mkdir -p "$TD/consumer/scripts" "$TD/stage/scripts" "$TD/stage/.ow"
  cp scripts/upgrade.sh scripts/ow-paths.sh scripts/ow-safe-paths.sh \
     scripts/ow-claude-manifest.sh scripts/ow-shims.sh scripts/ow-frontends.sh \
     scripts/ow-config-merge.sh scripts/ow-gitignore.sh \
     "$TD/consumer/scripts/"
  printf "ow:\n  version: \"0.0.1\"\nvault_path: docs/v\n" > "$TD/consumer/.ow.yml"
  # staged source = a STUB upgrader carrying the sentinel; it records the handoff env it received
  printf "#!/usr/bin/env bash\n# OW-UPGRADE-HANDOFF-CONTRACT: v1\necho \"H=\$OW_UPGRADE_HANDOFF ROOT=\$OW_UPGRADE_ROOT STAGE=\$OW_UPGRADE_STAGE\" > \"\$OW_UPGRADE_ROOT/proof\"\nrm -rf \"\$OW_UPGRADE_STAGE\"\n" > "$TD/stage/scripts/upgrade.sh"
  ( cd "$TD/consumer" && bash scripts/upgrade.sh --source "$TD/stage" ) >/dev/null 2>&1
  OK=1
  grep -q "H=1" "$TD/consumer/proof" || OK=0                 # handed off (worker env set)
  grep -q "ROOT=$TD/consumer" "$TD/consumer/proof" || OK=0   # consumer root forwarded
  grep -q "STAGE=" "$TD/consumer/proof" || OK=0              # staged tree forwarded
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

# a staged version WITHOUT the sentinel must NOT be re-exec'd (legacy fall-through path taken)
run "handoff: pre-contract staged version falls back to legacy" '
  TD=$(mktemp -d)
  mkdir -p "$TD/consumer/scripts" "$TD/stage/scripts" "$TD/stage/.ow"
  cp scripts/upgrade.sh scripts/ow-paths.sh scripts/ow-safe-paths.sh \
     scripts/ow-claude-manifest.sh scripts/ow-shims.sh scripts/ow-frontends.sh \
     scripts/ow-config-merge.sh scripts/ow-gitignore.sh \
     "$TD/consumer/scripts/"
  printf "ow:\n  version: \"0.0.1\"\nvault_path: docs/v\n" > "$TD/consumer/.ow.yml"
  # staged upgrader with NO sentinel + a tripwire: if it were ever exec_d it would write proof
  printf "#!/usr/bin/env bash\necho exec_ed > \"\${OW_UPGRADE_ROOT:-$TD}/proof\"\n" > "$TD/stage/scripts/upgrade.sh"
  out=$( cd "$TD/consumer" && bash scripts/upgrade.sh --source "$TD/stage" 2>&1 || true )
  OK=1
  [ -f "$TD/consumer/proof" ] && OK=0          # MUST NOT have re-exec_d the pre-contract stub
  echo "$out" | grep -q "legacy in-place" || OK=0   # legacy fall-through announced
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

# Section 22 — fix-log auto-closure (source_fix ↔ related_plan, #30)
printf "\n${c_bold}Section 22 — fix-log auto-closure (#30)${c_reset}\n"
PLAN_MD=".ow/commands/ow-plan.md"
IMPL_MD=".ow/commands/ow-implement.md"
FIXCLOSE_MD=".ow/commands/_shared/fixlog-close.md"   # 6.5 detail lives in the fragment
GIT_MD=".ow/commands/ow-git.md"
GITPOST_MD=".ow/commands/_shared/git-post-push.md"
FIX_MD=".ow/commands/ow-fix.md"

# regression guard — the original bug was: grep 'source_fix|related_plan' ow-plan.md = 0 hits
run "fixclose: ow-plan no longer 0-hit on source_fix/related_plan (was the bug)" \
  "[ \"\$(grep -icE 'source_fix|related_plan' $PLAN_MD)\" -gt 0 ]"

# AC1 — /ow-plan fix:<slug> writes source_fix: in plan AND related_plan: back in fix-log
run "fixclose: ow-plan accepts fix: source mode" \
  "grep -qE 'fix:<slug>|--from-fix' $PLAN_MD"
run "fixclose: ow-plan writes source_fix to plan frontmatter" \
  "grep -q 'source_fix' $PLAN_MD"
run "fixclose: ow-plan writes related_plan back-link (Phase 3.5)" \
  "grep -q 'Phase 3.5' $PLAN_MD && grep -q 'related_plan' $PLAN_MD"

# AC2 — /ow-implement closes the source fix-log on plan done (status: fixed + checkboxes)
run "fixclose: ow-implement has Phase 6.5 close-source-fix-log" \
  "grep -q '6.5 Close the source fix-log' $IMPL_MD"
run "fixclose: ow-implement flips fix-log status: fixed via source_fix" \
  "grep -q 'source_fix' $IMPL_MD && grep -q 'status: fixed' $IMPL_MD"
run "fixclose: ow-implement defers commit sha (pending, not a fake HEAD sha)" \
  "grep -q 'fixed_commit: pending' $FIXCLOSE_MD"
run "fixclose: ow-implement bars plan done without closing source fix-log" \
  "grep -qF 'bi-directional close' $FIXCLOSE_MD && grep -qF 'no fix-log left at \`in-progress\`' $FIXCLOSE_MD"

# AC3 — /ow-git --bump stamps fixed_in_version on the fix-log referenced by source_fix
run "fixclose: ow-git has Phase 8.6 fix-log version stamp" \
  "grep -q 'Phase 8.6' $GIT_MD"
run "fixclose: ow-git stamps fixed_in_version from real TARGET_VERSION (no-fake)" \
  "grep -q 'fixed_in_version' $GIT_MD && grep -q 'TARGET_VERSION' $GIT_MD"
run "fixclose: ow-git fills real fixed_commit sha from git" \
  "grep -q 'rev-parse --short HEAD' $GITPOST_MD"

# AC4 — no fix-log left in-progress: escalation path advertises auto-closure
run "fixclose: ow-fix escalation advertises auto-closure" \
  "grep -q 'source_fix' $FIX_MD && grep -qE 'closes automatically|automatically' $FIX_MD"

# AC4 hardening — --from-fix closure + reachable STOP (found by adversarial review)
run "fixclose: ow-implement closes --from-fix fix-log (target IS the fix-log)" \
  "grep -q 'type/fix-log' $FIXCLOSE_MD && grep -q 'FIXLOG=\"\$TGT\"' $FIXCLOSE_MD"
run "fixclose: ow-implement STOPs on missing source_fix target (no silent orphan)" \
  "grep -q '🛑 STOP' $FIXCLOSE_MD"
run "fixclose: ow-git Phase 8.6 stamps --from-fix fix-log (--fix with pending)" \
  "grep -qE 'fixed_commit:.*pending' $GITPOST_MD && grep -q 'from-fix' $GITPOST_MD"

# cross-file consistency — source_fix is the shared linkage field across all 4 specs + plan template
run "fixclose: source_fix present in all 4 command specs" \
  "for f in $PLAN_MD $IMPL_MD $GIT_MD $FIX_MD; do grep -q source_fix \"\$f\" || exit 1; done"
run "fixclose: implement 6.5 points at the fragment that owns the closure" \
  "grep -q '_shared/fixlog-close.md' $IMPL_MD"
run "fixclose: plan + fix-log templates carry the linkage fields" \
  "grep -q source_fix .ow/templates/plan.md && grep -q related_plan .ow/templates/fix-log.md"

# ════════════════════════════════════════════════════════════════════════════
# Section 23 — worktree flow: plan→implement→test --worktree + auto-merge (#31)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 23 — worktree flow (--worktree + auto-merge, #31)${c_reset}\n"
WT_PLAN=".ow/commands/ow-plan.md"
WT_IMPL=".ow/commands/ow-implement.md"
WT_TEST=".ow/commands/ow-test.md"
WT_FRAG=".ow/commands/_shared/worktree.md"        # create/record/commit detail lives in the fragment
WT_MERGE=".ow/commands/_shared/worktree-merge.md" # merge detail lives in this fragment
WT_GATE=".ow/commands/_shared/worktree-cleanup-gate.md"  # the delete gate — shared with /ow-fix-issue 5.3

# — opt-in flag threads through the flow —
run "wt: ow-plan accepts --worktree"            "grep -q -- '--worktree' $WT_PLAN"
run "wt: ow-plan writes worktree: true frontmatter" "grep -q '^worktree: true' $WT_PLAN || grep -q 'worktree: true' $WT_PLAN"
run "wt: ow-implement --worktree + --no-worktree override" "grep -q -- '--worktree' $WT_IMPL && grep -q -- '--no-worktree' $WT_IMPL"
run "wt: ow-implement has Phase 2.7 worktree setup" "grep -q 'Phase 2.7' $WT_IMPL"
run "wt: ow-implement defines WORK_ROOT abstraction" "grep -q 'WORK_ROOT' $WT_IMPL"
run "wt: ow-implement records worktree_status frontmatter" "grep -q 'worktree_status' $WT_FRAG"
run "wt: ow-implement frontmatter contract complete" \
  "grep -q 'worktree_dir' $WT_FRAG && grep -q 'worktree_branch' $WT_FRAG && grep -q 'worktree_base' $WT_FRAG"
run "wt: ow-implement orchestrator commits in worktree (6.4)" "grep -q '6.4' $WT_IMPL && grep -q 'git -C \"\$WORK_ROOT\" commit' $WT_FRAG"
run "wt: ow-implement branches from local HEAD"  "grep -q 'worktree add -b' $WT_FRAG"
run "wt: ow-implement STOP on create fail (no silent in-tree fallback)" "grep -q 'worktree create fail' $WT_FRAG"
run "wt: implement 2.7 points at the fragment that owns the worktree" "grep -q '_shared/worktree.md' $WT_IMPL"

# — auto-merge on PASS lives in /ow-test, local only, safe —
run "wt: ow-test has Phase 7 auto-merge"        "grep -q 'Phase 7' $WT_TEST && grep -qi 'Auto-merge on PASS' $WT_TEST"
run "wt: ow-test accepts --no-merge"            "grep -q -- '--no-merge' $WT_TEST"
run "wt: ow-test 7 points at the fragment that owns the merge" "grep -q '_shared/worktree-merge.md' $WT_TEST"
run "wt: ow-test keeps the PASS/--no-merge gate in the always-loaded spec" \
  "grep -q 'Never auto-merge if any scenario is FAIL/BLOCKED' $WT_TEST"
run "wt: ow-test merges --no-ff local"          "grep -q 'merge --no-ff' $WT_MERGE"
run "wt: no push in worktree merge (spec + fragment)" \
  "grep -qi 'never push' $WT_TEST && grep -qi 'never push' $WT_MERGE"
run "wt: ow-test cleans worktree after merge"    "grep -q 'worktree remove' $WT_GATE"
# — submodule-safe cleanup: absorb objects into main store, gate before any --force —
run "wt: absorbs submodule objects before remove" \
  "grep -q 'cat-file -e' $WT_GATE && grep -q 'ls-tree -r HEAD' $WT_GATE && grep -q 'CLEAN_OK' $WT_GATE"
run "wt: checks worktree dirty before remove" "grep -q 'status --porcelain' $WT_GATE"
run "wt: no worktree removal until merge verified (ancestor check)" \
  "grep -q 'merge-base --is-ancestor' $WT_GATE"
# the gate exists in exactly ONE place — both delete sites call it, neither re-implements it (dedupe is the point)
run "wt: both delete sites point at the single cleanup gate" \
  "grep -q '_shared/worktree-cleanup-gate.md' $WT_MERGE && grep -q '_shared/worktree-cleanup-gate.md' .ow/commands/ow-fix-issue.md"
run "wt: neither caller re-implements the absorb gate" \
  "! grep -q 'CLEAN_OK' $WT_MERGE && ! grep -q 'CLEAN_OK' .ow/commands/ow-fix-issue.md"   # CLEAN_OK = the gate's own marker (4.2's stray-output check legitimately uses status --porcelain)
run "wt: both delete sites call the gate function" \
  "grep -q 'ow_wt_gate' $WT_MERGE && grep -q 'ow_wt_gate' .ow/commands/ow-fix-issue.md && grep -q 'ow_wt_gate()' $WT_GATE"
# — the safety guarantee: non-destructive merge, never blows away parallel uncommitted work (#29) —
run "wt: ow-test uses merge --abort (non-destructive recover)" "grep -q 'merge --abort' $WT_MERGE"
run "wt: ow-test FORBIDS reset --hard/stash/clean to force merge" \
  "grep -q 'reset --hard' $WT_MERGE && grep -q 'git stash' $WT_MERGE && grep -q 'git clean' $WT_MERGE"
run "wt: ow-test STOP if main tree not on base (no risky checkout)" "grep -q \"not base\" $WT_MERGE"
run "wt: submodule mainline merge (7.3.2b) survives the split" \
  "grep -q '7.3.2b' $WT_MERGE && grep -q -- '--submodules' $WT_MERGE"

# — worktrees/ staging dir is gitignored (shared with fix-issue) —
run "wt: worktrees/ in managed gitignore block"  "grep -q 'worktrees/' scripts/ow-gitignore.sh"

# — BEHAVIORAL: prove the Phase 7 merge bash is actually non-destructive (not just string-present) —
# mirrors ow-test.md Phase 7.1-7.3; spec-prose-vs-bash gap is invisible to grep, so we RUN it.
_wt_phase7() {  # REPO BASE BR WT  → merges non-destructively, absorbs submodule objects, cleans up only past gate
  local REPO="$1" BASE="$2" BR="$3" WT="$4"
  [ "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" = "$BASE" ] || { echo GUARD-STOP; return 0; }
  git -C "$REPO" log "$BASE..$BR" --oneline | head -1 >/dev/null 2>&1 || { echo NO-COMMITS; return 0; }
  if ! git -C "$REPO" merge --no-ff "$BR" -m "merge $BR" >/dev/null 2>&1; then
    git -C "$REPO" merge --abort 2>/dev/null || true; echo MERGE-STOP; return 0
  fi
  # 7.3.0 verify merged-for-real before any cleanup (never remove worktree until merge verified)
  git -C "$REPO" merge-base --is-ancestor "$BR" HEAD 2>/dev/null || { echo NOT-MERGED; return 0; }
  # 7.3.1 dirty gate
  [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ] && { echo MERGED-WT-DIRTY; return 0; }
  # 7.3.2 absorb submodule objects + gitlink-resolve gate (superproject merge copies gitlink SHAs only)
  local CLEAN_OK=1 SHA SUB
  while IFS=$'\t' read -r SHA SUB; do
    [ -n "$SHA" ] || continue
    git -C "$REPO/$SUB" cat-file -e "$SHA" 2>/dev/null && continue
    git -C "$REPO/$SUB" fetch --no-tags "$WT/$SUB" HEAD >/dev/null 2>&1
    git -C "$REPO/$SUB" cat-file -e "$SHA" 2>/dev/null && continue
    CLEAN_OK=0
  done < <(git -C "$REPO" ls-tree -r HEAD | awk -F'\t' '{split($1,m," ")} m[1]=="160000" {print m[3] "\t" $2}')
  [ "$CLEAN_OK" -eq 1 ] || { echo MERGED-KEEP-WT; return 0; }
  # 7.3.3 gate passed → safe to remove (--force needed for submodule-bearing worktrees)
  git -C "$REPO" worktree remove "$WT" 2>/dev/null || git -C "$REPO" worktree remove --force "$WT"
  git -C "$REPO" branch -d "$BR" >/dev/null 2>&1 || true; echo MERGE-OK
}

run "wt[behavioral]: merge preserves parallel uncommitted file + cleans worktree" '
  S=$(mktemp -d); R="$S/r"; mkdir -p "$R/worktrees"
  git -C "$R" init -q -b main . 2>/dev/null || { mkdir -p "$R"; (cd "$R" && git init -q -b main); }
  cd "$R"; git config user.email t@t; git config user.name t
  printf "orig\n" > x; printf "doc\n" > a; git add -A; git commit -qm init
  printf "MY PARALLEL UNCOMMITTED\n" > a                      # user mid-work in main tree
  git worktree add -q -b plan/f "$R/worktrees/plan-f" HEAD
  printf "NEW IMPL\n" > "$R/worktrees/plan-f/x"
  git -C "$R/worktrees/plan-f" add -A; git -C "$R/worktrees/plan-f" commit -qm feat
  '"$(declare -f _wt_phase7)"'
  _wt_phase7 "$R" main plan/f "$R/worktrees/plan-f" >/dev/null
  ok=1
  grep -q "NEW IMPL" "$R/x" || ok=0                            # feature merged
  grep -q "MY PARALLEL UNCOMMITTED" "$R/a" || ok=0             # uncommitted PRESERVED
  git -C "$R" status --porcelain | grep -q " a$\|a$" || ok=0   # a still dirty (not reverted)
  [ -d "$R/worktrees/plan-f" ] && ok=0                          # worktree cleaned
  cd /tmp; rm -rf "$S"; [ "$ok" -eq 1 ]'

run "wt[behavioral]: conflict STOPs, keeps worktree, never clobbers uncommitted (#29)" '
  S=$(mktemp -d); R="$S/r"; mkdir -p "$R/worktrees"
  (cd "$R" && git init -q -b main)
  cd "$R"; git config user.email t@t; git config user.name t
  printf "base\n" > c; git add -A; git commit -qm init
  git worktree add -q -b plan/c "$R/worktrees/plan-c" HEAD
  printf "base\nWORKTREE\n" > "$R/worktrees/plan-c/c"
  git -C "$R/worktrees/plan-c" add -A; git -C "$R/worktrees/plan-c" commit -qm feat
  printf "base\nMY UNCOMMITTED — KEEP\n" > "$R/c"              # user edits SAME file, uncommitted
  '"$(declare -f _wt_phase7)"'
  out=$(_wt_phase7 "$R" main plan/c "$R/worktrees/plan-c")
  ok=1
  [ "$out" = MERGE-STOP ] || ok=0                               # refused, not forced
  grep -q "MY UNCOMMITTED — KEEP" "$R/c" || ok=0               # user work intact
  [ -d "$R/worktrees/plan-c" ] || ok=0                          # worktree KEPT for resolve
  [ "$(git -C "$R" rev-list --count main)" = "1" ] || ok=0     # base did NOT advance
  cd /tmp; rm -rf "$S"; [ "$ok" -eq 1 ]'

run "wt[behavioral]: submodule commits survive cleanup (absorb gate — data-loss repro)" '
  S=$(mktemp -d); SUBSRC="$S/subsrc"; R="$S/r"
  mkdir -p "$SUBSRC"; (cd "$SUBSRC" && git init -q -b main && git config user.email t@t && git config user.name t \
    && echo s > s.txt && git add -A && git commit -qm sub-init)
  mkdir -p "$R"; (cd "$R" && git init -q -b main)
  cd "$R"; git config user.email t@t; git config user.name t
  git -c protocol.file.allow=always submodule add -q "$SUBSRC" sub >/dev/null 2>&1
  git commit -qm super-init
  mkdir -p worktrees
  git worktree add -q -b plan/s "$R/worktrees/plan-s" HEAD
  git -C "$R/worktrees/plan-s" -c protocol.file.allow=always submodule update --init -q >/dev/null 2>&1
  (cd "$R/worktrees/plan-s/sub" && git config user.email t@t && git config user.name t \
    && echo new > n.txt && git add -A && git commit -qm sub-feat)
  SUBSHA=$(git -C "$R/worktrees/plan-s/sub" rev-parse HEAD)
  git -C "$R/worktrees/plan-s" add sub
  git -C "$R/worktrees/plan-s" commit -qm "bump sub"
  '"$(declare -f _wt_phase7)"'
  out=$(_wt_phase7 "$R" main plan/s "$R/worktrees/plan-s")
  ok=1
  [ "$out" = MERGE-OK ] || ok=0                                 # gate passed → cleanup ran
  git -C "$R/sub" cat-file -e "$SUBSHA" 2>/dev/null || ok=0     # merged submodule commit SURVIVES in main store
  [ -d "$R/worktrees/plan-s" ] && ok=0                          # worktree cleaned
  cd /tmp; rm -rf "$S"; [ "$ok" -eq 1 ]'

# command count is now still 21 (no new command file — flag-based feature)
run "wt: no worktree command (flag feature, no new command)" '[ ! -f .ow/commands/ow-worktree.md ] && [ ! -f .claude/commands/ow-worktree.md ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 24 — CONTEXT_REFS: conditional vault reads (cold-spawn cost control)
# ════════════════════════════════════════════════════════════════════════════
printf "${c_bold}Section 20 — CONTEXT_REFS conditional vault reads${c_reset}\n"

# The agents /ow-implement Phase 3 can spawn carry the ALWAYS/CONDITIONAL split. Only
# `docs` SHIPS a body — backend/frontend/mobile/design are written by /ow-agent create, so
# for them the invariant is enforced on the TEMPLATE (below), which is the only source they
# can come from. The escape hatch is what makes the split safe: a skipped doc may still be
# read, but never silently — so the worst case is old behavior plus one `context gap:` line.
for a in docs; do
  run "ctxrefs: $a §3 has ALWAYS block"       "grep -qF '**ALWAYS' .claude/agents/$a.md"
  run "ctxrefs: $a §3 has CONDITIONAL block"  "grep -qF '**CONDITIONAL' .claude/agents/$a.md"
  run "ctxrefs: $a reads CONTEXT_REFS"        "grep -qF 'CONTEXT_REFS' .claude/agents/$a.md"
  run "ctxrefs: $a skip is escalatable not silent" \
    "grep -qF 'CONTEXT_SKIPPED' .claude/agents/$a.md && grep -qF 'context gap:' .claude/agents/$a.md"
  run "ctxrefs: $a fail-safe = read all when no CONTEXT_REFS" \
    "grep -qF 'fail-safe = read everything' .claude/agents/$a.md"
done

# A doc the agent only WRITES at the end must not sit in its pre-code ALWAYS list.
# (docs agent is exempt — IMPLEMENTATION-STATUS is its primary work product.) Enforced on
# the template, since that is where every created code agent's §3 comes from.
run "ctxrefs: template ALWAYS block excludes IMPLEMENTATION-STATUS" \
  "! sed -n '/\*\*ALWAYS/,/\*\*CONDITIONAL/p' .ow/commands/ow-agent.md | grep -q IMPLEMENTATION-STATUS"
run "ctxrefs: docs agent KEEPS IMPLEMENTATION-STATUS as always-read" \
  "sed -n '/\*\*ALWAYS/,/\*\*CONDITIONAL/p' .claude/agents/docs.md | grep -q IMPLEMENTATION-STATUS"

# orchestrator side — both lines ALWAYS emitted, never omitted (absent line = read-all)
run "ctxrefs: ow-implement emits CONTEXT_REFS line" \
  'grep -qF "echo \"CONTEXT_REFS:" .ow/commands/_shared/delegation.md'
run "ctxrefs: ow-implement emits CONTEXT_SKIPPED line" \
  'grep -qF "echo \"CONTEXT_SKIPPED:" .ow/commands/_shared/delegation.md'
run "ctxrefs: ow-implement has a resolve step (delegated fragment)" \
  "grep -qF 'Resolve CONTEXT_REFS' .ow/commands/_shared/delegation.md"
run "ctxrefs: ow-implement tells agent to report context gap" \
  "grep -qF 'context gap:' .ow/commands/ow-implement.md"
run "ctxrefs: ow-agent template ships the contract" \
  "grep -qF '**CONDITIONAL' .ow/commands/ow-agent.md && grep -qF 'context gap:' .ow/commands/ow-agent.md"
# Every created agent inherits §3 from this template — so the whole 3-state contract has to
# be in it, or a project's own backend agent silently loses the escape hatch.
for k in '**ALWAYS' 'CONTEXT_REFS' 'CONTEXT_SKIPPED' 'fail-safe = read everything'; do
  run "ctxrefs: template carries '$k'" "grep -qF '$k' .ow/commands/ow-agent.md"
done

# ow-fix-issue spawns up to 7 parallel agents — biggest cold-write multiplier
run "ctxrefs: ow-fix-issue emits CONTEXT_REFS" \
  "grep -qF 'CONTEXT_REFS:' .ow/commands/_shared/fix-issue-fix-flow.md"
run "ctxrefs: ow-fix-issue emits CONTEXT_SKIPPED" \
  "grep -qF 'CONTEXT_SKIPPED:' .ow/commands/_shared/fix-issue-fix-flow.md"
run "ctxrefs: ow-fix-issue resolves per agent before spawn" \
  "grep -qF '4.0 Resolve CONTEXT_REFS' .ow/commands/ow-fix-issue.md"

# canonical fragment — one table, cited by both spawn sites, never copied
run "ctxrefs: fragment file exists"      '[ -f .ow/commands/_shared/context-refs.md ]'
run "ctxrefs: fragment owns uncertain⇒include" \
  "grep -qF 'Uncertain ⇒ include' .ow/commands/_shared/context-refs.md"
run "ctxrefs: fragment states 3-state contract" \
  "grep -qF 'fail-safe is to read everything' .ow/commands/_shared/context-refs.md"
run "ctxrefs: fragment defines context gap line" \
  "grep -qF 'context gap:' .ow/commands/_shared/context-refs.md"
run "ctxrefs: both spawn commands cite the fragment" \
  "grep -rqF '_shared/context-refs.md' .ow/commands/ow-implement.md .ow/commands/_shared/delegation.md && grep -qF '_shared/context-refs.md' .ow/commands/ow-fix-issue.md"
# drift guard: the include-when table lives in exactly ONE file (duplicate tables rot silently)
run "ctxrefs: include-when table appears once" \
  "[ \"\$(grep -rlF 'include when the task' .ow/commands/ | wc -l | tr -d ' ')\" -eq 1 ]"

# SRS layout — single file or hub + modules; one fragment cited by the writers and the reader
run "srs-layout: fragment file exists"   '[ -f .ow/commands/_shared/srs-layout.md ]'
run "srs-layout: every SRS writer + reader cites the fragment" \
  "grep -qF '_shared/srs-layout.md' .ow/commands/ow-new.md && grep -qF '_shared/srs-layout.md' .ow/commands/ow-doc.md && grep -qF '_shared/srs-layout.md' .ow/commands/ow-plan.md && grep -qF '_shared/srs-layout.md' .ow/commands/ow-reverse-engineer.md && grep -qF '_shared/srs-layout.md' .ow/commands/ow-clarify.md && grep -qF '_shared/srs-layout.md' .ow/commands/ow-verify.md"
run "srs-layout: srs.md records the layout key" \
  "grep -qE '^srs_layout: single' .ow/templates/srs.md"
run "srs-layout: module template links its hub + range" \
  "grep -qE '^srs_hub: ' .ow/templates/srs-module.md && grep -qE '^fr_range: ' .ow/templates/srs-module.md"
# the duplicate-FR pipeline in the fragment must actually catch a duplicate across hub + module
run "srs-layout: duplicate FR id is detected across files" \
  "_t=\$(mktemp -d) && printf '### FR-100 — a\n' > \"\$_t/SRS-p.md\" && printf '### FR-100 — b\n### FR-101 — c\n' > \"\$_t/SRS-p-m.md\" \
   && _pipe=\$(grep -F \"grep -oE '^#{2,4} FR-[0-9]+'\" .ow/commands/_shared/srs-layout.md) && [ -n \"\$_pipe\" ] \
   && _out=\$(cat \"\$_t\"/SRS-p.md \"\$_t\"/SRS-p-m.md | grep -oE '^#{2,4} FR-[0-9]+' | grep -oE 'FR-[0-9]+' | sort | uniq -d) \
   && rm -rf \"\$_t\" && [ \"\$_out\" = 'FR-100' ]"

# ════════════════════════════════════════════════════════════════════════════
# Section 25 — /ow-fix auto-fix gate (P2/P3 inline, P0/P1 → plan)
# ════════════════════════════════════════════════════════════════════════════
echo ""
printf "${c_bold}Section 25 — /ow-fix auto-fix gate${c_reset}\n"

run "autofix: ow-fix has the auto-fix gate phase" \
  "grep -q 'Auto-fix gate' $FIX_MD"
run "autofix: ow-fix asks inline (y / plan / pause)" \
  "grep -qF 'Fix now?' $FIX_MD && grep -qF 'plan' $FIX_MD"
run "autofix: ow-fix bars severity lowering to pass the gate" \
  "[ \"\$(grep -ciF 'lower severity to pass' $FIX_MD)\" -ge 2 ]"
run "autofix: ow-fix bars offering y when the gate fails" \
  "grep -qF 'Never offer \`y\` when the gate fails' $FIX_MD"
run "autofix: ow-fix delegates to the implement pipeline (never edits code itself)" \
  "grep -qF -- '--from-fix' $FIX_MD && grep -qF 'Never let \`/ow-fix\` edit code itself' $FIX_MD"
# drift guard: 4.4 must CITE ow-implement, not restate its phases (a second copy rots)
run "autofix: ow-fix cites ow-implement.md rather than copying its phases" \
  "grep -qF '.ow/commands/ow-implement.md' $FIX_MD"

# the gate's other half — --from-fix must REFUSE anything above P2
run "autofix: ow-implement --from-fix accepts P2 and P3" \
  "grep -qE '\--from-fix.*P2' $IMPL_MD"
run "autofix: ow-implement --from-fix refuses P0/P1 in bash (fail-closed)" \
  "grep -qF 'P2|P3) ;;' $IMPL_MD && grep -qF -- 'accepts only a fix-log with' $IMPL_MD"
run "autofix: ow-implement reads severity from the fix-log frontmatter" \
  "grep -qF \"grep -m1 '^severity:'\" $IMPL_MD"
# stale-reference guards — removed commands / vars must not reappear
run "autofix: no dangling /ow-daily-log reference in commands" \
  "! grep -rqF '/ow-daily-log' .ow/commands/"
run "autofix: no dangling \$CHECKIN_DIR reference in commands" \
  "! grep -rqF 'CHECKIN_DIR' .ow/commands/"

# ════════════════════════════════════════════════════════════════════════════
# Section 26 — shim prune: a command removed upstream loses its .claude shim
# ════════════════════════════════════════════════════════════════════════════
echo ""
printf "${c_bold}Section 26 — shim prune (removed commands)${c_reset}\n"

MANIFEST="scripts/ow-claude-manifest.sh"
# Emitters now live in the shared shims lib (sourced BY the manifest).
SHIMS="scripts/ow-shims.sh"

run "prune: generate_shims calls prune_orphan_shims" \
  "grep -q 'prune_orphan_shims \"\$specs\" \"\$root\"' $SHIMS"
run "prune: ownership detected from the generated-shim signature" \
  "grep -q '_is_generated_shim' $SHIMS && grep -qF 'description: obsidian-workflow /' $SHIMS"
run "prune: upgrade dry-run announces the prune" \
  "grep -q 'prune shims of removed commands' scripts/upgrade.sh"
run "prune: ow-sync spec no longer claims removal it does not do" \
  "! grep -qF 'picks up any command added/removed' .ow/commands/ow-sync.md"
run "prune: .claude/commands stays in ROLLBACK_PATHS (a prune is undoable)" \
  "grep -qF '.ow/commands .claude/commands .claude/agents' scripts/upgrade.sh"

# behavioural: build a throwaway tree and drive the real function
_prune_fixture() {                       # $1 = scratch dir
  mkdir -p "$1/.ow/commands" "$1/.claude/commands" "$1/commands"
  printf '# kept\n'     > "$1/.ow/commands/ow-kept.md"
  printf '# ghost\n'    > "$1/.ow/commands/ow-ghost.md"
  printf '# overridden\n' > "$1/.ow/commands/ow-over.md"
  printf '# proj override\n' > "$1/commands/ow-over.md"
  ( . scripts/ow-claude-manifest.sh; generate_shims "$1/.ow/commands" "$1" ow ) >/dev/null 2>&1
  printf -- '---\ndescription: my own thing\n---\n\nbody\n' > "$1/.claude/commands/ow-mine.md"
  rm "$1/.ow/commands/ow-ghost.md" "$1/.ow/commands/ow-over.md"   # upstream removes both
  ( . scripts/ow-claude-manifest.sh; generate_shims "$1/.ow/commands" "$1" ow ) >/dev/null 2>&1
}

run "prune: removed command's shim is deleted" \
  "T=\$(mktemp -d); _prune_fixture \"\$T\"; r=0; [ -f \"\$T/.claude/commands/ow-ghost.md\" ] && r=1; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "prune: still-shipped command's shim survives" \
  "T=\$(mktemp -d); _prune_fixture \"\$T\"; r=1; [ -f \"\$T/.claude/commands/ow-kept.md\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "prune: user-written command is never touched (no generated signature)" \
  "T=\$(mktemp -d); _prune_fixture \"\$T\"; r=1; [ -f \"\$T/.claude/commands/ow-mine.md\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "prune: shim backed by a commands/<verb>.md override survives spec removal" \
  "T=\$(mktemp -d); _prune_fixture \"\$T\"; r=1; [ -f \"\$T/.claude/commands/ow-over.md\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "prune: idempotent — second run deletes nothing more" \
  "T=\$(mktemp -d); _prune_fixture \"\$T\"; a=\$(ls \"\$T/.claude/commands\" | wc -l); ( . scripts/ow-claude-manifest.sh; generate_shims \"\$T/.ow/commands\" \"\$T\" ow ) >/dev/null 2>&1; b=\$(ls \"\$T/.claude/commands\" | wc -l); rm -rf \"\$T\"; [ \"\$a\" -eq \"\$b\" ]"

# ════════════════════════════════════════════════════════════════════════════
# Section 27 — greenfield sample-vault copy lands AT $VAULT_PATH (not nested)
# ════════════════════════════════════════════════════════════════════════════
echo ""
printf "${c_bold}Section 27 — greenfield sample-vault copy${c_reset}\n"

run "vaultcopy: install.sh sources the sample VAULT, not its parent docs/" \
  "grep -qF 'sample_vault=\"\$TMP_DIR/docs/obsidian-vault\"' scripts/install.sh"
run "vaultcopy: no copy from the docs/ parent survives" \
  "! grep -qF -- '\$TMP_DIR/docs/.' scripts/install.sh"
run "vaultcopy: existence guard checks the sample vault dir" \
  "grep -qF '&& -d \"\$sample_vault\" &&' scripts/install.sh"
run "vaultcopy: sample vault exists in this repo" \
  "[ -d docs/obsidian-vault/00-Index ]"

# behavioural: replay the installer's copy with the real repo layout
_vault_sim() {                               # $1 = scratch root, $2 = VAULT_PATH
  local tmp; tmp="$1/clone"
  mkdir -p "$tmp"; cp -r docs "$tmp/docs"    # simulate `git clone` of this repo
  local full_vault="$1/target/$2"; mkdir -p "$full_vault"
  local sample_vault="$tmp/docs/obsidian-vault"
  cp -r "$sample_vault/." "$full_vault/"
  printf '%s' "$full_vault"
}

run "vaultcopy: choice A (docs/obsidian-vault) is not double-nested" \
  "T=\$(mktemp -d); fv=\$(_vault_sim \"\$T\" docs/obsidian-vault); r=0; [ -d \"\$fv/obsidian-vault\" ] && r=1; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "vaultcopy: choice A puts 00-Index directly under \$VAULT_PATH" \
  "T=\$(mktemp -d); fv=\$(_vault_sim \"\$T\" docs/obsidian-vault); r=1; [ -f \"\$fv/00-Index/IMPLEMENTATION-STATUS.md\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "vaultcopy: choice B (docs) puts 00-Index directly under \$VAULT_PATH" \
  "T=\$(mktemp -d); fv=\$(_vault_sim \"\$T\" docs); r=1; [ -f \"\$fv/00-Index/IMPLEMENTATION-STATUS.md\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "vaultcopy: dotfiles (.obsidian) come along" \
  "T=\$(mktemp -d); fv=\$(_vault_sim \"\$T\" docs/obsidian-vault); r=1; [ -d \"\$fv/.obsidian\" ] && r=0; rm -rf \"\$T\"; [ \$r -eq 0 ]"
run "vaultcopy: sample vault carries no removed-subsystem folder" \
  "[ ! -d docs/obsidian-vault/75-Checkins ]"

# Section 28 — chunked implement: CHUNK block + handoff spawn
printf "\n${c_bold}Section 28 — chunked implement (CHUNK block + handoff)${c_reset}\n"
CH_IMPL=".ow/commands/ow-implement.md"
CH_AGENT=".ow/commands/ow-agent.md"
CH_FRAG=".ow/commands/_shared/delegation.md"   # partition/CHUNK block/loop live in the fragment

# ── partition (3.2) ──
run "chunk: implement has 3.2 partition phase" \
  "grep -q '2. Partition the plan' $CH_FRAG"
run "chunk: partition needs a verifiable boundary (build + test + no forward dep)" \
  "grep -q 'verifiable state' $CH_FRAG && grep -q 'builds/compiles' $CH_FRAG"
run "chunk: plan <=6 steps stays single-spawn (no CHUNK block)" \
  "grep -q 'emit no CHUNK block' $CH_FRAG"
run "chunk: --from-fix (no Implementation Steps) stays single-spawn" \
  "grep -q 'no \`Implementation Steps\`' $CH_FRAG"
run "chunk: one chunk = one agent (subagent_target: all splits per agent)" \
  "grep -q '1 chunk = 1 agent' $CH_FRAG"
run "chunk: STEPS is a contiguous range, never a jumped list" \
  "grep -q 'contiguous range' $CH_FRAG"

# ── CHUNK block is the authoritative contract (agent files are NOT shipped) ──
run "chunk: implement emits the CHUNK block" \
  "grep -q '=== CHUNK n/N ===\|=== CHUNK 2/4' $CH_FRAG"
run "chunk: block carries every handoff field" \
  "for f in STEPS EXIT_STATE READ_FULL READ_NAMED DIGEST DECISIONS DEVIATIONS CONTEXT_GAPS; do grep -q \"\$f:\" $CH_FRAG || exit 1; done"
run "chunk: RETURN PROTOCOL lives inside the injected block (not the agent file)" \
  "grep -q 'RETURN PROTOCOL' $CH_FRAG && grep -q 'STATUS: DONE | CONTINUE | BLOCKED' $CH_FRAG"
run "chunk: block states why it is authoritative (specialized agents are not shipped)" \
  "grep -q 'written by' $CH_FRAG && grep -q 'must not overwrite' $CH_FRAG"
run "chunk: empty field written (none), never omitted" \
  "grep -q 'emit the word (none)' $CH_FRAG"
run "chunk: CONTINUE spawns get a letter suffix, existing chunks never renumber" \
  "grep -q '2a/4' $CH_FRAG && grep -q 'never renumber' $CH_FRAG"

# ── loop + guards (3.5) ──
run "chunk: implement has 3.5 chunk loop" \
  "grep -q '6. Chunk loop' $CH_FRAG"
run "chunk: orchestrator runs EXIT_STATE itself (no fake results)" \
  "grep -q 'orchestrator runs \`EXIT_STATE\` itself' $CH_FRAG"
run "chunk: BLOCKED stops and asks a human — no auto-retry" \
  "grep -q 'never auto-retry' $CH_IMPL"
run "chunk: CONTINUE with 0 steps done is treated as BLOCKED" \
  "grep -q '0 step' $CH_FRAG"
run "chunk: spawn ceiling max(2N, N+3)" \
  "grep -q 'max(2 × N, N + 3)' $CH_FRAG"
run "chunk: bad partition re-partitions once, then asks a human" \
  "grep -q 're-partition' $CH_FRAG"
run "chunk: context gap feeds READ_NAMED of the remaining chunks" \
  "grep -q 'context gap:' $CH_FRAG && grep -q 'add that doc to the' $CH_FRAG"
run "chunk: chunks never commit — one commit at Phase 6.4" \
  "grep -qi 'chunks do not commit' $CH_FRAG"

# ── durability: Chunk Progress must not trip the Phase 6.0 open-checkbox gate ──
run "chunk: Chunk Progress section written to the plan" \
  "grep -q '## Chunk Progress' $CH_FRAG"
run "chunk: only - [x] is ever written (Phase 6.0 gate unaffected)" \
  "grep -qF -- '\`- [x]\` **only**, never \`- [ ]\`' $CH_FRAG"
run "chunk: progress written to the MAIN_ROOT vault, never inside a worktree" \
  "grep -q 'must never write \`docs/\` inside the worktree' $CH_FRAG"
run "chunk: resume re-runs the last ticked exit before skipping" \
  "grep -q '1.2 Resume gate' $CH_IMPL && grep -q 'never trust the marker' $CH_IMPL"

# ── prompt template + fail-safe ──
run "chunk: prompt tells the agent to obey STEPS only" \
  "grep -q 'do only these' $CH_FRAG"
run "chunk: no CHUNK block ⇒ whole plan (fail-safe = current behavior)" \
  "grep -q 'No CHUNK block' $CH_FRAG && grep -q 'do the whole plan' $CH_FRAG"

# ── contract reaches new agents via the /ow-agent template ──
run "chunk: ow-agent §0 template carries the CHUNK contract" \
  "grep -q 'CHUNK n/N' $CH_AGENT && grep -q 'No CHUNK block' $CH_AGENT"
run "chunk: ow-agent §3 template maps ALWAYS list to READ_FULL + READ_NAMED" \
  "grep -q 'READ_FULL\` + \`READ_NAMED' $CH_AGENT"

# ── the shipped agent + the template every created one comes from mirror the contract ──
run "chunk: shipped docs agent carries the §0 CHUNK contract" \
  "grep -q 'CHUNK n/N' .claude/agents/docs.md && grep -q 'READ_FULL' .claude/agents/docs.md"
run "chunk: the create template carries the §0 CHUNK contract" \
  "grep -q 'CHUNK n/N' .ow/commands/ow-agent.md && grep -q 'READ_FULL' .ow/commands/ow-agent.md"

# Section 29 — implement: delegation is a judgment call, never a mandate
printf "\n${c_bold}Section 29 — implement: subagent use is a judgment call${c_reset}\n"
DG_IMPL=".ow/commands/ow-implement.md"
DG_FRAG=".ow/commands/_shared/delegation.md"

run "delegate: implement Phase 3 has the 3.0 decision step" \
  "grep -q '3.0 Decide how to run it' $DG_IMPL"
run "delegate: implement states no mandate either way" \
  "grep -q 'no mandate either way' $DG_IMPL"
run "delegate: subagent_target = area rules, not an order to spawn" \
  "grep -q 'order to spawn' $DG_IMPL"
run "delegate: both modes offered, neither forced" \
  "grep -q 'whichever actually fits this plan' $DG_IMPL && grep -q 'Nothing' $DG_IMPL"
run "delegate: the spawn trade-off is stated on both sides" \
  "grep -q 'cold-cache write every time' $DG_IMPL && grep -q 'what it buys back' $DG_IMPL"
run "delegate: inline still carries the area gates" \
  "grep -q 'Running it inline' $DG_IMPL && grep -q -- '--rules <area>' $DG_IMPL"
run "delegate: context-block phases are delegated-mode only" \
  "grep -q 'Running inline → skip it entirely' $DG_IMPL && grep -q 'Running inline ⇒ none of it applies' $DG_FRAG"
run "delegate: chunking is delegated-mode only" \
  "grep -q 'Never chunk an inline run' $DG_IMPL && grep -q 'an inline run never chunks' $DG_FRAG"
run "delegate: no fan-out of parallel agents for one plan" \
  "grep -q 'never a fan-out' $DG_IMPL"
run "delegate: Never-list bars reading subagent_target as an order" \
  "grep -q 'Never read \`subagent_target\` as an order to spawn' $DG_IMPL"
run "delegate: no phase may make either mode mandatory" \
  "grep -q 'no phase may make either mode mandatory' $DG_IMPL"
run "delegate: DS gate binds the work, not the executor" \
  "grep -q 'the gate is on the work, not on who does it' $DG_IMPL"
run "delegate: result records how it ran (inline | subagent)" \
  "grep -q 'Executed by: inline' $DG_IMPL"

# ── /ow-test: same judgment call for test-runner ──
DG_TEST=".ow/commands/ow-test.md"
run "delegate: ow-test Phase 3 is inline-or-test-runner" \
  "grep -q 'Phase 3 — Run the smoke tests (inline or via test-runner)' $DG_TEST"
run "delegate: ow-test has the 3.0 decision step, no mandate" \
  "grep -q '3.0 Decide how to run it' $DG_TEST && grep -q 'no mandate either way' $DG_TEST"
run "delegate: ow-test names the same trade-off as implement 3.0" \
  "grep -q 'cold-cache write' $DG_TEST && grep -q 'what it buys back' $DG_TEST"
run "delegate: ow-test keeps the CONTEXT block mandatory when delegating" \
  "grep -q 'the PROJECT CONTEXT block below is \*\*mandatory\*\*' $DG_TEST"
run "delegate: ow-test inline owns tasks 1-7" \
  "grep -q 'Inline: tasks 1-7 are your own list' $DG_TEST"
run "delegate: ow-test Never-list bars a mandatory test-runner" \
  "grep -q 'Never treat the \`test-runner\` agent as mandatory' $DG_TEST"
run "delegate: ow-test dispatch table no longer orders a spawn" \
  "! grep -q 'dispatch test-runner' $DG_TEST"

# /ow-design — same rule: the DS gates bind the work, the design agent is never mandatory
DG_DESIGN=".ow/commands/ow-design.md"
run "delegate: ow-design has the 0.1 decision step, no mandate" \
  "grep -q '0.1 Decide how to run it' $DG_DESIGN && grep -q 'no mandate either way' $DG_DESIGN"
run "delegate: ow-design no longer orders a spawn" \
  "! grep -q 'Spawn the \`design\` subagent' $DG_DESIGN"
run "delegate: ow-design names the same trade-off as implement 3.0" \
  "grep -q 'cold-cache write' $DG_DESIGN && grep -q 'what it buys back' $DG_DESIGN"
run "delegate: ow-design inline still carries the §5 gates" \
  "grep -q 'Running inline' $DG_DESIGN && grep -q -- '--rules design' $DG_DESIGN"
run "delegate: ow-design Never-list bars a mandatory design agent" \
  "grep -q 'Never treat the \`design\` agent as mandatory' $DG_DESIGN"

# /ow-fix-issue — fan-out stays right for N>1 (independent worktrees), judgment for N=1
DG_FIXISSUE=".ow/commands/ow-fix-issue.md"
run "delegate: ow-fix-issue has the decision step, no mandate" \
  "grep -q 'Decide how to run it' $DG_FIXISSUE && grep -q 'no mandate either way' $DG_FIXISSUE"
run "delegate: ow-fix-issue keeps the fan-out for N>1 (independent worktrees)" \
  "grep -q 'fan out, that is the whole point' $DG_FIXISSUE"
run "delegate: ow-fix-issue single group is a judgment call" \
  "grep -q 'N = 1 approved group' $DG_FIXISSUE"
run "delegate: ow-fix-issue inline carries the same downstream gates" \
  "grep -q 'nothing changes downstream' $DG_FIXISSUE && grep -q 'carry steps 1-14 of \`_shared/fix-issue-fix-flow.md\` yourself' $DG_FIXISSUE"

# ════════════════════════════════════════════════════════════════════════════
# Section 30 — _shared/ command fragments (mode-gated detail read on demand, #34)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 30 — _shared/ command fragments (#34)${c_reset}\n"
FR_DIR=".ow/commands/_shared"
FR_IMPL=".ow/commands/ow-implement.md"
FR_TEST=".ow/commands/ow-test.md"
FR_FIXISSUE=".ow/commands/ow-fix-issue.md"

run "frag: the fragment set ships"        "for f in README worktree worktree-merge worktree-cleanup-gate delegation build-test fixlog-close fix-issue-fix-flow fix-issue-ready-for-test; do [ -f $FR_DIR/\$f.md ] || exit 1; done"
run "frag: implement points at every fragment it needs" \
  "for f in worktree delegation build-test fixlog-close; do grep -q \"_shared/\$f.md\" $FR_IMPL || exit 1; done"
run "frag: ow-test points at the merge fragment"  "grep -q '_shared/worktree-merge.md' $FR_TEST"
run "frag: fix-issue points at every fragment it needs" \
  "for f in fix-issue-fix-flow fix-issue-ready-for-test worktree-cleanup-gate; do grep -q \"_shared/\$f.md\" $FR_FIXISSUE || exit 1; done"
run "frag: every fragment is listed in the _shared README index" \
  "for f in $FR_DIR/*.md; do b=\$(basename \$f); [ \"\$b\" = README.md ] && continue; grep -q \"\$b\" $FR_DIR/README.md || exit 1; done"
# the whole point of the split: a fragment is READ on demand, never @-included (an @ would paste
# the body back into every run and the main spec would be big again)
run "frag: never @-included (read on demand)" \
  "! grep -rq '@\\.ow/commands/_shared' .ow/ .claude/ 2>/dev/null"
# regrowth guard — the reason the split exists is the always-loaded file's size
run "frag: implement spec stays lean (<400 lines)" \
  "[ \"\$(wc -l < $FR_IMPL | tr -d ' ')\" -lt 400 ]"
run "frag: ow-test spec stays lean (<400 lines)" \
  "[ \"\$(wc -l < $FR_TEST | tr -d ' ')\" -lt 400 ]"
run "frag: ow-fix-issue spec stays lean (<620 lines)" \
  "[ \"\$(wc -l < $FR_FIXISSUE | tr -d ' ')\" -lt 620 ]"
# a fragment is not a verb: no Phase 0, and no emitter may turn it into a command/skill
run "frag: fragments carry no Phase 0 preamble (not verbs)" \
  "! grep -rq 'OW-PHASE0' $FR_DIR/"
run "frag: no _shared shim or skill is emitted" '
  T=$(mktemp -d); mkdir -p "$T/.ow/commands/_shared"
  cp .ow/commands/*.md "$T/.ow/commands/" 2>/dev/null
  cp .ow/commands/_shared/*.md "$T/.ow/commands/_shared/" 2>/dev/null
  ( . scripts/ow-claude-manifest.sh; generate_shims "$T/.ow/commands" "$T" ow; generate_skills "$T/.ow/commands" "$T" ) >/dev/null 2>&1
  ok=1
  [ -e "$T/.claude/commands/_shared.md" ] && ok=0
  [ -e "$T/.agents/skills/_shared" ] && ok=0
  ls "$T/.claude/commands" | grep -q "^_shared" && ok=0
  rm -rf "$T"; [ "$ok" -eq 1 ]'
# lint coverage — fragments are inside checks 2/3/5/6, and a dangling pointer is fatal (check 7)
run "frag: conformance-lint scans the fragments"  "grep -q 'FRAG=\"\$CMDS/_shared\"' scripts/conformance-lint.sh"
_frag_cmd() {   # FILE FRAGNAME → a well-formed verb spec pointing at _shared/<FRAGNAME>.md
  printf -- '<!-- OW-PHASE0 -->\n```bash\n# 1) resolve config — never a bare relative path\neval "$(bash x --shell)" || exit 1\n[ -n "$VAULT_ABS" ] || exit 1\nexport OW_CTX_LOADED=1\n```\n🔴 Read `.ow/commands/_shared/%s.md`\n' "$2" > "$1"
}
run "frag[behavioral]: lint FAILS on a dangling fragment pointer" '
  T=$(mktemp -d); mkdir -p "$T/.ow/commands/_shared"; '"$(declare -f _frag_cmd)"'
  _frag_cmd "$T/.ow/commands/ow-x.md" nope
  out=$(bash scripts/conformance-lint.sh "$T" 2>&1); rc=$?; rm -rf "$T"
  [ "$rc" -ne 0 ] && echo "$out" | grep -q "check 7"'
run "frag[behavioral]: lint PASSES when the pointer resolves" '
  T=$(mktemp -d); mkdir -p "$T/.ow/commands/_shared"; '"$(declare -f _frag_cmd)"'
  _frag_cmd "$T/.ow/commands/ow-x.md" ok
  printf -- "# ok\n" > "$T/.ow/commands/_shared/ok.md"
  bash scripts/conformance-lint.sh "$T" >/dev/null 2>&1; rc=$?; rm -rf "$T"; [ "$rc" -eq 0 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 31 — Phase 0 step-1 block: no drift between commands (lint check 8)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 31 — Phase 0 step-1 anti-drift (lint check 8)${c_reset}\n"
# Every command pastes this block on every run, so a drifted copy breaks that one command and
# check 1 (marker present?) cannot see it. Keeping it inline is deliberate: the block always
# fires, so moving it to a fragment would save no per-run context and cost an extra read.
run "p0: check 8 exists in the lint"      'grep -q "check 8" scripts/conformance-lint.sh'
run "p0: real tree passes check 8"        'bash scripts/conformance-lint.sh 2>&1 | grep -q "check 8: Phase 0 step-1 block identical"'
run "p0: the marker no longer claims commands are wholly identical" \
  '! grep -rq "identical across all commands; enforced by conformance lint" .ow/commands/*.md'
run "p0: marker names the per-command exception (--rules area)" \
  'grep -q -- "per-command only in its \`--rules <area>\` argument" .ow/commands/ow-plan.md'
# BEHAVIORAL — drift must actually fail the gate, not just be described as failing
_p0_fixture() {   # DIR  → two commands whose step-1 blocks match
  mkdir -p "$1/.ow/commands"
  for v in a b; do
    printf -- '<!-- OW-PHASE0 -->\n```bash\n# 1) resolve config — never a bare relative path\neval "$(bash x --shell)" || exit 1\n[ -n "$VAULT_ABS" ] || exit 1\nexport OW_CTX_LOADED=1\nRULES=$(bash x --rules %s)\n```\n' "$v" > "$1/.ow/commands/ow-$v.md"
  done
}
run "p0[behavioral]: identical blocks PASS (differing --rules area is allowed)" '
  T=$(mktemp -d); '"$(declare -f _p0_fixture)"'
  _p0_fixture "$T"
  bash scripts/conformance-lint.sh "$T" >/dev/null 2>&1; rc=$?; rm -rf "$T"; [ "$rc" -eq 0 ]'
run "p0[behavioral]: a drifted step-1 line FAILS the lint" '
  T=$(mktemp -d); '"$(declare -f _p0_fixture)"'
  _p0_fixture "$T"
  sed -i.bak "s/eval \"\$(bash x --shell)\" || exit 1/eval \"\$(bash WRONG --shell)\"/" "$T/.ow/commands/ow-b.md"
  rm -f "$T/.ow/commands/"*.bak
  out=$(bash scripts/conformance-lint.sh "$T" 2>&1); rc=$?; rm -rf "$T"
  [ "$rc" -ne 0 ] && echo "$out" | grep -q "check 8"'
run "p0[behavioral]: a dropped VAULT_ABS assert FAILS the lint" '
  T=$(mktemp -d); '"$(declare -f _p0_fixture)"'
  _p0_fixture "$T"
  grep -v "VAULT_ABS" "$T/.ow/commands/ow-b.md" > "$T/x" && mv "$T/x" "$T/.ow/commands/ow-b.md"
  out=$(bash scripts/conformance-lint.sh "$T" 2>&1); rc=$?; rm -rf "$T"
  [ "$rc" -ne 0 ] && echo "$out" | grep -q "check 8"'

# ════════════════════════════════════════════════════════════════════════════
# Section 32 — /ow-fix-issue merge: verify base, never switch to it (#29)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 32 — fix-issue merge guards (#29 aligned with /ow-test)${c_reset}\n"
FI_SPEC=".ow/commands/ow-fix-issue.md"
run "fi-merge: no git checkout to reach the base branch" \
  "! grep -qE '^\\s*(cd \"\\\$TARGET_REPO\"|git(-C.*)? checkout \"?\\\$?\\{?(BASE|FIX\\[base_branch\\])' $FI_SPEC"
run "fi-merge: 5.1 verifies the repo is already on base"  "grep -q 'not base' $FI_SPEC || grep -q \"not base '\" $FI_SPEC"
run "fi-merge: 5.1 refuses to merge over a dirty repo"    "grep -q 'has uncommitted changes — merge skipped' $FI_SPEC"
run "fi-merge: wrong branch / dirty = skip, never force"  "grep -q 'never \`checkout\`' $FI_SPEC"
run "fi-merge: conflict aborts back to the pre-merge state" "grep -q 'merge --abort' $FI_SPEC"
run "fi-merge: ff-only pull is the only network step, justified" \
  "grep -q -- 'pull --ff-only origin' $FI_SPEC && grep -q 'never rewrite local history' $FI_SPEC"
run "fi-merge: destructive git still banned in the Never/Safety list" \
  "grep -q 'git reset --hard' $FI_SPEC && grep -q 'git stash' $FI_SPEC && grep -q 'git clean' $FI_SPEC"
run "fi-merge: cleanup-gate precondition says verify, not checkout" \
  "grep -q 'verifying, never switching' .ow/commands/_shared/worktree-cleanup-gate.md"

# ════════════════════════════════════════════════════════════════════════════
# Multi-person git sync — scripts/ow-git-sync.sh
# Behavioural, not grep-only: the conflict classifier decides what a human is
# asked to resolve, so it is exercised against real conflicted repos.
# ════════════════════════════════════════════════════════════════════════════
GS="$PWD/scripts/ow-git-sync.sh"
GS_TMP="${TMPDIR:-/tmp}/ow-gs-test.$$"

# _gs_repo <dir> — a git repo with a committed base, on branch main
_gs_repo() {
  rm -rf "$1"; mkdir -p "$1"; git init -q "$1"
  git -C "$1" config user.email t@t; git -C "$1" config user.name t
  git -C "$1" checkout -qb main 2>/dev/null || true
}
# _gs_conflict <dir> <relpath> <base> <mine> <theirs> — leaves <dir> mid-merge on that file
_gs_conflict() {
  local d="$1" f="$2"
  _gs_repo "$d"; mkdir -p "$d/$(dirname "$f")"
  printf '%b' "$3" > "$d/$f"; git -C "$d" add -A; git -C "$d" commit -qm base
  git -C "$d" checkout -qb feat
  printf '%b' "$4" > "$d/$f"; git -C "$d" commit -qam mine
  git -C "$d" checkout -q main
  printf '%b' "$5" > "$d/$f"; git -C "$d" commit -qam theirs
  git -C "$d" checkout -q feat; git -C "$d" merge main -m x >/dev/null 2>&1 || true
}
VROW='| ID | S |\n|---|---|\n'

run "git-sync: script exists + executable"  '[ -x scripts/ow-git-sync.sh ]'
run "git-sync: in owned manifest"           'bash scripts/ow-owned.sh 2>/dev/null; . scripts/ow-owned.sh; ow_owned_scripts | grep -qx "ow-git-sync.sh"'
run "git-sync: resolver emits git block"    'bash scripts/ow-paths.sh --json | jq -e ".git.auto_sync" >/dev/null'
run "git-sync: yml documents git block"     'grep -q "^git:" .ow.yml && grep -q "auto_resolve:" .ow.yml'
# code lines only — the header comments name --force / rebase --abort precisely to forbid them
run "git-sync: never force-pushes"          '! grep -vE "^[[:space:]]*#" scripts/ow-git-sync.sh | grep -qE "push .*(--force|-f )"'
run "git-sync: never aborts a rebase"       '! grep -vE "^[[:space:]]*#" scripts/ow-git-sync.sh | grep -q "rebase --abort"'
run "git-sync: vault path is symlink-safe"  'grep -q "pwd -P" scripts/ow-git-sync.sh'

run "git-sync: version class keeps higher semver" \
  "_gs_conflict $GS_TMP/v VERSION '1.2.3\n' '1.2.5\n' '1.2.4\n' && bash $GS resolve $GS_TMP/v >/dev/null && grep -qx '1.2.5' $GS_TMP/v/VERSION"
run "git-sync: changelog class unions both sides" \
  "_gs_conflict $GS_TMP/c CHANGELOG.md '## [1.0.0]\n- b\n' '## [1.2.5]\n- mine\n\n## [1.0.0]\n- b\n' '## [1.2.4]\n- theirs\n\n## [1.0.0]\n- b\n' && bash $GS resolve $GS_TMP/c >/dev/null && grep -q 'mine' $GS_TMP/c/CHANGELOG.md && grep -q 'theirs' $GS_TMP/c/CHANGELOG.md"
run "git-sync: vault-append unions table rows" \
  "_gs_conflict $GS_TMP/va docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md '${VROW}| FN-001 | done |\n' '${VROW}| FN-001 | done |\n| FN-003 | wip |\n' '${VROW}| FN-001 | done |\n| FN-002 | wip |\n' && OW_VAULT_ABS=$GS_TMP/va/docs/obsidian-vault bash $GS resolve $GS_TMP/va >/dev/null && grep -q 'FN-002' $GS_TMP/va/docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md && grep -q 'FN-003' $GS_TMP/va/docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md"
run "git-sync: vault prose is NEVER auto-resolved" \
  "_gs_conflict $GS_TMP/vp docs/obsidian-vault/FN-1.md 'intro\n' 'intro mine\n' 'intro theirs\n'; OW_VAULT_ABS=$GS_TMP/vp/docs/obsidian-vault bash $GS resolve $GS_TMP/vp | grep -q '^unresolved'"
run "git-sync: same row key + different value = human" \
  "_gs_conflict $GS_TMP/vk docs/obsidian-vault/S.md '${VROW}| FN-001 | wip |\n' '${VROW}| FN-001 | done |\n' '${VROW}| FN-001 | blocked |\n'; OW_VAULT_ABS=$GS_TMP/vk/docs/obsidian-vault bash $GS resolve $GS_TMP/vk | grep -q '^unresolved'"
run "git-sync: source conflict exits 3" \
  "_gs_conflict $GS_TMP/src app.js 'x=1\n' 'x=3\n' 'x=2\n'; bash $GS resolve $GS_TMP/src >/dev/null; [ \$? -eq 3 ]"
run "git-sync: no remote exits 4 (solo/offline unchanged)" \
  "_gs_repo $GS_TMP/solo && echo x > $GS_TMP/solo/a && git -C $GS_TMP/solo add -A && git -C $GS_TMP/solo commit -qm s; bash $GS sync $GS_TMP/solo >/dev/null; [ \$? -eq 4 ]"
run "git-sync: auto_sync=false exits 4" \
  "OW_GIT_AUTO_SYNC=false bash $GS sync $GS_TMP/solo >/dev/null; [ \$? -eq 4 ]"
run "git-sync: non-ff push re-syncs and retries" \
  "git init -q --bare $GS_TMP/rem && _gs_repo $GS_TMP/a && echo base > $GS_TMP/a/f && git -C $GS_TMP/a add -A && git -C $GS_TMP/a commit -qm base && git -C $GS_TMP/a remote add origin $GS_TMP/rem && git -C $GS_TMP/a push -q -u origin main && git clone -q $GS_TMP/rem $GS_TMP/b && git -C $GS_TMP/b config user.email b@b && git -C $GS_TMP/b config user.name b && echo alice >> $GS_TMP/a/f && git -C $GS_TMP/a commit -qam alice && git -C $GS_TMP/a push -q origin main && echo bob > $GS_TMP/b/g && git -C $GS_TMP/b add -A && git -C $GS_TMP/b commit -qm bob && bash $GS push $GS_TMP/b main | grep -q '^pushed'"
run "git-sync: tag collision exits 5, tag not moved" \
  "git -C $GS_TMP/a fetch -q origin && git -C $GS_TMP/a tag v9.9.9 && git -C $GS_TMP/a push -q origin v9.9.9 && git -C $GS_TMP/b tag -f v9.9.9 HEAD >/dev/null 2>&1; bash $GS push-tag $GS_TMP/b v9.9.9 | grep -q '^tag-collision'"
run "git-sync: status reports ahead/behind + upstream" \
  "bash $GS status $GS_TMP/b | grep -qE '^[0-9]+	[0-9]+	origin/main$'"
# `git rebase --autostash` exits 0 when the stash pops with conflicts — trusting that code
# stages conflict markers and pushes them. Behavioural, because only a real repo reproduces it.
run "git-sync: autostash pop conflict exits 3, never 'synced'" \
  "git init -q --bare $GS_TMP/rem2 && _gs_repo $GS_TMP/x && printf 'l1\nl2\nl3\n' > $GS_TMP/x/f && git -C $GS_TMP/x add -A && git -C $GS_TMP/x commit -qm base && git -C $GS_TMP/x remote add origin $GS_TMP/rem2 && git -C $GS_TMP/x push -q -u origin main && git clone -q $GS_TMP/rem2 $GS_TMP/y && git -C $GS_TMP/y config user.email y@y && git -C $GS_TMP/y config user.name y && printf 'l1\nTHEIRS\nl3\n' > $GS_TMP/y/f && git -C $GS_TMP/y commit -qam theirs && git -C $GS_TMP/y push -q origin main && printf 'l1\nMINE\nl3\n' > $GS_TMP/x/f; out=\$(bash $GS sync $GS_TMP/x); rc=\$?; [ \$rc -eq 3 ] && printf '%s' \"\$out\" | grep -q autostash"
run "git-sync: autostash conflict keeps both copies (markers + stash)" \
  "grep -q '<<<<<<<' $GS_TMP/x/f && git -C $GS_TMP/x stash list | grep -q autostash"
run "git-sync: re-running mid-conflict stays at 3, touches nothing" \
  "bash $GS sync $GS_TMP/x >/dev/null; [ \$? -eq 3 ] && grep -q MINE $GS_TMP/x/f"

rm -rf "$GS_TMP"

# spec wiring — the fragment must be reachable and the phases must reference it
run "git-sync: fragment exists"             '[ -f .ow/commands/_shared/git-sync.md ]'
run "git-sync: ow-git points at fragment"  'grep -q "_shared/git-sync.md" .ow/commands/ow-git.md'
run "git-post-push: ow-git points at fragment" 'grep -q "_shared/git-post-push.md" .ow/commands/ow-git.md'
run "git-post-push: gate is stated at the pointer" 'grep -q "only after a successful push" .ow/commands/ow-git.md'
run "git-sync: ow-git has Phase 2.5 sync"  'grep -q "Phase 2.5 — Sync with origin" .ow/commands/ow-git.md'
run "git-sync: --no-sync documented"        'grep -q -- "--no-sync" .ow/commands/ow-git.md'
run "git-sync: bare --pull is sync-only"    'grep -q "sync-only gate" .ow/commands/ow-git.md && grep -q "Sync-only never commits" .ow/commands/ow-git.md'
run "git-sync: bump fetches tags first"     'grep -q "fetch --tags" .ow/commands/ow-git.md'
run "git-sync: push goes through helper"    'grep -q "ow-git-sync.sh" .ow/commands/ow-git.md'
run "git-sync: exit 3 stops the command"    'grep -q "Exit 3 ends the command" .ow/commands/ow-git.md'
run "git-sync: worktree fetches base"       'grep -q "START_REF" .ow/commands/_shared/worktree.md && grep -q "worktree_base_sha" .ow/commands/_shared/worktree.md'
run "git-sync: fragment registered in README" 'grep -q "git-sync.md" .ow/commands/_shared/README.md'
# /ow-sync ships commands/ but never scripts/ → every call site must degrade, not fail
run "git-sync: callers guard on helper presence" \
  '[ "$(grep -c "\[ ! -x \"\$SYNC\" \]" .ow/commands/ow-git.md)" -ge 4 ] && grep -q "\[ -x \"\$SYNC\" \]" .ow/commands/_shared/worktree.md'
run "git-sync: fragment documents the degrade"  'grep -q "Never fail a run because the helper is missing" .ow/commands/_shared/git-sync.md'
# the autostash stop needs its own wording: the rebase is over, so `rebase --continue` is a dead end
run "git-sync: ow-git branches on the autostash stop" \
  'grep -q "autostash\*)" .ow/commands/ow-git.md && grep -q "git stash drop" .ow/commands/ow-git.md'
run "git-sync: fragment documents the autostash stop" \
  'grep -q "stash pop conflict" .ow/commands/_shared/git-sync.md && grep -q "strategy: merge\` never stashes" .ow/commands/_shared/git-sync.md'

# ════════════════════════════════════════════════════════════════════════════
# Version-bump safety — scripts/ow-version.sh (#34)
# Behavioural, not grep-only: the bug shipped because "the number changed" was
# the only check, so every assertion here is made against a real written file.
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 32.5 — /ow-git --bump version writer (#34)${c_reset}\n"
BV="$PWD/scripts/ow-version.sh"
BV_TMP="${TMPDIR:-/tmp}/ow-bv-test.$$"
mkdir -p "$BV_TMP"

run "version: script exists + executable"   '[ -x scripts/ow-version.sh ]'
run "version: in owned manifest"            '. scripts/ow-owned.sh; ow_owned_scripts | grep -qx "ow-version.sh"'
run "version: macOS bash 3.2 safe"          '! grep -q "declare -A" scripts/ow-version.sh'

run "version: plain VERSION gets bare semver" \
  "printf '0.3.35\n' > $BV_TMP/VERSION && bash $BV write $BV_TMP/VERSION 0.3.36 >/dev/null && grep -qx '0.3.36' $BV_TMP/VERSION"
# the whole point of #34: a `v` must never reach the file, from either direction
run "version: write strips a leaked v and says so" \
  "printf '0.3.35\n' > $BV_TMP/VERSION; bash $BV write $BV_TMP/VERSION v0.3.36 2>&1 >/dev/null | grep -q 'stripped the tag prefix' && grep -qx '0.3.36' $BV_TMP/VERSION"
run "version: write refuses a non-semver (exit 2)" \
  "printf '0.3.35\n' > $BV_TMP/VERSION; bash $BV write $BV_TMP/VERSION 0.3 >/dev/null 2>&1; [ \$? -eq 2 ] && grep -qx '0.3.35' $BV_TMP/VERSION"
run "version: validate rejects a v in the file (exit 5)" \
  "printf 'v0.3.36\n' > $BV_TMP/POISON.version; bash $BV validate $BV_TMP/POISON.version >/dev/null 2>&1; [ \$? -eq 5 ]"
run "version: read strips a leaked v (next bump not poisoned)" \
  "[ \"\$(bash $BV read $BV_TMP/POISON.version)\" = '0.3.36' ]"
# the exact string that shipped unbuildable: v-prefix AND a non-numeric build
run "version: validate rejects the shipped v0.3.36+v0336 string" \
  "printf 'name: a\nversion: v0.3.36+v03362608070806\n' > $BV_TMP/pubspec.yaml; bash $BV validate $BV_TMP/pubspec.yaml >/dev/null 2>&1; [ \$? -eq 5 ]"
run "version: validate rejects a non-numeric build (exit 6)" \
  "printf 'name: a\nversion: 0.3.36+v0336\n' > $BV_TMP/pubspec.yaml; bash $BV validate $BV_TMP/pubspec.yaml >/dev/null 2>&1; [ \$? -eq 6 ]"
run "version: pubspec build increments, zero-pad kept" \
  "printf 'name: a\nversion: 0.3.37+0009\n' > $BV_TMP/pubspec.yaml && bash $BV write $BV_TMP/pubspec.yaml 0.3.38 >/dev/null && grep -qx 'version: 0.3.38+0010' $BV_TMP/pubspec.yaml"
run "version: --build preserve keeps the build" \
  "bash $BV write $BV_TMP/pubspec.yaml 0.3.39 --build preserve >/dev/null && grep -qx 'version: 0.3.39+0010' $BV_TMP/pubspec.yaml"
run "version: package.json keeps its other keys" \
  "printf '{\n  \"name\": \"x\",\n  \"version\": \"0.3.35\"\n}\n' > $BV_TMP/package.json && bash $BV write $BV_TMP/package.json 0.3.36 >/dev/null && jq -e '.name == \"x\" and .version == \"0.3.36\"' $BV_TMP/package.json >/dev/null"
run "version: Cargo dep version is never touched" \
  "printf '[package]\nname = \"x\"\nversion = \"0.3.35\"\n\n[dependencies]\nserde = { version = \"1.0\" }\n' > $BV_TMP/Cargo.toml && bash $BV write $BV_TMP/Cargo.toml 0.3.36 >/dev/null && grep -q 'version = \"1.0\"' $BV_TMP/Cargo.toml && [ \"\$(bash $BV read $BV_TMP/Cargo.toml)\" = '0.3.36' ]"
run "version: pyproject reads its own section only" \
  "printf '[project]\nname = \"x\"\nversion = \"0.3.35\"\n\n[tool.pytest.ini_options]\nversion = \"nope\"\n' > $BV_TMP/pyproject.toml && [ \"\$(bash $BV read $BV_TMP/pyproject.toml)\" = '0.3.35' ]"
run "version: csproj Version element" \
  "printf '<Project>\n  <PropertyGroup>\n    <Version>0.3.35</Version>\n  </PropertyGroup>\n</Project>\n' > $BV_TMP/a.csproj && bash $BV write $BV_TMP/a.csproj 0.3.36 >/dev/null && grep -q '<Version>0.3.36</Version>' $BV_TMP/a.csproj"
# an unwritten version file drifts behind the tag — the spec forbids it, so never a silent skip
run "version: unsupported file type is loud (exit 3)" \
  "printf 'hello\nworld\n' > $BV_TMP/notes.foo; bash $BV write $BV_TMP/notes.foo 1.0.0 >/dev/null 2>&1; [ \$? -eq 3 ]"
run "version: missing file (exit 4)" \
  "bash $BV write $BV_TMP/nope/VERSION 1.0.0 >/dev/null 2>&1; [ \$? -eq 4 ]"
run "version: validate mismatch vs target (exit 5)" \
  "bash $BV validate $BV_TMP/VERSION 9.9.9 >/dev/null 2>&1; [ \$? -eq 5 ]"

rm -rf "$BV_TMP"

# spec wiring — the gate only exists if /ow-git actually routes through it
run "version: ow-git calls the writer twice"  '[ "$(grep -c "VERW.* write " .ow/commands/ow-git.md)" -ge 2 ]'
run "version: ow-git gates before commit"     '[ "$(grep -c "VERW.* validate " .ow/commands/ow-git.md)" -ge 2 ]'
run "version: no undefined bump_version_file"  '! grep -rq "bump_version_file" .ow/commands/'
run "version: tag-vs-file convention stated"   'grep -q "the .v. belongs on a git tag" .ow/commands/ow-git.md'
# the Phase 6 loop is a pipeline subshell: without this an aborted submodule still lets main tag
run "version: Phase 6 loop aborts the run"     'grep -q "^done || exit 1" .ow/commands/ow-git.md'
run "version: writer absence stops --bump"     'grep -q "ow-version.sh missing" .ow/commands/ow-git.md'
run "version: yml documents build_number"      'grep -q "build_number" .ow.yml && grep -q "verify_cmd" .ow.yml'
run "version: resolver passes the new knobs"   'bash scripts/ow-paths.sh --json | jq -e ".version_bump.build_number" >/dev/null'
run "version: conformance-lint check 10"       'bash scripts/conformance-lint.sh 2>&1 | grep -q "check 10"'
# ── the lint must not lose a check to SIGPIPE (#36) ──
# `producer | grep -q P` closes the pipe on the FIRST match; under the lint's own
# `set -o pipefail` the producer then dies 141 and the pipeline reports FAILURE even
# though P was found. It stays invisible while the producer's output fits the 64K pipe
# buffer, then a spec grows and a passing check silently inverts to a false alarm.
# `grep -c P >/dev/null` drains the input and has the same exit semantics.
run "lint: no SIGPIPE-prone grep -q pipeline" '! grep -q "| *grep -q" scripts/conformance-lint.sh'
run "lint: check 10 passes on this repo"      'bash scripts/conformance-lint.sh 2>&1 | grep -q "✓ check 10"'
run "lint: check 2 passes on this repo"       'bash scripts/conformance-lint.sh 2>&1 | grep -q "✓ check 2"'

# ════════════════════════════════════════════════════════════════════════════
# Section 33: phased plans — /ow-plan Phase 2.5 + /ow-implement --phase
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 33 — phased plans (## Phases + ## Shared Contract)${c_reset}\n"
PLAN=.ow/commands/ow-plan.md
IMPL33=.ow/commands/ow-implement.md
FRAG33=.ow/commands/_shared/phases.md
run "frag: phases.md exists"        '[ -f .ow/commands/_shared/phases.md ]'
run "frag: implement points at it"  'grep -q "_shared/phases.md" '"$IMPL33"
run "frag: listed in _shared index" 'grep -q "phases.md" .ow/commands/_shared/README.md'
# ── /ow-plan emits the structure ──
run "plan has Phase 2.5"           'grep -q "^## Phase 2.5 " '"$PLAN"
run "plan emits ## Phases"         'grep -q "^## Phases" '"$PLAN"
run "plan emits Shared Contract"   'grep -q "^## Shared Contract" '"$PLAN"
run "plan emits per-phase section" 'grep -q "^### Phase P1 " '"$PLAN"
run "plan emits context_closed"    'grep -q "context_closed: true" '"$PLAN"
run "plan emits context_refs"      'grep -q "context_refs:" '"$PLAN"
run "plan phase budget 120000"     'grep -q "PHASE_BUDGET=120000" '"$PLAN"
run "plan phase FLOOR + MAX"       'grep -q "FLOOR=15000" '"$PLAN"' && grep -q "MAX_PHASES=8" '"$PLAN"
run "plan merge keys same area"    'grep -q "only between phases with the same area" '"$PLAN"
run "plan forces /clear"           'grep -q "/clear" '"$PLAN"
run "plan refuses to over-phase"   'grep -q "Never phase a plan that is already small enough" '"$PLAN"
run "plan: one file, one phase"    'grep -q "Never assign the same Affected File to two phases" '"$PLAN"
run "plan: no contract redefine"   'grep -q "Never redefine a Shared Contract value inside a phase" '"$PLAN"
run "plan never approves"          'grep -q "Never set .status: approved. on the user.s behalf" '"$PLAN"
run "plan --no-phases escape"      'grep -q -- "--no-phases" '"$PLAN"
# ── --revise must not clobber a phase that is mid-implement (it sits at `approved`,
#    not `in-progress` — /ow-implement never stamps that) nor one holding a resume marker
run "revise rewrites planning only"  'grep -q "Rewrite .status: planning. phases and nothing else" '"$PLAN"
run "revise names the stuck-run trap" 'grep -q "stamps a phase row .in-progress. before" '"$PLAN"' && grep -q "died mid-way" '"$PLAN"
run "implement stamps in-progress"   'grep -q "Stamp the row .in-progress." '"$FRAG33"
run "revise protects resume markers" 'grep -q "resume marker" '"$PLAN"' && grep -q "## Step Progress" '"$PLAN"
run "plan Never: no blind rewrite"   'grep -q "unless it is .status: planning" '"$PLAN"
# ── /ow-implement consumes it ──
run "implement takes --phase"       'grep -q -- "--phase P2" '"$IMPL33"
run "implement has 1.3 phase gate"  'grep -q "^### 1.3 Phase gate" '"$IMPL33"
run "implement strips --phase"      'grep -q -- "s/\[\[:space:\]\]\*--phase" '"$IMPL33"
run "phase gate blocks on depends"  'grep -q "depends_on" '"$IMPL33"
run "phase gate blocks on planned"  'grep -q "Never proceed on .planned." '"$FRAG33"' && grep -q "state: actual" '"$FRAG33"
run "no-flag runs every phase"      'grep -q "phase in .## Phases. order" '"$FRAG33"
run "6.0 gates per phase section"   'grep -q "phase_section()" '"$FRAG33"
# ── regressions found by adversarial trace: each gate must be able to FAIL ──
# ── selective read: a phased plan must not cost every phase the whole file ──
run "phases: reads the plan selectively" 'grep -q "^## 1.5 Read the plan \*\*selectively\*\*" '"$FRAG33"' && grep -q "offset=" '"$FRAG33"
run "phases: forbids reading siblings"   'grep -q "Never read another phase.s section" '"$FRAG33"
run "implement Phase 1 points at 1.5"    'grep -q "read it \*\*selectively\*\*" '"$IMPL33"
run "plan: budget is the slice not file" 'grep -q "SESSION_FIXED=20000" '"$PLAN"' && ! grep -q "est + 25000" '"$PLAN"
run "plan: re-measures after writing"    'grep -q "Re-measure once the file exists" '"$PLAN"
# behavioral: the re-measure awk must charge each phase header+own-section, never the whole file
run "plan[behavioral]: per-phase slice < whole file" '
  d=$(mktemp -d); P="$d/plan.md"
  { printf -- "---\ntitle: x\n---\n"; i=0; while [ $i -lt 20 ]; do printf "header line\n"; i=$((i+1)); done
    printf -- "### Phase P1 — a\n"; i=0; while [ $i -lt 60 ];  do printf "p1 line\n"; i=$((i+1)); done
    printf -- "### Phase P2 — b\n"; i=0; while [ $i -lt 100 ]; do printf "p2 line\n"; i=$((i+1)); done
  } > "$P"
  H=$(awk "/^### Phase /{exit} {print}" "$P" | wc -c | tr -d " ")
  out=$(awk -v h="$H" "/^### Phase /{ if (id) printf \"%s %d\\n\", id, (h + n) / 2; id=\$3; n=0 } id { n += length(\$0) + 1 } END { if (id) printf \"%s %d\\n\", id, (h + n) / 2 }" "$P")
  whole=$(( $(wc -c < "$P" | tr -d " ") / 2 )); rm -rf "$d"
  p1=$(printf "%s" "$out" | awk "/^P1 /{print \$2}"); p2=$(printf "%s" "$out" | awk "/^P2 /{print \$2}")
  [ -n "$p1" ] && [ -n "$p2" ] || { echo "awk produced no rows: $out"; exit 1; }
  [ "$p1" -lt "$whole" ] && [ "$p2" -lt "$whole" ] && [ "$p2" -gt "$p1" ] || {
    echo "p1=$p1 p2=$p2 whole=$whole — want each < whole, and p2 (bigger section) > p1"; exit 1; }'
run "6.0 block derives its own vars" 'sed -n "/^## 4\. The done-gate/,/^## 5\./p" '"$FRAG33"' | grep -q "PLAN_PATH=" && sed -n "/^## 4\. The done-gate/,/^## 5\./p" '"$FRAG33"' | grep -q "PHASE_ID="'
run "6.0 refuses an empty PHASE_ID"  'grep -q "passes vacuously" '"$FRAG33"
run "DS gate reads the phase area"   'sed -n "/^## Phase 4 /,/^## Phase 5 /p" '"$IMPL33"' | grep -q "running phase.s .area."'
run "in-progress states the way out" 'grep -q "set its .status. cell back to .planning." '"$PLAN"
# behavioral: the two snippets phases.md ships must actually work — a slug target must resolve
# (`/ow-implement <slug>` is a documented trigger; a hard assert on a slug would STOP a valid run,
# and the same assert sits in the 6.0 gate AFTER the code is written), and phase_section must cut
# exactly one phase — an empty id matching nothing is how the done-gate passes vacuously.
run "phases[behavioral]: slug resolves + phase_section cuts one phase" '
  d=$(mktemp -d); PLAN_DIR="$d/plans"; mkdir -p "$PLAN_DIR"
  { printf "## Phases\n| P1 | api |\n\n"; printf "### Phase P1 — api\n#### Success Criteria\n- [x] ok\n";
    printf "### Phase P2 — web\n#### Success Criteria\n- [ ] open\n"; printf "## Approvals\n- [ ] plan box\n";
  } > "$PLAN_DIR/2026-09-11-1430-checkout-flow.md"
  # 🔴 run the REAL snippets out of the fragment — a copy here would keep passing after the spec drifts
  sed -n "/^ow_resolve_plan() {/,/^}/p"  .ow/commands/_shared/phases.md >  "$d/fn.sh"
  sed -n "/^phase_section() {/,/^}/p"    .ow/commands/_shared/phases.md >> "$d/fn.sh"
  [ "$(grep -c "^}" "$d/fn.sh")" -eq 2 ] || { echo "could not extract both functions from phases.md"; rm -rf "$d"; exit 1; }
  . "$d/fn.sh"
  P=$(ow_resolve_plan checkout-flow)
  [ -f "$P" ] || { echo "slug did not resolve"; rm -rf "$d"; exit 1; }
  [ -n "$(ow_resolve_plan "$P")" ] || { echo "full path did not resolve"; rm -rf "$d"; exit 1; }
  [ -z "$(ow_resolve_plan no-such-plan)" ] || { echo "bogus slug resolved"; rm -rf "$d"; exit 1; }
  o2=$(phase_section "$P" P2 | grep -c "\- \[ \]"); o1=$(phase_section "$P" P1 | grep -c "\- \[ \]")
  rm -rf "$d"
  [ "$o2" -eq 1 ] || { echo "P2 open boxes = $o2, want 1"; exit 1; }
  [ "$o1" -eq 0 ] || { echo "P1 open boxes = $o1, want 0 (it must not swallow P2 or ## Approvals)"; exit 1; }'
run "6.1 closes one phase row"      'grep -q "^### 6.1 Close the phase" '"$IMPL33"
run "6.2 closes the whole plan"     'grep -q "^### 6.2 Close the plan" '"$IMPL33"
run "plan done needs all rows done" 'grep -q "Never flip the plan .status: done. while a phase row is not .done." '"$IMPL33"' && grep -q "Never flip the plan.s frontmatter .status: done." '"$FRAG33"
run "marker carries the phase id"   'grep -q "carries its phase id" '"$FRAG33"
# the context_closed contract — /ow-plan emits it, implement + delegation are its only readers
run "implement honors context_closed"  'grep -q "context_closed" .ow/commands/ow-implement.md'
run "delegation honors context_closed" 'grep -q "context_closed" .ow/commands/_shared/delegation.md'
run "chunks never cross a phase"       'grep -q "a chunk never crosses a phase" .ow/commands/_shared/delegation.md'
run "lint has check 9"                 'grep -q "check 9" scripts/conformance-lint.sh'
run "check 9 guards context_closed"    'bash scripts/conformance-lint.sh 2>&1 | grep -q "check 9"'
# check 9 must stay silent where the plan spec is not installed — otherwise a fixture with a
# partial commands dir has its install/sync aborted by a command it does not have
run "check 9[behavioral]: skipped without ow-plan" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-lint-c9.$$ 2>&1; rc=$?; rm -rf "$d";
  { [ "$rc" -eq 0 ] && ! grep -q "check 9" /tmp/ow-lint-c9.$$; }; r=$?; rm -f /tmp/ow-lint-c9.$$; [ "$r" -eq 0 ]'
run "check 9[behavioral]: fires once ow-plan lands" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  printf "context_closed: true\n" > "$d/.ow/commands/ow-plan.md";
  printf "no flag here\n"        > "$d/.ow/commands/ow-implement.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-lint-c9b.$$ 2>&1; rc=$?; rm -rf "$d";
  { [ "$rc" -eq 1 ] && grep -q "check 9: context_closed contract missing" /tmp/ow-lint-c9b.$$; }; r=$?; rm -f /tmp/ow-lint-c9b.$$; [ "$r" -eq 0 ]'
# /ow-verify closes out a phased plan — read the phase table, never each phase body
run "verify rollup mode"           'grep -q "## Phases" .ow/commands/ow-verify.md'
run "verify rollup greps status"   'grep -q "grep -m1" .ow/commands/ow-verify.md'
run "verify rollup stops if open"  'grep -qi "never flip the plan" .ow/commands/ow-verify.md'
run "verify stops on planned row"  'grep -q "state: planned" .ow/commands/ow-verify.md'
# ── /ow-split is retired: no spec, no shim, no skill, no usage doc, no mention ──
run "split spec removed"           '[ ! -f .ow/commands/ow-split.md ]'
run "split shim removed"           '[ ! -f .claude/commands/ow-split.md ]'
run "split skill removed"          '[ ! -d .agents/skills/ow-split ]'
run "split usage doc removed"      '[ ! -f usage/ow-split.md ]'
# the only surviving mention is the migration clause in ow-implement 3.0 item 2 (a pre-phase
# sub-plan still carries context_closed:) — nothing may ROUTE a user to the retired command
run "nothing routes to ow-split"   '! grep -l "ow-split" .ow/commands/*.md .ow/commands/_shared/*.md CLAUDE.md README.md AI-README.md usage/README.md .ow.yml */prompts/router.md 2>/dev/null | grep -qv "ow-implement.md"'
run "split mention is migration-only" 'grep -c "ow-split" .ow/commands/ow-implement.md | grep -qx 1 && grep -q "retired" .ow/commands/ow-implement.md'
# every doc that states a command count must state the REAL one — a stale count outlives the
# command that changed it, and four separate docs carried "21" after /ow-split was removed
run "docs: no stale command count" '
  n=$(ls .ow/commands/ow-*.md | wc -l | tr -d " ")
  bad=$(grep -rn "[^0-9]$((n+1)) \(slash \)\?[Cc]ommands\|[^0-9]$((n+1)) verbs\|[^0-9]$((n+1)) คำสั่ง\|($((n+1)) ตัว)\|[^0-9]$((n+1)) source-of-truth" \
        CLAUDE.md README.md AI-README.md usage/README.md 2>/dev/null)
  [ -z "$bad" ] || { echo "stale count (real = $n):"; echo "$bad"; exit 1; }'
run "docs: state the real count"   '
  n=$(ls .ow/commands/ow-*.md | wc -l | tr -d " ")
  grep -q "คำสั่งทั้งหมด ($n ตัว)" CLAUDE.md && grep -q "$n Commands" README.md && grep -q "$n slash commands" README.md'
run "usage: one doc per command"   '
  for f in .ow/commands/ow-*.md; do [ -f "usage/$(basename "$f")" ] || { echo "no usage doc for $(basename "$f")"; exit 1; }; done
  for f in usage/ow-*.md; do [ -f ".ow/commands/$(basename "$f")" ] || { echo "orphan usage doc: $f"; exit 1; }; done'
run "usage doc for ow-plan"        '[ -f usage/ow-plan.md ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 34: inline resume marker — `## Step Progress` (dead-session recovery)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 34 — /ow-implement inline resume marker${c_reset}\n"
IMPL=.ow/commands/ow-implement.md
run "3.3 defines Step Progress"      'grep -q "### 3.3 .*Step Progress" '"$IMPL"
run "3.0 inline list points at 3.3"  'grep -q "Write the .## Step Progress. marker as you go (3.3)" '"$IMPL"
run "marker is [x]-only"             't=$(printf "Write \140- [x]\140 **only**"); grep -Fq "$t" '"$IMPL"
run "marker written after exit pass" 'grep -q "after the .exit:. actually ran and passed" '"$IMPL"
run "marker anchors plan steps"      'grep -q "steps <a>-<b>" '"$IMPL"
run "marker anchors fix-log files"   'grep -q "Affected Files. path" '"$IMPL"
run "marker never pre-ticks gates"   'grep -q "Never tick Goals / Success Criteria" '"$IMPL"
run "marker stays after run ends"    'grep -q "Leave the section in place" '"$IMPL"
# the 1.2 resume gate is the reader — it must name BOTH markers and re-run the last exit:
run "1.2 reads Chunk Progress"       'sed -n "/^### 1\.2 /,/^## Phase 2 /p" '"$IMPL"' | grep -q "Chunk Progress"'
run "1.2 reads Step Progress"        'sed -n "/^### 1\.2 /,/^## Phase 2 /p" '"$IMPL"' | grep -q "Step Progress"'
run "1.2 re-runs last exit:"         'sed -n "/^### 1\.2 /,/^## Phase 2 /p" '"$IMPL"' | grep -q "exit:"'
run "1.2 unions both markers"        'sed -n "/^### 1\.2 /,/^## Phase 2 /p" '"$IMPL"' | grep -qi "union"'
run "Never: inline must write marker" 'grep -q "Never run an inline plan without writing" '"$IMPL"
run "Never: no resume w/o re-verify" 'grep -q "Never resume from a progress marker" '"$IMPL"
# the old chunk-only wording was superseded by the marker-generic rule — one bullet, not two
run "no duplicate resume rule"       '[ "$(grep -c "Never resume" '"$IMPL"')" -eq 1 ]'
run "lint has check 11"              'grep -q "check 11" scripts/conformance-lint.sh'
run "check 11 runs on this repo"     'bash scripts/conformance-lint.sh 2>&1 | grep -q "check 11: inline resume marker"'
# ── behavioral: prove check 11 actually fails on each broken shape (a lint that
#    cannot fail is decoration — see the prose-vs-bash gap that shipped #34) ──
run "check 11[behavioral]: passes on a well-formed spec" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  { printf "### 1.2 Resume gate\n";
    printf "Chunk Progress + Step Progress -- re-run the exit: of the last ticked line (union)\n";
    printf "## Phase 2 -- next\n";
    printf "### 3.3 Step Progress marker\n";
    printf "Write \140- [x]\140 **only**, never \140- [ ]\140\n"; } > "$d/.ow/commands/ow-implement.md";
  printf "Write \140- [x]\140 **only**\n" > "$d/.ow/commands/_shared/delegation.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11a.$$ 2>&1; rm -rf "$d";
  grep -q "check 11: inline resume marker" /tmp/ow-c11a.$$; r=$?; rm -f /tmp/ow-c11a.$$; [ "$r" -eq 0 ]'
run "check 11[behavioral]: fires when the writer is gone" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  { printf "### 1.2 Resume gate\n";
    printf "Step Progress -- re-run the exit: of the last ticked line\n";
    printf "## Phase 2 -- next\n"; } > "$d/.ow/commands/ow-implement.md";
  printf "Write \140- [x]\140 **only**\n" > "$d/.ow/commands/_shared/delegation.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11b.$$ 2>&1; rm -rf "$d";
  grep -q "writer-or-reader-missing" /tmp/ow-c11b.$$; r=$?; rm -f /tmp/ow-c11b.$$; [ "$r" -eq 0 ]'
run "check 11[behavioral]: fires when 1.2 skips the exit: re-verify" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  { printf "### 1.2 Resume gate\n";
    printf "Step Progress -- trust the marker and skip ahead\n";
    printf "## Phase 2 -- next\n";
    printf "### 3.3 Step Progress marker\n";
    printf "Write \140- [x]\140 **only**\n"; } > "$d/.ow/commands/ow-implement.md";
  printf "Write \140- [x]\140 **only**\n" > "$d/.ow/commands/_shared/delegation.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11c.$$ 2>&1; rm -rf "$d";
  grep -q "1.2(no-exit-reverify)" /tmp/ow-c11c.$$; r=$?; rm -f /tmp/ow-c11c.$$; [ "$r" -eq 0 ]'
run "check 11[behavioral]: fires when the [x]-only rule is dropped" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  { printf "### 1.2 Resume gate\n";
    printf "Step Progress -- re-run the exit: of the last ticked line\n";
    printf "## Phase 2 -- next\n";
    printf "### 3.3 Step Progress marker\n";
    printf "tick it however you like\n"; } > "$d/.ow/commands/ow-implement.md";
  printf "Write \140- [x]\140 **only**\n" > "$d/.ow/commands/_shared/delegation.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11d.$$ 2>&1; rm -rf "$d";
  grep -q "ow-implement.md(no-\[x\]-only-rule)" /tmp/ow-c11d.$$; r=$?; rm -f /tmp/ow-c11d.$$; [ "$r" -eq 0 ]'
# /ow-plan --revise must not regenerate a phase that is mid-implement (it sits at `approved`,
# not `in-progress` — /ow-implement never stamps that) nor one holding a resume marker.
# The prose guards live in Section 33; this is the lint's behavioral half.
run "check 11[behavioral]: fires when revise may clobber a resuming phase" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  { printf "### 1.2 Resume gate\n";
    printf "Step Progress -- re-run the exit: of the last ticked line\n";
    printf "## Phase 2 -- next\n";
    printf "### 3.3 Step Progress marker\n";
    printf "Write \140- [x]\140 **only**\n"; } > "$d/.ow/commands/ow-implement.md";
  printf "Write \140- [x]\140 **only**\n" > "$d/.ow/commands/_shared/delegation.md";
  printf "rewrite every phase that is not done\n" > "$d/.ow/commands/ow-plan.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11f.$$ 2>&1; rm -rf "$d";
  grep -q "revise-may-overwrite-a-resuming-phase" /tmp/ow-c11f.$$; r=$?; rm -f /tmp/ow-c11f.$$; [ "$r" -eq 0 ]'
run "check 11[behavioral]: silent without ow-implement.md" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands/_shared"; : > "$d/.ow.yml";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c11e.$$ 2>&1; rm -rf "$d";
  ! grep -q "check 11" /tmp/ow-c11e.$$; r=$?; rm -f /tmp/ow-c11e.$$; [ "$r" -eq 0 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 35 — specialized agents: created per project, never shipped
# ════════════════════════════════════════════════════════════════════════════
# The bug this pins: a config flag that promises an agent Claude Code cannot spawn.
# Before v1.10.0 install shipped 9 bodies and back-filled from a library; now it ships 4
# and /ow-agent create writes the rest, so the SAME lie has to be caught a new way —
# enabled with no file under .claude/agents/ must be reported, never silently filled.
printf "\n${c_bold}Section 35 — specialized agents (created, not shipped)${c_reset}\n"
run "agents: ships exactly the always-on four" '
  n=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d " "); [ "$n" = 4 ]'
run "agents: no specialized body is shipped" '
  for a in backend frontend mobile design test-runner; do
    [ -e ".claude/agents/$a.md" ] && exit 1; done; exit 0'
run "agents: library writer is GONE"          '! grep -q "install_agent_library" scripts/ow-claude-manifest.sh scripts/install.sh scripts/upgrade.sh'
run "agents: no .ow/agents in the repo"  '[ ! -e .ow/agents ]'
run "agents: enabled-set reader defined"      'grep -q "^ow_enabled_agents()" scripts/ow-claude-manifest.sh'
run "agents: enabled-vs-body check defined"   'grep -q "^verify_enabled_agents()" scripts/ow-claude-manifest.sh'
run "agents: install verifies the enabled set" 'grep -q "verify_enabled_agents" scripts/install.sh'
run "agents: upgrade verifies the enabled set" 'grep -q "verify_enabled_agents" scripts/upgrade.sh'
run "agents: /ow-sync no longer snapshots agents" '
  grep -q "SNAPSHOT_PATHS=(templates commands)" .ow/commands/ow-sync.md'
# The retirement migration must be version-gated, back up first, and be rollback-able —
# an rm -rf that skips any of the three is how an upgrade eats work.
run "agents: library retirement is version-gated"  'grep -q "_ow_ver_lt \"\$current_version\" \"1.10.0\"" scripts/upgrade.sh'
run "agents: library retirement backs up first"    'grep -q "BACKUP_DIR/.ow/agents" scripts/upgrade.sh'
run "agents: retired library is rollback-safe"     'awk "/^ROLLBACK_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -q ".ow/agents"'
run "agents: enable requires an existing body"     'grep -q "no agent body for" .ow/commands/ow-agent.md'
run "agents: enable points at create"              'grep -q "ow-agent create \$NAME" .ow/commands/ow-agent.md'
run "agents: enable asserts spawnable"             'grep -q "still not spawnable" .ow/commands/ow-agent.md'
run "agents: disable removes the body too"         'grep -q "a flag on" .ow/commands/ow-agent.md'
run "agents: ow-agent never yq -i s config"       '! grep -qE "^yq -i" .ow/commands/ow-agent.md'
run "agents: regenerate STOPs when there is no body" 'grep -q "nothing to regenerate" .ow/commands/ow-agent.md'
run "agents: enable handles both config forms"     'grep -c "s/\^(\[\[:space:\]\]+\$NAME:" .ow/commands/ow-agent.md | grep -qx 4'
run "agents: enable reads the flag back"           'grep -q -- "--subagents" .ow/commands/ow-agent.md && grep -q "grep -qx \"\$NAME\"" .ow/commands/ow-agent.md'
# The failure this pins: writing the body before the flag is proven leaves a spawnable agent
# behind a config that says disabled — the same lie, mirrored. The flag flip and its read-back
# must both precede the cp.
run "agents: enable flips the flag BEFORE writing the body" '
  f=.ow/commands/ow-agent.md
  flag=$(grep -n "flip the flag" "$f" | head -1 | cut -d: -f1)
  read=$(grep -n "read the flag back" "$f" | head -1 | cut -d: -f1)
  cp=$(grep -n "cp \"\$SRC\" \"\$ROOT/.claude/agents" "$f" | head -1 | cut -d: -f1)
  [ -n "$flag" ] && [ -n "$read" ] && [ -n "$cp" ] && [ "$flag" -lt "$read" ] && [ "$read" -lt "$cp" ]'
run "agents: enable aborts without writing"    'grep -q "Nothing was written" .ow/commands/ow-agent.md'
# Prose alone let `disable docs` succeed while install/upgrade put the body straight back —
# config off, agent still spawnable.
run "agents: disable REFUSES the always-on four" 'grep -q "always-on and cannot be disabled" .ow/commands/ow-agent.md'
run "agents[behavioral]: always-on gate rejects docs, allows mobile" '
  for n in docs verifier security gh-issue; do
    case " docs verifier security gh-issue " in *" $n "*) ;; *) exit 1 ;; esac
  done
  case " docs verifier security gh-issue " in *" mobile "*) exit 1 ;; esac
  exit 0'
run "agents[behavioral]: flag flip covers map AND scalar form" '
  d=$(mktemp -d); NAME=backend;
  printf "subagents:\n  backend:     { enabled: false, model: sonnet }   # c\n" > "$d/map.yml";
  printf "subagents:\n  backend: false\n" > "$d/scalar.yml";
  for f in "$d/map.yml" "$d/scalar.yml"; do
    sed -i.bak -E -e "s/^([[:space:]]+$NAME:[[:space:]]*[{][[:space:]]*enabled:[[:space:]]*)false/\1true/" -e "s/^([[:space:]]+$NAME:[[:space:]]*)false[[:space:]]*\$/\1true/" "$f"; rm -f "$f.bak";
  done
  ok=1;
  grep -q "true" "$d/map.yml" || ok=0; grep -q "false" "$d/map.yml" && ok=0;
  grep -q "true" "$d/scalar.yml" || ok=0; grep -q "false" "$d/scalar.yml" && ok=0;
  rm -rf "$d"; [ "$ok" = 1 ]'
run "agents[behavioral]: enabled with no body is reported" '
  d=$(mktemp -d); mkdir -p "$d/.claude/agents";
  printf "subagents:\n  mobile:      { enabled: true, model: sonnet }\n" > "$d/.ow.yml";
  out=$( . scripts/ow-claude-manifest.sh; verify_enabled_agents "$d" 2>&1 ); r=$?;
  rm -rf "$d"; [ "$r" != 0 ] && echo "$out" | grep -q "ow-agent create"'
run "agents[behavioral]: a created body satisfies the check" '
  d=$(mktemp -d); mkdir -p "$d/.claude/agents";
  printf -- "---\nname: backend\nmodel: sonnet\n---\n" > "$d/.claude/agents/backend.md";
  printf "subagents:\n  backend:     { enabled: true, model: sonnet }\n" > "$d/.ow.yml";
  ( . scripts/ow-claude-manifest.sh; verify_enabled_agents "$d" ) >/dev/null 2>&1; r=$?;
  rm -rf "$d"; [ "$r" = 0 ]'
run "agents[behavioral]: nothing ever overwrites a created body" '
  d=$(mktemp -d); mkdir -p "$d/.claude/agents";
  printf -- "---\nname: backend\n---\nCREATED BY THIS PROJECT\n" > "$d/.claude/agents/backend.md";
  printf "subagents:\n  backend:     { enabled: true, model: sonnet }\n" > "$d/.ow.yml";
  ( . scripts/ow-claude-manifest.sh; verify_enabled_agents "$d" ) >/dev/null 2>&1;
  r=1; grep -qx "CREATED BY THIS PROJECT" "$d/.claude/agents/backend.md" && r=0; rm -rf "$d"; [ "$r" = 0 ]'
# /ow-agent create is now the ONLY source of a specialized body — the phases that make it
# more than a template fill-in must exist, or every created agent is generic again.
run "create: detects the stack before asking"  'grep -q "Detect the stack FIRST" .ow/commands/ow-agent.md'
run "create: STOPs rather than write a placeholder" 'grep -q "no placeholder agent, ever" .ow/commands/ow-agent.md'
run "create: gates derive from a taxonomy"     'grep -q "Derive the gates" .ow/commands/ow-agent.md'
run "create: bakes the stack, never the paths" 'grep -q "The stack is baked; the resolved values are not" .ow/commands/ow-agent.md'
# A created agent must NOT carry the ownership signature, or install/upgrade would be entitled to
# overwrite the body this project wrote against its own stack.
run "create: never writes the ownership signature" '
  grep -q "Never write the .<!-- obsidian-workflow:agent. signature" .ow/commands/ow-agent.md'
run "agents: only the shipped four carry the signature" '
  n=$(grep -l "^<!-- obsidian-workflow:agent" .claude/agents/*.md | wc -l | tr -d " "); [ "$n" = 4 ]'
run "suggest: grounded in code AND vault signals" '
  grep -q "Gather signals (both halves" .ow/commands/ow-agent.md'
run "suggest: never writes or enables"         'grep -q "never writes an agent itself" .ow/commands/ow-agent.md'
# A command that leans on an agent body must still work when that agent was never created.
run "implement: absent area agent ⇒ inline"    'grep -q "Only .docs. is guaranteed to exist" .ow/commands/ow-implement.md'
run "test: absent test-runner ⇒ inline"        'grep -q "created per project.*not shipped" .ow/commands/ow-test.md'
run "design: process lives in the command, not the agent" '
  [ -f .ow/commands/_shared/design-process.md ] &&
  grep -q "design-process.md" .ow/commands/ow-design.md &&
  ! grep -q "agent.s §6 Process" .ow/commands/ow-design.md'
run "design: audit score formula survived the move" '
  grep -q "100 − 8×HIGH − 4×MED − 1×LOW" .ow/commands/_shared/design-process.md'

# ════════════════════════════════════════════════════════════════════════════
# Section 36 — agent ownership by SIGNATURE (never by filename)
# ════════════════════════════════════════════════════════════════════════════
# The bug this pins: a project owning .claude/agents/backend.md was classified as
# obsidian-workflow's by NAME, so install overwrote it with no backup and no prompt, then the lint
# failed it for a missing §0 and aborted the install after the whole tree was written.
printf "\n${c_bold}Section 36 — agent ownership by signature${c_reset}\n"
run "sig: every shipped agent is signed"     'for f in .claude/agents/*.md; do grep -q "^<!-- obsidian-workflow:agent" "$f" || exit 1; done'
run "sig: signature sits below frontmatter"  'for f in .claude/agents/*.md; do head -1 "$f" | grep -q "^---$" || exit 1; done'
run "sig: manifest helper defined"           '. scripts/ow-claude-manifest.sh && command -v ow_is_owned_agent >/dev/null'
run "sig: lint decides by signature"         'grep -q "_agent_is_ow_owned" scripts/conformance-lint.sh'
run "sig: both copies spell it identically"  'grep -qF "obsidian-workflow:agent" scripts/conformance-lint.sh && grep -qF "obsidian-workflow:agent" scripts/ow-claude-manifest.sh && grep -qF "## §0. Context (injected — authoritative)" scripts/conformance-lint.sh && grep -qF "## §0. Context (injected — authoritative)" scripts/ow-claude-manifest.sh'
run "sig: no filename-based owned set left"  '! grep -q "OWNED_AGENTS_SET" scripts/install.sh'
run "sig: install write is signature-gated"  'grep -q "ow_is_owned_agent" scripts/install.sh'
run "sig: upgrade write is signature-gated"  'grep -q "ow_is_owned_agent" scripts/upgrade.sh'
run "sig: install backs up before overwrite" 'grep -q "^backup_before_overwrite()" scripts/install.sh && grep -q "^INSTALL_BAKDIR=" scripts/install.sh'
run "sig: install abort names the backup"    'grep -q "INSTALL_BAKDIR" scripts/install.sh && grep -q "restore with" scripts/install.sh'
run "sig: adopt runs before the .claude merge" '
  a=$(grep -n "^        adopt_existing_claude$" scripts/install.sh | cut -d: -f1);
  b=$(grep -n "^        install_claude_selective$" scripts/install.sh | cut -d: -f1);
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]'
run "gitignore: install backups ignored"     '. scripts/ow-gitignore.sh && ow_gitignore_block | grep -qF ".ow/backups/"'
run "sig[behavioral]: project backend.md is a note, not a failure" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands" "$d/.claude/agents"; : > "$d/.ow.yml";
  printf -- "---\nname: backend\n---\n\n# my own backend agent\n" > "$d/.claude/agents/backend.md";
  bash scripts/conformance-lint.sh "$d" >/dev/null 2>&1; r=$?; rm -rf "$d"; [ "$r" -eq 0 ]'
run "sig[behavioral]: a SIGNED agent without §0 is still fatal" '
  d=$(mktemp -d); mkdir -p "$d/.ow/commands" "$d/.claude/agents"; : > "$d/.ow.yml";
  printf -- "---\nname: docs\n---\n\n<!-- obsidian-workflow:agent -->\n\n# docs\n" > "$d/.claude/agents/docs.md";
  bash scripts/conformance-lint.sh "$d" >/dev/null 2>&1; r=$?; rm -rf "$d"; [ "$r" -ne 0 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 37 — .claude/settings.json is MERGED key-by-key, never overwritten
# ════════════════════════════════════════════════════════════════════════════
# The bug this pins: upgrade cp-overwrote settings.json, and it was in neither the backup
# loop nor ROLLBACK_PATHS nor SAFE_PATHS — so a consumer's permissions.deny and PreToolUse
# hooks were destroyed with no way back.
printf "\n${c_bold}Section 37 — settings.json key-granular merge${c_reset}\n"
run "settings: merge lib exists"             '[ -f scripts/ow-settings-merge.sh ]'
run "settings: merge fn defined"             '. scripts/ow-settings-merge.sh && command -v ow_settings_merge >/dev/null'
run "settings: merge lib is owned"           '. scripts/ow-owned.sh && ow_owned_scripts | grep -qx ow-settings-merge.sh'
run "settings: install merges"               'grep -q "ow_settings_merge" scripts/install.sh'
run "settings: upgrade merges"               'grep -q "ow_settings_merge" scripts/upgrade.sh'
run "settings: the only settings cp is the no-file fallback" '
  n=$(grep -c "cp \"\$STAGE/.claude/settings.json\"" scripts/upgrade.sh);
  g=$(grep -B1 "cp \"\$STAGE/.claude/settings.json\"" scripts/upgrade.sh | grep -c "elif \[ ! -f");
  [ "$n" = 1 ] && [ "$g" = 1 ]'
run "settings: in ROLLBACK_PATHS"            'awk "/^ROLLBACK_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -q "claude/settings.json"'
run "settings: backed up before the merge"   'grep -q "for p in .claude/commands .claude/agents .claude/settings.json; do" scripts/upgrade.sh'
run "settings: degrades, never destroys"     'grep -q "python3 not found" scripts/ow-settings-merge.sh && grep -q "LEFT UNCHANGED" scripts/ow-settings-merge.sh'
run "settings: adds no jq dependency"        '! grep -qE "^[^#]*[^a-z]jq " scripts/ow-settings-merge.sh'
run "settings: no blanket Bash shipped"      '! grep -qE "^ *\"Bash\",?$" .claude/settings.json'
run "settings: no blanket WebFetch shipped"  '! grep -qE "^ *\"WebFetch\",?$" .claude/settings.json'
run "settings: dead OW_VAULT gone"     '! grep -q "OW_VAULT" .claude/settings.json'
run "settings[behavioral]: hooks/deny/env survive, legacy blanket retired" '
  d=$(mktemp -d);
  printf "%s\n" "{" "  \"permissions\": { \"allow\": [\"Bash\",\"Read\",\"Edit\",\"Write\",\"WebFetch\"], \"deny\": [\"Read(./.env)\"] }," "  \"hooks\": { \"PreToolUse\": [] }," "  \"env\": { \"OW_VAULT\": \"docs\", \"CO\": \"x\" }" "}" > "$d/cur.json";
  ( . scripts/ow-settings-merge.sh; ow_settings_merge .claude/settings.json "$d/cur.json" ) >/dev/null 2>&1;
  ok=1;
  grep -q "PreToolUse" "$d/cur.json" || ok=0;
  grep -q "Read(./.env)" "$d/cur.json" || ok=0;
  grep -q "\"CO\"" "$d/cur.json" || ok=0;
  grep -qE "^ *\"Bash\",?$" "$d/cur.json" && ok=0;
  grep -q "OW_VAULT" "$d/cur.json" && ok=0;
  rm -rf "$d"; [ "$ok" = 1 ]'
run "settings[behavioral]: a curated allow list is never taken away" '
  d=$(mktemp -d); printf "%s\n" "{ \"permissions\": { \"allow\": [\"Bash(npm run test:*)\"] } }" > "$d/cur.json";
  ( . scripts/ow-settings-merge.sh; ow_settings_merge .claude/settings.json "$d/cur.json" ) >/dev/null 2>&1;
  r=1; grep -q "npm run test" "$d/cur.json" && grep -q "Read" "$d/cur.json" && r=0;
  rm -rf "$d"; [ "$r" = 0 ]'
run "settings[behavioral]: malformed target left untouched" '
  d=$(mktemp -d); printf "{bad" > "$d/cur.json"; cp "$d/cur.json" "$d/before";
  ( . scripts/ow-settings-merge.sh; ow_settings_merge .claude/settings.json "$d/cur.json" ) >/dev/null 2>&1;
  r=1; cmp -s "$d/before" "$d/cur.json" && r=0; rm -rf "$d"; [ "$r" = 0 ]'
run "settings[behavioral]: idempotent" '
  d=$(mktemp -d); printf "%s\n" "{ \"permissions\": { \"allow\": [\"Bash(npm run test:*)\"] } }" > "$d/cur.json";
  ( . scripts/ow-settings-merge.sh; ow_settings_merge .claude/settings.json "$d/cur.json" ) >/dev/null 2>&1;
  cp "$d/cur.json" "$d/once";
  ( . scripts/ow-settings-merge.sh; ow_settings_merge .claude/settings.json "$d/cur.json" ) >/dev/null 2>&1;
  r=1; cmp -s "$d/once" "$d/cur.json" && r=0; rm -rf "$d"; [ "$r" = 0 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 38 — CLAUDE.md managed block (dev prose never ships; the block thaws)
# ════════════════════════════════════════════════════════════════════════════
# The bug this pins: upgrade grepped for a marker literal the file has never used, so the
# refresh never ran, and CLAUDE.md is in SAFE_PATHS — leaving an installed CLAUDE.md frozen
# forever, dev-only prose included.
printf "\n${c_bold}Section 38 — CLAUDE.md managed block${c_reset}\n"
run "claude-md: helper exists + is owned"  '[ -f scripts/ow-claude-md.sh ] && . scripts/ow-owned.sh && ow_owned_scripts | grep -qx ow-claude-md.sh'
run "claude-md: merge fn defined"          '. scripts/ow-claude-md.sh && command -v ow_claude_md_merge >/dev/null'
run "claude-md: markers present"           'grep -qx "<!-- OW START: workflow -->" CLAUDE.md && grep -qx "<!-- OW END: workflow -->" CLAUDE.md'
run "claude-md: block extracts"            '. scripts/ow-claude-md.sh && ow_claude_md_block CLAUDE.md | grep -q "หัวใจ 3 ข้อ"'
run "claude-md: dev prose stays outside"   '. scripts/ow-claude-md.sh && ! ow_claude_md_block CLAUDE.md | grep -q "superpowers"'
run "claude-md: sample-vault line outside" '. scripts/ow-claude-md.sh && ! ow_claude_md_block CLAUDE.md | grep -q "sample vault"'
run "claude-md: install merges"            'grep -q "ow_claude_md_merge" scripts/install.sh'
run "claude-md: upgrade refreshes"         'grep -q "ow_claude_md_merge" scripts/upgrade.sh'
run "claude-md: no stale marker literal"   '! grep -qF "OW START -->" scripts/upgrade.sh'
run "claude-md: no BSD-fatal multiline awk -v" '! grep -qF "awk -v start=" scripts/upgrade.sh'
run "claude-md: backed up + rollbackable"  'grep -q "cp CLAUDE.md \"\$BACKUP_DIR/CLAUDE.md\"" scripts/upgrade.sh && awk "/^ROLLBACK_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -q "CLAUDE.md"'
run "claude-md[behavioral]: brownfield no-clobber + idempotent" '
  . scripts/ow-claude-md.sh;
  d=$(mktemp -d); printf "# My project\n\nhost rule one\n" > "$d/CLAUDE.md";
  ow_claude_md_merge "$d/CLAUDE.md" CLAUDE.md >/dev/null;
  ow_claude_md_merge "$d/CLAUDE.md" CLAUDE.md >/dev/null;
  s=$(grep -cF "<!-- OW START: workflow -->" "$d/CLAUDE.md");
  u=$(grep -c "host rule one" "$d/CLAUDE.md");
  dev=$(grep -c "superpowers" "$d/CLAUDE.md"); rm -rf "$d";
  [ "$s" = 1 ] && [ "$u" = 1 ] && [ "$dev" = 0 ]'
run "claude-md[behavioral]: legacy narrow block widens, host prose kept" '
  . scripts/ow-claude-md.sh;
  d=$(mktemp -d); printf "# Old\n\n<!-- OW START: command-list -->\nold list\n<!-- OW END: command-list -->\n\nhost tail\n" > "$d/CLAUDE.md";
  ow_claude_md_merge "$d/CLAUDE.md" CLAUDE.md >/dev/null;
  r=0; grep -q "OW START: workflow" "$d/CLAUDE.md" && grep -q "host tail" "$d/CLAUDE.md" && ! grep -q "old list" "$d/CLAUDE.md" || r=1;
  rm -rf "$d"; [ "$r" = 0 ]'
run "claude-md[behavioral]: unterminated marker refuses to guess" '
  . scripts/ow-claude-md.sh;
  d=$(mktemp -d); printf "# Host\n<!-- OW START: workflow -->\nstuff\nmore\n" > "$d/CLAUDE.md";
  ow_claude_md_merge "$d/CLAUDE.md" CLAUDE.md >/dev/null; r=$?;
  keep=$(grep -c "more" "$d/CLAUDE.md"); rm -rf "$d";
  [ "$r" = 2 ] && [ "$keep" = 1 ]'
run "claude-md[behavioral]: a source with no block writes nothing" '
  . scripts/ow-claude-md.sh;
  d=$(mktemp -d); printf "no markers\n" > "$d/src.md"; printf "host\n" > "$d/CLAUDE.md";
  ow_claude_md_merge "$d/CLAUDE.md" "$d/src.md" >/dev/null; r=$?;
  n=$(wc -l < "$d/CLAUDE.md" | tr -d " "); rm -rf "$d";
  [ "$r" = 1 ] && [ "$n" = 1 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 39 — prompts/ backfill + tombstones (upgrade destroys less, removes more)
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 39 — prompts/ backfill + tombstones${c_reset}\n"
run "prompts: out of the wholesale AI refresh" 'n=$(awk "/^ai_frontend_dirs\(\)/,/^}/" scripts/upgrade.sh | grep -c "|prompts|"); [ "$n" = 2 ]'
run "prompts: backfilled, never replaced"      'grep -q "into prompts/" scripts/upgrade.sh && grep -q "prompts/\$rel" scripts/upgrade.sh'
run "prompts: install + sync + upgrade agree"  'grep -q "kept existing: prompts/" scripts/install.sh && grep -qE "^[[:space:]]*prompts([[:space:]]|$)" .ow/commands/ow-sync.md'
run "tombstones: API exposed"                  '. scripts/ow-owned.sh && command -v ow_tombstones >/dev/null && command -v ow_tombstone_pending >/dev/null'
run "tombstones: 3 non-empty tab fields"       '. scripts/ow-owned.sh && ow_tombstones | awk -F"\t" "NF!=3 || \$1==\"\" || \$2==\"\" || \$3==\"\" {bad=1} END{exit bad?1:0}"'
run "tombstones: only rollback-covered dirs"   '. scripts/ow-owned.sh && ! ow_tombstones | cut -f1 | grep -qvE "^(scripts|bin)/"'
run "tombstones: since is a release version"   '. scripts/ow-owned.sh && ! ow_tombstones | cut -f2 | grep -qvE "^[0-9]+\.[0-9]+\.[0-9]+$"'
run "tombstones: never also owned"             '. scripts/ow-owned.sh; bad=""; for r in $(ow_tombstones | cut -f1); do b=$(basename "$r"); ow_owned_scripts | grep -qx "$b" && bad="$bad $b"; ow_owned_bin | grep -qx "$b" && bad="$bad $b"; done; [ -z "$bad" ] || { echo "tombstoned AND owned:$bad"; exit 1; }'
run "tombstones: version gate runs them once"  '. scripts/ow-owned.sh; [ "$(ow_tombstone_pending 0.0.0 | wc -l | tr -d " ")" -gt 0 ] && [ -z "$(ow_tombstone_pending 99.0.0)" ]'
# A row whose `since` is NEWER than the version being shipped never stops being pending: the
# consumer lands on the new version, the gate still reads cur < since, and the retirement runs
# again on every future upgrade. This pins the release cut to the rows it carries.
# Nothing tied the changelog to the version being shipped, so a release could carry a
# ow.version whose section does not exist — and upgrade.sh's own closing advice tells the
# user to "Check breaking changes ใน CHANGELOG.md".
run "changelog: has a section for the shipped version" '
  shipped=$(awk "/^ow:/{b=1;next} /^[a-zA-Z_]/{b=0} b && /^  version:/{gsub(/[ \"]/,\"\"); sub(/^version:/,\"\"); print; exit}" .ow.yml)
  [ -n "$shipped" ] || { echo "no ow.version"; exit 1; }
  grep -q "^## \[$shipped\]" CHANGELOG.md || { echo "CHANGELOG.md has no ## [$shipped] section"; exit 1; }'
run "changelog: newest section IS the shipped version" '
  shipped=$(awk "/^ow:/{b=1;next} /^[a-zA-Z_]/{b=0} b && /^  version:/{gsub(/[ \"]/,\"\"); sub(/^version:/,\"\"); print; exit}" .ow.yml)
  top=$(grep -m1 "^## \[" CHANGELOG.md | sed "s/^## \[//; s/\].*//")
  [ "$top" = "$shipped" ] || { echo "CHANGELOG top is [$top] but .ow.yml ships $shipped"; exit 1; }'
run "tombstones: since <= the shipped ow.version" '
  . scripts/ow-owned.sh
  shipped=$(awk "/^ow:/{b=1;next} /^[a-zA-Z_]/{b=0} b && /^  version:/{gsub(/[ \"]/,\"\"); sub(/^version:/,\"\"); print; exit}" .ow.yml)
  [ -n "$shipped" ] || { echo "no ow.version in .ow.yml"; exit 1; }
  bad=""
  for v in $(ow_tombstones | cut -f2); do
    _ow_ver_lt "$shipped" "$v" && bad="$bad $v"
  done
  [ -z "$bad" ] || { echo "tombstone since newer than shipped $shipped:$bad — they would re-fire every upgrade"; exit 1; }'
run "tombstones: upgrade applies, signature-guarded" 'grep -q "ow_tombstone_pending" scripts/upgrade.sh && grep -q "head -3 \"\$_tpath\"" scripts/upgrade.sh'
run "tombstones: backed up before rm"          'grep -q "BACKUP_DIR/\$_tpath" scripts/upgrade.sh'

# retired standard snapshot (v1.9.0) — the removal must be gated, backed up and rollback-covered.
# Without the gate it re-fires on every future upgrade and would delete a project's OWN
# .ow/policies/ years later; without the ROLLBACK_PATHS row --rollback silently loses them.
run "retire: removal is version-gated"        'grep -q "_ow_ver_lt \"\$current_version\" \"1.9.0\"" scripts/upgrade.sh'
run "retire: names all 5 retired paths"       '
  for p in .ow/STANDARD.md .ow/UPDATE-POLICY.md .ow/VERSION .ow/policies .ow/checklists; do
    grep -q "$p" scripts/upgrade.sh || { echo "upgrade.sh does not retire $p"; exit 1; }
  done'
run "retire: backed up before rm"             'grep -q "cp -R \"\$_retired\" \"\$BACKUP_DIR/\$_retired\"" scripts/upgrade.sh'
run "retire: rollback covers the retired set" '
  for p in .ow/STANDARD.md .ow/policies .ow/checklists; do
    awk "/^ROLLBACK_PATHS=\\(/{r=1} r{print} /^\\)/{if(r)exit}" scripts/upgrade.sh | grep -q "$p" \
      || { echo "ROLLBACK_PATHS missing $p"; exit 1; }
  done'
run "retire: installer no longer ships them"  '
  for p in STANDARD.md UPDATE-POLICY.md VERSION policies checklists; do
    awk "/^SAFE_ITEMS=\\(/{r=1} r{print} /^\\)/{if(r)exit}" scripts/install.sh | grep -q "\.ow/$p\"" \
      && { echo "install.sh still ships .ow/$p"; exit 1; }
  done; true'
run "retire[behavioral]: upgrade removes + backs up the snapshot" '
  TD=$(mktemp -d)
  mkdir -p "$TD/consumer/scripts" "$TD/consumer/.ow/policies" "$TD/consumer/.ow/checklists" "$TD/stage/scripts" "$TD/stage/.ow/commands"
  cp scripts/upgrade.sh scripts/ow-paths.sh scripts/ow-safe-paths.sh scripts/ow-owned.sh \
     scripts/ow-claude-manifest.sh scripts/ow-shims.sh scripts/ow-frontends.sh \
     scripts/ow-config-merge.sh scripts/ow-gitignore.sh "$TD/consumer/scripts/"
  cp scripts/ow-owned.sh "$TD/stage/scripts/"
  printf "ow:\n  version: \"1.8.1\"\nvault_path: docs/v\n" > "$TD/consumer/.ow.yml"
  printf "0.8.0\n"  > "$TD/consumer/.ow/VERSION"
  printf "# std\n"  > "$TD/consumer/.ow/STANDARD.md"
  printf "# up\n"   > "$TD/consumer/.ow/UPDATE-POLICY.md"
  printf "# pol\n"  > "$TD/consumer/.ow/policies/coding.md"
  printf "# chk\n"  > "$TD/consumer/.ow/checklists/before-commit.md"
  ( cd "$TD/consumer" && bash scripts/upgrade.sh --source "$TD/stage" ) >/dev/null 2>&1
  OK=1
  for p in .ow/VERSION .ow/STANDARD.md .ow/UPDATE-POLICY.md .ow/policies .ow/checklists; do
    [ -e "$TD/consumer/$p" ] && OK=0                                    # must be gone
    ls -d "$TD/consumer"/.ow.backup-*/"$p" >/dev/null 2>&1 || OK=0 # must be backed up
  done
  rm -rf "$TD"; [ "$OK" -eq 1 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 40 — shipped pointers resolve · project identity · dead code · sync scope
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 40 — shipped-pointer + identity + dead-code debts${c_reset}\n"
run "ptr: no dangling EVIDENCE-PATHS in agents" '! grep -rq "EVIDENCE-PATHS" .claude/agents/'
run "ptr: agents carry no evidence pointer"     '! grep -rq "ow-evidence" .claude/agents/'
run "ptr: gitignore comment pointer resolves"   '. scripts/ow-gitignore.sh; p=$(ow_gitignore_block | grep -oE "\.ow/[A-Za-z0-9_./-]+\.md" | head -1); [ -z "$p" ] || [ -f "$p" ]'
run "ptr: lint check 7 covers .ow paths"  'grep -q "templates|workflows|rules" scripts/conformance-lint.sh'
run "ptr[behavioral]: check 7 fails on a repo-only agent pointer" '
  d=$(mktemp -d); cp -R .ow "$d/"; mkdir -p "$d/.claude"; cp -R .claude/agents "$d/.claude/";
  printf "\nSee \140.ow/commands/ow-nope.md\140 for nothing\n" >> "$d/.claude/agents/verifier.md";
  bash scripts/conformance-lint.sh "$d" >/tmp/ow-c7.$$ 2>&1; r=$?; rm -rf "$d";
  grep -q "check 7" /tmp/ow-c7.$$; g=$?; rm -f /tmp/ow-c7.$$;
  [ "$r" -ne 0 ] && [ "$g" -eq 0 ]'
run "identity: install personalises name/slug"  'grep -q "project_slug" scripts/install.sh'
run "identity: sample marker matches shipped config" 'grep -q "^  name: \"Library Book Tracker\"" .ow.yml && grep -qF "name: \"Library Book Tracker\"" scripts/install.sh'
run "identity: install never yq -i s .ow.yml" '! grep -qE "yq +-i.*obsidian-workflow\.yml" scripts/install.sh'
run "identity[behavioral]: slug rule is BSD-sed safe" 's=$(printf "%s" "My Cool App" | tr "[:upper:]" "[:lower:]" | sed "s/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//"); [ "$s" = "my-cool-app" ]'
run "dead: detect_mode removed"                 '! grep -q "detect_mode" scripts/install.sh'
run "dead: ow_owned_claude_manifest removed"   '! grep -q "ow_owned_claude_manifest" scripts/ow-claude-manifest.sh scripts/install.sh scripts/upgrade.sh bin/ow'
run "sync: snapshot paths are the shipped set"  'grep -q "^SNAPSHOT_PATHS=(templates commands)" .ow/commands/ow-sync.md'

# ── retired workflow snapshot (v2.1.0) ────────────────────────────────────────
# .ow/workflows/obsidian.md routed the AI to nine command files obsidian-workflow never shipped
# (plan-work.md, fix-bug.md, verify-work.md …) and to a second vault layout. Same three
# guarantees as every other retirement: gone from the source, removed on upgrade, rollback-able.
run "wf: workflows dir is gone from the source"    '[ ! -d .ow/workflows ]'
run "wf: legacy obsidian templates are gone"       '[ ! -e .ow/templates/init.md ] && [ ! -e .ow/templates/obsidian-context.md ] && [ ! -e .ow/templates/obsidian-work-note.md ]'
run "wf: no spec/agent points at the retired files" '! grep -rq "obsidian-context\|obsidian-work-note\|00-Agent-Context" .ow/commands .claude/agents .ow/templates'
run "wf: no reference to a command file that never shipped" '! grep -rqE "commands/(plan-work|fix-bug|verify-work|understand-task|build-feature|write-document|test-report|handoff-report|init)\.md" .ow/commands .ow/templates .claude/agents'
run "wf: installer no longer copies workflows"     '! grep -q "\.ow/workflows" scripts/install.sh'
run "wf: retirement is version-gated"              'grep -q "_ow_ver_lt \"\$current_version\" \"2.1.0\"" scripts/upgrade.sh'
run "wf: retirement backs up first"                'grep -q "BACKUP_DIR/.ow/workflows" scripts/upgrade.sh'
run "wf: retired dir is rollback-safe"             'awk "/^ROLLBACK_PATHS=\(/,/^\)/" scripts/upgrade.sh | grep -q ".ow/workflows"' 

# ════════════════════════════════════════════════════════════════════════════
# Section 41 — a write that failed must never be reported as a success
# ════════════════════════════════════════════════════════════════════════════
# Both new merge helpers discarded the status of their write and printed a success word
# anyway, so install/upgrade logged "refreshed"/"appended"/"installed" for changes that never
# landed — and install has no verify step after that point, so the lie was terminal.
printf "\n${c_bold}Section 41 — no false success on a failed write${c_reset}\n"
run "write: merge declares rc=3 in its API contract" 'grep -q "exit 3 = the write FAILED" scripts/ow-claude-md.sh'
run "write: _cm_failed is local"                     'grep -q "local target=\"\$1\" src=\"\$2\" _cm_failed=0" scripts/ow-claude-md.sh'
run "write: every branch guards its write"           'n=$(grep -c "_cm_failed\" = 1 \] && return 3" scripts/ow-claude-md.sh); [ "$n" = 3 ]'
run "write: install discriminates rc 2 vs 3"         'grep -q "CLAUDE.md WRITE FAILED (rc=3)" scripts/install.sh'
run "write: upgrade discriminates rc 2 vs 3"         'grep -q "CLAUDE.md rewrite FAILED" scripts/upgrade.sh'
run "write: settings merge reports a failed install"  'grep -q "settings.json: install FAILED" scripts/ow-settings-merge.sh'
run "write[behavioral]: all three merge branches return 3 on failure" '
  . scripts/ow-claude-md.sh
  d=$(mktemp -d); ok=1
  mkdir "$d/a"; cp CLAUDE.md "$d/a/CLAUDE.md"; chmod 555 "$d/a"
  ( ow_claude_md_merge "$d/a/CLAUDE.md" CLAUDE.md >/dev/null 2>&1 ); [ "$?" = 3 ] || ok=0
  mkdir "$d/b"; chmod 555 "$d/b"
  ( ow_claude_md_merge "$d/b/CLAUDE.md" CLAUDE.md >/dev/null 2>&1 ); [ "$?" = 3 ] || ok=0
  printf "# host\n" > "$d/c.md"; chmod 444 "$d/c.md"
  ( ow_claude_md_merge "$d/c.md" CLAUDE.md >/dev/null 2>&1 ); [ "$?" = 3 ] || ok=0
  chmod 755 "$d/a" "$d/b"; rm -rf "$d"; [ "$ok" = 1 ]'
run "write[behavioral]: the happy paths still report their own word" '
  . scripts/ow-claude-md.sh
  d=$(mktemp -d); ok=1
  [ "$(ow_claude_md_merge "$d/x.md" CLAUDE.md)" = created ] || ok=0
  [ "$(ow_claude_md_merge "$d/x.md" CLAUDE.md)" = refreshed ] || ok=0
  printf "# host\n" > "$d/y.md"
  [ "$(ow_claude_md_merge "$d/y.md" CLAUDE.md)" = appended ] || ok=0
  rm -rf "$d"; [ "$ok" = 1 ]'

# ════════════════════════════════════════════════════════════════════════════
# Section 42 — --rollback is reversible; the preview matches the real run
# ════════════════════════════════════════════════════════════════════════════
# The restore is a wholesale rm -rf + cp -R of each rollback path. That is right for "undo the
# upgrade", but everything written AFTER the backup — /ow-agent create|enable output, the
# project's own slash commands, a hook added to settings.json — is in no backup at all.
printf "\n${c_bold}Section 42 — rollback safety + dry-run honesty${c_reset}\n"
run "rollback: snapshots the current state first" 'grep -q "^  rb_snapshot=\".ow.rollback-" scripts/upgrade.sh && grep -q "rb_saved=\$((rb_saved+1))" scripts/upgrade.sh'
run "rollback: tells the user where it went"      'grep -q "Pre-rollback state kept at" scripts/upgrade.sh'
run "rollback: snapshot is gitignored"            '. scripts/ow-gitignore.sh && ow_gitignore_block | grep -qF ".ow.rollback-*/"'
run "dryrun: tombstone preview checks the signature" 'awk "/^if \[ \"\\\$DRY_RUN\" -eq 1 \]/,/^fi\$/" scripts/upgrade.sh | grep -q "head -3 \"\\\$_tp\""'
run "dryrun: preview names what it will KEEP"     'grep -q "would KEEP (tombstoned but not obsidian-workflow" scripts/upgrade.sh'
run "dryrun: pending rows are not called zero"    'grep -q "rows pending for v" scripts/upgrade.sh'
run "dryrun: prompts message names the real cause" 'grep -q "the staged release ships none" scripts/upgrade.sh'
run "routers: one definition, no drift"           'grep -q "^router_frontends()" scripts/upgrade.sh && grep -q "_routers=\"\$(router_frontends)\"" scripts/upgrade.sh'
run "install: applies tombstones too"             'grep -q "ow_tombstones" scripts/install.sh && grep -q "retired \$_tpath" scripts/install.sh'

# ════════════════════════════════════════════════════════════════════════════
# Section 43 — version compare: the gate that decides whether a file is deleted
# ════════════════════════════════════════════════════════════════════════════
printf "\n${c_bold}Section 43 — version compare + pending-set contract${c_reset}\n"
run "ver: normaliser defined"                  'grep -q "^_ow_ver_norm()" scripts/ow-owned.sh'
run "ver[behavioral]: ordering is correct"     '
  . scripts/ow-owned.sh; ok=1
  _ow_ver_lt 1.8.0 1.8.1 || ok=0
  _ow_ver_lt 1.8.1 1.8.1 && ok=0
  _ow_ver_lt 1.9.0 1.10.0 || ok=0
  _ow_ver_lt 1.10.0 1.9.0 && ok=0
  _ow_ver_lt 1.8 1.8.1 || ok=0
  _ow_ver_lt v1.8.1 1.8.1 && ok=0
  _ow_ver_lt 2.0.0 1.8.1 && ok=0
  [ "$ok" = 1 ]'
run "ver[behavioral]: a suffixed version does not skip every row" '
  . scripts/ow-owned.sh
  # 1.8.0-rc1 is still BELOW 1.8.1 — a host VERSION file carrying a suffix must not silently
  # sort NEWER and skip the retirement (BSD sort falls back to a whole-line tiebreak).
  _ow_ver_lt "1.8.0-rc1" "1.8.1"'
run "ver[behavioral]: empty version applies every row" '. scripts/ow-owned.sh && _ow_ver_lt "" 1.8.1'
run "ver[behavioral]: nothing pending is not an error under set -e" '
  bash -c "set -euo pipefail; . scripts/ow-owned.sh; ow_tombstone_pending 99.0.0; echo REACHED" | grep -qx REACHED'

# ════════════════════════════════════════════════════════════════════════════
# Section 44 — coding discipline: one home, cited by every verb that writes code
# ════════════════════════════════════════════════════════════════════════════
# A citation like "OW §3.4" or "per CLAUDE.md test mandate" points at a rule nobody can open:
# it cannot be changed, cannot be checked, and each verb drifts to its own reading of it. The
# fragment is the home; conformance-lint check 12 is the guard that keeps it the ONLY home.
echo ""
printf "${c_bold}Section 44: coding discipline fragment${c_reset}\n"

CD=".ow/commands/_shared/coding-discipline.md"
run "coding-discipline: fragment exists" "[ -f $CD ]"
run "coding-discipline: owns the untestable list 1-6" \
  "grep -qF 'Untestable list (1–6)' $CD"
run "coding-discipline: owns the RED-before-fix rule" \
  "grep -qF 'must FAIL' $CD"
run "coding-discipline: owns the surgical-revert rule (#29)" \
  "grep -qF 'never' $CD && grep -qF 'git checkout' $CD && grep -qF 'git clean' $CD"
run "coding-discipline: names the project rules override" \
  "grep -qF '.ow/rules/' $CD"
run "coding-discipline: every code-writing verb cites it" \
  "grep -qF '_shared/coding-discipline.md' .ow/commands/ow-implement.md &&
   grep -qF '_shared/coding-discipline.md' .ow/commands/ow-fix.md &&
   grep -qF '_shared/coding-discipline.md' .ow/commands/ow-fix-issue.md &&
   grep -qF '_shared/coding-discipline.md' .ow/commands/_shared/fix-issue-fix-flow.md"
run "coding-discipline: listed in the _shared README table" \
  "grep -qF 'coding-discipline.md' .ow/commands/_shared/README.md"
# drift guard: the untestable list lives in exactly ONE file (a second copy rots silently)
run "coding-discipline: untestable list appears once" \
  "[ \"\$(grep -rlF 'pure styling/layout' .ow/commands/ | wc -l | tr -d ' ')\" -eq 1 ]"
# the dangling citations that made this fragment necessary must never come back
run "coding-discipline: no OW § citation anywhere in shipped specs" \
  "! grep -rqE 'OW (Standard )?§' .ow/commands/ .claude/agents/"
run "coding-discipline: no CLAUDE.md/AGENTS.md mandate citation" \
  "! grep -rqE '(CLAUDE|AGENTS)\.md[^.]{0,30}mandate' .ow/commands/ .claude/agents/"
run "coding-discipline: conformance-lint check 12 exists" \
  "grep -qF 'check 12' scripts/conformance-lint.sh"
# ownership contract (same as check 4): a project's own agent is a note, never an install-abort
run "coding-discipline[behavioral]: check 12 notes a project-owned agent, never fails on it" '
  _cd_t=$(mktemp -d) && cp -R . "$_cd_t/repo" 2>/dev/null;
  printf -- "---\nname: myown\n---\nFollow the CLAUDE.md mandate.\n" > "$_cd_t/repo/.claude/agents/myown.md";
  bash "$_cd_t/repo/scripts/conformance-lint.sh" "$_cd_t/repo" 2>&1 | grep -q "note: project-owned agent cites an unresolvable authority";
  _cd_n=$?;
  bash "$_cd_t/repo/scripts/conformance-lint.sh" "$_cd_t/repo" >/dev/null 2>&1; _cd_p=$?;
  rm -rf "$_cd_t"; [ $_cd_n -eq 0 ] && [ $_cd_p -eq 0 ]'
run "coding-discipline[behavioral]: check 12 fails on a fake citation" '
  _cd_tmp=$(mktemp -d) && cp -R . "$_cd_tmp/repo" 2>/dev/null;
  printf "\n- rule per OW §9.9\n" >> "$_cd_tmp/repo/.ow/commands/ow-doc.md";
  ! bash "$_cd_tmp/repo/scripts/conformance-lint.sh" "$_cd_tmp/repo" >/dev/null 2>&1;
  _cd_rc=$?; rm -rf "$_cd_tmp"; [ $_cd_rc -eq 0 ]'

# ════════════════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL))
echo ""
printf "${c_bold}─────────── Summary ───────────${c_reset}\n"
printf "  ${c_green}Passed:${c_reset}  %d\n" "$PASS"
[ "$FAIL" -gt 0 ] && printf "  ${c_red}Failed:${c_reset}  %d\n" "$FAIL"
[ "$SKIP" -gt 0 ] && printf "  ${c_yellow}Skipped:${c_reset} %d (filter)\n" "$SKIP"
printf "  Total run: %d\n\n" "$TOTAL"

if [ "$FAIL" -gt 0 ]; then
  printf "${c_red}${c_bold}FAILED tests:${c_reset}\n"
  for n in "${FAILED_NAMES[@]}"; do echo "  • $n"; done
  echo ""
  exit 1
fi

printf "${c_green}${c_bold}All tests passed${c_reset}\n"
exit 0
