# `_shared/phases.md` — running one phase of a phased plan

Read this the moment a plan carries a `## Phases` table (`/ow-plan` Phase 2.5). No such section ⇒ the plan
is flat, none of this applies, and `/ow-implement` runs unchanged.

This fragment is authoritative for the phase gate, the per-phase done-gate, and the phase close-out.
`/ow-implement` must not restate these rules.

A **phase** is the unit of work: `/ow-implement <plan> --phase P2` runs exactly one, no flag runs them all in
order. The point is context — one phase's read set was measured against an executor's budget, so a session
that reads two phases' worth has already lost the saving the breakdown existed to produce.

## 1. Resolve the target phase

🔴 This gate runs at Phase 1.3, **before** 2.7.1 — so derive both values here rather than expecting them from
a later phase. The `PLAN_PATH` expression is the same one 2.7.1 uses (deriving it twice is harmless):

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# `ow_resolve_plan` — the target may be a PATH or a bare SLUG (`/ow-implement checkout-flow --phase P2`).
# Plans are named `YYYY-MM-DD-HHmm-<slug>.md`, so a slug matches by suffix; newest wins on a tie.
ow_resolve_plan() {
  [ -f "$1" ] && { printf '%s' "$1"; return 0; }
  set -- "$(find "$PLAN_DIR" -maxdepth 1 -name "*$1.md" 2>/dev/null | sort | tail -1)"   # find, not a glob: an unmatched glob aborts under zsh
  [ -n "$1" ] && [ -f "$1" ] && printf '%s' "$1"
}
PLAN_ARG=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--phase[[:space:]]+[A-Za-z0-9_-]+//g; s/[[:space:]]*--(no-)?worktree//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
PLAN_PATH=$(ow_resolve_plan "$PLAN_ARG")
PHASE_ID=$(printf '%s' "$ARGUMENTS" | sed -nE 's/.*--phase[[:space:]]+([A-Za-z0-9_-]+).*/\1/p')
[ -f "$PLAN_PATH" ] || { echo "FATAL: no plan resolves from: $PLAN_ARG"; exit 1; }
grep -q '^## Phases' "$PLAN_PATH" && PHASED=1 || PHASED=0
```

🔴 Resolve the **slug form too** — `/ow-implement <slug>` is a documented trigger, and treating a slug as a
missing path would STOP a perfectly valid run here at 1.3, before anything has been resolved.
🔴 `PLAN_PATH` must resolve to a real file before anything below reads it — an empty/unresolved path makes
every `grep` here answer "no phases", which silently downgrades a phased plan to a flat one and skips the
entry gate entirely. Assert it, never let it fail open.
🔴 A flat plan (`PHASED=0`) plus `--phase` = **STOP** — there is nothing to select, and running the whole
plan "because the flag looked harmless" is not what the user asked for.

## 1.5 Read the plan **selectively** — never the whole file

🔴 A phased plan holds every phase's section in one file. Opening all of it puts 6 phases you will not touch
into the context this phase was sized against — the exact cost the breakdown exists to avoid, paid back in
full. `Read` takes `offset`/`limit`, so read only the slices this run needs:

```bash
grep -n '^## Shared Contract\|^## Phases\|^### Phase \|^## Design System\|^## Verification' "$PLAN_PATH"
# → the line numbers that bound (a) the shared header and (b) each phase section
```

Then **two Reads, not one**:
1. **Shared header** — `Read(PLAN_PATH, offset=1, limit=<first "### Phase " line - 1>)`: frontmatter, Problem,
   Task, Goals, Non-goals, Doc Gaps, `## Shared Contract`, the `## Phases` table. Every gate in §2 reads from here
2. **This phase only** — `Read(PLAN_PATH, offset=<its "### Phase <id>" line>, limit=<next "### Phase " or
   "## " line − that line>)`. Plus, at the end of the file, the plan-level `## Design System Compliance` /
   `## Verification` / `## Risks` / `## Approvals` when a gate actually needs them

