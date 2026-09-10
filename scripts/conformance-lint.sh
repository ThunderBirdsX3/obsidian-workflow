#!/usr/bin/env bash
# obsidian-workflow — conformance lint (#14)
# ─────────────────────────────────────────────────────────────────────────────
# Hard gate that stops the read-mechanism work from silently regressing. Run by
# /ow-sync (verify phase) and by the installer (post-copy); both ABORT on failure.
# Pure grep/shell — NO yq/jq dependency, so it runs even when prerequisites are missing.
#
# Checks (any failure ⇒ non-zero exit):
#   1. Every command verb spec has the canonical Phase 0 'Load Context' preamble.
#   2. No `docs/obsidian-vault` runtime-path literal in an executable block (command/agent).
#   3. No inline jq/yq reading the submodules LIST from a YAML config (config-mgmt yq writes
#      in ow-sync/ow-agent are allow-listed).
#   4. Every OW-OWNED agent has the §0 injected-context header. (#21) Ownership is
#      decided by the file's SIGNATURE, never its name — a project may legitimately own a
#      .claude/agents/backend.md. A project's own agent lacking §0 is a NOTE, not a failure:
#      a gate that aborts an install over a file obsidian-workflow never wrote is a false gate.
#   5. No command/agent WRITES a binary/artifact path under the vault — the vault is text only.
#   6. No reference to the retired evidence/upload subsystem (/ow-evidence, /ow-upload,
#      EVIDENCE.md manifests, EVIDENCE_RAW_ROOT/CURATED_ROOT, test-artifacts/) survives in a
#      command, fragment or agent. Results are quoted into the vault doc, never stored as files.
#   7. Every `_shared/<file>.md` fragment pointer AND every backtick-quoted `.ow/<area>/…md`
#      path written in a spec or a shipped agent resolves (#34) — a verb spec delegates mode-gated
#      rules to a fragment it reads on demand, and an agent points at the installed spec that
#      carries a contract. A dangling pointer loses the rule in silence, and a pointer at a file
#      the installer never copies is dead the moment it lands in a host project. Only
#      backtick-quoted paths count: a bare path inside a sample-output fence is illustration.
#   8. The Phase 0 step-1 block (resolver → .ow/local/paths.env, source it, VAULT_ABS assert,
#      export — never `eval`: Bash tool calls do not share shell state) is byte-identical in
#      every verb spec. Check 1 only proves the marker is present, so a typo in one command's
#      resolver call would live there forever; every command loads this block on every run, so a
#      drifted copy is a per-command failure mode nothing else catches. Step 2 is exempt — its
#      `--rules <area>` argument is legitimately per-command.
#   9. The `context_closed` contract appears in ow-split.md, ow-implement.md and
#      _shared/delegation.md. /ow-split emits the flag and the other two are its only readers;
#      losing it on one side silently re-inflates a sub-plan's context to the full include-when set.
#      Gated on ow-split.md being present — a project that has not adopted /ow-split has no
#      emitter and so nothing to guard; it must never be aborted by this check.
#  10. /ow-git --bump writes version files through scripts/ow-version.sh, the writer exists, and
#      no spec calls the old undefined `bump_version_file` (#34). An improvised write is how a
#      `v`-prefixed version reached a pubspec and shipped as a tagged, unbuildable release.
#  12. No spec or agent cites an authority that does not exist (`OW §…`, `CLAUDE.md … mandate`).
#      A citation nobody can open is a rule with no home: unchangeable, uncheckable, and read
#      differently by every verb. A cross-verb rule belongs in a `_shared/` fragment, cited by the
#      pointer check 7 already validates.
#  11. /ow-implement's inline resume marker (`## Step Progress`) has BOTH of its sides — §3.3 writes
#      it and the §1.2 resume gate reads it AND re-runs its `exit:`. An inline run may not chunk, so
#      this marker is the only state that survives a dead session; lose the writer and a fresh
#      session must re-derive progress from git diff, lose the re-verify and it trusts a marker whose
#      code may have been reverted. It must also emit `- [x]` only — a `- [ ]` would trip Phase 6.0.
#
# Checks 2/3/5/6 cover the `_shared/` fragments too — bash lifted out of a verb spec must not
# escape the same gates. Check 1 does not: a fragment is not a verb and has no Phase 0.
#
# Usage: bash scripts/conformance-lint.sh [ROOT]   (default: git toplevel or CWD)

