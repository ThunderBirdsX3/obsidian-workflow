# `_shared/worktree-merge.md` — auto-merge the worktree back on PASS (#31)

Read this **only when `/ow-test` Phase 7 fires**: `WT_MODE=on` **AND** every scenario PASS **AND** no
`--no-merge`. Any other case → no merge, keep the worktree, end at the normal Output.

Merge the feature branch back into the base branch **local only (no push)** + cleanup the worktree.
🔴 **Absolutely non-destructive** — never touch uncommitted work in the main tree ("never restore another file
that has changes" — rule #29 extended to the merge step).

This file is authoritative for the whole merge step: the guards, the merge, the cleanup gate and the handoff text.

🔴 **Standing bans for every step below** (violating one loses the user's parallel uncommitted work, #29):
- **never push** — worktree mode merges locally and stops (push = `/ow-git`)
- **never `git reset --hard` / `git stash` / `git checkout --` / `git clean`** to force the merge through
- **never delete the worktree until the merge succeeded *and* was verified** (7.3.0) and **never `--force`
  before gates 7.3.1-7.3.2 both pass** — deleting before verify/absorb = unpushed commits lost permanently

## 7.1 Pre-merge guards (any fail = STOP, keep the worktree, non-destructive)
```bash
# defensive re-read (bash blocks are separate calls from Phase 0.5 → vars do not persist): merge is a critical step, must be self-sufficient
[ -n "$WT" ] || WT=$(grep -m1 '^worktree_dir:' "$PLAN_FILE" | sed -E 's/^worktree_dir:[[:space:]]*//')
[ -n "$BR" ] || BR=$(grep -m1 '^worktree_branch:' "$PLAN_FILE" | sed -E 's/^worktree_branch:[[:space:]]*//')
[ -n "$BASE" ] || BASE=$(grep -m1 '^worktree_base:' "$PLAN_FILE" | sed -E 's/^worktree_base:[[:space:]]*//')
[ -n "$REPO" ] || { REPO=$(grep -m1 '^worktree_repo:' "$PLAN_FILE" | sed -E 's/^worktree_repo:[[:space:]]*//'); REPO="${REPO:-$MAIN_ROOT}"; }
[ -n "$BR" ] && [ -n "$BASE" ] && [ -n "$REPO" ] || { echo "🛑 worktree fields incomplete in $PLAN_FILE — skipping merge (worktree kept)"; exit 0; }
SLUG="${BR#plan/}"
CUR=$(git -C "$REPO" rev-parse --abbrev-ref HEAD)
if [ "$CUR" != "$BASE" ]; then
  echo "🛑 main tree is on branch '$CUR', not base '$BASE' — not checking out (guards your uncommitted work)"
  echo "   worktree kept: $WT — return to '$BASE' and re-run /ow-test, or merge yourself: git -C \"$REPO\" merge --no-ff $BR"
  exit 0    # not an error — just not ready to merge yet
fi
git -C "$REPO" log "$BASE..$BR" --oneline | head -1 >/dev/null 2>&1 \
  || { echo "ℹ️ no new commits on $BR (empty worktree?) — skipping merge"; exit 0; }
```
🔴 **Never `git checkout $BASE`** — the main tree is already on base (guard above); if it is not = STOP (no switch = no risk to the user's work)
🔴 **Never `git pull`** — this flow is local only (push/sync = `/ow-git`)
🔴 A worktree cut from `origin/$BASE` (`_shared/worktree.md` §1, multi-person path) carries those
upstream commits with it, so this merge advances local `$BASE` past where it was. That is intended —
it is still **local, no fetch, no push**; nothing here reaches origin

## 7.2 Non-destructive merge (--no-ff, local)
```bash
TITLE=$(grep -m1 '^title:' "$PLAN_FILE" | sed -E 's/^title:[[:space:]]*//; s/^"//; s/"$//')
git -C "$REPO" merge --no-ff "$BR" -m "Merge plan/$SLUG: ${TITLE:-$SLUG}

<Co-Authored-By per project convention>"
if [ $? -ne 0 ]; then
  # git refused/conflict — non-destructive: abort restores the pre-merge state (the user's uncommitted work stays intact)
  git -C "$REPO" merge --abort 2>/dev/null || true
  echo "🛑 merge failed (conflict, or a local change overlaps a file the merge touches) — main tree restored to its pre-merge state"
  echo "   your uncommitted work is intact · worktree + branch kept: $WT ($BR)"
  echo "   resolve yourself: cd \"$REPO\" && git merge --no-ff $BR    (or enter the worktree and fix the conflict)"
  exit 0
fi
MERGE_SHA=$(git -C "$REPO" rev-parse HEAD)
```
🔴 **`git merge` non-destructive by design** — if it would overwrite a file holding a local uncommitted change → git **aborts by itself, never overwrites**;
we run `merge --abort` again to leave the index clean, then STOP. **Never `reset --hard` / `git stash` / `git checkout --` / `git clean`**
to force the merge through = deletes the user's uncommitted work (#29). A conflict is the user's job, not the skill's.

## 7.3 Cleanup + record (only on a successful merge — gate before deleting)

🔴 **Invariant: never delete the worktree until (1) every scenario PASS (2) the merge succeeded (3) the cleanup
gate passes** — any one of them missing → always keep the worktree (deleting later is possible; a wrong delete is unrecoverable)

🔴 **Read `.ow/commands/_shared/worktree-cleanup-gate.md` and follow it** — it owns the gate
(merge verified → worktree clean → submodule objects absorbed) and the delete step, shared with `/ow-fix-issue` 5.3.
Run its §1 with `ow_wt_gate "$REPO" "$WT" "$BR"` — it returns non-zero → **STOP here** (`exit 0`, worktree kept,
7.4 reports it honestly), never delete. It returns 0 → run 7.3.2b below, **then** its §2 delete in the same bash block.

```bash
# 7.3.2b — worktree mode: also advance each submodule repo's OWN mainline (develop/master) so it absorbs the work (#31)
# the superproject merge just pinned a new gitlink (7.2) but the submodule repo itself is still on the old commit → plan/<slug>
# becomes an orphan branch inside the submodule (from the submodule repo's own view the work is invisible). The objects are fully
# absorbed into the main store (7.3.2 gate passed) → the merge is safe and local. non-destructive: dirty/wrong branch = skip + report
RES="$REPO/scripts/ow-paths.sh"
SUB_MERGE_NOTE=""
while IFS=$'\t' read -r SUB RO SUBBR; do
  [ -n "$SUB" ] || continue
  [ "$RO" = "true" ] && continue                             # read-only submodule (e.g. figma) → never touched
  SUB="${SUB#./}"
  [ -n "$SUBBR" ] || { SUB_MERGE_NOTE="$SUB_MERGE_NOTE\n   ⚠️ $SUB: no submodules[].branch in .ow.yml — skipped (set branch so the mainline absorbs the work)"; continue; }
  TGT=$(git -C "$REPO" ls-tree HEAD "$SUB" | awk '$2=="commit"{print $3}')   # the gitlink SHA the merge just pinned = the plan's new commit
  [ -n "$TGT" ] || continue
  git -C "$REPO/$SUB" cat-file -e "$TGT" 2>/dev/null || { SUB_MERGE_NOTE="$SUB_MERGE_NOTE\n   ⚠️ $SUB: objects $TGT are not in the main store — skipped (the gitlink is still pinned correctly)"; continue; }
  git -C "$REPO/$SUB" merge-base --is-ancestor "$TGT" "$SUBBR" 2>/dev/null && continue   # $SUBBR already has the work → silent
  SCUR=$(git -C "$REPO/$SUB" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$SCUR" != "$SUBBR" ]; then
    SUB_MERGE_NOTE="$SUB_MERGE_NOTE\n   ⚠️ $SUB: main tree is on '$SCUR', not '$SUBBR' — skipped (guards uncommitted work); merge yourself: git -C $REPO/$SUB checkout $SUBBR && git merge $TGT"
    continue
  fi
  if [ -n "$(git -C "$REPO/$SUB" status --porcelain 2>/dev/null)" ]; then
    SUB_MERGE_NOTE="$SUB_MERGE_NOTE\n   ⚠️ $SUB: has uncommitted changes — merge skipped (keeps the user's work); merge yourself: git -C $REPO/$SUB merge $TGT"
    continue
  fi
  # a plain merge = fast-forward while $SUBBR has not diverged (the worktree branched off the mainline tip ⇒ FF is the norm):
  # develop → exactly $TGT = the gitlink matches the superproject (does not dirty the monorepo). Diverged → git makes a merge commit itself
  if git -C "$REPO/$SUB" merge "$TGT" -m "Merge plan/$SLUG into $SUBBR"; then
    if [ "$(git -C "$REPO/$SUB" rev-parse HEAD)" = "$TGT" ]; then
      echo "   ✅ $SUB: $SUBBR fast-forward → plan/$SLUG ($(git -C "$REPO/$SUB" rev-parse --short HEAD))"
    else
      echo "   ✅ $SUB: $SUBBR ← plan/$SLUG (merge $(git -C "$REPO/$SUB" rev-parse --short HEAD)) — the superproject gitlink is bumped at /ow-git"
    fi
  else
    git -C "$REPO/$SUB" merge --abort 2>/dev/null || true    # a conflict is the user's job; restore state, never force it with reset --hard (#29)
    SUB_MERGE_NOTE="$SUB_MERGE_NOTE\n   ⚠️ $SUB: merge conflict on '$SUBBR' — skipped (main tree restored); resolve yourself: git -C $REPO/$SUB merge $TGT"
  fi
done < <(bash "$RES" --submodules 2>/dev/null)
[ -n "$SUB_MERGE_NOTE" ] && printf 'ℹ️ submodule mainline merge — some were skipped:%b\n' "$SUB_MERGE_NOTE"

# 7.3.3 — delete: the gate's §2 (R/W/B are already set by ow_wt_gate above)
```
🔴 **The submodule mainline merge (7.3.2b) is local + non-destructive** — wrong branch / dirty / conflict = **skip that one + report** (never `reset --hard`/`checkout`/`stash` to force it through, #29); no push (push = `/ow-git`). FF possible ⇒ the superproject gitlink still matches; diverged ⇒ a merge commit + `/ow-git` bumps the gitlink for you
🔴 7.3.2b runs **inside** the gate's window — after `ow_wt_gate` returned 0, before its §2 delete. It never
re-opens the question of whether deleting is safe: a skipped submodule merge leaves the gitlink correctly pinned.

Update `$PLAN_FILE` frontmatter (surgical **Edit**, MAIN_ROOT): `merge_commit: <MERGE_SHA>` in every case where the merge succeeded;
`worktree_status: merged` when cleanup finished completely / `worktree_status: merged-cleanup-pending` when the gate STOPped it

## 7.4 Handoff

Print `+ cleanup worktree` **only when 7.3 finished completely** (gate passed + deleted) — never report a partial cleanup as a full ✅
(render in `$PROJECT_LANG`):
```
✅ Smoke PASS → merged plan/<slug> into <base> (local, <sha>) + cleanup worktree
   main tree: <base> @ <sha> (not pushed)
🎯 Next: /ow-git --bump   # push + version bump (— /ow-test never pushes)
```
If the cleanup gate STOPped it (merge succeeded but cleanup pending):
```
✅ Smoke PASS → merged plan/<slug> into <base> (local, <sha>)
🛑 worktree kept: <WT> — <reason: uncommitted changes / submodule objects not absorbed yet>
   Never delete it yourself with --force until every gitlink resolves from the main store
```
