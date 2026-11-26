# `_shared/git-conflict.md` — `/ow-git` Phase 2.6: merge vault docs by intent

Read this **only when Phase 2.5 left a repo at exit 3** (`.ow/local/sync-conflicts` non-empty).
A clean sync never opens this file.

The sync helper already merged everything with a fixed rule (version · lock · changelog · vault
rows · frontmatter `version:`/dates). What is left in the vault is **prose** — two people edited
the same FN/FEAT/SRS doc. Those changes came from plans and fix-logs, so the reason behind each
side is on record: merge by that reason, not by guessing between two texts.

**Off** when `git.auto_resolve` has no `vault-ai` (`bash "$SYNC" config` → `auto_resolve=`).
Off ⇒ skip straight to **Stop** below.

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
OW_ROOT="$(git rev-parse --show-toplevel)"; SYNC="$OW_ROOT/scripts/ow-git-sync.sh"
for repo in $(cat "$OW_ROOT/.ow/local/sync-conflicts"); do
  echo "=== $repo ==="
  bash "$SYNC" classify "$repo"                  # vault-append rows still here = AI candidates
done
```

Per candidate file (class `vault-append`, still conflicted) — **one file at a time**:

1. **Read the three versions** — `git -C <repo> show :1:<file>` (base) · `:2:<file>` (HEAD side) ·
   `:3:<file>` (incoming side). During a **rebase**, `:2` is the upstream (teammate) and `:3` is
   *your* replayed commit — git's inversion; the `sides` labels follow the stage numbers.
2. **Collect the evidence** — `bash "$SYNC" sides <repo> <file>` → commits on each side and the
   plan / fix-log files those commits touched. Read those logs (both sides, from their commit:
   `git show <sha>:<log>`), the commit subjects, and any `$PLAN_DIR`/`$FIX_DIR` file in either
   side's tree that links `[[<doc-name>]]`. No log and no meaningful commit subject on a side ⇒
   that side's intent is unknown ⇒ **leave the file for the human**.
3. **Merge** — base + every change the HEAD side made + every change the incoming side made,
   each one traced to its log. Two changes to different sections / rows / sentences ⇒ keep both.
   Same sentence, same value, or same decision changed two different ways ⇒ **leave the file for
   the human** — even if one log is newer. Write the result in the vault's present-tense style
   (`_shared/vault-doc-style.md`) — never "A changed this, B changed that" inside the doc.
4. **Gate — every item, or the file goes back** (`git -C <repo> checkout -m -- <file>` restores the
   conflict markers exactly as git left them):
   - no `<<<<<<<` / `|||||||` / `=======` / `>>>>>>>` line left
   - frontmatter parses: `yq --front-matter=extract '.' <file>` exits 0
   - every `[[wikilink]]` and every heading present on either side (`:2` and `:3`) is still
     present, unless one side's log says it removed it
   - `bash "$OW_ROOT/scripts/ow-verify-vault-style.sh"` passes
5. **Stage** — `git -C <repo> add -- <file>`. Record `<file> ← <log-a>, <log-b>` for the report.

Then, per repo where every candidate staged and **no non-vault file is still conflicted**:

```bash
out=$(bash "$SYNC" continue "$repo"); rc=$?
echo "$out"        # resolved lines for later replayed commits → also go into Phase 9
```

`continue` → rc `3` means the **next** replayed commit stopped too: run this phase again on that
repo (new candidates, new evidence). A repo whose conflicts are all gone drops out of the list.

**Stop** — any repo still at `3` (code conflict, a file the gate sent back, or `vault-ai` off):

```bash
echo "🛑 $repo — conflict left for you. Nothing was staged, committed, pushed or bumped."
bash "$SYNC" classify "$repo"
echo "   resolve → git add <file> && git rebase --continue   (or --abort) → re-run this command"
exit 1
```

Report both lists with the stop: what the AI merged (with the logs it used) **and** what is left.
Files already staged stay staged — the human's `rebase --continue` keeps them.

🔴 **Vault `.md` only.** Source code, README, `usage/`, anything outside `$VAULT_ABS` ⇒ human,
always — there is no plan/fix-log trail to merge those by
🔴 **Unsure = leave it.** A wrong merge in a spec doc is a silent wrong requirement that the next
`/ow-implement` builds faithfully. A stop costs the user one manual merge
🔴 Never edit the plan / fix-log files themselves here — they are evidence, not merge targets
🔴 Every file this phase stages becomes an `auto-resolved … (vault-ai)` row in Phase 9 with the
logs it was merged from — never drop one
