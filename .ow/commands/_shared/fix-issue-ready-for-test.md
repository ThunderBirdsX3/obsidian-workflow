# `_shared/fix-issue-ready-for-test.md` — `--ready-for-test` handoff (`/ow-fix-issue` Phase 8)

Read this **only when `$ARGUMENTS` carries `--ready-for-test`** — that mode skips Phases 0.5-7 entirely, and no
other mode reads this file.

Purpose: after push + version bump are done → **tell the tester which version the fix is in** (guards against a
tester using an old build and reporting wrongly that "it is still broken") + flip the label `in progress` →
`ready for test` automatically.

## 8.0 Resolve label set (config-aware)
Use the same label names as `/ow-triage-issues` (Phase 0.2) — default `in progress` / `ready for test`; if the project overrides them in `.ow.yml` `triage.labels.*`, read those values instead (yq read; default when the block is absent):
```bash
CFG="$(git rev-parse --show-toplevel)/.ow.yml"
IN_PROGRESS=$(yq -r '.triage.labels.in_progress // "in progress"' "$CFG" 2>/dev/null || echo "in progress")
READY=$(yq -r '.triage.labels.ready_for_test // "ready for test"' "$CFG" 2>/dev/null || echo "ready for test")
```

## 8.1 Resolve issue set + fix-log
- `#NN` present in args → use only those
- absent → scan `$FIX_DIR` (85-FixLog) for fix-logs with `status: fixed` + a `github_issue:` + **no** `fixed_in_version:` yet (= never handed off)

For each issue → read the fix-log frontmatter: `github_issue`, `worktree`/repo (submodule), base branch, `## 🔧 Fix.Commit` (the merge commit hash on base — from Phase 5.4)

## 8.2 🔴 Verify pushed (no-fake-results gate)
Before flipping you must confirm the fix **really reached the remote** — otherwise the tester will not find the build:
```bash
git -C "$REPO" fetch origin "$BASE" --quiet
git -C "$REPO" branch -r --contains "$MERGE_SHA" | grep -q "origin/$BASE" \
  || { echo "⏭️ #$NN — merge $MERGE_SHA is not on origin/$BASE yet → skipped (run /ow-git push first)"; continue; }
```
Not pushed yet → **skip that issue** + tell the user (never flip/comment while it is unpushed)

## 8.3 🔴 Resolve version (vX.Y.Z — never fabricate)
In order:
1. `--version <X.Y.Z>` in args → use it (authoritative)
2. read the `[vX.Y.Z]` token from the commit message of the merge/bump commit on the base branch (appended by `/ow-git --bump`):
   ```bash
   VER=$(git -C "$REPO" log origin/"$BASE" -1 --format=%B | grep -oE '\[v[0-9]+\.[0-9]+\.[0-9]+\]' | head -1 | tr -d '[]v')
   ```
3. still nothing → `git -C "$REPO" describe --tags --abbrev=0 origin/$BASE` (latest reachable tag)
4. still nothing → **never guess** — post the comment without a version + add the line `⚠️ version: not found — specify /ow-fix-issue #NN --ready-for-test --version X.Y.Z` + keep the `in progress` label (do not flip until the version is known)

> 🔴 **no fake results:** the version must come from a real arg / commit-token / git tag only — **never fabricate the version**, never compute or guess the number

## 8.4 Comment version + flip label (auto, per issue)
For each issue that passed 8.2 + has a version from 8.3 (comment body rendered in `$PROJECT_LANG` — the template below is the English rendering):
```bash
gh issue comment "$NN" --body "✅ **Fixed — ready to test in v${VER}**

- Please test on **v${VER} or newer** (older versions do not carry the fix — the results will not match)
- Repo/branch: \`${REPO}/${BASE}\` @ \`${MERGE_SHA:0:7}\`
- Fix-log: <link fix-log> · Test-plan: <link test-plan, if any>

— Marked ready by \`/ow-fix-issue --ready-for-test\`"

gh issue edit "$NN" --remove-label "$IN_PROGRESS" --add-label "$READY"
```
🔴 **Comment before editing the label** — so the version note is in the issue history before the state changes
🔴 **Comment is rendered in `$PROJECT_LANG`** (from `project.language`)
🔴 **Never close the issue** — the tester verifies first, then the user/tester closes it (rule unchanged)

## 8.5 Update fix-log (traceability)
Per fix-log → frontmatter: `fixed_in_version: v<X.Y.Z>` + `status: ready-for-test` (guards against a duplicate handoff on the next auto-scan)

## 8.6 Report
```
✅ Ready-for-test handoff — N issues
  ✅ #62 — v1.4.2, label → ready for test, comment posted (web/develop @ abc1234)
  ✅ #63 — v1.4.2, label → ready for test, comment posted
  ⏭️ #74 — skipped: not pushed yet (run /ow-git first)
  ⚠️ #71 — pushed but no version found → specify --version
```
