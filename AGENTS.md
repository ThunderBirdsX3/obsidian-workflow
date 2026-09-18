# AGENTS.md — obsidian-workflow

Shared instruction file for AI coding agents that read `AGENTS.md` at the repository
root: **Cline**, **Kimi Code CLI**, **OpenAI Codex CLI**, and any future tool adopting
the same convention. Claude Code reads `CLAUDE.md` instead; both describe the same
workflow.

This project uses **obsidian-workflow** — AI + Obsidian docs-driven development following
spec-kit philosophy.

## Commands

Every command verb has an authoritative spec at `.ow/commands/<verb>.md`. A
project may override any of them with `commands/<verb>.md` at the repo root — **the
override always wins**.

Detail that only one mode or one phase needs (worktree build, worktree merge + its cleanup
gate, delegation, the build/test run, fix-log closure, the fix flow for one issue, the
`--ready-for-test` handoff) and every contract shared by two or more verbs (coding
discipline, the conditional vault-read table) live in `.ow/commands/_shared/<file>.md`. A spec points at
the fragment at the exact phase that needs it and the fragment is **read on demand** — never
pasted in — so a run that never reaches that phase never loads it. A fragment shared by two
specs is the single source of truth for what it covers; neither caller restates its rules.

They are also installed as skills at `.agents/skills/<verb>/SKILL.md`, generated from
those specs. Invocation differs per tool:

| Tool | How to invoke |
|---|---|
| Cline | `/ow-plan` (bare verb) |
| Kimi Code | `/skill:ow-plan` |
| Codex CLI | `codex run 'ow-plan'`, or just name the verb |

Do not paraphrase a spec from memory. Read the file and follow its Phase structure
start to finish. Not sure which verb applies? Run `ow-help`.

## The four non-negotiables

1. **Vault-first** — read the docs that relate to the task before asking questions or
   writing code. Start at `<vault>/00-Index/IMPLEMENTATION-STATUS.md`. Read what the
   task needs, not the whole vault.
   - UI/web work, even asked for directly in chat without going through `ow-implement` —
     if `70-Reference/DesignSystem/` exists, always read `DS-Tokens.md`, `DS-Components.md`,
     `DS-Patterns.md`, `DS-Accessibility.md` before writing code. A needed component missing
     from the DS ⇒ tell the user to run `ow-design component <name>` first; never guess it.
     `70-Reference/DesignSystem/` absent (no DS set up yet) ⇒ skip this, proceed as normal —
     do not suggest creating a DS first.
2. **Plan and implement are separate** — `ow-plan` and `ow-fix` produce documents and
   must not touch code. `ow-implement` is the only verb that modifies code.
3. **Log everything** — every plan and fix leaves a log in the vault stating what was
   actually run and what it produced.
4. **A vault doc states the present** — every note outside `80-ImplementPlan`,
   `85-FixLog`, `90-TestPlan` and `95-Handoff` describes the project as it is now.
   Never write "was X, now Y" or a `## Changelog` section into a spec doc: overwrite the
   old value, and leave the before/after in the plan or fix-log of that run. Contract:
   `.ow/commands/_shared/vault-doc-style.md`.

## Result honesty — absolute

- Never claim a test passed without running it.
- Never invent a commit hash, URL, token count, or file content you have not read.
- Nothing verified yet? Write `pending verification`.
- Never modify a shared repo or production without confirming scope first.
- Never put a secret or credential into vault docs.

## Talking to the user

Write so someone who is not in the code understands it. Use jargon only where it cannot be
avoided, and gloss it in brackets the first time.

**Answers / end-of-command summaries** — max 7 bullets, one line each, never nested. Result
first, reasoning after and only where it is needed: what changed (and where), the checks
actually run, risks/open/next only when they exist. No fixed multi-section template.

- Never: preamble, restating the user's question, narrating what you did not do, or a table
  unless it really compares 3+ things.
- Go longer only when the user asks for detail, or when test/error output must be quoted verbatim.

**Questions** — ask only what changes the work if answered differently; decide the rest
yourself and say what you decided.

- One question at a time (unless the command's own spec says to batch), max 2 lines, at most
  4 options each with a one-phrase consequence.
- Always carry a **Recommended: <option>** plus a one-line reason, so "go with that" ends it.

## Language

| What | Language |
|---|---|
| Chat, reports, end-of-command summaries, questions to the user | `project.language` |
| Documents written under `vault_path` | `project.vault_language` (falls back to `project.language`) |
| Code comments, frontmatter keys, file paths, commit messages | English |

One command commonly does both: `ow-plan` writes the plan in the vault language, then
reports in the project language.

## Coding discipline

State the success criteria before starting. Make the minimum correct change. Every
changed line must trace back to the request, the bug, or a stated criterion. No
speculative abstraction, config, dependency, or feature. No unrelated refactoring or
formatting churn. A reproducing test goes RED before a bug fix. Verification must map
back to the success criteria.

Full contract — including the untestable list and the audit run before marking anything
done — is `.ow/commands/_shared/coding-discipline.md`; read it before editing code,
and let the project's own rule file for area `coding` under `.ow/rules/` override it.

## Config

Read `.ow.yml` at the start of every session: `mode`, `vault_path` (default
`docs/obsidian-vault`), `project.language` / `project.vault_language`, `subagents.*`,
`submodules`, `ow.version`.

Project rules live in `.ow/rules/<area>.md` with front-matter `applies_to: [<area>]`
(format: `.ow/rules/README.md`). Write new rules there, never into `.ow/commands/`.

## Personas

These tools have no user-definable subagents, so use persona switching: when the work
enters a domain, say which persona you are acting as and follow that file's scope and
gates. The persona definitions live in `.claude/agents/*.md` and are readable by any
tool regardless of which assistant is driving:

Always present: `docs.md` (vault) · `verifier.md` (test/lint/build) · `security.md`
(secret/PII) · `gh-issue.md` (read-only issue reading, for `ow-triage-issues` /
`ow-fix-issue`).

Anything else — `backend.md`, `frontend.md`, `mobile.md`, `design.md`, `test-runner.md` —
exists only if this project ran `/ow-agent create <name>`; obsidian-workflow ships no body for it.
The file is absent ⇒ there is no persona to switch into: do the work yourself under the
command spec's own gates (`.ow/commands/<verb>.md`, plus `_shared/design-process.md`
for design-system work), which carry the same rules either way.

## Not supported outside Claude Code

`.ow.yml` can pin an AI model per command (`commands.overrides.<verb>`) and per
subagent (`subagents.<name>.model`). Both are Claude Code features. Cline, Kimi Code
and Codex ignore them — the commands still work, they just run on whatever model the
session is already using.
