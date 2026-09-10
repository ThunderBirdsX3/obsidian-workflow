#!/usr/bin/env bash
# obsidian-workflow — command-shim EMITTERS for every AI front-end kind (single source)
# ─────────────────────────────────────────────────────────────────────────────
# One verb spec (.ow/commands/<verb>.md, or the project's commands/<verb>.md
# override) is projected into whatever file format each front-end kind actually
# reads. All emitters share ONE override resolver, so no front-end can be blind to
# the project override layer — codex/gpt/glm/gemini used to ship STATIC routers
# hardcoded to .ow/commands/ and silently ignored commands/<verb>.md.
#
# Kinds (see scripts/ow-frontends.sh):
#   commands  → .claude/commands/<verb>.md               generate_shims
#   skills    → .agents/skills/<verb>/SKILL.md           generate_skills
#   router    → <folder>/prompts/router.md               generate_router
#
# Portable: bash 3.2 + BSD userland.

# ─── shared override resolver ─────────────────────────────────────────────────
# ow_ref <verb> <target_root> → repo-relative path of the spec that WINS.
# Project override layer (commands/<verb>.md) beats the packaged default.
ow_ref() {
  local verb="$1" root="$2"
  if [ -f "$root/commands/$verb.md" ]; then
    printf 'commands/%s.md\n' "$verb"
  else
    printf '.ow/commands/%s.md\n' "$verb"
  fi
}

