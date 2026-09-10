# `_shared/worktree.md` — worktree mode (#31)

Read this **only when `WT_MODE=on`** (resolved in `/ow-implement` Phase 2.7.1). `WT_MODE=off`
⇒ nothing here applies: `WORK_ROOT=$MAIN_ROOT` and the build happens in the main tree.

Worktree mode builds in a **separate git worktree** so the **main working tree is never touched**
(parallel uncommitted work stays safe), then `/ow-test` auto-merges it back once the tests pass.
Mirrors `/ow-fix-issue` Phase 3, but as a **single task** (not parallel).

> 🔑 **WORK_ROOT contract** (holds across Phases 3-6): **code** (implementer cwd — yours or the agent's ·
> `git diff` · build/test) → `$WORK_ROOT`; **vault + plan file** (`$VAULT_ABS` · `$PLAN_DIR`) →
> **always absolute under `$MAIN_ROOT`**. ⇒ the worktree commit is **code only**, and so
> is the merge back → it never collides with the vault/plan-file copy inside the worktree.

## 1. Create the worktree (runs at Phase 2.7.2)

```bash
mkdir -p "$MAIN_ROOT/worktrees"
grep -qx 'worktrees/' "$MAIN_ROOT/.gitignore" 2>/dev/null || echo 'worktrees/' >> "$MAIN_ROOT/.gitignore"

BASE=$(git -C "$MAIN_ROOT" rev-parse --abbrev-ref HEAD)
[ "$BASE" = HEAD ] && { echo '🛑 main tree = detached HEAD — checkout a branch first, or use --no-worktree'; exit 1; }

SLUG=$(basename "$PLAN_PATH" .md)
WT="$MAIN_ROOT/worktrees/plan-$SLUG"                  # gitignored (line 2 ensures it)
BR="plan/$SLUG"

# Pick the start point. On a shared branch the main tree is routinely a few commits behind origin,
# and branching from it bakes that staleness into every conflict the merge back will hit.
#   behind, nothing local  → branch from origin/$BASE: newest base, and the user's main tree is
#                            still never touched (no checkout, no ff, no fetch into their branch)
#   diverged / offline / no remote → local HEAD, exactly as before (their local commits matter more)
START_REF=HEAD; BASE_NOTE="local HEAD"
SYNC="$MAIN_ROOT/scripts/ow-git-sync.sh"
if [ -x "$SYNC" ]; then
  ab=$(bash "$SYNC" status "$MAIN_ROOT" 2>/dev/null)          # "<ahead>\t<behind>\t<upstream>" — fetches first
  AHEAD=$(printf '%s' "$ab" | cut -f1); BEHIND=$(printf '%s' "$ab" | cut -f2); UP=$(printf '%s' "$ab" | cut -f3)
  if [ "$UP" != none ] && [ "${BEHIND:-0}" -gt 0 ] && [ "${AHEAD:-0}" -eq 0 ]; then
    START_REF="$UP"; BASE_NOTE="$UP (local $BASE was $BEHIND commit behind)"
  elif [ "$UP" != none ] && [ "${AHEAD:-0}" -gt 0 ] && [ "${BEHIND:-0}" -gt 0 ]; then
    echo "⚠️  $BASE diverged (ahead $AHEAD / behind $BEHIND) — worktree builds on your LOCAL base; /ow-git sync before merging"
  fi
fi

# Branch from $START_REF (excludes the main tree's uncommitted work → parallel work stays safe).
# A worktree already exists → reuse it (re-run idempotent).
if git -C "$MAIN_ROOT" worktree list --porcelain | grep -qx "worktree $WT"; then
  echo "♻️  reuse existing worktree: $WT"
else
  git -C "$MAIN_ROOT" worktree add -b "$BR" "$WT" "$START_REF" \
    || git -C "$MAIN_ROOT" worktree add "$WT" "$BR" \
    || { echo "🛑 worktree create fail: $WT — clean up and retry, or --no-worktree"; exit 1; }
  echo "🌱 branched from: $BASE_NOTE"
fi
WORK_ROOT="$WT"
BASE_SHA=$(git -C "$WT" rev-parse HEAD)
```
🔴 **create fail → STOP** (never fall back silently to the main tree — the user asked for isolation to keep
parallel work untouched; silence = a lost guarantee)
🔴 **The main tree is never checked out, fast-forwarded or fetched into** — branching from `origin/$BASE`
gets the fresh base without touching a single ref the user is standing on
🔴 **No remote / offline / helper absent → `HEAD`, unchanged** — a solo project behaves exactly as before

