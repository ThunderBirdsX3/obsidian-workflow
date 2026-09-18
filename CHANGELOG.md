# CHANGELOG — obsidian-workflow

Format: [Keep a Changelog](https://keepachangelog.com). Versions: SemVer.
Version marker: `ow.version` in `.ow.yml`.

## [1.4.1] — 2026-09-18

### Changed — CLAUDE.md / AGENTS.md gain a UI/design-system entry rule, and CLAUDE.md moves to English

`70-Reference/DesignSystem/` (tokens, components, patterns, a11y) was only enforced as a hard
gate inside `/ow-implement` Phase 4. A UI request made directly in chat, without going through
that command, had no path to the same rules.

- `CLAUDE.md` / `AGENTS.md` — the Vault-first rule now says: for UI/web work, even asked for
  directly in chat, read `DS-Tokens.md`, `DS-Components.md`, `DS-Patterns.md`,
  `DS-Accessibility.md` first when `70-Reference/DesignSystem/` exists; a missing component
  routes the user to `/ow-design component <name>` instead of being guessed; no DS directory at
  all ⇒ skip silently, do not suggest creating one.
- `CLAUDE.md`'s shipped block (between the `OW START/END: workflow` markers) is now written in
  English, matching `AGENTS.md` — both are core template content injected into every consumer
  project regardless of that project's `project.language`, so hardcoding Thai prose into the
  template no longer ships a Thai-only file to non-Thai projects. `project.language` still
  governs the language Claude actually chats in; this only changes the language the instruction
  file itself is written in.
- `scripts/test.sh` — two assertions pinned to the old Thai literals (`หัวใจ 3 ข้อ`, `คำสั่งทั้งหมด
  ($n ตัว)`) now check the equivalent English text.

## [1.4.0] — 2026-09-16

### Added — a test-credentials protocol so a test user is never invented

`test_credentials` in `.ow.yml` (`env_file`, `example_file`, `roles`, `redact`) was resolved by
`ow-paths.sh` into `$TEST_ENV_FILE` / `$TEST_CREDENTIALS_JSON` / `$CRED_REDACT`, but no command
spec ever read those vars — asked to fill `.env.test`, the AI had no protocol and no ban on
guessing a username/password for it.

- `_shared/test-credentials.md` (new fragment) — the schema, deriving `$EXAMPLE_FILE`/`$ROLES`
  from `$TEST_CREDENTIALS_JSON`, and the rule: a role with no value is asked of the user, never
  invented.
- `/ow-init` Phase 6.2/6.3 — adds `$TEST_ENV_FILE` to `.gitignore`, scaffolds
  `$EXAMPLE_FILE` (blank values) from `roles[]`.
- `/ow-test` Phase 2 — a missing test-user credential (vs. a server secret) points at the
  fragment instead of a generic blocker.
- `/ow-secure` Phase 6 — `$TEST_ENV_FILE` committed to git is flagged at the same severity as a
  committed `.env.production`.

## [1.3.1] — 2026-09-15

### Fixed — project rules for multi-area commands load again

- `ow-paths.sh --rules` accepts a comma-separated area list. `/ow-fix` asks for
  `--rules coding,testing`, which returned no files and exited 0, so its project rules were never
  read. Each rule file prints once even when it matches several areas.
- `--rules` resolves under `rules.dir` from `.ow.yml` (default `.ow/rules`), like
  `--rules-expected` and `--rules-validate`.
- `.ow/rules/README.md` no longer claims the resolver expands vault links inside a rule file;
  it does not.

### Changed — the AI entry files say where a rule goes

- `CLAUDE.md` and `AGENTS.md` point to `.ow/rules/<area>.md` with front-matter
  `applies_to: [<area>]`, and to `.ow/rules/README.md` for the full format. A rule file with
  neither a matching name nor `applies_to` is never loaded.

## [1.3.0] — 2026-09-14

### Added — an SRS can split into a hub + one file per module

A project-wide SRS grows with every functional area, and `/ow-plan` loads it whole inside a
40,000-token vault budget even when the task touches one area. A small SRS stays one file.

- `_shared/srs-layout.md` (new fragment) — the layout contract: `single` (one `SRS-<project>.md`)
  or `split` (hub `SRS-<project>.md` + `SRS-<project>-<module>.md`). Split when the FRs cover
  ≥ 2 areas **and** the SRS passes ~10,000 tokens. The hub keeps overview / NFR / data model /
  integrations and a `## 3. Modules` table; each module owns its FRs inside an FR range the hub
  assigns, so FR IDs stay unique project-wide. Ships a duplicate-FR-id check.
- `templates/srs-module.md` (new) · `templates/srs.md` gains `srs_layout:` + `modules:` ·
  `feature.md` / `plan.md` link the module of a split SRS.
- Writers: `/ow-new` 1.3, `/ow-doc` (new type `SRS-module`), `/ow-reverse-engineer` (new
  Phase 4.5 — one draft FR per endpoint, grouped by feature cluster; acceptance and NFRs left
  TODO, never inferred from code; an existing SRS is extended, never overwritten or split unasked).
- Readers: `/ow-plan` 1.2–1.3 reads the hub + only the modules the task touches; `/ow-clarify`
  scans a module with its hub sections and writes each answer to the file holding the ambiguous
  text; `/ow-verify` Phase 4 warns on a duplicate FR id, an FR outside its module range, an FR
  in the hub, or a broken hub ↔ module link.
- `docs` agent knows the `SRS-<slug>-<module>` name and defers SRS splitting to the fragment.

## [1.2.0] — 2026-09-14

### Removed — per-machine config (`.ow.local.yml`) and personal overrides (BREAKING)

Config is `.ow.yml` only. Nothing reads `.ow.local.yml` any more.

- `.ow.local.yml.example` deleted; `upgrade` retires it on consumers (backed up,
  `--rollback` restores it). A user's own `.ow.local.yml` is left in place — `upgrade`
  and `ow doctor` warn that it is not read, so any value still in it can be moved into `.ow.yml`.
- External vault: set `vault_path` in `.ow.yml` to the absolute path (installer option D
  writes it there).
- Template chain is 2-tier: `templates/` → `.ow/templates/`. `.ow/local/templates/` and
  `.ow/local/rules/` are no longer looked up. Agent/command model overrides and
  `submodules` are read from `.ow.yml` only.
- Resolver output drops `TEMPLATES_LOCAL`, `EXTERNAL_VAULT`, `SECRETS_FILE` (and the JSON
  `vault.external`, `paths.secrets_file`, `templates.local` keys).
- `ow init --local` and `merge_local_config` removed. `upgrade` protects the
  `test_credentials.env_file` path instead of `paths.secrets_file`.
- `.ow/local/` stays gitignored as per-machine runtime state (`paths.env`, `adopt.marker`).

## [1.1.1] — 2026-09-11

### Fixed — a phased plan is read one phase at a time, and sized that way

`/ow-split` kept each unit in its own file, so an executor opened only what it
needed. Folding phases into one plan file lost that: `/ow-implement --phase P2`
read every sibling phase's section too, and `/ow-plan` 2.5.2 charged a flat
25,000 for "plan + prompt + rules + agent" — a constant that does not grow with
the phase count, so an 8-phase plan under-priced its own read set by ~20k tokens.

- `_shared/phases.md` §1.5 — read the plan **selectively**: `grep -n` the section
  boundaries, then two `Read`s with `offset`/`limit` (the shared header, then this
  phase's section). Reading a sibling phase "for context" is forbidden — a value
  needed across phases belongs in `## Shared Contract`, which the header already
  carries. The whole file is still read for the last phase's 6.0 gate and `/ow-verify`.
- `/ow-plan` 2.5.2 — the per-phase estimate now counts that slice, not the whole
  file, and `SESSION_FIXED` (20,000) covers only what every run pays regardless of
  the plan. After Phase 3 writes the file, the real slice sizes are measured and the
  `est tokens` column is corrected.
- `## Shared Contract` is unchanged and stays cheap (~1 line per shared value, and
  the section is omitted entirely when phases share nothing).

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
