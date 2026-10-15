# `_shared/auto-loop.md` — `--auto`: phase loop · fix loop · STOPPED

Read this **only when `AUTO_MODE=on`** (`/ow-implement … --auto`, resolved in Phase 2.7.1). `AUTO_MODE=off` ⇒
nothing here applies and every STOP / "ask a human" in `ow-implement.md` and `_shared/delegation.md` holds as written.

`--auto` means: **the human answered once, before the run.** Either the user typed `--auto` on a plan they approved,
or `/ow-auto` approved the plan under its grant. From Phase 1 on this run **never waits for an answer** — it finishes,
or it ends with `STOPPED: <reason>` and leaves everything in place for a human to look at later.

## 1. Phase loop (phased plan, no `--phase` flag)

1. Resolve the phase order from the `## Phases` table: a phase is *ready* when every `depends_on` row is `done` and
   its consumed Shared Contract rows are not `state: planned` (`phases.md` §2 — the same gate, applied repeatedly)
2. Run the first ready phase exactly as `ow-implement.md` Phases 1.3 → 6.1 describe (selective read, `phases.md` §1.5)
3. Phase closed (`6.1`) → pick the next ready phase → repeat. 🔴 Do **not** `/clear` — the loop stays in this session;
   `## Chunk Progress` / `## Step Progress` are the resume state if the session dies (`/ow-implement <plan> --auto`
   again → 1.2 resumes). Keep your own context lean: hold HANDOFFs, not plan text you no longer need
4. No phase ready but phases remain ⇒ `STOPPED: dependency — <phase> waits on <phase>` (a plan bug: `/ow-plan --revise`)
5. All phases `done` → 6.2 closes the plan

Flat plan (no `## Phases`) → there is no loop; `--auto` only skips "Start now?" and enables §2.

## 2. Fix loop (triggered from 5.1 and from delegation §6 step 3)

Only a failing `EXIT_STATE` or 5.0 build/test that **you ran yourself** enters this loop — a test or build command whose
real stdout says fail. Anything else (`BLOCKED` from a worker, timeout, auth, malformed result) goes to §3.

```
FIX_N=0 ; MAX="$AUTO_MAX_FIX"          # from Phase 0 (.ow.yml auto.max_fix_per_phase, default 2)
loop:
  FIX_N=FIX_N+1 ; FIX_N > MAX → emit STOPPED: fix-cap (<phase>) — §3
  1. write the fix-log (below), status: in-progress
  2. build a fix chunk and run it (inline, native agent, or external worker — the same backend as the run):
       === CHUNK fix<FIX_N> (authoritative — your scope) ===
       STEPS: fix                       # one job: make EXIT_STATE pass, minimum change, scope = the failing area
       EXIT_STATE: <the command that failed>
       READ_FULL: <plan path>
       READ_NAMED:
         - <fix-log path>               # symptom + the failing output
         - <files the failing chunk changed>
       === HANDOFF (chunk that failed) ===  ← the HANDOFF the failing chunk returned, verbatim
       FAILURE OUTPUT (tail -40 of the real run — never the whole log):
       <…>
       === RETURN PROTOCOL … (delegation §4, unchanged) ===
  3. you run EXIT_STATE yourself:
       pass → fix-log status: fixed + GREEN result · progress line (below) · continue the chunk loop
       fail → loop
     worker returned BLOCKED → §3 at once (does not consume a fix attempt)
```

Spawn cap: `max(2 × N, N + 3)` from `delegation.md` §6 — **fix chunks count** toward it; reaching it first ⇒ `STOPPED: spawn-cap`.

**Fix-log** — `$FIX_DIR/YYYY-MM-DD-HHMM-<plan-slug>-<phase>-fix<N>.md` (`<phase>` = `P2`, or `flat`), from the
`fix-log.md` template, filled short and honest — no empty sections:
- frontmatter: `severity: P2` · `area:` the phase/plan area · `related_plan: "[[<plan-slug>]]"` · `reported_by: self` ·
  `auto_run: <run-log path>` when invoked by `/ow-auto`, else `none`
- `## Symptom` — the failing line(s) of the real output (≤ 5 lines)
- `## Reproduction` / `## Vault Context Read` — `(auto — see plan <phase>)`
- `## Root Cause` — 1–3 lines of what the failing HANDOFF + output show; `unknown — see fix attempt` is honest when it is
- `## Fix Approach` — one line · `## Affected Files` — files the fix chunk may touch
- `## Test Cases` — the `EXIT_STATE` command · `## Risk` — `scope-limited to the failing area` · `## Next` — `rerun EXIT_STATE`
- `## GREEN result` — filled when it passes (command + the pass line)

**Progress line** (`## Chunk Progress`, same rules as `delegation.md` §6):
```markdown
- [x] P2 fix 1/2 · `pnpm test src/returns` · 2026-10-15 15:21 · exit: 41/41 pass · fixlog: 85-FixLog/2026-10-15-1518-returns-P2-fix1.md
```
Only written when the `exit:` actually passed. A fix that did not pass leaves its fix-log at `in-progress` and no line.

`--from-fix <fix-log> --auto` (how `/ow-auto` feeds a failed `/ow-test` back in): the fix-log is the unit of work
(`fixlog-close.md` §0 gate: P2/P3 only); the loop above applies with `<phase>` = `flat`.

## 2.5 Auto commit (`--auto` only — the human is not there to run `/ow-git`)

