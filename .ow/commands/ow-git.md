---
description: Submodule-aware git ops — commit, push, branch, merge across main repo + submodules from plan/fix scope
---

# ow-git — Submodule-aware git ops

Commit + push both submodules + main repo per plan/fix scope, or free text

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
/ow-git --plan <vault>/80-ImplementPlan/<slug>.md
/ow-git --plan <vault>/80-ImplementPlan/<slug>.md --bump patch   # plan has source_fix: → stamp fixed_in_version + fixed_commit into the fix-log (Phase 8.6)
/ow-git --fix <vault>/85-FixLog/<slug>.md [--bump patch]          # push → comment version + flip label on every issue it Closes (Phase 8.5)
/ow-git --message "feat: add search"
/ow-git --status | --pull | --branch <name> | --merge-to default | --no-push | --no-sync
```

## What reads what — keep the everyday path small

| Fragment | Read only when |
|---|---|
| `_shared/git-conflict.md` | Phase 2.5 left a repo at exit 3 (Phase 2.6) |
| `_shared/git-bump.md` | the user passed `--bump` (Phase 5.5 + hooks in Phase 6/7) |
| `_shared/git-post-push.md` | a Phase 8.5 / 8.6 gate holds after a successful push |
| `_shared/git-sync.md` | a sync helper returned an exit code this spec does not handle, or you need the conflict-class table |

A plain `--plan` / `--fix` / `--message` commit opens **none** of them.

## Rules

- **Never run automatically** — only when the user invokes it (Phase 8.5 is a sub-step of a push the user asked for)
- **Default = no bump (opt-in)** — omitting `--bump` = no tag, no version file, no `[vX.Y.Z]`. 🔴 Never add `--bump` yourself — even when `/ow-test` / `/ow-implement` suggests "Next: `/ow-git --bump`"; a version bump is the user's decision only
- **Auto-sync (Phase 2.5)** — default-on (`git.auto_sync`, off per run with `--no-sync`); no remote / offline → skipped silently
- **Auto issue-handoff (Phase 8.5)** — a push containing `Closes #NN` → comment "fixed in vX.Y.Z" + flip label `ready for test` (off with `--no-ready-for-test`); never close the issue
- Submodules come from the resolver (`.ow.yml` `submodules:`); read-only ones (e.g. figma) and ones with nothing staged are skipped silently; main commits after every submodule pushed
- **Worktree mainline push (#31)** — a submodule with nothing staged whose branch leads upstream is pushed too

## Phase 1 — Parse args

| Flag | Purpose |
|---|---|
| `--plan <path>` / `--fix <path>` | Scope staged files from the plan / fix-log + auto message (`fix:` prefix for `--fix`) |
| `--message "<msg>"` | Explicit message |
| `--branch <name>` · `--branch default` · `--create-branch` · `--switch-only` | Switch main + submodules (except read-only); `default` = branch from `.gitmodules`; switch-only = no commit |
| `--status` | Branch + dirty state + ahead/behind per repo |
| `--pull` | Alone: sync only, then stop. With work flags: no-op (sync is default-on) |
| `--no-sync` · `--rebase` · `--merge` | Skip Phase 2.5 · force its strategy for this run |
| `--no-push` | Commit only |
| `--bump patch\|minor\|major` | **opt-in** unified bump → `_shared/git-bump.md` |
| `--merge-to <branch\|default>` · `--no-ff` · `--delete-source` | Phase 8 |
| `--no-ready-for-test` | Turn off Phase 8.5 |

Message precedence: `--message` > free text > auto-from-plan/fix > prompt user

## Phase 2 — Status / Switch-only

`--status` or `--switch-only` → branch ops only, no stage/commit/push.

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  echo "=== $repo ==="
  git -C "$repo" branch --show-current
  git -C "$repo" status --short
  [ -x "$SYNC" ] && bash "$SYNC" status "$repo" | awk -F'\t' '{printf "  ahead %s · behind %s · %s\n",$1,$2,$3}'
done
```

## Phase 2.5 — Sync with origin (every run that will commit/push)

Skip silently on `--status` · `--switch-only` · `--no-sync` · `git.auto_sync: false`.

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
if [ ! -x "$SYNC" ]; then
  # /ow-sync ships commands/ but not scripts/ — degrade, never fail
  echo "⚠️  scripts/ow-git-sync.sh missing — auto-sync skipped. Run \`bash scripts/upgrade.sh\` to enable it."
else
  [ "$rebase_flag" = "1" ] && export OW_GIT_STRATEGY=rebase
  [ "$merge_flag"  = "1" ] && export OW_GIT_STRATEGY=merge
  OW_ROOT="$(git rev-parse --show-toplevel)"
  : > "$OW_ROOT/.ow/local/sync-conflicts"
  for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
    out=$(bash "$SYNC" sync "$repo"); rc=$?
    echo "$repo: $out"
    case $rc in
      0|4) ;;                                # synced / in sync / offline-solo
      3)   case "$out" in
             *autostash*)                    # the user's uncommitted work — never an AI merge target
               echo "🛑 $repo — stash pop conflict. Nothing was staged, committed, pushed or bumped."
               bash "$SYNC" classify "$repo"
               echo "   your work is safe twice: the markers in the file, and \`git stash list\`"
               echo "   resolve → git add <file> && git stash drop → re-run this command"
               exit 1 ;;
             *) echo "$repo" >> "$OW_ROOT/.ow/local/sync-conflicts" ;;
           esac ;;
      *)   echo "🛑 $repo — git sync failed"; exit 1 ;;
    esac
  done
fi
```

`.ow/local/sync-conflicts` non-empty → **Phase 2.6**: 🔴 Read `.ow/commands/_shared/git-conflict.md` and run it.
🔴 **Exit 3 ends the command** — after Phase 2.6 has had its turn. Never commit on top of an unfinished rebase
🔴 Every `resolved` line the helper prints goes into the Phase 9 report

## Phase 3 — `--pull` (sync-only gate)

```bash
if [ "$pull_flag" = "1" ] && [ -z "${plan:-}${fix:-}${message:-}${free_text:-}" ]; then
  echo "✅ sync only — nothing staged, committed or pushed"; exit 0
fi
```

🔴 **Sync-only never commits** — no commit prompt, no empty commit, no push.

## Phase 4 — Scope staged files (if --plan / --fix)

Stage only the plan/fix-log `Affected Files`; tell the user which dirty files were skipped.

```bash
files=$(grep -oP '`[^`]+`' "$plan" | head -50 | tr -d '`')
for f in $files; do git add "$f"; done
```

## Phase 4.5 — Secret scan (staged diff only)

A quick gate, not `/ow-secure` (that stays the user's pre-flight).

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  git -C "$repo" diff --cached -U0 | grep -E '^\+' \
    | grep -qE 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]+ PRIVATE KEY-----|gh[ps]_[A-Za-z0-9]{36,}|sk-[A-Za-z0-9]{32,}|xox[bpoa]-[0-9a-zA-Z-]{10,}|AIza[0-9A-Za-z_-]{35}' \
    && { echo "🛑 $repo: possible secret in staged diff — nothing committed. Run /ow-secure to locate it."; exit 1; }
done
true
```

## Phase 5 — Commit message

`--message` > free text > auto (`feat(<area>): <plan title>` · `fix(<area>): <fix title>`) > prompt user.
`--bump` → 🔴 Read `.ow/commands/_shared/git-bump.md` and run §1 now (Phase 5.5); it sets `TARGET_VERSION` + `VERSION_TAG`.

## Phase 6 — Commit + push per submodule

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
bash "$RESOLVER" --submodules | while IFS="$(printf '\t')" read -r sub ro subbr; do
  [ "$ro" = "true" ] && continue
  [ -n "$sub" ] || continue
  cd "$sub"; repo="$sub"
  br=$(git branch --show-current)
  if [ -z "$(git diff --cached --name-only)" ]; then
    # nothing staged, but /ow-test may have merged a worktree into the mainline locally (#31)
    up="@{upstream}"; git rev-parse --verify --quiet "$up" >/dev/null 2>&1 || up="origin/$br"
    ahead=$(git rev-list --count "$up..HEAD" 2>/dev/null || echo 0)
    if [ "${ahead:-0}" -gt 0 ] && [ "$no_push" != "1" ]; then
      bash "$SYNC" push "$sub" "$br" || { echo "🛑 $sub: push failed — see above"; exit 1; }
      echo "ℹ️ $sub: nothing staged but $br leads upstream by $ahead commit — pushed (#31)"
    fi
    cd -; continue
  fi
  # --bump: git-bump.md §2 here (version files)
  git commit -m "$msg${VERSION_TAG:+ $VERSION_TAG}"
  if [ "$no_push" != "1" ]; then
    if [ ! -x "$SYNC" ]; then git push origin "$br"; rc=$?; else bash "$SYNC" push "$sub" "$br"; rc=$?; fi
    [ $rc -eq 3 ] && { echo "🛑 $sub: conflict while re-syncing for push — resolve, then re-run"; exit 1; }
    [ $rc -eq 0 ] || { echo "🛑 $sub: push rejected — see above"; exit 1; }
  fi
  # --bump: git-bump.md §3 here (tag + tag push)
  cd -
done || exit 1     # the loop is a pipeline subshell — without this an exit inside it would not stop Phase 7
```

🔴 Push goes through `scripts/ow-git-sync.sh push` (re-syncs + retries on a teammate's push), never `--force`

## Phase 7 — Main repo commit

Stage submodule pointer updates + main repo files in scope, then:

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
BR=$(git branch --show-current); repo=.
# --bump: git-bump.md §2 here (main's root VERSION = canonical)
git commit -m "$msg${VERSION_TAG:+ $VERSION_TAG}"
if [ "$no_push" != "1" ]; then
  if [ ! -x "$SYNC" ]; then git push origin "$BR"; rc=$?; else bash "$SYNC" push . "$BR"; rc=$?; fi
  [ $rc -eq 3 ] && { echo "🛑 main: conflict while re-syncing for push — resolve, then re-run"; exit 1; }
  [ $rc -eq 0 ] || { echo "🛑 main: push rejected — see above"; exit 1; }
fi
# --bump: git-bump.md §3 here (tag + tag push)
```

## Phase 8 — Merge-to (optional)

`--merge-to <branch>` per repo: checkout target → `bash "$SYNC" sync <repo>` (exit 3 → STOP before
the merge; 4 → carry on) → `merge --no-ff` source → `bash "$SYNC" push <repo> <target>`.
`--delete-source` → delete source local + remote, only after verifying it is merged.

## Phase 8.5 / 8.6 — post-push side effects

Run **only after a successful push** (never on `--no-push` / `--status` / `--switch-only`):

- **8.5 issue-handoff** — the pushed commits carry `Closes` / `Fixes` / `Resolves #NN`, **or**
  `--fix <fix-log>` whose fix-log has `github_issue:` — and no `--no-ready-for-test`
- **8.6 fix-log version stamp (#30)** — `--bump` ran **and** a local fix-log is finalized:
  `--plan` whose plan has `source_fix:`, **or** `--fix` whose fix-log has `fixed_commit: pending`

Neither gate holds → Phase 9. Either holds → 🔴 Read `.ow/commands/_shared/git-post-push.md` and run it.

## Phase 9 — Report

```
git-sync summary
================
Repo   Branch     Pushed             Version
api    [develop]  8a77a02..2f7e850   v0.2.78
main   [main]     99027c0..163b39e   v0.2.78
figma  [read-only] —                 skipped

sync (Phase 2.5)                    api ↻rebased +2 · main in-sync
auto-resolved                       docs/obsidian-vault/40-Functions/FN-Search.md (vault-ai ← 2026-06-08-1533-bar, 2026-06-08-1610-baz)
ready-for-test handoff (Phase 8.5)  v0.2.78:  #62 #63 → ready for test ✅
```

Version column only with `--bump` (same number in every repo). Sync / auto-resolved / handoff / stamp
lines only when they happened — but **never drop an `auto-resolved` row**. No 'Fixes' column.

## Output (short bullets, in `$PROJECT_LANG`)

What was done · real commit hash + push result per repo (from actual git — never fabricated) ·
open items (skipped files, conflicts) · next step.

## Never

- `git push --force` (never at all in the sync/retry path) · `git reset --hard` · `git rebase --abort` on the user's behalf
- Commit / push / bump after a sync returned exit 3
- Commit in a read-only submodule · delete a branch not verified merged
- Move a tag that already exists on origin (exit 5)
- Resolve a conflict without listing it in the report · AI-merge a file outside the vault
