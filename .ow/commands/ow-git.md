---
description: Submodule-aware git ops — commit, push, branch, merge across main repo + submodules from plan/fix scope
---

# ow-git — Submodule-aware git ops

Commit + push both submodules + main repo per plan/fix scope, or free text

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble. Step 1 (resolver eval + assert + export) is byte-identical in every command and conformance-lint check 8 fails on any drift. Step 2 is per-command only in its `--rules <area>` argument (/ow-fix-issue extends it for multi-area + rules-validate). Do NOT edit anything else per-command. -->

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

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
/ow-git --plan <vault>/80-ImplementPlan/<slug>.md --bump patch   # if the plan has source_fix: → auto stamp fixed_in_version + fixed_commit into the fix-log (Phase 8.6)
/ow-git --fix <vault>/85-FixLog/<slug>.md
/ow-git --fix <vault>/85-FixLog/<slug>.md --bump patch   # push+bump → auto comment version + flip label on every issue it Closes (Phase 8.5)
/ow-git --message "feat: add search"
/ow-git --branch <name>
/ow-git --status
/ow-git --pull                        # sync only — fetch + rebase every repo, then stop (no commit)
/ow-git --no-sync                     # skip the Phase 2.5 auto-sync for this run only
/ow-git --merge-to default
/ow-git --no-push
/ow-git --fix <...> --bump patch --no-ready-for-test    # push+bump but leave issues untouched (auto-handoff off)
```

## Rules

- **Never run automatically** — run only when the user invokes it (the Phase 8.5 issue-handoff is a sub-step of a push the user asked for, not the command running itself)
- **Auto-sync (Phase 2.5)** — every run that will commit/push first fetches + rebases onto origin, so two people on the same branch never fight over a non-fast-forward push. Default-on (`git.auto_sync`, off per run with `--no-sync`); no remote / offline → skipped silently. A conflict it cannot resolve → **STOP before staging** (nothing committed, nothing pushed, nothing bumped)
- **Auto issue-handoff (Phase 8.5)** — a push containing `Closes #NN` → auto comment "fixed in vX.Y.Z" + flip label `ready for test` (default-on; turn it off with `--no-ready-for-test`); the **never close** issue rule still holds
- **Auto fix-log stamp (Phase 8.6)** — a `--bump` push of a plan that has `source_fix:` → stamp `fixed_in_version` + `fixed_commit` (real sha) into the source fix-log (mirror of 8.5 for a local fix-log: no comment / no label flip) (#30)
- **Unified bump version (Phase 5.5)** — `--bump` computes `TARGET_VERSION` once (= bump from the max of every repo's current version), then uses the same number for tag + commit-tag + version file in every repo **including main** (main = canonical version, moves on every `--bump`); never bump repos separately until the versions diverge (config `version_bump.unified`, default true). The version file is written by `scripts/ow-version.sh` (bare semver, read-back verified) and a **format gate runs before commit/tag/push** — a malformed bump aborts instead of shipping (#34)
- **Default = no bump (opt-in)** — omitting `--bump` = `--no-bump`: no tag, no version file written, no `[vX.Y.Z]` appended. 🔴 Never add `--bump` yourself — even when another phase/command (`/ow-test`, `/ow-implement`) suggests "Next: `/ow-git --bump`"; a version bump is the user's decision only (they must invoke `--bump patch|minor|major` explicitly)
- Follows the `.ow.yml` `submodules:` list
- Submodule branches come from `.gitmodules` or config
- **Read-only submodules** (e.g. figma) → skip silently
- **Worktree mainline push (#31)** — a submodule with nothing staged but whose branch leads upstream (`/ow-test` Phase 7 already merged the worktree work into the mainline locally) → push it to origin too, otherwise the work is invisible on the submodule's own remote
- Main repo commits after every submodule has pushed
- Submodule with nothing staged → skip silently

## Phase 1 — Parse args

| Flag | Purpose |
|---|---|
| `--plan <path>` | Plan file → scope staged files + auto-generate commit message |
| `--fix <path>` | Fix log → scope + commit prefix `fix:` |
| `--branch <name>` | Switch main + submodules before commit (except read-only) |
| `--branch default` | Switch back to the branch from `.gitmodules` |
| `--create-branch` | Create the branch if it does not exist |
| `--message "<msg>"` | Explicit message |
| `--no-push` | Commit only |
| `--switch-only` | Switch only, no commit |
| `--status` | Show branch + dirty state + ahead/behind vs origin per repo |
| `--pull` | **Sync only** when it stands alone (no `--plan` / `--fix` / `--message` / free text): Phase 2.5 runs, then the command **ends** — nothing staged, committed or pushed. Combined with work flags it just forces the sync and the run continues |
| `--no-sync` | Skip the Phase 2.5 sync for this run (overrides `git.auto_sync: true`) |
| `--rebase` | Sync with `strategy: rebase` regardless of config (default) |
| `--merge` | Sync with `strategy: merge` regardless of config |
| `--bump patch\|minor\|major` | **opt-in** — bump version (**unified — one number across every submodule**, Phase 5.5) + tag + append `[vX.Y.Z]` |
| `--no-bump` | **(default)** — omitting `--bump` lands here: skip the bump entirely |
| `--merge-to <branch>` | After push → merge into the branch |
| `--merge-to default` | Merge into each repo's tracked branch |
| `--no-ff` | force `--no-ff` merge commit |
| `--delete-source` | After a successful merge → delete the source branch local + remote |
| `--no-ready-for-test` | Turn off auto issue-handoff (Phase 8.5) — no version comment / no label flip even when the push has `Closes #NN` |

Message precedence: `--message` > free text > auto-from-plan/fix > prompt user

## Phase 2 — Status / Switch-only modes

If `--status` or `--switch-only`: do branch ops only — no stage/commit/push

```bash
# Status example — main repo (.) + every submodule. Submodules come from the
# resolver TSV (path<TAB>read_only<TAB>branch), NOT jq: the config is YAML, so `jq` silently
# no-ops and the loop would iterate nothing (#4). The resolver also honors any
# .ow.local.yml override.
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  echo "=== $repo ==="
  git -C "$repo" branch --show-current
  git -C "$repo" status --short
  # ahead/behind vs origin — fetches first, so "0 behind" is never a stale-ref lie.
  # No remote / offline → prints "0 0 none" (exit 4) and the line just reads "local only".
  # Helper absent (a /ow-sync-only project) → the column is simply not shown.
  [ -x "$SYNC" ] && bash "$SYNC" status "$repo" | awk -F'\t' '{printf "  ahead %s · behind %s · %s\n",$1,$2,$3}'
done
```

## Phase 2.5 — Sync with origin (runs before staging, in every mode that will commit/push)

🔴 Read `.ow/commands/_shared/git-sync.md` — exit codes, conflict classes, invariants.

**Skip entirely** (and say nothing) when: `--status` · `--switch-only` · `--no-sync` ·
`git.auto_sync: false`. Otherwise it runs on **every** commit/push run, `--pull` or not.

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
# `/ow-sync` ships commands/ but never scripts/ (only scripts/upgrade.sh does) — so this
# spec can legitimately arrive in a project that does not have the helper yet. Degrade to
# the pre-sync behavior and say so; never fail the run over it.
if [ ! -x "$SYNC" ]; then
  echo "⚠️  scripts/ow-git-sync.sh missing — auto-sync skipped (single-person behavior)."
  echo "    run \`bash scripts/upgrade.sh\` to install it, then multi-person sync turns on."
else
  # --rebase / --merge override the configured strategy for this run only
  [ "$rebase_flag" = "1" ] && export OW_GIT_STRATEGY=rebase
  [ "$merge_flag"  = "1" ] && export OW_GIT_STRATEGY=merge

  for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
    [ -n "$repo" ] || continue
    out=$(bash "$SYNC" sync "$repo"); rc=$?
    echo "$repo: $out"
    case $rc in
      0|4) ;;                                # synced / already in sync / offline-solo → carry on
      3)   echo "🛑 $repo — conflict left for you. Nothing was staged, committed, pushed or bumped."
           bash "$SYNC" classify "$repo"
           case "$out" in
             # the rebase already finished — `rebase --continue` here is a dead end
             *autostash*)
               echo "   your work is safe twice: the markers in the file, and \`git stash list\`"
               echo "   resolve → git add <file> && git stash drop → re-run this command" ;;
             *)
               echo "   resolve → git add <file> && git rebase --continue   (or --abort) → re-run this command" ;;
           esac
           exit 1 ;;
      *)   echo "🛑 $repo — git sync failed"; exit 1 ;;
    esac
  done
