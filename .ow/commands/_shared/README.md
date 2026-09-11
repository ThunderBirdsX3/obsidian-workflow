# `_shared/` — command fragments

Conditional blocks lifted out of a verb spec so the always-loaded file stays small.

**Contract**

- A fragment is **read on demand**, never `@`-included — the pointer in the verb spec is
  `🔴 Read .ow/commands/_shared/<file>.md` at the exact phase that needs it.
  (`@` would paste the body back into every run and defeat the split.)
- A fragment holds work that is **mode-gated** (worktree mode, delegated mode), pure boilerplate, or a
  **contract shared by ≥2 verbs** (`context-refs.md`, `coding-discipline.md`, `vault-doc-style.md`) — one home so the verbs
  cannot drift apart. A single-verb rule that fires on every run of that verb stays in its verb spec.
- A fragment is authoritative for what it covers: the verb spec must not restate its rules
  (a second copy drifts silently — same reason as `context-refs.md` in this directory).
- Files here are **not verbs**: every emitter globs `commands/*.md` (files only), so nothing in
  this subdir becomes a slash command, a skill, or a shim.
- `conformance-lint.sh` scans these files for checks 2/3/5/6 and validates that every pointer
  written in a verb spec resolves (a dangling pointer = a rule lost in silence).

**Shipping** — `install.sh`, `upgrade.sh` and `/ow-sync` all copy `.ow/commands/`
recursively (`cp -R`), so this subdir reaches consumer projects with no extra plumbing.

| File | Read when | Read by |
|---|---|---|
| `worktree.md` | `WT_MODE=on` (`--worktree`, or plan `worktree: true`) | `/ow-implement` 2.7 · 6.4 · 7 |
| `worktree-merge.md` | `WT_MODE=on` **and** every scenario PASS **and** no `--no-merge` | `/ow-test` 7 |
| `worktree-cleanup-gate.md` | any worktree is about to be deleted | `worktree-merge.md` 7.3 · `/ow-fix-issue` 5.3 |
| `fix-issue-fix-flow.md` | always, at Phase 4 — delegated (= the prompt) or inline (= your own checklist) | `/ow-fix-issue` 4.1 |
| `fix-issue-ready-for-test.md` | `--ready-for-test` (that mode skips Phases 0.5-7) | `/ow-fix-issue` 8 |
| `delegation.md` | the work is delegated to a subagent (3.0 judgment) | `/ow-implement` 3.1–3.5 |
| `phases.md` | the plan carries a `## Phases` table (a phased plan) | `/ow-implement` 1.3 · 3.3 · 4 · 6.0 · 6.1 |
| `coding-discipline.md` | at the code-editing phase — always, for any verb that writes code | `/ow-implement` 5.2 · 5.3 · `/ow-fix` 3 · `fix-issue-fix-flow.md` 4 · 6 |
| `context-refs.md` | a conditional vault read set is being selected | `/ow-plan` 1.3 · `/ow-implement` 3.1 · `/ow-fix-issue` 4.0 · `delegation.md` 1 |
| `vault-doc-style.md` | a vault doc OUTSIDE `$PLAN_DIR`/`$FIX_DIR`/`$TEST_DIR`/`$HANDOFF_DIR` is written | `/ow-init` 2 · `/ow-new` 1 · `/ow-clarify` 3 · `/ow-doc` 3 · `/ow-reverse-engineer` 6 · `/ow-implement` 2 · 6.2 · `design-process.md` |
| `design-process.md` | any design-system work runs — the DS gates + per-action process | `/ow-design` 1 · 2 · 3 · 4 · 5 |
| `build-test.md` | always, at the build/test run | `/ow-implement` 5.0 |
| `fixlog-close.md` | the run is fix-escalated (`source_fix:` / `--from-fix`) | `/ow-implement` 6.5 |
| `git-sync.md` | a sync actually runs (not `--status` / `--switch-only` / `--no-sync` / `auto_sync: false`) | `/ow-git` 2.5 · 6 · 7 |
| `git-post-push.md` | a push succeeded **and** either (the pushed range closes an issue, or `--fix` on a fix-log with `github_issue:`) with no `--no-ready-for-test` — **or** `--bump` finalizes a local fix-log (`--plan` with `source_fix:`, or `--fix` with `fixed_commit: pending`) | `/ow-git` 8.5 · 8.6 |
