---
description: Fix GitHub bug issues end-to-end — auto-discover real-bugs, parallel worktree agents diagnose+fix+test+commit, auto-merge to base branch locally (NO push), handoff to /ow-test + /ow-git
---

# /ow-fix-issue — Issue → Fix Orchestrator (parallel worktree)

Takes GitHub issues (single / batch / cluster) → diagnoses + implements + tests + commits each fix **in its own worktree** (parallel agents when more than one group is approved — a single group is a judgment call, Phase 4) → **auto-merge** each fix branch into the base branch of its submodule (serial within a submodule) → cleanup → **STOP** and hand off to the user to run `/ow-test` + `/ow-git`

> **Core rule:** `/ow-fix-issue` = **parallel implement + serial merge (local) + cleanup** within one scope — the user invoking it = approval covering `commit` + `merge (local)` + `worktree remove`
> **But never push, never flip `ready for test`, never comment, never close an issue** — hand back to the user at the `/ow-test` + `/ow-git` step
>
> This step follows `/ow-triage-issues` — pick up only confirmed real-bugs (has label `bug`, none of question/wontfix/need-info/not-implement-yet)

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
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec.
#    The rule file is NAMED (not just a dir) so a missing rule cannot vanish silently (#22).
RES="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
for AREA in coding testing; do
  RULES=$(bash "$RES" --rules "$AREA" | paste -sd' ' -)
  if [ -n "$RULES" ]; then
    for _rf in $RULES; do echo "Read rule($AREA): $_rf"; done
  else
    echo "rule($AREA): (none) — expected file: $(bash "$RES" --rules-expected "$AREA" | cut -f1)"
  fi
done
# Fail loud: a rule REGISTERED in .ow.yml rules.files that fails to resolve is a STOP-RISK,
# never a silent skip — surface it instead of proceeding as if no rule existed.
bash "$RES" --rules-validate >/dev/null 2>&1 || \
  echo "⚠ STOP-RISK: a rule registered in .ow.yml rules.files did not resolve — run: bash \"$RES\" --rules-validate"
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $FN_DIR $PHASE_DIR $FLOW_DIR
$REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $TEMPLATE_CHAIN
$GUARDRAILS_JSON $COMMAND_PREFIX`. A later phase runs in a
FRESH SHELL — Phase 0's exports are gone — so it re-hydrates first, then asserts:
`. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"` followed by
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Why auto-merge but no push?

obsidian-workflow has an absolute **no auto-push** rule — push + version bump + cross-submodule coordination are `/ow-git`'s job (user trigger only). `/ow-fix-issue` may merge into the base branch **locally** (reversible, nothing has left the machine) but always stops before push

## Prerequisite

- `gh` CLI authenticated + inside a git repo
- agent `gh-issue` enabled (`/ow-agent enable gh-issue`)
- the relevant specialized subagent enabled (`backend` / `frontend` / `mobile` per stack — `/ow-agent enable <name>`)
- `.ow.yml` has a correct `submodules:` (if multi-repo) or `[]` (monorepo)

## Trigger

```
/ow-fix-issue                              # 🌟 DEFAULT — auto-discover every real-bug + per-group approval + parallel execute
/ow-fix-issue --dry-run                    # default mode + show the plan then stop; no approval, no run

# Specific mode (issues named explicitly — skips auto-discover + approval gate)
/ow-fix-issue #62                          # 1 issue → 1 worktree, 1 worker (agent or inline — Phase 4)
/ow-fix-issue #62 #63 #64                  # 1 explicit group (cluster) — 1 worktree, 1 worker closes them all
/ow-fix-issue #62 --diagnose-only          # stop at fix-log + RED baseline (same as the /ow-fix flow)
/ow-fix-issue #62 --submodule web          # force the submodule when detection fails

# Ready-for-test mode (RESUME — run only after /ow-git push+bump)
/ow-fix-issue --ready-for-test             # auto: scan fix-logs with status:fixed already pushed but not yet flipped → comment version + flip label
/ow-fix-issue #62 #63 --ready-for-test     # only the listed issues
/ow-fix-issue #62 --ready-for-test --version 1.4.2   # force the version (when auto-detect fails)
```

