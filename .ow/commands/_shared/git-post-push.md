# Shared — /ow-git post-push side effects (Phase 8.5 + 8.6)

## Phase 8.5 — Auto issue-handoff (ready-for-test) — **after a successful push**

Purpose: when this push closes a GitHub issue (`Closes #NN`) → comment "fixed in vX.Y.Z" + flip the label for the tester automatically **within one session** (no separate `/ow-fix-issue --ready-for-test` call needed), because `/ow-git --bump` already knows the exact version number

### 8.5.1 Trigger gate (all must hold — otherwise skip silently)
- ✅ a push actually happened (not `--no-push` / `--status` / `--switch-only`)
- ✅ **an issue ref exists in the commits just pushed** — scan `Closes #NN` / `Fixes #NN` across the pushed commit range (every repo) **or** `--fix <fix-log>` carrying `github_issue:` frontmatter
- ✅ **no** `--no-ready-for-test`

> An ordinary commit (plan/feat with no `Closes #NN`) → gate fails → no issue is touched (safe for everyday `/ow-git` use)

### 8.5.2 Collect the issue numbers this push closes
```bash
# RESOLVER = "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" (Phase 2)
# range = the commits pushed in this round: capture each repo's origin ref before the push (Phase 6/7)
#         then use "<pre-push remote sha>..HEAD" (or git log @{push}..HEAD after the push)
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  git -C "$repo" log "${PREPUSH_REF[$repo]}"..HEAD --format=%B 2>/dev/null \
    | grep -ioE '(close[sd]?|fixe?[sd]?|resolve[sd]?) #[0-9]+' | grep -oE '#[0-9]+'
done | sort -u
```
(`--fix` mode: also add the numbers from the fix-log `github_issue:`)

### 8.5.3 Resolve version (authoritative from this bump)
- If `--bump` was used this round → use **`$TARGET_VERSION` from Phase 5.5** (unified — one number across every submodule) directly, no detection needed
- If there was no bump → fall back to `/ow-fix-issue` Phase 8.3 (commit `[vX.Y.Z]` token > `git describe --tags`); nothing found → hand off without a version (fix-issue Phase 8 warns + does not flip)

### 8.5.4 Delegate to `/ow-fix-issue` Phase 8 (reuse the one logic — never duplicate)
```
/ow-fix-issue <#NN #MM ...> --ready-for-test --version <vX.Y.Z>
```
Continues in the current session — fix-issue Phase 8 runs verify-pushed (8.2, already passing since we just pushed) → comments the version + flips `in progress`→`ready for test` (8.4) → updates the fix-log `fixed_in_version` (8.5)

🔴 **No duplicated logic** — Phase 8.5 only detects + invokes; comment/flip/verify live in `/ow-fix-issue` Phase 8 alone (single source)
🔴 **The never-close rule still holds** — the handoff only flips to ready-for-test; the tester verifies before closing

### 8.5.5 Roll the result into the Report (Phase 9)
Show in the summary which issues were commented + flipped (or skipped, with the reason)

## Phase 8.6 — Fix-log version stamp (#30) — **after a successful push**

Purpose: when a `--bump` push closes out a local fix-log (`/ow-implement` set `fixed_commit: pending` in Phase 6.5 because the commit/version did not exist yet) → fill in `fixed_in_version` + `fixed_commit` (real sha) on the fix-log — **a mirror of 8.5**, but a local fix-log has no GitHub issue → **no comment / no label flip**, just stamp the frontmatter so it stays traceable. Covers both the plan-driven path and the `--from-fix` path

### 8.6.1 Trigger gate (all must hold, otherwise skip silently)
- ✅ `--bump` ran this round (`$TARGET_VERSION` non-empty = a real push + tag, Phase 5.5)
- ✅ a local fix-log is finalized by this push — found two ways:
  - **plan-driven** — `--plan <path>` whose plan has `source_fix:` (escalated via `/ow-plan fix:`)
  - **from-fix** — `--fix <fixlog>` whose fix-log has `fixed_commit: pending` (P2/P3 via `/ow-implement --from-fix`, no plan)

> No `--bump` / no `--plan` with `source_fix:` / no `--fix` with `pending` → gate fails → no fix-log is touched (safe for everyday `/ow-git` — same as 8.5). A fix-log carrying `github_issue:` goes to Phase 8.5 (not here)

### 8.6.2 Resolve fix-log + stamp
```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
[ -n "${TARGET_VERSION:-}" ] || exit 0          # no bump → no stamp
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
FIXLOG=""; AREA_HINT=""
if [ -n "${plan:-}" ]; then                      # plan-driven — "$plan" = --plan <path> arg (Phase 4 scope)
  SRC=$(grep -m1 '^source_fix:' "$plan" | sed -E 's/^source_fix:[[:space:]]*//; s/^"?\[\[//; s/\]\]"?$//; s/\.md$//')
  if [ -n "$SRC" ] && [ "$SRC" != "none" ]; then
    FIXLOG=$(find "$FIX_DIR" -maxdepth 1 -name "${SRC##*/}.md" 2>/dev/null | head -1)
    [ -n "$FIXLOG" ] || echo "⚠ source_fix points at a fix-log that cannot be found: $SRC (skipping stamp)"
    AREA_HINT=$(grep -m1 '^submodule_target:' "$plan" | sed -E 's/^submodule_target:[[:space:]]*//; s/[[:space:]].*$//')
  fi
elif [ -n "${fix:-}" ] && grep -q '^fixed_commit:[[:space:]]*pending' "$fix" 2>/dev/null; then
  FIXLOG="$fix"                                  # from-fix — "$fix" = --fix <fixlog> still pending (from /ow-implement --from-fix)
  AREA_HINT=$(grep -m1 '^area:' "$fix" | sed -E 's/^area:[[:space:]]*//; s/[[:space:]].*$//')
fi
[ -n "$FIXLOG" ] || exit 0                        # no fix-log to stamp → safe-skip (fabricate nothing)
# repo holding this work's commit: monorepo/all/docs/cross → "."; multi-repo → submodule per area/target
case "$AREA_HINT" in
  ""|all|docs|main|cross) FIX_REPO="." ;;
  *) FIX_REPO=$(bash "$RESOLVER" --submodules | awk -v s="$AREA_HINT" '$1==s{print;exit}'); [ -n "$FIX_REPO" ] || FIX_REPO="." ;;
esac
FIX_SHA=$(git -C "$FIX_REPO" rev-parse --short HEAD)   # real sha from git — never fabricated
```

Edit the frontmatter of `$FIXLOG` (surgical **Edit**):
- `fixed_in_version: v$TARGET_VERSION`   (the same number as the unified bump — Phase 5.5)
- `fixed_commit: $FIX_SHA`               (overwrites the `pending` that `/ow-implement` wrote in Phase 6.5)

🔴 **no fake results:** `fixed_in_version` = `$TARGET_VERSION` from Phase 5.5 (a real tag); `fixed_commit` = the real sha from git — never fabricate / never guess
🔴 A local fix-log has **no** GitHub issue → unlike 8.5: **never invoke** `/ow-fix-issue --ready-for-test`, no comment, no label flip — only stamp the 2 fields

### 8.6.3 Roll into the Report (Phase 9)
Show the line: `fix-log stamp (Phase 8.6) v$TARGET_VERSION: <fix-slug> ← plan <plan-slug>`
