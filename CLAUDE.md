<!--
  obsidian-workflow — CLAUDE.md

  The block between the OW markers below is the SAME block that
  install/upgrade inject into a host project (scripts/ow-claude-md.sh is the
  single source of truth for the merge). Everything a consumer project needs
  belongs INSIDE it.

  Everything OUTSIDE the markers is this source repo's own dev prose and never
  reaches a host project; in a host project that space belongs to the host.
-->

<!-- OW START: workflow -->
# CLAUDE.md — obsidian-workflow

This project uses **obsidian-workflow** — AI + Obsidian docs-driven development, following spec-kit philosophy

## The three core rules

1. **Vault-first** — read the docs in `docs/` relevant to the task before asking questions or writing code (only what's relevant, not the whole vault)
   - UI/web work, even asked for directly in chat without going through `/ow-implement` — if `70-Reference/DesignSystem/` exists, always read `DS-Tokens.md`, `DS-Components.md`, `DS-Patterns.md`, `DS-Accessibility.md` before writing code. A needed component missing from the DS ⇒ tell the user to run `/ow-design component <name>` first, never guess it. `70-Reference/DesignSystem/` absent (no DS set up yet) ⇒ skip this, proceed as normal — do not suggest creating a DS first.
2. **Plan and implement are separate** — `/ow-plan` produces a plan, never touches code · **`/ow-implement` is the only command that edits code** · `/ow-fix` diagnoses + writes a fix-log, then asks before acting
3. **Log everything** — every plan/fix leaves a log in the vault stating what actually ran and what it produced

## All commands (20)

Not sure which one → `/ow-help` · the spec for each verb lives at `.ow/commands/<verb>.md` (sub-modes live in `_shared/`, read when that mode fires) · usage docs at `usage/`

```
Setup:         /ow-init  /ow-sync  /ow-agent
Spec-driven:   /ow-new  /ow-clarify  /ow-plan  /ow-checklist  /ow-implement  /ow-fix
GitHub:        /ow-triage-issues  /ow-fix-issue
Docs + tests:  /ow-doc  /ow-test  /ow-design
Reverse:       /ow-reverse-engineer   ← extract a spec from existing code/db
Delivery:      /ow-secure  /ow-verify  /ow-git  /ow-handoff
Help:          /ow-help
```

## Talking to the user

Language follows `project.language` (`$PROJECT_LANG`, default `th`) — write so someone who is not in the code understands it. Use jargon only where it cannot be avoided (gloss it in brackets the first time).

**Answers / summaries** — ≤7 bullets · one line each, never nested · result first, reasoning after and only where needed: what was done · evidence actually run · risks/open items (only when they exist)
- Never: preamble · restating the user's question · narrating what was not done · a table (unless it really compares 3+ things)
- Go longer only when the user asks for detail, or test/error output must be quoted verbatim

**Questions** — ask only what changes the work if answered differently; decide the rest yourself and say what you decided
- One question at a time (unless the command's own spec says to batch) · ≤2 lines · at most 4 options each with a one-phrase consequence
- Always carry a **Recommended: <option>** plus a one-line reason, so "go with that" ends it

**Absolutely never:** claim a test passed without running it · invent a commit hash / URL / token count · modify a shared repo or production without confirming scope — not verified yet? write `pending verification`

## Vault (`docs/`)

`00-Index` MOC + IMPLEMENTATION-STATUS · `10-PRD` · `20-Features` FEAT-* · `30-Roles` · `40-Functions` FN-* · `50-Phases` PHASE-* · `60-Flows` · `70-Reference` ADR / TechStack / AuthorizationMatrix · `80-ImplementPlan` `YYYY-MM-DD-HHmm-<slug>.md` · `85-FixLog` `YYYY-MM-DD-HHMM-<slug>.md` · `90-TestPlan` · `95-Handoff` HOR-*

🔴 **A vault doc states the "present" only** — never write "was X, now Y" / a `## Changelog` in a spec doc · before/after belongs only in `80-ImplementPlan`, `85-FixLog`, `90-TestPlan`, `95-Handoff` (full contract: `.ow/commands/_shared/vault-doc-style.md` · gate: `/ow-secure` Phase 2.6)

## Config + snapshot

- `.ow.yml` at root — comments in the file already explain every key, read the real file · 🔴 **never `yq -i` this file** (strips comments) — edit surgically only
- `subagents` — 4 ship by default: `docs` `verifier` `security` `gh-issue` · the rest are **names, not files**, until `/ow-agent create <name>` writes a body matching the stack (`/ow-agent suggest` tells you which ones you should have) · enabled but no file = install/upgrade reports it, never fills it in silently
- `.ow/` = the snapshot (`commands/` `templates/`), updated by `/ow-sync` · `.ow/rules/` belongs to this project — sync never touches it — write new rules at `.ow/rules/<area>.md` + frontmatter `applies_to: [<area>]` (full format: `.ow/rules/README.md`) · root `templates/` overrides `.ow/templates/`
- `scripts/` + `bin/` = mixed-ownership — upgrade refreshes owned files one by one per manifest (`ow-owned.sh`), never `rm -rf` the whole dir · per-script detail lives in that script's own header comment · hard prerequisite: `yq` must be installed

## Language

| What | Language |
|---|---|
| Chat / reports / questions to the user | `project.language` (`$PROJECT_LANG`) |
| Files under `vault_path`, every folder | `project.vault_language` — unset ⇒ falls back to `project.language` (`$VAULT_LANG`) |
| Code comments · frontmatter · commit messages · `.ow/commands` · `.claude/agents` | English |
<!-- OW END: workflow -->

## Design spec for obsidian-workflow's own development (`.superpowers/`)

The `superpowers:brainstorming` skill writes design specs to `.superpowers/specs/` — **gitignored**

`docs/` in this repo is the **sample vault** (`docs/obsidian-vault/`) that a greenfield install copies into a new project — never mix obsidian-workflow's own dev specs into it