# ow_verbs <verb_specs_dir>
# The verbs every emitter covers: the packaged specs, sorted.
#
# Deliberately NOT including project-only commands (a commands/<verb>.md with no
# packaged counterpart). generate_shims has always emitted for packaged verbs only,
# and all three emitters must agree — a verb that appears in the router but has no
# skill/shim would be a phantom. prune_orphan_* still PRESERVES a project-backed
# file if one exists, so nothing a project already has is lost.
ow_verbs() {
  local specs="$1" vf
  for vf in "$specs"/*.md; do [ -e "$vf" ] && basename "$vf" .md; done 2>/dev/null | sort
}

# ─── kind: commands (Claude Code) ─────────────────────────────────────────────
# Write one resolved @-include shim per verb into <target_root>/.claude/commands/.
# Exactly ONE @-target per shim (never dual-@, which would paste both bodies).
generate_shims() {
  local specs="$1" root="$2" prefix="${3:-ow}"   # prefix reserved for P2 filename rename
  local dst="$root/.claude/commands"
  mkdir -p "$dst"
  local vf verb ref model
  for vf in "$specs"/*.md; do
    [ -e "$vf" ] || continue
    verb="$(basename "$vf" .md)"
    ref="$(ow_ref "$verb" "$root")"
    # resolve this command's AI model from config (inherit ⇒ no pin). Fail-safe: if the
    # resolver/yq/config is unavailable, omit the line so the command follows the session.
    model=""
    if [ -f "$root/scripts/ow-paths.sh" ] && command -v yq >/dev/null 2>&1; then
      model="$(OW_ROOT="$root" bash "$root/scripts/ow-paths.sh" --command-model "$verb" 2>/dev/null || true)"
    fi
    # filename parity with the verb spec (command_prefix rename is deferred → P2)
    {
      printf -- '---\n'
      printf 'description: obsidian-workflow /%s — see %s\n' "$verb" "$ref"
      [ -n "$model" ] && [ "$model" != inherit ] && printf 'model: %s\n' "$model"
      printf -- '---\n\n'
      printf '@%s\n' "$ref"
    } > "$dst/$verb.md"
  done
  prune_orphan_shims "$specs" "$root"
}

# _is_generated_shim <file>
# True only for a shim THIS script wrote: the `description: obsidian-workflow /<verb>` frontmatter
# line plus the single @-include pointing at a commands/ spec. A hand-written command
# never carries both, so ownership is detected from content — no manifest to maintain.
_is_generated_shim() {
  head -6 "$1" | grep -q '^description: obsidian-workflow /' \
    && grep -q '^@\(\.ow/\)\?commands/' "$1"
}

# prune_orphan_shims <verb_specs_dir> <target_root>
# Delete generated shims for verbs that no longer resolve — the command was removed
# upstream and no project override supplies it. Without this a removed command keeps
# tab-completing and its shim @-includes a file that is gone.
# NEVER touches: a verb that still has a spec, a verb backed by commands/<verb>.md,
# or any file lacking the generated-shim signature (user-owned).
prune_orphan_shims() {
  local specs="$1" root="$2"
  local dst="$root/.claude/commands"
  [ -d "$dst" ] || return 0
  local sf verb
  for sf in "$dst"/*.md; do
    [ -e "$sf" ] || continue
    verb="$(basename "$sf" .md)"
    [ -f "$specs/$verb.md" ] && continue          # still shipped
    [ -f "$root/commands/$verb.md" ] && continue  # project override still resolves it
    if _is_generated_shim "$sf"; then
      rm -f "$sf" && printf '  pruned removed command: .claude/commands/%s.md\n' "$verb"
    else
      printf '  kept (user-owned, no spec): .claude/commands/%s.md\n' "$verb"
    fi
  done
}

# ─── kind: skills (Cline · Kimi Code · Codex CLI) ─────────────────────────────
# Emit .agents/skills/<verb>/SKILL.md — the ONE neutral layout all three read:
#   Cline   resolveSkillsConfigSearchPaths() includes <ws>/.agents/skills
#   Kimi    project generic skill group includes .agents/skills (always read)
#   Codex   picks the same tree up alongside the root AGENTS.md
#
# Frontmatter must satisfy the INTERSECTION of both validators:
#   - directory name matches [a-z0-9-]{1,64}      (Kimi's validator)
#   - `name:` EXACTLY equals the directory name   (Cline rejects a mismatch)
#   - `description:` present, <= 1024 chars       (Cline)
#   - body non-empty                              (Cline SDK throws otherwise)
# Bodies are thin delegates: the agent reads the resolved spec and follows it, so
# these files never drift from .ow/commands/ and keep the override layer.
#
# NOT emitted here: model pins. `commands.overrides.<verb>` is a Claude Code concept;
# neither Cline nor Kimi has a per-command model. Silently ignored by design.
generate_skills() {
  local specs="$1" root="$2"
  local dst="$root/.agents/skills"
  mkdir -p "$dst"
  local vf verb ref desc
  for vf in "$specs"/*.md; do
    [ -e "$vf" ] || continue
    verb="$(basename "$vf" .md)"
    case "$verb" in
      *[!a-z0-9-]*|"")
        printf '  skipped (name not [a-z0-9-]): %s\n' "$verb"; continue ;;
    esac
    [ ${#verb} -le 64 ] || { printf '  skipped (name > 64 chars): %s\n' "$verb"; continue; }
    ref="$(ow_ref "$verb" "$root")"
    desc="obsidian-workflow /$verb — read $ref and follow its Phase structure."
    mkdir -p "$dst/$verb"
    {
      printf -- '---\n'
      printf 'name: %s\n' "$verb"
      printf 'description: %s\n' "$desc"
      printf -- '---\n\n'
      printf '# %s\n\n' "$verb"
      printf 'Read `%s` in this repository and follow it exactly, start to finish.\n\n' "$ref"
      printf 'That file is the authoritative spec for this command — phases, gates and\n'
      printf 'output format all come from it. Do not summarise or improvise around it.\n'
    } > "$dst/$verb/SKILL.md"
  done
  prune_orphan_skills "$specs" "$root"
}

# _is_generated_skill <file>
# Ownership by content signature, same contract as _is_generated_shim: a hand-written
# skill never carries both the obsidian-workflow description line and the delegate sentence.
_is_generated_skill() {
  grep -q '^description: obsidian-workflow /' "$1" \
    && grep -q 'follow it exactly, start to finish' "$1"
}

# prune_orphan_skills <verb_specs_dir> <target_root>
# Mirror of prune_orphan_shims. Removes a generated skill DIRECTORY only when the
# verb no longer resolves AND the SKILL.md carries our signature — a user's own
# skill under .agents/skills/ is never touched.
prune_orphan_skills() {
  local specs="$1" root="$2"
  local dst="$root/.agents/skills"
  [ -d "$dst" ] || return 0
  local d verb
  for d in "$dst"/*/; do
    [ -d "$d" ] || continue
    verb="$(basename "$d")"
    [ -f "$specs/$verb.md" ] && continue
    [ -f "$root/commands/$verb.md" ] && continue
    if [ -f "$d/SKILL.md" ] && _is_generated_skill "$d/SKILL.md"; then
      rm -rf "$d" && printf '  pruned removed command: .agents/skills/%s/\n' "$verb"
    else
      printf '  kept (user-owned, no spec): .agents/skills/%s/\n' "$verb"
    fi
  done
}