set -uo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CMDS="$ROOT/.ow/commands"
FRAG="$CMDS/_shared"
AGENTS="$ROOT/.claude/agents"
# Agent NAMES obsidian-workflow ships — the always-on four, and only those. Specialized agents
# (backend/frontend/mobile/design/test-runner) are written per project by /ow-agent create
# and are NOT shipped names, so owning one is normal and must not raise the collision note.
# This list only labels a name collision in the check-4 note — it never decides ownership,
# which is always proven by content. (#21)
OWNED_AGENTS=" docs verifier security gh-issue "
# _agent_is_ow_owned <file> — true when obsidian-workflow authored this agent. Ownership is proven
# by CONTENT, the same contract as _is_generated_shim / _is_generated_skill in
# scripts/ow-shims.sh. Two strings identify a obsidian-workflow agent and obsidian-workflow is the only
# writer of either: the marker at the top of every shipped agent, and the §0 injected-context
# header /ow-agent writes into every agent it generates.
# Keep byte-identical with ow_is_owned_agent in scripts/ow-claude-manifest.sh.
_agent_is_ow_owned() {
  grep -q '^<!-- obsidian-workflow:agent' "$1" && return 0
  grep -qF '## §0. Context (injected — authoritative)' "$1"
}
FAIL=0
note() { printf '  %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*" >&2; FAIL=1; }
okk()  { printf '  ✓ %s\n' "$*"; }

# helper: print only the lines INSIDE ```bash / ```sh fences of a file
_bash_lines() {
  awk '/^[[:space:]]*```/{ if(inf==0){inf=1;b=($0~/```(bash|sh)/)?1:0}else{inf=0;b=0}; next } inf&&b{print}' "$1"
}

echo "conformance-lint (#14) — root: $ROOT"

# ── check 1: Phase 0 preamble present in every command ───────────────────────
if [ -d "$CMDS" ]; then
  missing=""
  for f in "$CMDS"/*.md; do
    [ -e "$f" ] || continue
    grep -q 'OW-PHASE0' "$f" || missing="$missing $(basename "$f")"
  done
  [ -z "$missing" ] && okk "check 1: all commands have the Phase 0 preamble" \
    || fail "check 1: commands missing Phase 0:$missing"
fi

# ── check 2: no obsidian-vault runtime-path literal in executable blocks ──────
hits=""
for f in "$CMDS"/*.md "$FRAG"/*.md "$AGENTS"/*.md; do
  [ -e "$f" ] || continue
  if _bash_lines "$f" | grep -c 'docs/obsidian-vault' >/dev/null; then hits="$hits $(basename "$f")"; fi
done
[ -z "$hits" ] && okk "check 2: no obsidian-vault runtime literal in executable blocks" \
  || fail "check 2: obsidian-vault literal in executable block:$hits"

# ── check 3: no jq/yq reading the submodules list from YAML inline ────────────
# Allow-list: config-management yq writes (del(.standard), .subagents.x=true, version key)
# in ow-sync.md / ow-agent.md are legitimate and NOT a submodule-list read.
hits=""
for f in "$CMDS"/*.md "$FRAG"/*.md; do
  [ -e "$f" ] || continue
  if grep -nE '(jq|yq)[^|]*\.submodules' "$f" | grep -cE '\.ya?ml' >/dev/null; then
    hits="$hits $(basename "$f")"
  fi
done
[ -z "$hits" ] && okk "check 3: no jq/yq submodule-list read from YAML (use --submodules)" \
  || fail "check 3: inline jq/yq submodule-list read:$hits"

# ── check 4: every OW-OWNED agent has §0 (#21) ─────────────────────────
# Ownership is decided by the file's SIGNATURE, never by its name. A signed agent that
# lacks §0 is fatal — only obsidian-workflow writes the signature, so that is a shipped-tree defect.
# A project's own agent is a NOTE whatever it is called: a gate that aborts an install over
# a file obsidian-workflow never wrote is a false gate, and install has no rollback.
if [ -d "$AGENTS" ]; then
  missing=""; user_missing=""; shadowed=""
  for f in "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    if _agent_is_ow_owned "$f"; then
      grep -qE '^## §0\.' "$f" || missing="$missing $(basename "$f")"
      continue
    fi
    grep -qE '^## §0\.' "$f" || user_missing="$user_missing $(basename "$f")"
    case "$OWNED_AGENTS" in *" $base "*) shadowed="$shadowed $(basename "$f")" ;; esac
  done
  [ -z "$missing" ] && okk "check 4: all obsidian-workflow-owned agents have §0" \
    || fail "check 4: obsidian-workflow-owned agents missing §0:$missing"
  [ -n "$user_missing" ] && note "check 4 (note): user-owned agents without §0 (not injected by obsidian-workflow commands):$user_missing"
  [ -n "$shadowed" ] && note "check 4 (note): project-owned agents under a shipped name — yours is kept, obsidian-workflow's is not installed:$shadowed"
fi

# ── check 5: no binary/artifact WRITE under the vault ────────────────────────
hits=""
for f in "$CMDS"/*.md "$FRAG"/*.md "$AGENTS"/*.md; do
  [ -e "$f" ] || continue
  if grep -qE 'mkdir -p "\$VAULT_ABS[^"]*(artifact|screenshot|capture)|> *"\$VAULT_ABS[^"]*\.(png|jpe?g|zip|har|trace|log|txt|json)' "$f"; then
    hits="$hits $(basename "$f")"
  fi
done
[ -z "$hits" ] && okk "check 5: no binary/artifact write under the vault" \
  || fail "check 5: binary write under vault:$hits"

# ── check 6: no reference to the retired evidence/upload subsystem ───────────
if [ -d "$CMDS" ]; then
  hits=""
  for f in "$CMDS"/*.md "$FRAG"/*.md "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    if grep -qE 'ow-(evidence|upload)|upload-evidence|EVIDENCE\.md|EVIDENCE_(RAW|CURATED)_ROOT|OW-EVIDENCE:START|test-artifacts/' "$f"; then
      hits="$hits $(basename "$f")"
    fi
  done
  [ -z "$hits" ] && okk "check 6: no retired evidence/upload reference in commands or agents" \
    || fail "check 6: retired evidence/upload reference:$hits"
fi

# ── check 7: every _shared/ fragment pointer resolves (#34) ──────────────────
# A verb spec keeps mode-gated detail in .ow/commands/_shared/<file>.md and reads it on
# demand (never @-included). A pointer at a file that is not there = a rule lost in silence, so
# a dangling reference is fatal — the same class of failure as check 1.
if [ -d "$CMDS" ]; then
  hits=""
  for f in "$CMDS"/*.md "$FRAG"/*.md "$AGENTS"/*.md; do
    [ -e "$f" ] || continue
    for ref in $(grep -oE '_shared/[A-Za-z0-9_.-]+\.md' "$f" | sort -u); do
      [ -f "$CMDS/$ref" ] || hits="$hits $(basename "$f")→$ref"
    done
    # Same class one level up: a spec or a shipped agent may only point at a file the
    # installer actually copies into the host project. Backtick-quoted paths only — a bare
    # path inside a sample-output fence (ow-sync.md's diff preview) is illustration.
    for ref in $(grep -oE '`\.ow/(commands|templates|workflows|rules)/[A-Za-z0-9_./-]+\.md`' "$f" | sed 's/`//g' | sort -u); do
      [ -f "$ROOT/$ref" ] || hits="$hits $(basename "$f")→$ref"
    done
  done
  [ -z "$hits" ] && okk "check 7: every _shared/ + .ow/ pointer resolves" \
    || fail "check 7: dangling fragment/spec pointer:$hits"
fi

# ── check 8: the Phase 0 step-1 block has not drifted between commands ───────
# Every command pastes this block into context on every run; a drifted copy (typo'd resolver
# path, missing VAULT_ABS assert, missing export) breaks that one command only and check 1 —
# which just looks for the marker — would never see it. Step 2 is skipped: its `--rules <area>`
# argument is per-command by design.
if [ -d "$CMDS" ]; then
  ref=""; ref_cmd=""; drift=""; nop0=""
  for f in "$CMDS"/ow-*.md; do
    [ -e "$f" ] || continue
    blk=$(awk '/^# 1\) resolve config/{on=1} on{print} /^export OW_CTX_LOADED=1/{if(on) exit}' "$f")
    case "$blk" in
      *"export OW_CTX_LOADED=1"*) : ;;
      *) nop0="$nop0 $(basename "$f")"; continue ;;
    esac
    if [ -z "$ref" ]; then ref="$blk"; ref_cmd=$(basename "$f")
    elif [ "$blk" != "$ref" ]; then drift="$drift $(basename "$f")"
    fi
  done
  if [ -n "$nop0" ]; then
    fail "check 8: Phase 0 step-1 block missing/unterminated in:$nop0"
  elif [ -n "$drift" ]; then
    fail "check 8: Phase 0 step-1 block drifted from $ref_cmd in:$drift"
  else
    okk "check 8: Phase 0 step-1 block identical across all commands"
  fi
fi

# ── check 9: the context_closed contract is present on both sides (#35) ──────
# /ow-split emits `context_closed: true` in every sub-plan; /ow-implement Phase 3.0 and
# _shared/delegation.md §1 are the only readers. The contract is pure prose in three files —
# drop it from one side and sub-plans silently fall back to full include-when resolution,
# re-inflating exactly the context the split existed to bound. Nothing else catches that.
# Gated on ow-split.md being installed: no emitter ⇒ nothing to guard. A project that has not
# picked up /ow-split yet (or a fixture with a partial commands dir) must never be aborted by it.
if [ -f "$CMDS/ow-split.md" ]; then
  _cc_missing=""
  grep -q 'context_closed' "$CMDS/ow-split.md" || _cc_missing="$_cc_missing ow-split.md"
  for _cc_f in "$CMDS/ow-implement.md" "$FRAG/delegation.md"; do
    [ -f "$_cc_f" ] || { _cc_missing="$_cc_missing $(basename "$_cc_f")(absent)"; continue; }
    grep -q 'context_closed' "$_cc_f" || _cc_missing="$_cc_missing $(basename "$_cc_f")"
  done
  [ -z "$_cc_missing" ] && okk "check 9: context_closed contract present in split/implement/delegation" \
    || fail "check 9: context_closed contract missing in:$_cc_missing"
fi

# ── check 10: --bump writes version files through the canonical writer (#34) ──
# ow-git.md used to call an UNDEFINED `bump_version_file` — no such function exists anywhere,
# so every run improvised the write, which is how `v0.3.36` reached a pubspec and shipped as a
# tagged, unbuildable release. Three things must hold together or the trap comes back: the
# writer exists, the spec calls it, and nothing calls the old ghost helper. A missing writer is
# the worst case — `--bump` fails closed on it, so the lint must catch it before an install does.
if [ -f "$CMDS/ow-git.md" ]; then
  _bv_bad=""
  [ -f "$ROOT/scripts/ow-version.sh" ] || _bv_bad="$_bv_bad scripts/ow-version.sh(absent)"
  _bash_lines "$CMDS/ow-git.md" | grep -c 'ow-version\.sh' >/dev/null \
    || _bv_bad="$_bv_bad ow-git.md(no-writer-call)"
  grep -rn 'bump_version_file' "$CMDS" 2>/dev/null | grep -c . >/dev/null \
    && _bv_bad="$_bv_bad bump_version_file(undefined-ghost-helper)"
  [ -z "$_bv_bad" ] && okk "check 10: --bump writes version files via scripts/ow-version.sh" \
    || fail "check 10: version-write path broken:$_bv_bad"
fi

# ── check 11: the inline resume marker has a writer AND a verifying reader ──
# A delegated run records `## Chunk Progress` per chunk; an inline run is FORBIDDEN to chunk, so
# `## Step Progress` is the only state that outlives a dead session. Three things must hold or the
# marker is worse than useless: §3.3 writes it, §1.2 reads it, and §1.2 re-runs the last ticked
# `exit:` before skipping past it — a marker trusted blindly will skip work whose code was reverted.
# The `- [x]`-only rule is the fourth: a `- [ ]` in the marker would trip the Phase 6.0 done-gate.
if [ -f "$CMDS/ow-implement.md" ]; then
  _sp_bad=""
  # writer + reader: the string must appear at least twice (§3.3 defines it, §1.2 consumes it)
  [ "$(grep -c 'Step Progress' "$CMDS/ow-implement.md")" -ge 2 ] \
    || _sp_bad="$_sp_bad Step-Progress(writer-or-reader-missing)"
  # §1.2 specifically — the resume gate must name the marker and re-verify its exit:
  _sec12=$(sed -n '/^### 1\.2 /,/^## Phase 2 /p' "$CMDS/ow-implement.md")
  printf '%s\n' "$_sec12" | grep -c 'Step Progress' >/dev/null || _sp_bad="$_sp_bad 1.2(does-not-read-marker)"
  printf '%s\n' "$_sec12" | grep -c 'exit:' >/dev/null || _sp_bad="$_sp_bad 1.2(no-exit-reverify)"
  # the open-checkbox guard, worded identically in both marker specs
  for _sp_f in "$CMDS/ow-implement.md" "$FRAG/delegation.md"; do
    [ -f "$_sp_f" ] || continue
    grep -Fq 'Write `- [x]` **only**' "$_sp_f" \
      || _sp_bad="$_sp_bad $(basename "$_sp_f")(no-[x]-only-rule)"
  done
  # /ow-split Phase 5.5 regenerates sub-plans in place. /ow-implement goes approved → done and never
  # stamps in-progress, so a sub-plan whose run died mid-way sits at `approved` with real work in the
  # tree — a re-run that rewrites anything-not-done would destroy it AND its resume marker. Gated on
  # ow-split.md, like check 9: a project that never adopted /ow-split has nothing to regenerate.
  if [ -f "$CMDS/ow-split.md" ]; then
    grep -q 'Step Progress' "$CMDS/ow-split.md" \
      || _sp_bad="$_sp_bad ow-split.md(5.5-may-overwrite-a-resuming-sub-plan)"
  fi
  [ -z "$_sp_bad" ] && okk "check 11: inline resume marker written (3.3) + verified on resume (1.2)" \
    || fail "check 11: resume-marker contract broken:$_sp_bad"
fi

# ── check 12: no spec cites an authority that does not exist (#36) ───────────
# A spec that says "required per CLAUDE.md test mandate" or "OW §3.4" points the reader — human or
# agent — at a rule they cannot open. The rule then has no home: nobody can change it, nobody can
# check it, and every verb drifts to its own reading of it. Cross-verb rules live in a `_shared/`
# fragment that check 7 already proves resolves; this check makes the ONLY way to cite one be that
# resolvable pointer. `.claude/agents` is scanned too — an agent prompt is executable text as much
# as a spec is.
# 🔴 Same ownership contract as check 4: a project's OWN agent is a note, never a failure — an
# install must not abort over a file obsidian-workflow never wrote. Ownership is proven by content.
_auth_hits=""; _auth_notes=""
for _af in "$CMDS"/*.md "$FRAG"/*.md "$AGENTS"/*.md; do
  [ -f "$_af" ] || continue
  # `OW §<n>` / `OW Standard §…` — the retired standard document; nothing resolves it any more
  # `<doc> mandate` where <doc> is CLAUDE.md/AGENTS.md — those files carry no numbered mandate
  _h=$(grep -nE 'OW (Standard )?§|(CLAUDE|AGENTS)\.md[^.]{0,30}mandate' "$_af" 2>/dev/null | head -1)
  [ -n "$_h" ] || continue
  case "$_af" in
    "$AGENTS"/*) _agent_is_ow_owned "$_af" \
        || { _auth_notes="$_auth_notes $(basename "$_af")"; continue; } ;;
  esac
  _auth_hits="$_auth_hits
    $(basename "$_af"): $_h"
done
[ -n "$_auth_notes" ] && note "note: project-owned agent cites an unresolvable authority (not a failure):$_auth_notes"
if [ -z "$_auth_hits" ]; then
  okk "check 12: no spec/agent cites a non-existent authority (OW §… / CLAUDE.md mandate)"
else
  fail "check 12: citation with no resolvable source — put the rule in a _shared/ fragment and point at it:$_auth_hits"
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "conformance-lint: PASS"; exit 0; else echo "conformance-lint: FAIL" >&2; exit 1; fi