## 2. Record the state → plan frontmatter (surgical Edit, Phase 2.7.3)

Edit the frontmatter of `$PLAN_PATH` (the file in the `$MAIN_ROOT` vault — **never** touch the docs/ copy
inside the worktree):
```yaml
worktree: true
worktree_dir: <WT — absolute>
worktree_branch: plan/<slug>
worktree_base: <BASE>
worktree_base_sha: <BASE_SHA>       # the commit it was actually cut from (origin/<BASE> or local HEAD)
worktree_repo: <MAIN_ROOT>          # monorepo; multi-repo + submodule_target → submodule path
worktree_status: built              # /ow-test reads this field → flips it to merged when the merge succeeds
```
🔴 The plan file lives in MAIN_ROOT → the worktree copy is never edited → the merge never collides with docs/
(worktree = code only)

## 3. WORKTREE block for a delegated agent (append after PROJECT CONTEXT — `_shared/delegation.md` §3)

The agent has no bash + lives inside the worktree → this block is the only context telling it where it works:
```bash
echo "=== WORKTREE (worktree mode — authoritative) ==="
echo "Working tree: $WORK_ROOT   # edit code here only — never touch anything outside this dir (the vault uses the absolute path above)"
echo "Branch: $BR   ·   Base: $BASE   ·   Repo: $MAIN_ROOT"
echo "After implement+test pass: commit in the worktree (NO push, NO merge) — /ow-test merges it when smoke passes"
echo "=== END WORKTREE ==="
```
🔴 The agent **leaves the code uncommitted** (same as normal mode) — the orchestrator audits (5.2/5.3) then
commits it itself in §4 · the agent must never commit / push / merge

## 4. Commit in the worktree (Phase 6.4 — after 5.0/5.2/5.3/6.0 all pass)

The orchestrator commits the code in the worktree (NO push, NO merge) — it becomes a feature-branch commit
that `/ow-test` merges back to base when smoke passes:
```bash
git -C "$WORK_ROOT" add -A
git -C "$WORK_ROOT" diff --cached --quiet && { echo "ℹ️ no code changes in the worktree — skip commit"; } || \
git -C "$WORK_ROOT" commit -m "<type>(<scope>): <one-line from the plan title> (plan/$SLUG)

<Co-Authored-By per project convention>"
# then update worktree_status in the plan frontmatter (MAIN_ROOT): built (confirmed) — /ow-test flips it → merged
```
🔴 The commit captures only the worktree's code files (the vault lives outside the worktree → not included)
· **never push · never merge** (that is `/ow-test`'s job)
🔴 Chunks never commit — every chunk lives in the same worktree, committed once here (guards against a partial commit)
🔴 Empty worktree (no code changed, e.g. a docs-only plan) → skip the commit + tell the user (nothing to merge —
`/ow-test` runs normally and skips the merge)

## 5. Handoff appended to the Phase 7 output (render in `$PROJECT_LANG`)

```
🌳 Worktree build done — branch plan/<slug> (commit <sha>) in worktrees/plan-<slug>/
   the main working tree is untouched (parallel uncommitted work stays safe)

🎯 Next: /ow-test <plan>   →  smoke test in the worktree → PASS = auto-merge back to <base> (local, no push) + cleanup
   (FAIL = the worktree is kept at worktrees/plan-<slug>/ to keep working on)
```
