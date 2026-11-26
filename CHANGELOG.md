# CHANGELOG — obsidian-workflow

Format: [Keep a Changelog](https://keepachangelog.com). Versions: SemVer.
Version marker: `ow.version` in `.ow.yml`.

## [2.7.0] — 2026-11-26

Minor. No config change needed.

### Changed — `/ow-git` reaches the commit faster

- `ow-git.md` is 13.7KB instead of 38.7KB. A plain `--plan` / `--fix` / `--message` commit opens no `_shared/` fragment.
- `--bump` detail (unified version, version-file writer, tags) lives in `_shared/git-bump.md` and is read only when the user passes `--bump`.
- The Phase 2.6 vault-ai conflict merge lives in `_shared/git-conflict.md` and is read only when Phase 2.5 leaves a repo at exit 3.
- `_shared/git-sync.md` is reference only: `/ow-git` handles exit 0/3/4/5 inline and opens it only for an unexpected exit code or the conflict-class table.
- Phase 6/7 have one commit + push path each; `--bump` hooks in at two marked points.

### Changed — secret check before commit

- `/ow-git` no longer requires a full `/ow-secure` run before committing. New Phase 4.5 greps the staged diff of every repo for common key patterns (AWS, private key, GitHub, `sk-`, Slack, Google) and stops before the commit on a hit. `/ow-secure` stays the recommended full pre-flight (PII, dependencies).

## [2.6.0] — 2026-11-22

Minor. No config change needed.

### Changed — the plan file is lighter

- The plan no longer has the sections Vault Context Read, Task, Verification, Approvals or Design Additions — removed from `/ow-plan`'s inline template and from the shipped `.ow/templates/plan.md`. The docs read go into `related_docs:`; a doc skipped for the token budget is an `excluded by budget:` line in Doc Gaps Found, and such lines never trigger the docs-fix phase (`/ow-implement` Phase 2).
- Goals are plain bullets. Success Criteria carry `(unit)` / `(integration)` / `(build)` / `(ow-test)`; `(ow-test)` items have no checkbox because `/ow-test` owns them.
- `## Risks` appears only when `risk_level` is medium or high.

### Changed — approve a plan by replying in the `/ow-plan` chat

- `/ow-plan` ends with a summary of at most 10 lines. The user replies `approve` in that chat and `/ow-plan` stamps `status: approved` · `approved_by: user (chat)` · `approved_at`. Setting the frontmatter by hand still works.
- `/ow-plan` never starts `/ow-implement`; the user runs it in a new session.

### Changed — `/ow-implement` starts without asking

- `/ow-implement <plan>` starts at once — typing the plan path is the go-ahead. The "Start now?" question remains only for a `risk_level: high` plan without `--auto`.
- With no `--phase` it runs every phase in order and never asks; over ~120k it only notes it. `--phase <id>` + `/clear` between sessions is advised only when a phase is over `PHASE_BUDGET`.

### Changed — `/ow-implement` done-gate

- The Phase 6.0 open-checkbox gate ignores boxes a human or `/ow-test` owns: old `## Approvals` / `## Goals` boxes, the routing boxes under a fix-log's `## Next`, `(ow-test)` lines and live-E2E lines. Boxes inside callouts (`> - [ ]`) and tables still count.
- The `/ow-auto` item-close commit now stages `<plan>`.
- Closing a fix-log (`_shared/fixlog-close.md` §2) ticks proven boxes, then runs `open_boxes` on the fix-log, and only then sets `status: fixed`. The fix-log template's "Out of scope" line is a plain bullet, not a box.
- The shipped `.ow.yml` pins a model for four commands only — `ow-plan` / `ow-secure` → opus, `ow-implement` / `ow-fix` → sonnet; every other command inherits the session model. An existing project keeps the overrides in its own `.ow.yml`.
- Every timestamp these commands write (`approved_at`, `completed_at`, plan and fix-log file names and `date:`, the Smoke test line) comes from `date '+%Y-%m-%d %H:%M'` run at that moment, never typed from memory.

### Changed — `/ow-test` web checks and plan record

- Web checks run in this order: the project's own test/E2E command → the Playwright MCP's run-code tool (one call per multi-step script; nothing installed) → step-by-step MCP only for what a script cannot judge. `/ow-test` never installs Playwright, a browser or a package.
- `/ow-test <plan>` appends one line under the plan's `## Implementation Result`: `- Smoke test (/ow-test, YYYY-MM-DD HH:mm): PASS <n>/<total> · FAIL <n> · BLOCKED <n> — <target>`. It never closes the plan. `/ow-test <plan>` covers every `(ow-test)` Success Criterion and `→ /ow-test:` bullet in the plan; one that cannot run is reported BLOCKED / NOT_RUN, never dropped.
- `usage/ow-plan.md`, `usage/ow-implement.md`, `usage/ow-test.md`, `usage/ow-design.md`, `usage/README.md`, `README.md` and `/ow-help` updated to match.

## [2.5.0] — 2026-11-16

Minor. No config change needed.

### Changed — `/ow-archive` also archives test plans

- `/ow-archive` used to move only `$PLAN_DIR` and `$FIX_DIR` files. It now also moves `$TEST_DIR` (90-TestPlan) files into `$TEST_DIR/archive/<name>/`, using the same subfolder name as the plans and fix-logs.
- `_README.md` in each of the three folders is skipped — it is folder documentation, not a finished artifact.
- `usage/ow-archive.md` and `usage/README.md` updated to match.

## [2.4.1] — 2026-11-03

Patch. No config change needed.

### Fixed — `/ow-auto` subagents follow the per-command model

- `/ow-auto` runs `/ow-plan` and `/ow-test` in their own subagent, but never passed a `model`, so both ran on the session model (e.g. opus) whatever `commands.overrides.<verb>` said — the shim's `model:` pin only applies when a human types the slash command.
- The spec now resolves the model with `scripts/ow-paths.sh --command-model <verb>` and passes it to the Agent tool: `inherit` ⇒ no pin, `opus|sonnet|haiku` as-is, a full `claude-*` id ⇒ its family word.
- `/ow-implement` and fix rounds still run in the host context, so they stay on the session model.

## [2.4.0] — 2026-10-21

Minor. Behaviour change for new installs only; existing projects are untouched.

### Changed — installer no longer copies the sample vault

- A greenfield install used to copy the Library Book Tracker sample vault (`docs/obsidian-vault/` of this repo) into the new project. That is the toolkit's own demo, not project data, so it no longer ships: greenfield now creates the empty numbered skeleton folders only, same as brownfield.
- `--no-sample` is still accepted so existing scripts keep working, but it is now a no-op.
- Smoke test Section 27 now asserts the installer has no sample-vault copy instead of checking where the copy lands.

## [2.3.0] — 2026-10-21

Minor. No breaking change: upgrade migrates the old layout.

### Changed — agent bodies move to `.ow/subagents/`; `.claude/agents/` becomes symlinks

- The four always-on bodies and every `/ow-agent create` body are real files in `.ow/subagents/` (committed). `.claude/agents/<name>.md` is a relative symlink to it (`ow_link_agents` in `scripts/ow-claude-manifest.sh`), so a clone that ignores `.claude/` loses nothing, and other front-ends read the same bodies (`AGENTS.md` persona map now points at `.ow/subagents/`).
- install / upgrade write the bodies to `.ow/subagents/` for every project (codex-only included) and link them when `claude` is enabled. Upgrade migrates the old layout: an owned real file in `.claude/agents/` (by signature) moves over; a project's own agent stays put; a differing same-name real file is kept with a WARN. `--rollback` covers `.ow/subagents`.
- `/ow-agent` create / enable / disable write `.ow/subagents/` and re-link. `apply_agent_models`, `verify_enabled_agents`, `conformance-lint.sh`, `ow doctor` follow the new path. `.ow/subagents` joins the protected paths (`ow-safe-paths.sh`, `/ow-sync`).
- Name is `subagents`, not `agents`: `.ow/agents/` is the retired specialized-body library (v1.10.0).

### Added — `ow regen` (`scripts/ow-regen.sh`)

- Offline rebuild of the generated front-end files on a fresh clone: reads `ai_agents` from `.ow.yml`, then writes `.claude/commands/` shims + `.claude/agents/` links (claude), `.agents/skills/` (codex / cline / kimi), `<folder>/prompts/router.md` (router front-ends). No network, no version bump, user-owned files kept. Needs `yq`. Listed in `ow-owned.sh`, so upgrade ships it to projects.

## [2.2.0] — 2026-10-17

Minor. No breaking change.

### Changed — `/ow-auto` runs `/ow-plan` and `/ow-test` in their own subagent

- On Claude Code, each item's plan step and test step (plus the test-level fix-log write) run in a `general-purpose`
  subagent, so a plan body or a test log never enters the orchestrator's context. The subagent replies with at most
  5 lines (result, file paths, one line of evidence, `STOPPED:`). The orchestrator checks that the files exist and
  reads only the test report's verdict table. `/ow-implement` and `--from-fix` stay in the orchestrator because they
  dispatch chunks themselves. A host with no Agent tool (Codex) runs these steps inline, as before.

## [2.1.0] — 2026-10-17

Minor. No breaking change.

### Added — external worker out of credits → the host continues, the worker is retried next chunk

- `ow-worker.sh` returns `STATUS: BLOCKED` + `REASON: quota-exhausted` when Codex or Claude reports an exhausted
  balance / usage limit (error records and stderr only, never the model's prose; also when `claude -p` reports it
  with exit 0). Under `--auto` the same chunk (or fix chunk) reruns on the host without consuming a fix attempt or a
  timeout/blocked strike; the next chunk tries the worker again, so restored credits are used at once. Outside
  `--auto` the BLOCKED stands. Spec: `_shared/worker-cli.md` §3.1, `_shared/auto-loop.md`.

### Fixed — `auto.worker_timeout_min: 0` killed the worker immediately

- `0` now means no timeout: the watchdog does not start.

## [2.0.1] — 2026-10-16

Patch. No breaking change.

### Fixed — `/ow-plan` answered in English although `project.language` is `th`

- The Phase 5 STOP message was an English quote the model pasted as-is, and the language rule covered only questions,
  the STOP message and the final summary. Now every chat sentence of the run is `$PROJECT_LANG` (progress notes
  between tool calls included); the quoted STOP text is marked as English source to translate, and the summary's
  `Problem` line is translated, not restated from the plan file. The plan file body stays `$VAULT_LANG`.

### Changed — vault-language gate tolerates verbatim labels

- `ow-verify-vault-lang.sh` (`/ow-secure` Phase 2.5) no longer flags a foreign-language label / term kept verbatim:
  `inline code`, `[[wikilink]]`, or a quoted string of at most 4 words. All other prose must still be `vault_language`.

## [2.0.0] — 2026-10-15

Major version for the new hands-off mode. No breaking change: every command run without the new flags behaves
exactly as in 1.6.2, and an existing `.ow.yml` gains the optional `auto:` block on upgrade.

### Added — `/ow-auto` + `/ow-implement --auto` · external worker `--codex` / `--claude`

- `/ow-auto <PHASE|FEAT|brief>`: clarifies every queued item once (one batch), then runs `/ow-plan` →
  `/ow-implement --auto` → `/ow-test --no-merge` per item with no further questions. State lives in a run-log under
  `80-ImplementPlan`; an item that cannot finish is `stopped` and independent items continue. `--resume <run-log>`.
- `/ow-implement --auto`: runs every plan phase in-session, skips "Start now?", and repairs a failing build/test
  with at most `auto.max_fix_per_phase` fix chunks (each with a short fix-log). Ends with `STOPPED: <reason>`
  instead of asking. Without the flag nothing changes — `BLOCKED → stop, ask a human` holds.
- `--codex` / `--claude`: chunks run in the other vendor's CLI via `scripts/ow-worker.sh` (`codex exec -s
  workspace-write` / `claude -p --permission-mode acceptEdits`); only the HANDOFF returns to the orchestrator, raw
  output goes to `.ow/local/runs/`. Preflight (CLI + login) runs before any write; a failure never falls back silently.
- Auto runs commit locally on their own: every closed plan phase, every passed fix, every closed plan and item
  (`feat(…) (auto · plan/<slug>)` / `fix(…)` / `docs(vault): close …`). Scoped `git add -- <paths>` on the main
  tree, never `add -A`, never push, never `/ow-git` — pushing stays the human's step.
- `.ow.yml` block `auto:` (`max_fix_per_phase`, `worker_timeout_min`, `codex_model`, `claude_model`) — optional.
  `codex_model` takes a full slug or a family alias (`sol`): the alias resolves to the newest listed model in
  `~/.codex/models_cache.json` and falls back to the next one when the account rejects it.
- Not in scope: durable runner outside the session, provider failover, parallel worktrees, token/cost caps
  (reported `unknown`). Verified against `codex-cli 0.155.1`.

## [1.6.2] — 2026-10-15

### Changed — `/ow-implement` spec trimmed (399 → 362 lines)

The always-loaded spec sat one line under its 400-line regrowth guard. No rule was dropped.

- The `--from-fix` severity gate (P2/P3 only, fail-closed) and the fix-log-mode description move
  to `_shared/fixlog-close.md` §0; Phase 1.1 points there — a plan run never reads it.
- Two `Never` lines that restated 3.0 (no chunking/fan-out inline) and 3.1 rule 5 (no
  `git checkout/restore/stash/clean` on files the task does not own) are removed; the body rules stay.
- The 3.0 area table, the `context_closed` read-set note, the Phase 4 design-system gate, the 6.2
  `$IMPL_STATUS` note and the header comment are reworded shorter, same meaning.

## [1.6.1] — 2026-10-15

### Fixed — commands actually read project rules (`.ow/rules/`)

Phase 0 step 2 only echoed `Read rule: <path>`, and nothing later in any spec referred to the
rules again, so the model saw a path and moved on — most visibly in `/ow-secure`.

- `scripts/ow-paths.sh --rules-load <area[,area]>` — prints the full text of every rule
  resolved for the area(s), a `RULE(<area>): (none) — expected file: …` line for an area with no
  rule, and a `STOP-RISK` line when a rule registered in `.ow.yml` `rules.files` is missing.
- All 21 commands: Phase 0 step 2 is that one call, so the rule text lands in context instead
  of a bare path. The final report carries `rules applied: <file, …>` (or `rules applied: none`).
  `/ow-fix-issue` uses `--rules-load coding,testing` in place of its own loop.
- `/ow-secure` — new "Project rules — how they bind each phase": a rule may add Phase 1–2
  patterns/paths/allowlists but never waive the secret/PII scans; it may replace the Phase 4–6
  generic checks; an ambiguous conflict with a BLOCK keeps the BLOCK. The report lists rules
  applied and the phase each changed.
- Tests: rule content + none line + STOP-RISK from `--rules-load`; every command uses it and
  reports rules applied.

## [1.6.0] — 2026-10-07

### Added — `/ow-git` merges vault-doc conflicts on its own: version numbers by rule, prose by intent

A shared branch collided on vault docs constantly, and almost every collision was either a
frontmatter `version:` both people bumped or two edits to different parts of one FN/FEAT/SRS
doc. All of them stopped the sync for a human.

- `scripts/ow-git-sync.sh` — the `vault-meta` class now merges a frontmatter region holding
  `version:` and date fields key by key: dates keep the later one, different versions keep the
  higher one, and the same version on both sides that moved from base (both people bumped) adds
  the deltas (`0.1.0` + `0.1.1` + `0.1.1` ⇒ `0.1.2`; `0.1.3` + `0.2.0` + `0.2.0` ⇒ `0.3.0`). Any
  other key in the region ⇒ human. Table/list regions and frontmatter regions in one file are
  decided per region.
- Rebase/merge run with `merge.conflictStyle=diff3`, so conflict markers carry the common
  ancestor (`|||||||`) — the version rule needs it, and a human resolving by hand sees it too.
- After every successful sync, a vault doc both sides edited **without** a conflict (different
  sections, same `version:` bump) gets the same add-the-deltas rule as its own `docs:` commit,
  reported like any auto-resolve. Identical files on both sides (the same change arriving
  twice) and files with uncommitted edits are left alone.
- New subcommands: `sides <repo> <file>` (commits and plan/fix-log files per side of a
  conflicted file) and `continue <repo>` (resolve safe classes + `rebase --continue` until done,
  reporting every replayed commit's auto-resolves — the old second pass discarded them).
- `/ow-git` Phase 2.6 — vault prose still conflicted after the script: the AI reads base / HEAD /
  incoming plus each side's plan and fix-logs, merges both intents, and stages the file only if
  it passes the gate (no markers, frontmatter parses, every wikilink and heading kept,
  `ow-verify-vault-style.sh` passes). Same spot changed two ways, or no log for a side ⇒ human.
  Vault `.md` only — code and non-vault docs always stop for a human.
- `git.auto_resolve` gains `vault-ai` (default on). A project with its own `auto_resolve` list
  adds it by hand. The app `VERSION` file still keeps the higher semver only.

### Changed — tests follow the v1.5.1 blanket `Bash` permission

- `scripts/test.sh` — asserts the shipped `.claude/settings.json` carries the bare `"Bash"`
  allow, and the legacy-signature merge test checks that the blanket `WebFetch` is retired.
- `scripts/ow-settings-merge.sh` — warns about a bare `"Bash"` only when the consumer added it
  and the shipped set has none, so every upgrade no longer prints a warning about our own grant.

## [1.5.1] — 2026-09-22

### Changed

- `.claude/settings.json` — the shipped allow list grants a bare `"Bash"` instead of the scoped
  `Bash(...)` list.

## [1.5.0] — 2026-09-22

### Added — `/ow-archive`

- New command moves everything under `80-ImplementPlan/` and `85-FixLog/` into an
  `archive/<name>/` subfolder (default: today's date, or `/ow-archive <name>` / `--into <name>`),
  then fixes vault links that pointed at the old path. Content and frontmatter are untouched —
  archiving is a location change, not a status transition.

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