fi
```

🔴 **Exit 3 ends the command** — never "sync failed, committing anyway". A commit on top of an
unfinished rebase is the exact damage this phase exists to prevent
🔴 **Every `resolved` line the helper prints must reach the Phase 9 report** — an auto-resolve the
user never hears about is a silent edit to their work
🔴 Read-only submodules are skipped by the loop's own read-only column (Phase 6), and a repo with
no remote returns exit 4 → a solo/offline project behaves exactly as it did before this phase existed
🔴 **Helper absent ⇒ degrade, never fail.** Phase 6/7 fall back to a plain `git push origin <branch>`
(the pre-sync behavior) and the report says auto-sync was off — a `/ow-sync`-only project keeps working.
Scope: **this sync helper only**. `scripts/ow-version.sh` (Phase 6/7 version writer) is the one helper
whose absence STOPs a `--bump`, because degrading there means an ad-hoc write — the defect itself (#34)

## Phase 3 — `--pull` (sync-only gate)

`--pull` carries no sync logic of its own — Phase 2.5 does the work, and `--rebase` / `--merge`
pick its strategy. Submodules sync in that same loop; there is no second pull path.

What `--pull` decides is **where the run stops**:

```bash
# "just update me" — /ow-git --pull with nothing else to do
if [ "$pull_flag" = "1" ] && [ -z "${plan:-}${fix:-}${message:-}${free_text:-}" ]; then
  echo "✅ sync only — nothing staged, committed or pushed"
  exit 0                      # ends after Phase 2.5; Phases 4-9 never run