**Mode detection (from `$ARGUMENTS`):**
- has `--ready-for-test` → **Ready-for-test mode** (resume) → skip Phase 0.5-6, go straight to **Phase 8** (post-push issue handoff)
- no `#NN` → **Auto-discover mode** (default) → run Phase 0.5
- has `#NN` → **Specific mode** → skip Phase 0.5 (auto-discover + approval), go straight to Phase 1 (invoke = approval)

> **`--ready-for-test` is a separate step after `/ow-git`** — because "the version the fix shipped in" is knowable only once push + bump are done (Phase 1-6 do not push and do not know the version). Run in order: `/ow-fix-issue #NN` → `/ow-test` → `/ow-git --bump patch` → `/ow-fix-issue #NN --ready-for-test`

---

## Phase 0 — Pre-flight

### 0.1 Config + gh CLI + repo
```bash
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)"   # resolve VAULT_PATH, submodules, etc.
gh auth status || { echo "Run 'gh auth login'"; exit 1; }
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
MAIN_ROOT="$(git rev-parse --show-toplevel)"
```

### 0.2 Resolve repo layout (monorepo vs multi-repo submodules)

Read `.ow.yml` `submodules:`:

```yaml
# Multi-repo example
submodules:
  - name: api
    path: ./api          # path to the submodule checkout
    branch: develop      # base branch of this submodule
  - name: web
    path: ./web
    branch: develop
  - name: app
    path: ./app
    branch: master
```

| Layout | Meaning |
|---|---|
| `submodules: []` (monorepo) | a single repo — base branch = current branch or the `main`/`develop` set in `.ow.yml` `default_branch` (absent → current HEAD upstream) — wave parallelism = parallel at implement, serial at merge (one base branch only) |
| `submodules: [...]` (multi-repo) | each submodule has its own base branch — merge in parallel across submodules, serial within a submodule |

🔴 **Never hardcode `develop`/`master`** — always read from config; store per submodule as `FIX[base_branch]`

### 0.3 Worktrees dir + .gitignore
```bash
mkdir -p "$MAIN_ROOT/worktrees"
grep -qx "worktrees/" "$MAIN_ROOT/.gitignore" 2>/dev/null || echo "worktrees/" >> "$MAIN_ROOT/.gitignore"
```

### 0.4 Validate args (Specific mode)
Each issue must:
- have label `bug` (real bug confirmed through triage)
- have none of { `question`, `wontfix`, `need info`, `not implement yet`, `in progress`, `ready for test` }
- state = open

On failure → list the skipped issues + reason, then ask (render in `$PROJECT_LANG`): "Continue anyway? (`yes`/`no`)"

---

## Phase 0.5 — Auto-Discover Mode (🌟 default — when `$ARGUMENTS` has no `#NN`)

🔴 **Skip this entire phase** when the user names the issues (Specific mode) → go to Phase 1

### 0.5.1 Fetch all eligible bugs
```bash
gh issue list \
  --label bug \
  --search "is:open \
            -label:\"in progress\" -label:\"ready for test\" \
            -label:question -label:\"need info\" \
            -label:\"not implement yet\" -label:wontfix" \
  --limit 100 \
  --json number,title,body,labels,comments,createdAt,url
```

Result = the pool of real-bugs ready to fix (already triaged)

### 0.5.2 Auto-group (cluster vs standalone)
For each issue:
- has label `cluster` → parse the comment "**Cluster proposal:**" for the list `#<NN>, #<MM>, ...` → group by matching member list (sort for a canonical group key)
- no `cluster` → standalone (1 issue = 1 group)
- a cluster member appearing in several proposals (overlap) → merge into one group (transitive closure)

### 0.5.3 Auto-priority order
Order the groups (top to bottom = run first):

