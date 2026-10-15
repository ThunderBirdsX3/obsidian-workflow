---
description: Hands-off run — clarify once, then plan → implement → test every feature of a vault phase (or one FEAT / brief) with no further questions; optional external worker (--codex / --claude)
---

<!-- Obsidian behaviour: the run-log lives in $PLAN_DIR (history allowed there) · FEAT docs get `## Clarifications` only ·
every other vault write is done by the verbs this command calls -->

# /ow-auto — one order, run to the end

The human answers **once, before anything starts**. After that the run plans, implements and tests every item in its
queue by calling the existing verbs — `/ow-clarify`, `/ow-plan`, `/ow-implement --auto`, `/ow-test` — and never asks
again: an item that cannot finish is recorded as `stopped` and the run moves to the next independent one.

This command **calls** specs; it never shortens them. Each verb runs its own Phase 0 → 7 as its file says.

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble. Step 1 (resolver eval + assert + export) is byte-identical in every command and conformance-lint check 8 fails on any drift. Step 2 is per-command only in its `--rules-load <area[,area]>` argument. Do NOT edit anything else per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/<prefix>-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
OW_ROOT="$(git rev-parse --show-toplevel)"; OW_ENV="$OW_ROOT/.ow/local/paths.env"
mkdir -p "$OW_ROOT/.ow/local"
bash "$OW_ROOT/scripts/ow-paths.sh" --shell > "$OW_ENV.tmp" && mv "$OW_ENV.tmp" "$OW_ENV" || {
  echo "FATAL: obsidian-workflow resolver missing/failed — run /<prefix>-init"; exit 1; }
. "$OW_ENV"
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules-load coding
```

Step 2's rule text is binding (it OVERRIDES this spec for its area); the final report lists `rules applied: <file, …>` or `rules applied: none`.
Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $FN_DIR $PHASE_DIR $FLOW_DIR
$REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $TEMPLATE_CHAIN
$GUARDRAILS_JSON $COMMAND_PREFIX`. A later phase runs in a
FRESH SHELL — Phase 0's exports are gone — so it re-hydrates first, then asserts:
`. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"` followed by
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-auto PHASE-1                    # vault phase → queue = every FEAT under "## 2. Scope → In" whose doc is not status: done
/ow-auto FEAT-Returns               # one feature → one plan
/ow-auto "<brief>"                  # free text → one plan (no FEAT doc; clarifications live in the run-log only)
/ow-auto <target> --codex           # external worker = Codex CLI (host must be Claude Code)
/ow-auto <target> --claude          # external worker = Claude CLI (host must be Codex)
/ow-auto <target> --worktree        # passed to every /ow-plan in the queue (implement+test in a worktree)
/ow-auto <target> --merge           # adds `merge` to the grant → /ow-test may auto-merge on PASS (default: --no-merge)
                                    # `commit` is ALWAYS in the grant: every passed phase / fix / plan is committed locally (never pushed)
/ow-auto --resume <run-log>         # continue a run after a dead session / context loss
```

Empty → ask (render in `$PROJECT_LANG`): "What should I run to the end?" — the only other question this command ever asks is Phase 1.5.

**Naming:** a *vault phase* is a `50-Phases/PHASE-*` doc (a milestone holding FEATs). A *plan phase* is `P1..Pn` inside one plan
(`/ow-plan` 2.5). This command walks both: FEAT → plan → plan phases.

## Phase 1 — Resolve target → queue

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"; [ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
TARGET=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--(codex|claude|worktree|merge)//g; s/[[:space:]]*--resume[[:space:]]+[^[:space:]]+//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
WORKER=native; case " $ARGUMENTS " in *" --codex "*) WORKER=codex ;; esac; case " $ARGUMENTS " in *" --claude "*) WORKER=claude ;; esac
GRANT="plan, implement, commit"; case " $ARGUMENTS " in *" --merge "*) GRANT="plan, implement, commit, merge" ;; esac   # commit is always granted under auto — local only, never push
WT_FLAG=""; case " $ARGUMENTS " in *" --worktree "*) WT_FLAG="--worktree" ;; esac
```

1. `--resume` present → Phase 6, skip the rest of this phase
2. **Host check** — `--codex` on a Codex host or `--claude` on a Claude host ⇒ 🔴 STOP: "same host — this flag dispatches to
   the *other* CLI". Both flags ⇒ STOP
3. **Preflight** — `WORKER≠native` ⇒ `bash "$ROOT/scripts/ow-worker.sh" $WORKER --preflight`; exit ≠ 0 ⇒ 🔴 STOP with its
   message. Runs **before any file is written** — a failed preflight leaves no run-log, no plan
