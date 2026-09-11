# CHANGELOG — obsidian-workflow

Format: [Keep a Changelog](https://keepachangelog.com). Versions: SemVer.
Version marker: `ow.version` in `.ow.yml`.

## [1.1.0] — 2026-09-11

### Changed — `/ow-split` retired; phases live inside the plan (BREAKING)

- `/ow-plan` Phase 2.5 breaks a large task into **phases** written into the plan itself:
  a `## Phases` table (id · name · area · depends_on · est tokens · status), a `## Shared
  Contract` table for values crossing phases, and a self-contained `### Phase Pn` section
  carrying its own `context_refs` / Affected Files / Steps / Test Plan / Success Criteria.
  Knobs: `--phase-budget` (default 120000), `--max-phases` (default 8), `--no-phases`.
- `/ow-implement <plan> --phase P2` runs exactly one phase; no flag runs them all in order.
  The entry gate refuses a phase whose `depends_on` is unfinished or whose consumed contract
  row is still `state: planned`; the done-gate scopes to that phase's section, and the plan
  flips `done` only once every phase row is `done`. Detail: `_shared/phases.md` (new fragment).
- `/ow-plan --revise` now carries the phase-protection rules: only `status: planning` phases
  are rewritten, never one named by a `## Step Progress` / `## Chunk Progress` resume marker.
- `/ow-verify` rollup mode reads the `## Phases` table instead of grepping sub-plan files.
- `context_closed: true` is now emitted by `/ow-plan` (it was `/ow-split`); conformance-lint
  check 9 and check 11 follow the emitter. Command count: 21 → 20.
- **Migrating:** an in-flight `/ow-split` parent plus its sub-plan files keep working as
  ordinary plans — finish them with `/ow-implement <sub-plan>` as before. New work gets
  phases from `/ow-plan`. Consumer projects drop the `ow-split` shim/skill on the next sync
  (`prune_orphan_shims` / `prune_orphan_skills` already handle a removed command).

## [1.0.0] — 2026-09-10

Initial public release of **obsidian-workflow** — an AI + Obsidian docs-driven
development workflow for Claude Code, built on the spec-kit philosophy.

- 21 slash commands (`/ow-*`): setup (`ow-init` `ow-sync` `ow-agent`), spec-driven
  (`ow-new` `ow-clarify` `ow-plan` `ow-split` `ow-checklist` `ow-implement` `ow-fix`),
  GitHub (`ow-triage-issues` `ow-fix-issue`), docs + test (`ow-doc` `ow-test` `ow-design`),
  `ow-reverse-engineer`, delivery (`ow-secure` `ow-verify` `ow-git` `ow-handoff`), `ow-help`.
- Vault-first: the AI reads the relevant `docs/` before answering or writing code.
- Plan and implement are separate — only `/ow-implement` edits code.
- Every plan / fix carries a log of what actually ran and what it produced; the vault
  holds text only, command output is quoted into the doc.
- 4 always-on subagents (`docs` `verifier` `security` `gh-issue`); specialized agents are
  written per project by `/ow-agent create`.
- 7 AI front-end adapters (Claude Code, Codex, Gemini, GPT, GLM, Cline, Kimi) sharing one
  command spec set under `.ow/commands/`.
- Config-driven path resolver (`scripts/ow-paths.sh`), conformance lint
  (`scripts/conformance-lint.sh`), smoke test suite (`scripts/test.sh`), and in-place
  self-upgrade (`scripts/upgrade.sh`).

### Migrating from an earlier install

Projects on a pre-v1.0.0 layout re-adopt with a clean `ow init` from a fresh checkout —
there is no automatic in-place migration across the rename.