fi
```

🔴 **Sync-only never commits.** A user asking to update must not get a commit prompt, an empty
commit, or a push — `git pull` does not commit either
🔴 With `--plan` / `--fix` / `--message` / free text present, `--pull` is redundant (Phase 2.5 is
already default-on) and the run continues normally
🔴 A conflict in this mode behaves like any other: Phase 2.5 exits 3, the rebase is left in place,
and the report tells the user how to finish it

## Phase 4 — Scope staged files (if --plan / --fix)

Read the plan/fix file → list `Affected Files` → stage only what is in that list

```bash
files=$(grep -oP '`[^`]+`' "$plan" | head -50 | tr -d '`')
for f in $files; do git add "$f"; done
```

A file not in the plan → not staged; tell the user which files were skipped

## Phase 5 — Generate commit message

Precedence order:
1. `--message`
2. Free text from `$ARGUMENTS`
3. Auto from plan/fix:
   - Plan: `feat(<area>): <plan title>` or `feat: <title>`
   - Fix: `fix(<area>): <fix title>`
4. Prompt user

Append the version tag (`$VERSION_TAG` from Phase 5.5) if `--bump` — **the same number in every repo**

## Phase 5.5 — Resolve unified bump version (if `--bump`)

🔴 **Every repo with a change in the same round must get the same version** — never bump separately until web=v0.2.76 / app=v0.2.77 (numbers diverge). Compute `TARGET_VERSION` **once**, then use it for every repo that commits
🔴 **The bumped version is the real one** (the git tag + the version file written) — the *number* must match, not just what the summary table shows. **The two are not the same string** (#34):

| what | value | why |
|---|---|---|
| git tag | `v$TARGET_VERSION` — e.g. `v0.3.36` | the `v` belongs on a git tag |
| version file | bare `$TARGET_VERSION` — e.g. `0.3.36` | `pubspec.yaml` / `package.json` / `Cargo.toml` **reject** a `v` and the release will not build |

`$TARGET_VERSION` is therefore always computed **bare** and the `v` is added only at `git tag` / `git push origin v…`. A `v` that leaks into the canonical version file poisons every future bump, because the next bump re-reads that same file

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
UNIFIED=$(echo "$VERSION_BUMP_JSON" | jq -r '.unified // true')      # default = unified
KIND="<patch|minor|major from --bump>"

# 0) 🔴 No-change guard — does any repo actually have a staged change? none at all → no commit + no bump
CHANGED=0
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  [ -n "$repo" ] || continue
  [ -n "$(git -C "$repo" diff --cached --name-only 2>/dev/null)" ] && CHANGED=1
done
if [ "$CHANGED" = "0" ]; then
  echo "ℹ️ No staged change — skipping commit + bump entirely (no tag, no push)"; TARGET_VERSION=""; 
  # → skip the rest of Phase 5.5; Phase 6 will skip every repo on its own
else

# 1) current version per repo (latest semver tag vX.Y.Z; none = 0.0.0)
#    include main (.) too — main is the canonical version (Phase 7 tags + writes root VERSION on every --bump)
#    ⇒ max() covers both an ahead root VERSION and submodule tags
#    🔴 fetch tags FIRST — a teammate's v0.2.78 that exists only on origin would otherwise be
#       invisible here and this round would compute the SAME number (Phase 7's tag push then
#       collides, exit 5). Offline ⇒ fetch fails silently and local tags are used, unchanged.
VERW="$(git rev-parse --show-toplevel)/scripts/ow-version.sh"
vers=()
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  [ -n "$repo" ] || continue
  git -C "$repo" fetch --tags --quiet origin 2>/dev/null || true
  v=$(git -C "$repo" tag --list 'v*.*.*' | sed 's/^v//' | sort -V | tail -1)
  vers+=("${v:-0.0.0}")
  # the version FILES count too, otherwise a file hand-edited ahead of the tags is walked
  # back. `read` strips a leaked `v` so one bad hand-edit cannot poison the next bump (#34);
  # an unreadable file is skipped here and caught hard by the write+validate gate in Phase 6/7
  for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
    [ -f "$repo/$vf" ] || continue
    fv=$(bash "$VERW" read "$repo/$vf" 2>/dev/null) && [ -n "$fv" ] && vers+=("$fv")
  done
done

# 2) BASE = max(current across every repo) — guard against walking back a repo that is ahead
BASE=$(printf '%s\n' "${vers[@]:-0.0.0}" | sort -V | tail -1)

# 3) TARGET_VERSION = bump(BASE, KIND) — computed once
IFS=. read -r MA MI PA <<<"$BASE"
case "$KIND" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  *)     PA=$((PA+1)) ;;                # patch (default)
esac
TARGET_VERSION="$MA.$MI.$PA"
# append_tag from config (default "[v{version}]") → token appended to the commit msg
VERSION_TAG=$(echo "$VERSION_BUMP_JSON" | jq -r '.append_tag // "[v{version}]"' | sed "s/{version}/$TARGET_VERSION/")
echo "🔢 Unified bump: BASE=$BASE → TARGET=v$TARGET_VERSION (used by every repo that commits — including main)"
fi   # end no-change guard
```