4. **Queue**

   | target | resolve | queue |
   |---|---|---|
   | `PHASE-<n>` / a file in `$PHASE_DIR` | `find "$PHASE_DIR" -name "PHASE-<n>*.md"` | read **`## 2. Scope` → the `**In:**` list only** (never Out / Risks / Progress). Each `[[FEAT-*]]` whose doc in `$FEAT_DIR` has frontmatter `status` ≠ `done` and ≠ `abandoned` is one item (`abandoned` = a human decision, never built). Order: the `Priority <k>` number on the line ascending, ties in file order. A FEAT with `depends_on:` naming a FEAT that is not `done` is placed after it. A `[[FEAT-*]]` with **no doc** in `$FEAT_DIR` → item recorded at once as `stopped: FEAT doc missing — run /ow-new or /ow-doc first`, and nothing depending on it runs |
   | `FEAT-<name>` / a file in `$FEAT_DIR` | file exists | one item |
   | anything else | not a file | one `brief` item (the text itself) |

   Empty queue (every FEAT already `done`) → report and end; nothing to do is a fine outcome.
5. Show the queue (item · plan state · worker · grant) in `$PROJECT_LANG` — informational, not a question

## Phase 1.5 — Clarify once, as one batch (the only stop)

1. For every item: run `/ow-clarify` **Phase 1 (taxonomy scan, read-only)** on the FEAT doc — a `brief` item is scanned
   as text. ≤ 5 questions per item; a question the vault already answers is not asked
2. Collect every question into **one batch** (this is the deliberate difference from `/ow-clarify`'s one-at-a-time:
   the run stops for a human exactly once). Every question carries a **Recommended** answer; the user may reply
   "all recommended"
3. Write the answers back: FEAT doc `## Clarifications` (exactly `/ow-clarify` Phase 3 — `$VAULT_LANG`, one answer per
   question, no history) **and** the run-log `## Clarifications` (brief item: run-log only)
4. No questions at all → skip silently

🔴 From here on **no question reaches the user after Phase 1.5** — `/ow-plan` runs with `OW_AUTO_RUN` set and takes
Recommended + `## Auto Decisions` for anything left (`ow-plan.md` Phase 2); `/ow-implement --auto` ends with `STOPPED:`
instead of asking (`_shared/auto-loop.md` §3).

## Phase 2 — Run-log (written before the first verb runs)

`$PLAN_DIR/YYYY-MM-DD-HHmm-auto-<slug>.md` — slug = lower-cased target (`phase-1`, `feat-returns`, or ≤ 5 words of the brief):

```markdown
---
type: auto-run
status: running              # running | done | done-with-stops | stopped
target: PHASE-1
worker: codex                # native | codex | claude
grant: [plan, implement, commit]   # + merge when --merge · commit = local commits per phase / fix / plan / item, never push
worktree: false
started_at: 2026-10-15 14:02
host: claude                 # claude | codex
---
# /ow-auto PHASE-1

## Queue
| # | item | plan | state | updated | note |
|---|---|---|---|---|---|
| 1 | FEAT-Checkout | — | queued | — | Priority 1 |
| 2 | FEAT-Returns  | — | queued | — | Priority 1 · depends on FEAT-Checkout |

## Clarifications
- **FEAT-Returns Q1 (Edge):** … **A:** … *(2026-10-15)*

## Stops
```

`state` ∈ `queued | planning | implementing | testing | done | stopped`. 🔴 Update the row **before the verb runs**
(`planning` / `implementing` / `testing`) and **after it returns** (`done`, or `stopped: <reason>` + a line under `## Stops`):
two writes per step, never one at the end. `export OW_AUTO_RUN="<run-log path>"` once the file exists — `/ow-plan` reads it.

## Phase 3 — Walk the queue (per item)

1. **Existing plan first** — a plan in `$PLAN_DIR` whose `related_feature:` names this FEAT and is not `done`/`abandoned`:
   `approved` / `in-progress` → skip to step 3 (`/ow-implement` 1.2 resumes its progress markers — never plan the
   FEAT a second time); `planning` → step 2 grants it as is. Newest wins on a tie. No existing plan →
   `state: planning` → run **`/ow-plan <FEAT doc or brief> $WT_FLAG`** as its spec says, every Phase. Under `OW_AUTO_RUN`
   it asks nothing (`ow-plan.md` Phase 2). The plan file exists **before** step 2 — always
2. **Grant** — surgical Edit on the plan frontmatter:
   ```yaml
   status: approved
   approved_by: ow-auto
   approved_at: <YYYY-MM-DD HH:mm>
   auto_grant: [implement, commit]    # + merge when the run-log grant has it
   auto_run: <run-log path>
   auto_brief: "<target or brief exactly as typed>"
   ```
   Write `plan` + `planning → implementing` into the Queue row
3. `state: implementing` → run **`/ow-implement <plan> --auto`** (+ `--codex` / `--claude` when `WORKER≠native`). It returns
   either a closed plan or a Phase 7 output ending in `STOPPED: <reason>` → item `stopped: <reason>` + `## Stops` line
   (copy the `STOPPED:` line verbatim) → step 7
