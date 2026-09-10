# `_shared/git-sync.md` — sync with origin before commit/push (multi-person)

Read this **only when a sync actually runs** — `/ow-git` Phase 2.5, Phase 6, Phase 7.
`--status` / `--switch-only` / `--no-sync` / `git.auto_sync: false` ⇒ nothing here applies.

Shared-branch teams hit three failures that a single-person repo never sees: a push rejected
because a teammate pushed first, two people bumping to the same version, and a branch cut from a
base that is already behind. Every rule below exists for one of those.

## 0. The one entry point

All of it lives in `scripts/ow-git-sync.sh`. **Never hand-roll `git pull` / `git rebase` /
retry loops in a command spec** — the conflict classifier decides what a human sees, and a rule
that lives only in prose runs differently every session.

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
bash "$SYNC" status   <repo>            # "<ahead>\t<behind>\t<upstream>"  (fetches first)
bash "$SYNC" sync     <repo>            # fetch + rebase|merge onto upstream, auto-resolve safe classes
bash "$SYNC" push     <repo> <branch>   # push; non-fast-forward → re-sync + retry
bash "$SYNC" push-tag <repo> <tag>      # push one tag; collision is fatal, never forced
bash "$SYNC" classify <repo>            # "<class>\t<file>" per conflicted file, writes nothing
```

**Helper not installed?** `/ow-sync` refreshes `commands/` but never `scripts/` — so this fragment
can reach a project that does not have `ow-git-sync.sh` yet. Every caller guards with `[ -x "$SYNC" ]`
and degrades to the single-person behavior (plain `git push`, no sync) with a one-line note pointing at
`bash scripts/upgrade.sh`. **Never fail a run because the helper is missing.**

## 1. Exit codes — branch on these, never on the text

| Code | Meaning | What the calling command does |
|---|---|---|
| `0` | synced / already in sync / pushed | continue |
| `3` | **conflict left for a human** | **STOP the whole command** — no stage, no commit, no push, no bump, no Phase 8.x |
| `4` | skipped (no remote · no upstream · fetch failed · `auto_sync: false`) | continue as if single-person — **never an error** |
| `5` | tag collision — remote already owns this version | STOP the bump; commits already pushed stay pushed |
| `1` | hard error | STOP and show the git output |

Exit `4` is the offline/solo path: a project with no remote must keep working exactly as before.

## 2. Conflict classes

Class is chosen by **path**; whether it is actually resolved is decided **per conflict region**.
A file in a safe class whose regions do not match the class shape still goes to the human.

| Class | Files | Rule |
|---|---|---|
| `version` | `VERSION`, `package.json`, `pubspec.yaml` | keep the **higher semver**; every region line must carry a version |
| `lock` | `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `poetry.lock`, `Cargo.lock`, `composer.lock`, `Gemfile.lock` | take the checked-out side, then **regenerate** lockfile-only from the manifest. Regen missing or failing ⇒ back to conflicted (never commit a lock we cannot vouch for) |
| `changelog` | `CHANGELOG.md` | union both sides, dedupe identical lines, higher version block first |
| `vault-append` | `.md` under `$VAULT_ABS` | union — **only** when every region line on both sides is a table row / list item **and** no primary key appears on both sides with different content |
| `vault-meta` | frontmatter date fields (`updated:`, `last_synced:`, `date_modified:`, `synced_at:`) | keep the later date |
| everything else | source code, vault prose, other frontmatter | **human** |

The classes that pay for themselves in a real team: `00-Index/IMPLEMENTATION-STATUS.md`, MOC link
lists — append-only tables that collide constantly. Plan and fix-log
filenames carry a timestamp, so those never collide in the first place.

Which classes run at all comes from `.ow.yml` → `git.auto_resolve`
(default `[version, lock, changelog, vault]`; `[]` turns every auto-resolve off).

## 3. Invariants

- 🔴 **Never `--force` / `--force-with-lease`** in any path. Plain push only ⇒ a teammate's
  history cannot be lost through this flow by construction.
- 🔴 **Never `rebase --abort` for the user.** Exit `3` leaves the rebase exactly where it stopped
  so the human can finish it in place. Re-running `sync` on a repo mid-conflict returns `3`
  without touching anything.
- 🔴 **Never resolve silently.** Every auto-resolved file prints `resolved\t<class>\t<file>`,
  and the calling command must show it in its report.
- 🔴 **Dirty tree is fine** — the rebase runs `--autostash`. A stash that fails to pop leaves the
  stash intact; nothing is dropped. `git rebase --autostash` still exits **0** in that case (the
  rebase itself succeeded), so `sync` re-checks for unmerged files on the success path and returns
  **3** with `conflict\tautostash`. The work exists twice — markers in the worktree *and* the kept
  stash — and neither copy is ever staged.
- 🔴 **`strategy: merge` never stashes.** Git refuses to merge over a dirty tree (`Your local
  changes would be overwritten`) ⇒ exit `1`, nothing touched. Fewer surprises, more stops.
- 🔴 **A tag is a claim on a version.** Collision ⇒ exit `5` and stop. Never move a remote tag.
- `rerere.enabled` is turned on per repo on first sync, so the same hunk collision is free next time.

## 4. What a `3` looks like to the user

Report, in `$PROJECT_LANG`:

```
🛑 conflict — sync stopped (nothing committed, nothing pushed)
   auto-resolved: docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md  (vault-append)
   for you:       src/api/checkout.ts
   → resolve, then: git add <file> && git rebase --continue     (or: git rebase --abort)
   → then re-run the same /ow-git command
```

Show the auto-resolved files **and** the ones left over. A user who sees only the leftovers cannot
tell that something was merged on their behalf.

A `conflict\tautostash` needs its own wording — the rebase already finished, so there is **no
`git rebase --continue`** to run and telling the user to run one sends them into a dead end:

```
🛑 stash pop conflict — sync stopped (nothing committed, nothing pushed)
   your work is safe twice: the markers in the file, and `git stash list`
   for you:  src/api/checkout.ts
   → resolve, then: git add <file> && git stash drop
   → then re-run the same /ow-git command
```