🔴 Never read another phase's section "for context" — if this phase genuinely needs something from a sibling,
that value belongs in `## Shared Contract`, which you already hold. Needing more than the contract means the
phase boundary was drawn wrong: report it rather than reading across.
🔴 The whole-file reads that remain legitimate: the Phase 6.0 final gate on the **last** phase, and
`/ow-verify`. Both are cheap by comparison and neither precedes code.

## 2. The entry gate — every item, before any code

With `--phase <id>`:

1. The id must be a row in `## Phases` → not found = **STOP**, list the ids, never guess
2. That row's `status` is already `done` → **STOP**, tell the user (re-running re-applies finished work)
3. Every id in its `depends_on` must be `status: done` in the table → otherwise **STOP**:
   "`<dep>` is not done — run `/ow-implement <plan> --phase <dep>` first"
4. 🔴 **Shared Contract gate** — every `## Shared Contract` row whose `consumers` include this phase must be
   `state: actual`. Any still `planned` → **STOP**: its producer has not run, and implementing against an
   assumed value is how two phases ship different field names. Never proceed on `planned`
5. Scope for the whole run = **that phase's section only** — its `context_refs`, Affected Files,
   Implementation Steps, Test Plan, Success Criteria, owned docs
6. 🔴 **The phase row's `area` is the area for this run** — it replaces the plan's `subagent_target`
   everywhere that value is read: the `/ow-implement` 3.0 table (which `.claude/agents/<area>.md` and which
   rules apply), the Phase 4 design-system gate, `ow-paths.sh --rules <area>`, and `AREA` in
   `delegation.md` §3. A phased plan spanning areas carries `subagent_target: all` in its frontmatter, and
   `all` resolves no agent file, fires no DS gate and matches no rule set — reading it instead of the row's
   `area` silently drops every area gate this phase was supposed to run under
7. 🔴 **Stamp the row `in-progress`** (surgical Edit, that cell only) before the first code change. That is
   the only mark distinguishing "this phase died mid-run, with real work in the tree" from "never started",
   and `/ow-plan --revise` refuses to rewrite it. A run that dies before its first `## Step Progress` line
   would otherwise sit at `planning` and be regenerated from scratch, destroying the work

🔴 Never edit a file or a vault doc another phase owns. The phase sections were partitioned so that no file
belongs to two of them; reaching across is a double-edit and a merge conflict waiting to happen.

Without `--phase` on a phased plan → run **every** phase in `## Phases` order: for each one, items 1-7 above
and then `/ow-implement` Phases 3 → 6.1 in full, before moving to the next. 🔴 A phase is finished — gates,
contract write-back, its row ticked `done` — before the next one starts; a later phase reads the contract the
earlier one just wrote, which is what the order is for. Before starting, sum the `est tokens` column: over
~120k ⇒ **warn**, never block:

> This plan is ~`<sum>`k tokens of read set. Running it in one session risks compaction mid-run — one phase
> per session with `/clear` between them is cheaper and safer: `/ow-implement <plan> --phase P1`

## 3. Read set + resume, per phase

- **Read set** — the running phase's `context_refs:` list **is** the read set (`context_closed: true`);
  never another phase's. Details: `/ow-implement` 3.0 item 2 · `delegation.md` §1
- **Chunking** (delegated runs) — partition the running phase's `#### Implementation Steps` only; a chunk
  never crosses a phase boundary (`delegation.md` §2)
- **Resume marker** — a phased run's marker line carries its phase id, in **both** shapes:
  `- [x] P2 steps 1-4 · …` (inline, `/ow-implement` 3.3) and `- [x] P2 chunk 1/4 · steps 1-3 · …`
  (delegated, `delegation.md` §6). 🔴 Without the id a resume cannot tell which phase's step 3 was ticked,
  and `/ow-plan --revise` cannot tell which phase the marker protects. On resume, apply the 1.2 gate to
  **this phase's** lines only — another phase's lines are history, never this run's resume point