4. `state: testing` → run **`/ow-test <plan> --no-merge`**; `merge` in `auto_grant` → run `/ow-test <plan>` (its own PASS
   auto-merge applies). Any scenario FAIL/BLOCKED → **test-level fix round**: write a fix-log (`_shared/auto-loop.md` §2
   fix-log shape, `severity: P2`, Symptom = the failing scenario lines) → `/ow-implement --from-fix <fix-log> --auto`
   (+ worker flag) → `/ow-test` again. At most `AUTO_MAX_FIX` rounds per item (Phase 0 var); still failing →
   `stopped: test-fail after <n> fix rounds` → step 7
5. `state: done` — `/ow-implement` 6.2 already flipped the FEAT / `$IMPL_STATUS` and committed its own work
   (`_shared/auto-loop.md` §2.5). Write the row, then **commit the item close** in the project root (`$ROOT`): `git add -- <run-log>
   <FEAT doc> <$IMPL_STATUS> <test report /ow-test wrote>` then
   `git commit -m "docs(vault): close <FEAT> (auto · <run-log slug>)" -m "<Co-Authored-By trailer>" -- <the same paths>` — path-limited, so nothing the user staged rides along. Nothing staged → skip. Commit fails → `stopped: commit — <git last line>`,
   never `--no-verify`. **Never push** — `/ow-git` is the human's step after the run
6. **Unmerged dependency** (`--worktree` without `--merge`): `/ow-test --no-merge` leaves an item's code on its worktree
   branch, so a dependent item's new worktree would be cut from a base without it → the dependent becomes
   `stopped: depends on <item> (unmerged — /ow-test <plan> merges it, then --resume)`; independent items still run.
   Phase 1 step 5 shows this up front when the queue has dependencies
7. **After a stop**: continue with the **next item that does not depend on the stopped one** (FEAT `depends_on:` or the
   PHASE Scope line that names it). Every dependent item → `stopped: depends on <item>` at once, not attempted.
   Worktrees, dirty trees and in-progress fix-logs of a stopped item stay exactly as they are
8. Queue exhausted → run-log `status: done` (no stops) or `done-with-stops`

🔴 Never `cat` a worker log, events file or stderr into this context — the verbs already hold the evidence they need
and the run-log holds the paths. 🔴 Hold HANDOFF-sized facts between items, not plan bodies.

## Phase 6 — `--resume <run-log>`

1. Read the run-log. `status: done` → report "nothing to resume" and end — never re-plan a finished run
2. Flags (`worker`, `grant`, `worktree`, `host`) come **from the run-log frontmatter**; flags typed on the resume line are
   ignored with a one-line note (changing provider = a new run). `host` differs from the current host → STOP
3. Per row: `done` → skip · `queued` → Phase 3 from step 1 · `planning` → Phase 3 step 1 again (an unapproved plan has
   no side effect; step 1's existing-plan rule picks up a drafted file — no `/ow-plan --revise`, which would ask) · `implementing` → Phase 3 step 3 (`/ow-implement` 1.2
   resumes from `## Chunk Progress` / `## Step Progress`, re-running the last `exit:` first) · `testing` → step 4 ·
   `stopped` → retry from the state before the stop (the human resumed, so the human fixed something); fix caps count
   from zero again
4. `## Clarifications` are already in the run-log — a resume **never re-asks** them (Phase 1.5 is skipped)
5. Set `status: running`, continue Phase 3

## Phase 7 — Output (short bullets, in `$PROJECT_LANG`)

- **Done** — items finished / total, with each plan path
- **Evidence** — the build/test commands actually run per item and their real pass/fail (from the verbs' outputs)
- **Stopped** — each stopped item with its `STOPPED:` line and where to look (worktree, fix-log)
- **Auto Decisions** — every line the plans gained under `## Auto Decisions`, for review
- **Run-log** — path · **usage: unknown** (providers do not expose it reliably; never invent a number)
- **Next** — `/ow-auto --resume <run-log>` once the stopped items are unblocked · no `merge` grant → `/ow-test <plan>` to merge

## Never

- Never ask the user anything after Phase 1.5 — an item that cannot proceed is `stopped`, the run continues or ends
- Never approve a plan without `auto_brief` equal to what the user typed · never widen the grant (`merge`/push/deploy) yourself
- Never push, never `/ow-git`, never `git add -A` on the main tree — commits are local and scoped (`_shared/auto-loop.md` §2.5)
- Never skip, reorder or paraphrase a Phase of `/ow-clarify`, `/ow-plan`, `/ow-implement`, `/ow-test` — call them
- Never run an item whose dependency is `stopped` · never touch a stopped item's worktree, dirty tree or fix-log
- Never read raw worker output into this context · never write tokens, auth paths or secrets into the run-log
- Never claim usage/cost figures — `usage: unknown`