Every unit of work that passed its gates is committed **at once, locally** — a dead session then loses nothing that
was proven. Three commit points inside `/ow-implement`; `/ow-auto` adds a fourth when an item closes (`ow-auto.md` Phase 3 step 5).

| point | when | stage exactly | message |
|---|---|---|---|
| plan phase closed | 6.1 — the phase passed 5.0 / 5.2 / 5.3 / 6.0 | the code files named on every `FILES:` HANDOFF line of this phase (inline: the files your steps edited — never a `git diff --name-only` list, which also holds files dirty before the run) + the plan file | `feat(<area>): <plan title> — <Pn> (auto · plan/<slug>)` |
| fix passed | §2 step 3, `EXIT_STATE` green | the fix-log `## Affected Files` + the fix-log + the plan file | `fix(<area>): <symptom, one line> (auto fix n/N · plan/<slug>)` |
| plan closed | 6.2 | the plan file + every vault doc the Vault Update Checklist named + `$IMPL_STATUS` | `docs(vault): close plan <slug> (auto)` |

```bash
# main tree — scoped staging. 🔴 never `git add -A` on the main tree: it holds other people's uncommitted work (3.1 rule 5)
git -C "$WORK_ROOT" add -- <code paths>            # only the paths listed above; a dirty file not on the list is left alone
git -C "$MAIN_ROOT" add -- <plan / vault paths>    # vault + plan always live in MAIN_ROOT (worktree.md WORK_ROOT contract)
# path-limited commit: `git commit -- <paths>` records ONLY those paths — anything the user staged before the
# run stays staged and out of the auto commit (a bare `git commit` would take the whole index)
git -C "$WORK_ROOT" diff --cached --quiet -- <the same paths> && echo "ℹ️ nothing staged — skip commit" || \
  git -C "$WORK_ROOT" commit -m "<message>" -m "<Co-Authored-By per project convention>" -- <the same paths>
SHA=$(git -C "$WORK_ROOT" rev-parse --short HEAD)   # the real sha — never typed from memory
```
Worktree mode: code lives in `$WORK_ROOT` (the worktree — `add -A` there is fine, `worktree.md` §4) and the vault in
`$MAIN_ROOT` → **two commits**, one per repo root, same message. The 6.4 single end-of-run commit is replaced by these.

- `<area>` = the phase / plan `area` (`backend` → `api`, `frontend` → `web`, else the area name) · `<slug>` = plan file slug
- Record the sha on the progress line: ` · commit: <sha7>` (`## Chunk Progress` / `## Step Progress` / the `fix n/N` line)
- Commit fails (pre-commit hook, lock, conflict) → `STOPPED: commit — <git's last line>`; **never `--no-verify`**, never retry blindly
- 🔴 Never push · never merge · never call `/ow-git` from an auto run (it syncs, bumps and pushes — that is the human's step
  afterwards) · the `merge` grant only ever reaches `/ow-test`

## 3. STOPPED — how an auto run ends without finishing

When any of these happens, **do not ask, do not wait**: leave code, worktree and dirty tree exactly as they are, write
what you know, and end the run with one line the caller can parse:

```
STOPPED: <reason> — <phase/chunk> — <one line of evidence> — next: <what a human should look at>
```

| situation | reason token |
|---|---|
| worker `BLOCKED`, re-partition done once (`delegation.md` §6), `BLOCKED` again | `blocked` |
| `FIX_N > AUTO_MAX_FIX` | `fix-cap` |
| spawn cap reached | `spawn-cap` |
| `ow-worker.sh` returned `REASON: timeout` twice for the same chunk | `timeout` |
| preflight / exit 2/3/4 from `ow-worker.sh` | `worker-unavailable` |
| no ready phase but phases remain | `dependency` |
| 5.2 coverage gate: `PROD>0 && TEST==0` and no untestable reason fits | `coverage` |
| scope would have to grow beyond the plan (`/ow-plan --revise` needed) | `scope` |
| a §2.5 commit failed (hook / lock / conflict) | `commit` |

Before the line: write the progress markers you have, leave fix-logs at their true status, and (worktree mode)
**do not commit** a phase that did not pass its gates. The Phase 7 output carries the `STOPPED:` line last.

## 4. `## Auto Decisions`

A decision the run had to make that a human would normally have been asked (an ambiguity the plan did not settle,
an acceptance criterion with two readings) → take the option a careful engineer would recommend, and record it in
the plan under `## Auto Decisions` — one line each:
```markdown
## Auto Decisions (written by --auto — review after the run)
- P2 · retry policy on 409 → exponential backoff, 3 tries · FN-API-Returns §4.2 silent on it · 2026-10-15 15:02
```
Never silent. Phase 7 lists them. A wrong one is corrected afterwards with `/ow-plan --revise` + a new run.

## Never

- Never ask the user anything after Phase 1 — `STOPPED:` is the only way out that is not `done`
- Never count a fix attempt whose `exit:` you did not run · never write a `fix n/N` line for a failed attempt
- Never enter the fix loop for a `BLOCKED`, a timeout, an auth error or a malformed result — those are §3
- Never roll back, `git reset`, `git clean` or delete a worktree on STOPPED
- Never change the meaning of `BLOCKED` outside `--auto`
- Never `git add -A` on the main tree · never push · never `--no-verify` · never call `/ow-git` (§2.5)