🔴 **No change → no bump:** if no repo has a staged change → `TARGET_VERSION` is empty → Phase 6 neither commits nor tags (no empty commit + no free version jump)
🔴 **`max()` is mandatory** — a repo sitting at v0.2.77 is never pulled back to v0.2.76; web+app both → **v0.2.78 together**
🔴 `unified: false` (not recommended) → bump each repo from its own current version (legacy — versions may diverge)
🔴 **Default = `--no-bump`** (omitting `--bump` lands here) → skip Phase 5.5 entirely (no tag / no append / no version file written); Phase 5.5 runs only when the user explicitly asks for `--bump`

## Phase 6 — Commit + push per submodule (the same version in every repo)

```bash
# Read path<TAB>read_only<TAB>branch rows from the resolver. The read-only skip is driven by
# the TSV's second column in the SAME pass — no jq re-query against YAML (#4).
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
VERW="$(git rev-parse --show-toplevel)/scripts/ow-version.sh"
BUILD_POLICY=$(echo "$VERSION_BUMP_JSON" | jq -r '.build_number // "increment"' 2>/dev/null); BUILD_POLICY="${BUILD_POLICY:-increment}"
# 🔴 the ONE helper whose absence is fatal instead of degrading — see the note under this block
if [ -n "${TARGET_VERSION:-}" ] && [ ! -f "$VERW" ]; then
  echo "🛑 scripts/ow-version.sh missing — run: bash scripts/upgrade.sh (a commands-only /ow-sync does not ship scripts/)"; exit 1
fi
bash "$RESOLVER" --submodules | while IFS="$(printf '\t')" read -r sub ro subbr; do
  [ "$ro" = "true" ] && continue          # read-only submodule (e.g. figma) → skip
  [ -n "$sub" ] || continue

  cd "$sub"
  current_branch=$(git branch --show-current)
  staged=$(git diff --cached --name-only)
  if [ -z "$staged" ]; then
    # nothing staged — but the mainline (develop/master) may have been advanced locally by
    # /ow-test Phase 7 (worktree merge) without reaching origin yet → push the branch that leads
    # upstream, otherwise the work is invisible on the remote (#31)
    up="@{upstream}"; git rev-parse --verify --quiet "$up" >/dev/null 2>&1 || up="origin/$current_branch"
    ahead=$(git rev-list --count "$up..HEAD" 2>/dev/null || echo 0)
    if [ "${ahead:-0}" -gt 0 ] && [ "$no_push" != "1" ]; then
      bash "$SYNC" push "$sub" "$current_branch" || { echo "🛑 $sub: push failed — see above"; exit 1; }
      echo "ℹ️ $sub: nothing staged but $current_branch leads upstream by $ahead commit — pushed (worktree mainline merge, #31)"
    fi
    cd -; continue
  fi

  # --bump: use the same TARGET_VERSION in every repo (Phase 5.5) — write the version file (if set) + append the tag to the msg
  if [ -n "${TARGET_VERSION:-}" ]; then
    for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
      [ -f "$vf" ] || continue
      # canonical per-stack writer (VERSION/package.json/pubspec/pyproject/Cargo/csproj).
      # It writes BARE semver, keeps the build number numeric+monotonic, and read-back
      # verifies. Any non-zero = STOP before commit/tag/push (#34).
      bash "$VERW" write "$vf" "$TARGET_VERSION" --build "$BUILD_POLICY" >/dev/null \
        || { echo "🛑 $sub: version write failed for $vf — nothing committed, nothing tagged"; exit 1; }
      # format gate — a diff-only "the number changed" check passes on garbage too
      bash "$VERW" validate "$vf" "$TARGET_VERSION" >/dev/null \
        || { echo "🛑 $sub: $vf failed the version format gate — nothing committed, nothing tagged"; exit 1; }
    done
    # optional: the ecosystem's own resolver is the authoritative check
    echo "$VERSION_BUMP_JSON" | jq -r '.verify_cmd[]? // empty' | while IFS= read -r vcmd; do
      [ -n "$vcmd" ] || continue
      sh -c "$vcmd" >/dev/null 2>&1 || { echo "🛑 $sub: version verify_cmd failed: $vcmd"; exit 1; }
    done || exit 1
    git add -A
    MSG="$msg $VERSION_TAG"               # the same number in every repo
  else
    MSG="$msg"
  fi

  git commit -m "$MSG"
  # the same tag in every repo (idempotent — skip if it already exists)
  [ -n "${TARGET_VERSION:-}" ] && { git rev-parse "v$TARGET_VERSION" >/dev/null 2>&1 || git tag "v$TARGET_VERSION"; }
  if [ "$no_push" != "1" ]; then
    # push via the helper: a teammate who pushed first = non-fast-forward → it re-syncs and
    # retries (git.push_retry). Exit 3 = conflict → STOP; never a plain `git push` here, and
    # never a force.
    if [ ! -x "$SYNC" ]; then git push origin "$current_branch"; rc=$?; else
    bash "$SYNC" push "$sub" "$current_branch"; rc=$?; fi
    [ $rc -eq 3 ] && { echo "🛑 $sub: conflict while re-syncing for push — resolve, then re-run"; exit 1; }
    [ $rc -eq 0 ] || { echo "🛑 $sub: push rejected — see above"; exit 1; }
    if [ -n "${TARGET_VERSION:-}" ]; then
      if [ ! -x "$SYNC" ]; then git push origin "v$TARGET_VERSION"; rc=$?; else
      bash "$SYNC" push-tag "$sub" "v$TARGET_VERSION"; rc=$?; fi
      [ $rc -eq 5 ] && { echo "🛑 $sub: v$TARGET_VERSION already exists on origin — a teammate took this number. Commits are pushed; re-run with --bump to claim the next one. The remote tag is NOT moved."; exit 1; }
      [ $rc -eq 0 ] || { echo "🛑 $sub: tag push failed"; exit 1; }
    fi
  fi
  cd -
done || exit 1     # 🔴 the loop runs in a pipeline subshell — without this an `exit 1` inside it
                   # would only end the subshell and Phase 7 would still tag + push main
```

