# `_shared/worktree-cleanup-gate.md` — delete a merged worktree without losing commits

Read this before **any** worktree deletion: `/ow-test` Phase 7 (through `_shared/worktree-merge.md` §7.3) and
`/ow-fix-issue` Phase 5.3. Both delete a worktree whose commits exist **nowhere else** — neither flow pushes —
so one wrong `--force` is unrecoverable. This file is authoritative for the gate; no caller restates it.

🔴 **A superproject `merge --no-ff` records only the gitlink SHA — it does not copy submodule objects.**
A submodule inside a linked worktree keeps its objects **only** in the per-worktree store
(`.git/worktrees/<wt>/modules/<sub>/`), which dies together with `worktree remove --force`
⇒ deleting before absorbing them into the main store = the just-merged commits are **lost permanently**.
A repo with no submodules → gate 2 is a no-op and deletion proceeds as usual.

🔴 **Gate fails = keep the worktree, report it, move on** — never delete "to tidy up later". A single-worktree
caller STOPs (`exit 0`); a loop caller `continue`s to the next fix. Deleting later is always possible; a wrong
delete is not. "The merge succeeded" ≠ "the objects are safe".

**Precondition:** `$REPO` is already checked out on the base branch the merge landed on — each caller guarantees
it by **verifying, never switching** — both STOP rather than `checkout` when the repo is on another branch
(`/ow-test` 7.1 · `/ow-fix-issue` 5.1) ⇒ `HEAD` = that base tip.

## 1. The gate — all three must pass

Paste the function into the **same** bash block that does the deleting (a function does not survive across blocks):

```bash
ow_wt_gate() {                       # REPO WORKTREE BRANCH  →  0 = safe to delete · 1 = keep it
  R="$1"; W="$2"; B="$3"
  # gate 0 — the merge really happened: every commit of $B must already be an ancestor of base HEAD
  #          (self-sufficient — never trust control flow across bash blocks)
  git -C "$R" merge-base --is-ancestor "$B" HEAD 2>/dev/null || {
    echo "🛑 $B is not fully merged into base — never delete the worktree (kept: $W)"; return 1; }
  # gate 1 — the worktree must be clean (never --force away anyone's uncommitted work)
  [ -n "$(git -C "$W" status --porcelain 2>/dev/null)" ] && {
    echo "🛑 worktree has uncommitted changes — kept: $W (merge already succeeded; check/commit yourself, then re-run)"; return 1; }
  # gate 2 — absorb submodule objects into the main store, then require every gitlink on HEAD to resolve
  CLEAN_OK=1
  while IFS=$'\t' read -r SHA SUB; do
    [ -n "$SHA" ] || continue
    git -C "$R/$SUB" cat-file -e "$SHA" 2>/dev/null && continue        # already in the main store
    git -C "$R/$SUB" fetch --no-tags "$W/$SUB" HEAD 2>/dev/null        # pull the objects out of the worktree
    git -C "$R/$SUB" cat-file -e "$SHA" 2>/dev/null && continue
    CLEAN_OK=0; echo "   ⚠️ submodule '$SUB' @ $SHA — objects are not in the main store yet"
  done < <(git -C "$R" ls-tree -r HEAD | awk -F'\t' '{split($1,m," ")} m[1]=="160000" {print m[3] "\t" $2}')
  [ "$CLEAN_OK" -eq 1 ] || {
    echo "🛑 worktree kept: $W — deleting now = the already-merged submodule commits are lost permanently (not pushed yet)"
    echo "   fix: git -C \"$R/<sub>\" fetch \"$W/<sub>\" HEAD   until every gitlink resolves, then delete it yourself:"
    echo "        git -C \"$R\" worktree remove --force \"$W\""
    return 1; }
  return 0
}
```

## 2. Delete — only once §1 returned 0

```bash
git -C "$R" worktree remove "$W" 2>/dev/null || git -C "$R" worktree remove --force "$W"
git -C "$R" branch -d "$B" 2>/dev/null || true     # -d (merged-only) is safe — never -D
```

🔴 `--force` is legitimate **only here**: it is required for a worktree that carries submodules (git refuses the
plain form), and it is safe only because §1 proved the objects already live in the main store.