# ─── kind: router (paste-into-web / prompt-file tools) ────────────────────────
# Curated shorthands. Everything else gets the mechanical pair `ow-<verb>` / `<verb>`.
# Kept here rather than in the registry because they describe VERBS, not front-ends.
_router_extra_alias() {
  case "$1" in
    ow-help)              echo "?" ;;
    ow-triage-issues)     echo "triage" ;;
    ow-fix-issue)         echo "fix-from-issue" ;;
    ow-reverse-engineer)  echo "reverse" ;;
    ow-git)               echo "git-sync" ;;
  esac
}

# generate_router <verb_specs_dir> <target_root> <folder> <tool label>
# Rewrite <folder>/prompts/router.md. The verb→spec table is derived, so a project
# override (commands/<verb>.md) now shows up here too instead of being ignored.
# system.md is NOT generated — it is hand-written per tool and ships as a static asset.
generate_router() {
  local specs="$1" root="$2" folder="$3" label="${4:-this assistant}"
  local dst="$root/$folder/prompts"
  mkdir -p "$dst"
  local verb ref short extra row
  {
    printf '# obsidian-workflow verb router (for %s)\n\n' "$label"
    printf 'When user says `ow-<verb>: <task>` or `<verb>: <task>`, read the corresponding spec file and follow its Phase structure.\n\n'
    printf -- '<!-- generated by scripts/ow-shims.sh — edits are overwritten on install/upgrade/sync -->\n\n'
    printf '## Verb → spec mapping\n\n'
    printf '| User input | Spec file to load |\n|---|---|\n'
    while IFS= read -r verb; do
      [ -n "$verb" ] || continue
      ref="$(ow_ref "$verb" "$root")"
      short="${verb#ow-}"
      row="\`$verb\` / \`$short\`"
      extra="$(_router_extra_alias "$verb")"
      [ -n "$extra" ] && row="$row / \`$extra\`"
      printf '| %s | `%s` |\n' "$row" "$ref"
    done <<EOF
$(ow_verbs "$specs")
EOF
    printf '\n## Persona switching\n\n'
    printf 'When working in a particular domain, mention you are acting as the corresponding subagent persona\n'
    printf -- '- but ONLY if that file exists. Always present:\n\n'
    printf -- '- Docs/vault → "Acting as `.claude/agents/docs.md`"\n'
    printf -- '- Verification → "Acting as `.claude/agents/verifier.md`"\n'
    printf -- '- Security → "Acting as `.claude/agents/security.md`"\n'
    printf -- '- GitHub issue reading → "Acting as `.claude/agents/gh-issue.md`" (read-only)\n\n'
    printf 'Present only if this project ran `/ow-agent create <name>` (obsidian-workflow ships no body for these):\n\n'
    printf -- '- Backend work → `.claude/agents/backend.md`\n'
    printf -- '- Frontend work → `.claude/agents/frontend.md` (DS-strict)\n'
    printf -- '- Mobile → `.claude/agents/mobile.md`\n'
    printf -- '- Tests → `.claude/agents/test-runner.md`\n'
    printf -- '- Design system / Figma export → DS-Tokens → `.claude/agents/design.md`\n\n'
    printf 'The file is absent ⇒ there is no persona to switch into: do the work yourself under the\n'
    printf -- 'command spec in `.ow/commands/<verb>.md` (plus `_shared/design-process.md` for\n'
    printf -- 'design-system work). The gates are identical either way — no persona never means no gate.\n\n'
    printf 'Each persona file describes role, scope, gates (§5), and forbidden actions.\n'
  } > "$dst/router.md"
}
