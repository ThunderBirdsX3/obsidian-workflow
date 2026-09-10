# `_shared/coding-discipline.md` — coding discipline (cross-verb contract)

> **Single source of truth** for the four rules below. Every verb that writes code reads this file at
> its code-editing phase and never restates a rule here in its own words — a second copy drifts
> silently (same contract as `context-refs.md` in this directory).
>
> Read by: `/ow-implement` 5.2 · 5.3 · `/ow-fix` Phase 3 · `_shared/fix-issue-fix-flow.md` 4 · 6
>
> 🔴 The project's own rule file for area `coding` under `.ow/rules/` — loaded by every
> command's Phase 0 via `ow-paths.sh --rules coding` — **overrides** anything in this file. This is
> the floor that applies when a project has written no rule of its own.

## 1. Checkable success criteria before the first edit

No edit starts until the criteria are written down and each one can be checked by something that
**exits non-zero when it fails** — a test, a build, a captured output, a before/after screenshot pair.
"Looks right" is not a criterion.

- `/ow-plan` writes them into the plan · `/ow-fix` writes them into the fix-log `## Success Criteria`
- Bug criteria come in pairs: **what must become correct again** + **what must not break**
  (regression). Map each one to a Test Case, one by one
- A criterion with no way to check it → rewrite it until there is one, or drop it and say which

## 2. Minimum correct change

The smallest change that satisfies the criteria — nothing more:

- **Changed-line traceability** — every hunk ties back to a plan step / success criterion. A hunk that
  cannot explain its "why" → revert it
- **No speculative additions** — no abstraction, config key, dependency, flag or feature that the plan
  or the bug did not ask for
- **No unrelated refactor / format churn** — the formatter/linter runs on the **changed files only**
  (`<fmt> <files>`); across the whole tree it is read-only `--check`

🔴 **Reverting out-of-scope churn = surgical `Edit` on the files this task itself changed** — never
`git checkout` / `git restore` / `git stash` / `git clean`: they drop the whole uncommitted file,
including a parallel task's work (#29). A file that was already dirty and this task does not need →
leave it alone entirely: never revert it, never edit it, never stage it.

## 3. Test first — the scope depends on the work

| The work | Contract |
|---|---|
| **A bug with a reproduction** (`/ow-fix`, `/ow-fix-issue`) | the test that reproduces it is written **before** the fix and **must FAIL** first — that captured RED output is the only proof the fix fixed something. No untestable escape: a bug that can be reproduced can be asserted |
| **A bug the harness genuinely cannot reproduce** (third-party outage, device-only, timing/race) | the automated test may be skipped **only** with the reason written into the fix-log, plus the before/after states manually observed and written down in its place |
| **A feature / refactor** (`/ow-implement`) | the coverage gate: production files changed with no test file changed → **STOP**, unless the change maps to the untestable list below |

**Untestable list (1–6) — the only acceptable reasons a production change ships with no test:**
1. pure styling/layout (no logic) · 2. config/constants/env wiring · 3. generated code (codegen,
migration scaffolding) · 4. static content / i18n string · 5. third-party integration with no
sandbox/stub · 6. vault docs / markdown only

🔴 **"hard / time-consuming" is not untestable** — it must map to one of these 6, named explicitly.

## 4. The audit before marking done

Check `git diff HEAD` against every rule above:

- [ ] every success criterion has a check mapped to it — state **pass / fail / not-checked + reason**
- [ ] every hunk traces back to a success criterion or a plan step
- [ ] no speculative addition
- [ ] no unrelated refactor / format churn
- [ ] the §3 test contract was met — RED before the fix, or a named untestable reason 1–6

Any item fails → **fix it inside this task before marking done**, by the safe revert method in §2.
Scope discipline is this task's job and is never punted to a follow-up.