| Priority | Group type | Reason |
|---|---|---|
| 1 | P0 standalone | severe + fast (1 fix) — unblock first |
| 2 | P0 cluster | severe but several fixes |
| 3 | P1 standalone | major + fast |
| 4 | P1 cluster | major, several fixes |
| 5 | P2 standalone, P2 cluster | minor |
| 6 | P3 standalone, P3 cluster | polish |
| 7 | unscored | severity cannot be inferred |

**Severity infer:** from the issue body's severity field (whatever the issue template calls it, in any language) or keywords (P0/blocker/data loss → P0; major → P1; minor → P2; polish/i18n/cosmetic → P3)

**Submodule tie-breaker:** within the same priority → group by the submodule order in config (less context switching + shared dev server)

### 0.5.4 Display queue plan (overview — informational)

```
🗂️ Queue plan — N groups (auto-ordered)

| # | Group                    | Submodule | Issues               | Priority |
|---|--------------------------|-----------|----------------------|----------|
| 1 | P0 standalone — #37      | api       | [#37](url)           | P0       |
| 2 | P1 standalone — #35      | web       | [#35](url)           | P1       |
| 3 | Cluster A — register     | web       | [#62](u) [#63](u)    | P1       |
| 4 | Cluster B — upload       | app       | [#58](u) [#59](u)    | P2       |

🔍 Every group is asked up-front (Phase 0.5.5), then executed in parallel per submodule (Phase 0.5.6)
```

🔴 **`--dry-run` flag = show the plan and stop; never enter 0.5.5**

### 0.5.5 Approval phase (🔴 ask every group **before** execution starts)

Loop over every group and ask the user one group at a time — **run nothing, only collect answers**.
Prompt text is rendered in `$PROJECT_LANG`; the answer keywords stay literal:

```
for GROUP in queue:
  ──────────────────────────────────────
  🛑 Approve Group <N>/<TOTAL> — <name>
     Submodule: <name>     Priority: P<n>
     Issues:
       - [#NN](url) — <title> (<severity hint>)
       - [#MM](url) — <title>

  - `yes` / `y`  → mark approved → ask the next group
  - `skip`       → mark skipped → ask the next group
  - `stop`       → end the approval phase (remaining groups count as skipped) → execute only the approved ones
  - `edit`       → user edits the issue list in the group → show it again + ask again
  ──────────────────────────────────────
```

🔴 **Approval phase = zero execution** — only collect yes/skip/stop
🔴 **Unclear answer = ask again, never guess**

After every group is answered → show the approved-list summary

### 0.5.6 Parallel execution — decoupled implement vs merge

**Core insight:** the only thing that actually contends on the base branch is the **merge step** — the implement step (writing code in a worktree) does not contend because each group has its own worktree + branch

#### Stage A — Implement (parallel across every approved group)
- open a worktree for every approved group at once (1 group = 1 worktree = 1 worker)
- more than one approved group ⇒ one agent per group into the concurrency pool (independent worktrees — fan out);
  a single approved group ⇒ the Phase 4 judgment decides agent vs inline
- **Cap = global max concurrent agents** (default 7) — more than 7 approved → batch 7 at a time
- the worker in each worktree runs Phase 4.1 as usual (diagnose → test → fix → test pass → commit)

🔴 **Implement = fully parallel** — each worktree is separate, the base branch is untouched during implement

#### Stage B — Merge (serial **within** a submodule, parallel **across** submodules — local only)
- once an agent finishes committing → enter the merge queue of the submodule that group touches
- 1 merge worker per submodule (parallel across submodules)
- each worker: `verify repo is on base + clean → pull --ff-only → merge --no-ff → cleanup`, one group at a time, serial
  (never `checkout` — not on base = skip that repo + report, Phase 5.1)
- **monorepo:** a single merge worker (one base branch) — merge every group serially