🔴 **A version file is written through `scripts/ow-version.sh`, never by hand** (#34) — it is the only writer that (a) forces **bare** semver (strips a leaked `v` and says so), (b) keeps a `+build` suffix numeric and strictly increasing (zero-padding preserved), (c) **reads the file back** and re-parses it. "The number changed" is not a check: a malformed value changes too, and it ships as a tagged release that will not build. Every non-zero exit STOPs the run **before** `git commit` / `git tag` / push:
`2` malformed version · `3` unsupported file type (never a silent skip — an unwritten version file drifts behind the tag) · `4` file missing / no version field · `5` read-back or expected mismatch · `6` non-numeric build number
🔴 **This helper is the one exception to "helper absent ⇒ degrade"** (the rule above for `ow-git-sync.sh`): a missing `ow-version.sh` means falling back to an ad-hoc write, which is exactly the defect. `--bump` STOPs and asks for `bash scripts/upgrade.sh` — **not** `/ow-sync`, which ships `commands/` and never `scripts/`, so a project that synced this spec without upgrading is precisely the case this guard catches. Without `--bump` the helper is never touched
🔴 **`version_bump.verify_cmd`** (optional, list) — the ecosystem's own resolver is the authoritative check; it runs after the write and before the commit, e.g. `["cd app && flutter pub get", "npm --prefix web pkg get version"]`
🔴 **Every submodule's commit message + git tag uses the same `v$TARGET_VERSION`** — never bump per repo
🔴 Push the tag too (`git push origin v$TARGET_VERSION`) so `/ow-fix-issue --ready-for-test` (Phase 8.5/8.3) can detect the version from the tag
🔴 **Never revert any repo's version file** — the only skip condition is an empty staged diff (`[ -z "$staged" ]`, the line above): a repo with no change at all → skip (no commit / no bump / no tag). A repo with a real change (even docs-only) → the version bump rides along with the commit that is happening anyway, **no `git checkout -- <version-file>`**. Never use "docs-only" or set-membership (`∈ S`) to decide a bump — the only decider is "is staged empty or not" (otherwise a docs-only repo gets its version wrongly reverted → the version file drifts behind the tag)

## Phase 7 — Main repo commit

After the submodules push:
1. Stage submodule pointer updates (if any)
2. Stage main repo files per scope
3. `--bump`: write main's version file = `$TARGET_VERSION` (canonical) + stage
4. Commit (append `$VERSION_TAG` to the msg if `--bump`) + tag `v$TARGET_VERSION` + push (unless `--no-push`)

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
VERW="$(git rev-parse --show-toplevel)/scripts/ow-version.sh"
BUILD_POLICY=$(echo "$VERSION_BUMP_JSON" | jq -r '.build_number // "increment"' 2>/dev/null); BUILD_POLICY="${BUILD_POLICY:-increment}"
BR=$(git branch --show-current)
# main (umbrella / standalone root) — commit at the root repo
if [ -n "${TARGET_VERSION:-}" ]; then
  [ -f "$VERW" ] || { echo "🛑 scripts/ow-version.sh missing — run: bash scripts/upgrade.sh (a commands-only /ow-sync does not ship scripts/)"; exit 1; }
  for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
    [ -f "$vf" ] || continue
    # root VERSION = canonical — it is re-read by the NEXT bump, so a malformed write here
    # poisons every future release. Same writer + same gate as Phase 6 (#34).
    bash "$VERW" write "$vf" "$TARGET_VERSION" --build "$BUILD_POLICY" >/dev/null \
      || { echo "🛑 main: version write failed for $vf — nothing committed, nothing tagged"; exit 1; }
    bash "$VERW" validate "$vf" "$TARGET_VERSION" >/dev/null \
      || { echo "🛑 main: $vf failed the version format gate — nothing committed, nothing tagged"; exit 1; }
  done
  echo "$VERSION_BUMP_JSON" | jq -r '.verify_cmd[]? // empty' | while IFS= read -r vcmd; do
    [ -n "$vcmd" ] || continue
    sh -c "$vcmd" >/dev/null 2>&1 || { echo "🛑 main: version verify_cmd failed: $vcmd"; exit 1; }
  done || exit 1
  git add -A
  git commit -m "$msg $VERSION_TAG"
  git rev-parse "v$TARGET_VERSION" >/dev/null 2>&1 || git tag "v$TARGET_VERSION"
  if [ "$no_push" != "1" ]; then
    if [ ! -x "$SYNC" ]; then git push origin "$BR"; rc=$?; else bash "$SYNC" push . "$BR"; rc=$?; fi
    [ $rc -eq 3 ] && { echo "🛑 main: conflict while re-syncing for push — resolve, then re-run"; exit 1; }
    [ $rc -eq 0 ] || { echo "🛑 main: push rejected — see above"; exit 1; }
    if [ ! -x "$SYNC" ]; then git push origin "v$TARGET_VERSION"; rc=$?; else bash "$SYNC" push-tag . "v$TARGET_VERSION"; rc=$?; fi
    [ $rc -eq 5 ] && { echo "🛑 main: v$TARGET_VERSION already exists on origin — a teammate took this number. Commits are pushed; re-run with --bump to claim the next one. The remote tag is NOT moved."; exit 1; }
    [ $rc -eq 0 ] || { echo "🛑 main: tag push failed"; exit 1; }
  fi
else
  git commit -m "$msg"
  if [ "$no_push" != "1" ]; then
    if [ ! -x "$SYNC" ]; then git push origin "$BR"; rc=$?; else bash "$SYNC" push . "$BR"; rc=$?; fi
    [ $rc -eq 3 ] && { echo "🛑 main: conflict while re-syncing for push — resolve, then re-run"; exit 1; }
    [ $rc -eq 0 ] || { echo "🛑 main: push rejected — see above"; exit 1; }
  fi
fi
```

🔴 **Push goes through `scripts/ow-git-sync.sh push`, never a bare `git push`** — a teammate's
commit landing between Phase 2.5 and here is normal on a shared branch; the helper re-syncs and
retries instead of failing the run. Never `--force`.

🔴 **main is the canonical version** — on every `--bump` main writes its version file (root `VERSION`) = the same `$TARGET_VERSION` as the submodules + always tags `v$TARGET_VERSION`. root VERSION therefore **moves every single time** and can never fall behind a submodule tag.
🔴 **Never revert main's version file** — even when the diff is docs/submodule-pointer only. The version bump rides along with the commit that is happening anyway. Never use "docs-only" / set-membership (`∈ S`) to decide — the only decider = is staged empty or not (the same Phase 6 guard).

## Phase 8 — Merge-to (optional)

If `--merge-to <branch>`:
- per repo: checkout target → **sync the target** (`bash "$SYNC" sync <repo>` — the target branch
  is the one most likely to have moved under you) → merge --no-ff source → `bash "$SYNC" push <repo> <target>`
- sync exit 3 → **STOP before the merge**; exit 4 (offline/solo) → carry on
- If `--delete-source`: delete source local + remote

## Phase 8.5 / 8.6 — post-push side effects

Two side effects that run **only after a successful push** (never on `--no-push` / `--status` /
`--switch-only`). Both are gated on state this run already holds, so decide here **without opening
the fragment**:

- **8.5 issue-handoff** — an issue ref exists in the commits just pushed (`Closes` / `Fixes` /
  `Resolves #NN`, any repo in the range) **or** the run is `--fix <fix-log>` whose fix-log carries
  `github_issue:` — **and** the run has no `--no-ready-for-test`
- **8.6 fix-log version stamp (#30)** — `--bump` ran this round **and** a local fix-log is finalized
  by it: `--plan <path>` whose plan has `source_fix:`, **or** `--fix <fixlog>` whose fix-log has
  `fixed_commit: pending`. A fix-log carrying `github_issue:` belongs to 8.5, not here

Neither gate holds → skip straight to Phase 9; the fragment is never read (the everyday
`/ow-git` commit path never opens it).
Either gate holds → 🔴 Read `.ow/commands/_shared/git-post-push.md` and run **that** phase —
the fragment restates each gate in full and is the authority if the two ever disagree.

## Phase 9 — Report

Show (`--bump` → the Version column **must be the same number in every repo, including main**):
```
git-sync summary
================
Repo   Branch     Pushed             Version
api    [develop]  8a77a02..2f7e850   v0.2.78
web    [develop]  b74346d..3b62477   v0.2.78
app    [master]   1357ace..9bd02f1   v0.2.78
main   [main]     99027c0..163b39e   v0.2.78
figma  [read-only] —                 skipped

sync (Phase 2.5)                    api ↻rebased +2 · web in-sync · app in-sync · main ↻rebased +1
auto-resolved                       docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md (vault-append)
ready-for-test handoff (Phase 8.5)  v0.2.78:  #62 #63 → ready for test ✅
fix-log stamp (Phase 8.6)           v0.2.78:  2026-06-08-1523-foo ← plan 2026-06-08-1533-bar
```
🔴 **The sync line shows only when a sync ran** and something moved; every `resolved` line the
helper printed becomes an `auto-resolved` row — **never drop one**, a file merged on the user's
behalf that they never hear about is a silent edit to their work
🔴 A push that needed a retry shows it: `web  [develop]  b74346d..3b62477  v0.2.78  (retried after teammate push)`
(the Phase 8.6 line shows only when the plan in scope has `source_fix:`; otherwise it is not shown)
🔴 **Do not list issues/fixes (a 'Fixes' column) in the table** — that is work detail, not summary substance; keeping it in the commit message / handoff is enough
🔴 **The Version column is the same number for every repo, including main** (from Phase 5.5 unified, reflecting the real tag + version file) — main = canonical version, moves on every `--bump`
(if the gate fails — the push has no `Closes #NN`, or `--no-ready-for-test` was used — the handoff line is not shown)

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-git, answer with **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — which commit/push/bump, in which repo
- **Result** — real commit hash + push result + branch per repo (cited from actual git)
- **Open / risks** — skipped files, conflicts to resolve
- **Next** — `/ow-handoff` or the next step (if the gate passed)

🔴 **Never fabricate** commit hash/URL — cite from actual git only.

## Never

- Never `git push --force` without explicit user confirmation — and **never at all** inside the
  sync/retry path (`scripts/ow-git-sync.sh` uses plain push only, by construction)
- Never commit before running /ow-secure
- Never delete a branch without verifying it is merged
- Never commit in the figma (or any read-only) submodule
- Never `git reset --hard` without confirmation
- Never `git rebase --abort` on the user's behalf — a stopped rebase stays where it is so they can finish it
- Never commit / push / bump after a sync returned exit 3 — the run ends there
- Never move a tag that already exists on origin (exit 5 = a teammate claimed that version)
- Never resolve a conflict without listing it in the Phase 9 report