## 4. The done-gate — this phase's section, not the whole file

The other phases' checkboxes are future work; counting them would make every phase but the last
unfinishable. So the Phase 6.0 open-checkbox gate runs against the phase section:

🔴 This block runs at Phase 6.0 — a **fresh shell**, so §1's values are gone. Re-derive them here, and take
`PHASE_ID` from **the phase this run is currently executing**: the `--phase` argument, or on a run-all the id
of the current iteration (`$ARGUMENTS` carries no id in that case — the loop does).

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"   # $PLAN_DIR — ow_resolve_plan needs it
PLAN_ARG=$(printf '%s' "$ARGUMENTS" | sed -E 's/[[:space:]]*--phase[[:space:]]+[A-Za-z0-9_-]+//g; s/[[:space:]]*--(no-)?worktree//g; s/^[[:space:]]+//; s/[[:space:]]+$//')
PLAN_PATH=$(ow_resolve_plan "$PLAN_ARG")            # same resolver as §1 — re-paste it, fresh shell
PHASE_ID="<the phase being executed right now>"     # --phase arg, or the run-all loop's current id
[ -f "$PLAN_PATH" ] && [ -n "$PHASE_ID" ] || { echo "FATAL: phase gate has no target"; exit 1; }
phase_section() {              # usage: phase_section <plan> <phase-id>  → that phase's section only
  awk -v id="$2" '$0 ~ "^### Phase " id " " { inp=1; next }
                  inp && /^### Phase |^## / { exit }
                  inp' "$1"
}
phase_section "$PLAN_PATH" "$PHASE_ID" | grep -c "\- \[ \]"   # must = 0 for THIS phase
```

🔴 This assert fires **after** the code is written and 5.0/5.2/5.3 have passed, so it must never fire on a
valid run: resolve the slug form exactly as §1 does, or a slug-invoked phased run can never tick its phase
`done`. It is a real-target check, not a path-shape check.
🔴 An empty `PHASE_ID` makes the awk pattern `^### Phase  ` match nothing, so the gate counts **zero open
checkboxes and passes vacuously** — the phase would close with its Test Plan, Success Criteria and the
contract write-back still unticked. Assert both values; never let this gate fail open.

🔴 Every other gate is unchanged and still mandatory for the phase: 5.0 build/test run · 5.2 coverage ·
5.3 discipline. A phase is not cheaper to finish than a plan — it is only smaller.

## 5. Close the phase

Gates all passed ⇒ with **Edit (surgical)** set that phase's `status` cell in the `## Phases` table to
`done` — never touch another row, never rewrite the table.

Then:
- **Every** row `done` → run the 6.0 gate once more against the **whole file** (the plan-level checkboxes —
  Design System Compliance, Approvals, Verification — are not in any phase section and nobody has counted
  them yet), then continue into `/ow-implement` 6.2
- Any row not yet `done` → the plan **stays** at `status: approved`; skip 6.2, and tell the user
  which phase is next: `/ow-implement <plan> --phase <next>`, 🔴 after a `/clear` — that is where the saving
  comes from

🔴 Never flip the plan's frontmatter `status: done` while one phase row is not `done` — `/ow-verify` and
`$IMPL_STATUS` would both report work that was never run.

## Never

- Never run a phase whose `depends_on` is unfinished, or whose consumed Shared Contract row is still `state: planned`
- Never edit a file or a doc another phase owns
- Never gate one phase on the whole file's checkboxes, and never flip the plan `done` while a phase row is not `done`
- Never write a phased run's `## Step Progress` / `## Chunk Progress` line without its phase id
- Never read the plan's `subagent_target` in place of the running phase's `area` — it drops every area gate
- Never read another phase's `context_refs` — that is the budget this phase was sized against