🔴 **Merge within a submodule = serial, mandatory** — `git merge` must be atomic on the base branch
🔴 **Merge = local only — no push** (push is `/ow-git`'s job)

#### Failure handling
- **Test fail in Stage A** → mark the group "partial" + do not enter the merge queue + do not affect other groups
- **Merge conflict in Stage B** → 🛑 stop the merge queue of that submodule only — other submodules continue — keep the worktree + report to the user
- **Stage A fatal (worktree create fail)** → skip that group, other groups continue

### 0.5.7 Final report → go to Phase 6

---

## Phase 1 — Resolve Pool (Specific mode)

### 1.1 Direct issue list
If `$ARGUMENTS` has `#NN` → extract the numbers into a list

### 1.2 Cluster reference (`cluster:<slug>`)
Find issues with label `cluster` + a comment containing `Cluster proposal:` + a matching slug — or simpler: use Phase 1.1 (the user lists every number of the group)

---

## Phase 2 — Submodule Detection (per issue)

For each issue → decide which submodule it belongs to (monorepo = skip this phase):

| Hint in the issue body | Submodule (mapped per config) |
|---|---|
| "Mobile App", "iOS", "Android", "Flutter", "React Native" | mobile submodule |
| "Web", "Dashboard", "Vue", "React" (and their equivalents in the project's own language) | web submodule |
| "API", "GraphQL", "mutation", "schema", "endpoint", error pattern `Validation failed` | api submodule |
| Cross-cutting (e.g. validation in API + form in web) | `cross` — tell the user first |

🔴 **Map keyword → submodule via `.ow.yml` `submodules[].name`** — if the project uses different names (e.g. `backend`/`frontend`), map to those
Cannot decide → ask in 1 message before continuing (or use `--submodule <name>`)

🔴 **Cross-submodule = never auto parallel** — fall back to serial

---

## Phase 3 — Worktree Setup (per issue, parallel-safe)

### 3.1 Slug + path
```bash
NN=<issue number>
SUBMODULE=<name from config | "" for monorepo>
SLUG=<kebab-case from the issue title, ≤ 5 words>
WORKTREE_DIR="$MAIN_ROOT/worktrees/${SUBMODULE:-main}-${NN}-${SLUG}"
BRANCH="fix/${NN}-${SLUG}"
TARGET_REPO="${SUBMODULE_PATH:-$MAIN_ROOT}"   # submodule path or main root
```

### 3.2 Base branch (read from config — never hardcode)
- multi-repo: `BASE_BRANCH = submodules[name].branch`
- monorepo: `BASE_BRANCH = .ow.yml default_branch` or the current upstream

🔴 **Store as `FIX[base_branch]`** so Phase 5 can read it

### 3.3 Create worktree (at the level of the submodule/repo being fixed)
```bash
git -C "$TARGET_REPO" fetch origin
git -C "$TARGET_REPO" worktree add -b "$BRANCH" "$WORKTREE_DIR" "origin/$BASE_BRANCH"
```

🔴 **Worktree at submodule level only** (not the superproject) — avoids submodule init recursion

### 3.4 Flip label: + `in progress`
```bash
gh issue edit "$NN" --add-label "in progress"   # do not remove bug — a bug is still a bug, it is just in progress
```

---

## Phase 4 — Implement each approved group (parallel when there is more than one)

### Decide how to run it (🔴 no mandate either way)

**N > 1 approved groups → fan out, that is the whole point of this command.** The groups are *genuinely
independent* — separate issues, separate worktrees, separate branches — so parallel agents buy real wall-clock
and each one's noisy diagnose/test loop stays out of your context. This is the opposite of `/ow-implement`,
where one plan on one tree is sequential work.

**N = 1 approved group → your judgment**, same trade-off as `/ow-implement` 3.0: a spawn shares no context
with you and pays a cold-cache write, which a one-file P3 fix rarely earns back; a long diagnose → red test →
fix → green loop usually does. Running it inline means **you** work inside that group's `<WORKTREE_DIR>`, read
`.claude/agents/<area>.md` **if that file exists** + the `RULES(...)` files, and carry steps 1-14 of `_shared/fix-issue-fix-flow.md` yourself.
🔴 Only `docs` is guaranteed to be there — every other area agent is one this project wrote with
`/ow-agent create`, so an absent file means inline, not a blocked run.

🔴 Whichever way it runs, nothing changes downstream: the worktree isolation (Phase 3), the before/after
the red→green pairing, the fix-log, the serial merge (Phase 5) and the no-push rule all apply identically.

Delegating (always for N > 1, and for N = 1 when the judgment above lands there) — **send N Agents in 1 message**
(max 7 parallel) — `subagent_type` per submodule:

| Submodule role | subagent_type |
|---|---|
| web / frontend | `frontend` |
| mobile | `mobile` |
| api / backend | `backend` |
| monorepo (mixed) | choose by the area of the fix |

🔴 **Never use the `isolation: "worktree"` flag** — we manage the worktrees ourselves (Phase 3)

### 4.0 Resolve CONTEXT_REFS per agent

🔴 Read `.ow/commands/_shared/context-refs.md` — canonical include-when table + escalation rule.

The context block is built **before** the agent diagnoses → the issue body is the only information available. Classify
as far as the issue allows **per agent** (each covers a different area/submodule → CONTEXT_REFS need not be identical),
**uncertain ⇒ include**, then let the `context gap:` rule catch the rest. Never delay a spawn to wait for diagnosis

### 4.1 The fix flow (both modes)

🔴 **Read `.ow/commands/_shared/fix-issue-fix-flow.md` and follow it** — it owns the whole flow for one
group: PROJECT CONTEXT block · steps 1-14 (fix-log → test-first → RED/GREEN record → minimum fix →
commit-no-push → verification record → vault sync) · MUST-NOT list · return format. Delegating → send it as the
agent prompt; inline → carry it yourself. Nothing from it is restated here.

### 4.2 Wait for all agents

Every agent done → collect the outputs → check: commit hashes all present? tests pass? fix-log verification record complete?
🔴 **Check no stray run output rode along:** the scratch output of a run must never be committed with the fix — confirm:
```bash
git -C "$MAIN_ROOT" status --porcelain | grep -E '(before|after)-.*\.(png|txt)$|-output\.txt$' \
  && echo "🛑 #$NN — run output found in the tree → delete it, never commit it along with the fix"
```
🔴 **Check red→green pairing:** the fix-log records a RED baseline but no GREEN result → incomplete; send the agent back through step 8 before marking fixed — never mark fixed on a RED record alone
If an agent fails → keep the `in progress` label + report to the user

---

## Phase 5 — Auto-Merge to base branch (serial within submodule, LOCAL only)

After the agents finish (status: fixed) → the skill merges each fix branch into its submodule's base branch **locally** (no push)

> Base branch per submodule = `${FIX[base_branch]}` (from config, Phase 3.2). 🔴 Never hardcode

### 5.1 Pre-merge guard

🔴 **Never `git checkout`** to put the target repo on its base branch — switching branches changes the state of
the user's own checkout and leaves it changed (#29, same rule `/ow-test` Phase 7 follows). Already on base = merge;
not on base = **skip that repo + report**, and the user decides.

```bash
CUR=$(git -C "$TARGET_REPO" rev-parse --abbrev-ref HEAD)
if [ "$CUR" != "${FIX[base_branch]}" ]; then
  report "⏭️ $TARGET_REPO is on '$CUR', not base '${FIX[base_branch]}' — merge skipped (guards your checkout)"
  report "   worktree + branch kept: ${FIX[worktree]} (${FIX[branch]})"
  report "   merge yourself: git -C $TARGET_REPO checkout ${FIX[base_branch]} && git merge --no-ff ${FIX[branch]}"
  continue
fi
[ -n "$(git -C "$TARGET_REPO" status --porcelain)" ] && {
  report "⏭️ $TARGET_REPO has uncommitted changes — merge skipped (never merges over work in progress)"; continue; }
git -C "$TARGET_REPO" log "${FIX[base_branch]}..${FIX[branch]}" --oneline | head -1 >/dev/null 2>&1 || {
  report "Skip ${FIX[branch]} — no new commits"; continue; }
```

### 5.2 Serial merge loop (within a submodule — never parallel)
```bash
for FIX in "${FIXES[@]}"; do
  TARGET_REPO="${FIX[repo]}"           # submodule path or main root
  BASE="${FIX[base_branch]}"           # from config
  BRANCH="${FIX[branch]}"
  NN="${FIX[nn]}"; TITLE="${FIX[title]}"

  # 5.1 guards run here (on base · clean · has commits) — any of them skips this repo, never forces it

  # the fix branch was cut from origin/$BASE (Phase 3.3) → fast-forward local base onto the remote tip first so
  # the only merge commit is the fix's own. --ff-only = non-destructive: diverged base makes git refuse, not rewrite
  git -C "$TARGET_REPO" pull --ff-only origin "$BASE" || {
    report "⏭️ $TARGET_REPO/$BASE cannot fast-forward from origin (diverged) — merge skipped, user resolves"; continue; }

  git -C "$TARGET_REPO" merge --no-ff "$BRANCH" -m "Merge fix #$NN: $TITLE

Closes #$NN

Co-Authored-By: <AI signature per project convention>"

  if [ $? -ne 0 ]; then
    git -C "$TARGET_REPO" merge --abort 2>/dev/null || true    # restore the pre-merge state; a conflict is the user's job
    report "🛑 Merge conflict on #$NN ($TARGET_REPO/$BASE) — repo restored to its pre-merge state"
    report "Worktree + branch kept at: ${FIX[worktree]}"
    report "User resolves it: cd $TARGET_REPO && git merge --no-ff $BRANCH"
    exit   # stop this submodule only — other submodules continue
  fi
done
```

🔴 **No `git push` in Phase 5** — merge locally and stop; pushing happens through `/ow-git`
🛑 **Conflict = STOP immediately** (that submodule only) — the next fixes in the same submodule hold; other submodules continue
🔴 **Never `git checkout` / `git reset --hard` / `git stash` / `git clean` / `git restore` to make a merge possible** —
they change or drop the user's own work (#29). Wrong branch / dirty / diverged / conflict = **skip + report**, never force.
`pull --ff-only` is the one network step allowed here, and only because it can never rewrite local history.

### 5.3 Cleanup worktrees (only the ones that merged successfully — gate before deleting)

🔴 **Read `.ow/commands/_shared/worktree-cleanup-gate.md` and follow it** — it owns the gate (merge
verified → worktree clean → submodule objects absorbed) and the delete step, shared with `/ow-test` Phase 7.
Paste its §1 function into this block, then per merged fix:

```bash
for FIX in "${MERGED[@]}"; do
  R="${FIX[repo]}"; W="${FIX[worktree]}"; B="${FIX[branch]}"
  ow_wt_gate "$R" "$W" "$B" || continue      # gate failed → keep this worktree, report, next fix
  # gate passed → the gate's §2 delete
done
```

🔴 A failed gate skips **only that fix** — the other merged fixes still get cleaned up (`continue`, never `exit`).

### 5.4 Update fix-log
Update `## 🔧 Fix.Commit` to the **merge commit hash on the base branch** (not the fix branch commit) — because a revert uses the merge hash

---

## Phase 6 — Handoff Report (🔴 STOP here — no push)

```
✅ Parallel fix + auto-merge (local) complete — base branches ready for /ow-test + /ow-git

| # | Title                       | Submodule | Base    | Merge commit | Status      |
|---|-----------------------------|-----------|---------|--------------|-------------|
| 62| <title>                     | web       | develop | abc1234      | ✅ merged   |
| 63| <title>                     | web       | develop | def5678      | ✅ merged   |
| 74| <title>                     | app       | master  | 1357ace      | ✅ merged   |
| 67| <title>                     | web       | develop | —            | ❌ test fail (worktree kept) |

📎 Fix-logs: <VAULT_PATH>/85-FixLog/

📦 Base branches updated LOCALLY (not pushed yet):
  <web>/develop  (#62, #63)
  <app>/master   (#74)

🎯 Next step (user trigger):
  1. /ow-test               # smoke only the area/role the fix touched (from fix-log + reporter)
  2. /ow-git --bump patch   # push + bump + 🟢 AUTO comment "fixed in vX.Y.Z" + flip label ready for test
                             #   (Phase 8.5 — fires by itself because the commit carries Closes #NN; disable with --no-ready-for-test)
  3. after the tester verifies → the user/tester closes the issue themselves

  ℹ️ Already pushed but auto was off at the time / the version was not out yet → run it manually later:
     /ow-fix-issue #62 #63 #74 --ready-for-test [--version X.Y.Z]

🛑 Manual follow-up:
  - #67 (test fail) — worktree kept at worktrees/web-67-<slug>/
    The user goes in to diagnose further, or `git worktree remove --force` to abandon it
    (⚠️ if the worktree contains submodules: unpushed commits inside the submodule are lost with the per-worktree store)
```

---

## Phase 7 — Failure Handling

If an agent fails (test fail / cannot reproduce / blocked):
- Keep the `in progress` label (never roll it back to plain `bug` — confusing)
- fix-log status: `in-progress` (not `fixed`)
- Do not commit in the worktree (keep it dirty for the user to inspect)
- Report to the user naming the blocker

User: goes into the worktree to continue + commits themselves / or `git -C <repo> worktree remove <path> --force`
(⚠️ `--force` on a worktree containing submodules = deletes the per-worktree store — submodule commits not yet pushed/absorbed are lost forever)

---

## Phase 8 — Ready-for-Test Handoff (`--ready-for-test` mode only — run after `/ow-git`)

Runs only when `$ARGUMENTS` has `--ready-for-test` (skips Phase 0.5-7): after push + version bump → tell the
tester which version carries the fix + flip the label `in progress` → `ready for test`.

> **This mode is the sanctioned exception to the "never flip/comment" rule** (see Rules) — because it runs *after* push, as a handoff step by design, not during fix/merge

It runs → 🔴 **Read `.ow/commands/_shared/fix-issue-ready-for-test.md` and follow it** — that file owns
the whole mode (8.0 label set · 8.1 issue set + fix-log · 8.2 verify-pushed gate · 8.3 resolve version ·
8.4 comment + flip · 8.5 fix-log · 8.6 report). Nothing about it is restated here.

---

## Output (short bullets, in `$PROJECT_LANG`)

When /ow-fix-issue finishes, answer in **short bullets that are quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — result table: how many issues fixed/merged (group → pass/fail)
- **Verification** — merge commit hashes **taken from the real git log** + the before→after test result per fix
- **Risks / open** — only when present: partial/failed groups · conflicts still open
- **Next** — not pushed yet → `/ow-test` + `/ow-git --bump`, then `/ow-fix-issue #NN --ready-for-test` (comment version + flip label)

🔴 **Never fabricate** commit hash/test count/link — hashes must be parsed from the real git log; none = `pending verification`.

## Rules

### Mode
- 🌟 **Default = Auto-Discover** — no args → Phase 0.5 (discover + per-group approval + parallel Stage A/B)
- **Specific** — `#NN` present → skip Phase 0.5 + skip the approval gate (invoke = approval) → Phase 1
- **Ready-for-test (resume)** — `--ready-for-test` present → skip Phase 0.5-6 → **Phase 8** (post-push: comment version + flip label). Run after `/ow-git --bump` only
- **Dry-run** — `--dry-run` works in both modes (default: queue plan then stop / specific: resolved issues + planned worktree then stop)

### Scope (doable within a single invocation)
- ✅ Auto-discover real-bugs from GitHub (default)
- ✅ Per-group approval gate (default)
- ✅ Parallel implement of every approved group (Stage A, cap N agents)
- ✅ Commit on the fix branch (the agent does it in the worktree)
- ✅ **Merge into the base branch LOCALLY** — serial within a submodule, parallel across submodules (Stage B)
- ✅ Worktree + fix branch cleanup after a successful merge
- ✅ Update fix-log + the `in progress` label on GitHub

### What the skill **does not do** in the fix/merge flow (Phase 1-6 — handed back to the user)
- 🔴 **Never push** — `/ow-git` only (version bump + cross-submodule coordination)
- 🔴 **Never flip `ready for test` in Phase 1-6** — that is a post-push state; done in **Phase 8 (`--ready-for-test` mode)** after `/ow-git` only
- 🔴 **Never comment on GitHub in Phase 1-6** — neither orchestrator nor agent comments (the version comment happens in Phase 8 only)
- 🔴 **Never close an issue** — the tester verifies before the user/tester closes it (Phase 8 does not close either)
- 🔴 **Never run the `/ow-test` smoke yourself** — user trigger (tests are serial, ports clash, an emulator may be needed)

> **Phase 8 (`--ready-for-test`) is a deliberate exception:** it may flip the label + comment the version because it runs *after* push as a handoff step, while keeping the rules **never close** + **never flip when it is not really pushed** (8.2 gate) + **never fabricate the version** (8.3)

### Safety stops
- 🛑 **Agent test FAIL** → leave the worktree dirty + do not enter the merge queue — other groups continue
- 🛑 **Merge conflict in Stage B** → stop the merge queue of that submodule — other submodules continue — the user resolves it then runs `/ow-git` themselves
- 🛑 **`git pull --ff-only` fail** (base diverged) → skip that fix + report; the worktree and branch are kept
- 🛑 **Target repo not on its base branch, or dirty** → skip that fix + report (Phase 5.1) — 🔴 never `checkout`
  or clean it to make the merge possible (#29); the user's own checkout state is never changed by this command

### Implementation constraints
- 🔴 **Submodule worktree only** (avoids submodule init recursion)
- 🔴 **Cross-submodule fix → serial fallback** (never auto parallel)
- 🔴 **Test creation is mandatory** — the agent must never skip the test mandate
- 🔴 **Worktree dir inside `worktrees/`** (gitignored)
- 🔴 **Always merge --no-ff** (preserves fix branch history → easy revert)
- 🔴 **Base branch read from config** — never hardcode `develop`/`master`
- **Max N global parallel agents** (default 7) — rate limit + output stays readable
- **Commit message:** Conventional Commits + `Closes #<NN>` + Co-Authored-By footer
- **Fix-log Commit hash = the merge commit on the base branch** (a revert uses the merge hash)
- **No fake results:** commit hash / merge hash / test result must come from real git/test output — never fabricated

## Never

- Never push to remote — pushing is `/ow-git`'s job only (obsidian-workflow no-auto-git rule)
- Never flip `ready for test` / comment in the fix/merge flow (Phase 1-6) — done in Phase 8 (`--ready-for-test`) after `/ow-git` only
- Never close an issue in any mode (Phase 8 included) — the tester verifies before the user/tester closes it
- Never flip `ready for test` while it is not really pushed (Phase 8.2 gate) — guards against the tester not finding the build
- Never fabricate the version in a comment — it must come from a real `--version` / commit `[vX.Y.Z]` token / git tag (Phase 8.3, no fake results)
- Never hardcode the base branch (`develop`/`master`) — always read `.ow.yml` `submodules[].branch`
- Never use the `isolation: "worktree"` flag on an agent — we manage the worktrees ourselves (Phase 3)
- Never modify files outside the worktree (except the vault) — other agents are working in parallel
- Never skip test creation — a reproducing test must FAIL before the fix (`_shared/coding-discipline.md` §3); the only exception is a bug the harness genuinely cannot reproduce, and that reason goes in the fix-log
- Never commit a broken state — agent failed = leave the worktree dirty + fix-log status: in-progress
- Never fabricate a commit hash / merge hash / test result (no fake results)
- Never keep merging in a submodule that hit a conflict — STOP that submodule only and report to the user
