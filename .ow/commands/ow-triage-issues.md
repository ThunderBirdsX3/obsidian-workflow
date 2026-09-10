---
description: Batch-triage GitHub bug issues — classify + label + comment + propose clusters (read-only on code, confirmation gate before touching GitHub)
---

# /ow-triage-issues — GitHub Bug Triage Bot

Batch-triage GitHub issues labelled `bug` → classify + label + comment + propose clusters (never edits code, never opens a fix-log)

> **Core rule:** `/ow-triage-issues` is **read + label + comment only**. Never edit code, never open a fix-log, never close an issue yourself (except for the classes explicitly marked closeable)
>
> Triage is the step **before** `/ow-fix-issue` — it separates ready-to-fix real bugs from question/need-info/wontfix/not-implement-yet, so `/ow-fix-issue` only picks up confirmed ones

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

## Prerequisite

- `gh` CLI authenticated (`gh auth status`)
- Inside a git repo bound to a GitHub remote
- The `gh-issue` agent is enabled (run `/ow-agent enable gh-issue` if it is not)

## Trigger

```
/ow-triage-issues                    # triage every bug without a triage/fix label yet
/ow-triage-issues #62 #63 #64        # triage only the issues named
/ow-triage-issues --dry-run          # classify + report, without really labelling/commenting
/ow-triage-issues --no-cluster       # skip cluster detection (pass 1 only)
```

The default repo comes from `gh repo view --json nameWithOwner -q .nameWithOwner` (must be inside a git repo)

---

## Phase 0 — Pre-flight

### 0.1 Check gh CLI + repo
```bash
gh auth status || { echo "Run 'gh auth login' first"; exit 1; }
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repo: $REPO"
```

### 0.2 Resolve label set (config-aware)

Triage uses labels to classify handling. Defaults (overridable in `.ow.yml` under `triage.labels.*`):

| Purpose | Default label |
|---|---|
| bug (real, pending fix) | `bug` |
| not-a-bug / how-to | `question` |
| needs more info | `need info` |
| feature / spec pending | `not implement yet` |
| by-design / out-of-scope / dup | `wontfix` |
| in progress (set by fix-issue) | `in progress` |
| ready for tester | `ready for test` |
| cluster marker | `cluster` |

Only one new label is needed — `cluster`. If it does not exist → create it:
```bash
gh label list --search cluster --json name -q '.[].name' | grep -qx cluster || \
  gh label create cluster --color "fbca04" --description "Issue grouped with related issues (see comment)"
```

If the project uses different label names (another language / another scheme) → read them from `.ow.yml`:
```yaml
# optional override
triage:
  labels:
    bug: "bug"
    question: "question"
    need_info: "need info"
    not_implement: "not implement yet"
    wontfix: "wontfix"
    in_progress: "in progress"
    ready_for_test: "ready for test"
    cluster: "cluster"
```

---

## Phase 1 — Fetch Pool

### 1.1 Default pool (no args) — **oldest first**
```bash
# Capture into a variable exactly once — this is the raw snapshot frozen in 1.3
POOL_JSON=$(gh issue list \
  --label bug \
  --search "is:open sort:created-asc \
            -label:question -label:\"need info\" \
            -label:\"not implement yet\" -label:wontfix \
            -label:\"in progress\" -label:\"ready for test\"" \
  --limit 50 \
  --json number,title,labels,author,body,url,createdAt)
```

In words: **open bugs carrying no triage/fix label at all — ordered oldest to newest**

🔴 **`sort:created-asc` is mandatory** — because:
1. An older issue has waited longer → higher priority (nothing left to rot)
2. An older issue may be the root cause of a newer one → triaging it first helps dedupe the newer ones
3. Cluster detection (Phase 3) works better — the older issue is usually the cluster's parent

### 1.2 Explicit pool (args are issue numbers)
If `$ARGUMENTS` carries issue numbers → fetch only those with `gh issue view <N> --json ...`, collect them into `POOL_JSON` (an array), and sort by `createdAt` ascending before processing — an explicit pool is already a snapshot (the user named it exactly; it never grows on its own)

### 1.3 🧊 Freeze snapshot — **fetch the pool once, then lock it**

🔴 **The pool is snapshotted here exactly once** — store the issue numbers from 1.1/1.2 as a **frozen ordered list** (e.g. `POOL=[55, 56, 67, 71, 74]`) and use that list for the whole run

```bash
# Captured once — every later phase reads this variable; never re-query
POOL=$(echo "$POOL_JSON" | jq -r 'sort_by(.createdAt) | .[].number')
echo "🧊 Frozen pool ($(echo "$POOL" | wc -w | tr -d ' ') issues): $POOL"
```

🔴 **After 1.3, never run `gh issue list` again for the rest of the run** — both batching (Phase 2) and apply (Phase 5) must **slice from the frozen `POOL`** only

🔴 **An issue that arrives / is relabelled after the snapshot is OUT OF SCOPE for this run** — even if it matches the `bug` filter, never pull it in mid-run. The user runs `/ow-triage-issues` again to pick up new arrivals (a fresh snapshot)

> **Why:** triage is a batch job that must be deterministic — the preview (Phase 4) must match exactly what is applied (Phase 5). If the pool grows mid-run the preview goes stale and the user approves one set while another is applied (breaking the confirmation-gate contract)

### 1.4 Report the pool before starting
Show the user (oldest → newest, from the frozen `POOL`), rendered in `$PROJECT_LANG`:
```
🔍 Pool to triage: N issues (oldest first, snapshot @ <time>)
  #55 — [BUG] <title> (2026-05-27)
  #56 — [BUG] <title> (2026-05-27)
  ...
  #74 — [BUG] <title> (2026-05-28, newest)

Split into batches of ≤ 7 (eases rate limits + keeps output readable)
⌈N / 7⌉ batches in total — processed in order (oldest first) from the frozen pool
```

If the pool exceeds 20 → confirm with the user before starting

---

## Phase 2 — Parallel triage (batches of ≤ 7)

🔴 **Every batch is sliced from the frozen `POOL` (Phase 1.3) only** — `batches = chunk(POOL, 7)`. Never run `gh issue list` again to find "the next batch"; loop until `POOL` is exhausted and stop, no matter how many new issues arrive meanwhile

### 2.1 Fan out per issue (parallel)

For each issue in the batch → dispatch the `gh-issue` agent **in a single message** (max 7 in parallel) to:
- Fetch full content + images
- Return structured analysis

Prompt sent to the gh-issue agent:
```
Read issue #<NN> from repo <owner>/<repo>.
Return summary + all image observations.
DO NOT modify the issue (you are read-only).
```

### 2.2 Classify (Claude reads the agent output, then decides)

For each issue → classify using this rule sheet:

| Class | Criteria | Label action | Comment? | Close? |
|---|---|---|---|---|
| **real-bug** | Reproducible + the system behaves against spec | Keep `bug` (no change) | optional summary | no |
| **not-a-bug (question)** | User misunderstood / asking how-to / the spec is correct | + `question`, remove `bug` | ✅ explain why | ✅ |
| **needs-info** | Repro insufficient / screenshot missing / version unclear | + `need info` | ✅ ask for the specific missing field | no |
| **not-implement-yet** | Wants a new feature / the customer's spec has not arrived | + `not implement yet`, remove `bug` | ✅ state which spec is awaited | no |
| **duplicate** | Duplicates an older issue (open or closed) | + `wontfix` | ✅ link the original issue | ✅ |
| **wontfix** | By design / out of scope / cost > benefit | + `wontfix` | ✅ explain why | ✅ |

> **Conservative rule:** when the class is unclear → default to `needs-info`, the safest option. Never guess

### 2.3 Plan only — **never apply here**

🔴 Phase 2 is classify + plan, **held in memory only**. Never call a real `gh issue edit/comment/close`

Per issue, store a struct:
```yaml
- nn: 62
  title: "..."
  class: real-bug
  add_labels: []                  # real-bug = no label added
  remove_labels: []
  close: false
  comment: null                   # real-bug = no comment (the no-comment rule, Phase 4.2)
  reasoning: "UI bug rendering the wrong button, clear repro, screenshot attached"

- nn: 73
  title: "..."
  class: wontfix
  add_labels: [wontfix]
  remove_labels: []
  close: true
  comment: |
    **Triage:** wontfix
    <1-3 sentence rationale, rendered in `$PROJECT_LANG`>
    — Triaged by `/ow-triage-issues`
  reasoning: "This behaviour follows deliberate design intent — etc."
```

The full plan is shown in Phase 4 for the user to review **before applying**

---

## Phase 3 — Cluster detection (plan only; skipped with --no-cluster)

Once every issue is classified → **for class `real-bug` only** → work out clusters and store them in the plan struct (never comment on GitHub here)

### 3.1 Heuristic
- **Surface overlap:** the issue bodies mention the same page/component (e.g. the registration page, a dropdown, profile upload)
- **Root cause guess:** similar error patterns (e.g. several "duplicate dropdown" issues may all come from one master-data resolver)
- **Files touched:** from the guessed submodule + component → overlap suggests a cluster

### 3.2 Store the cluster in the plan struct (never apply)
For each issue in the cluster → add a `cluster_comment` field to be posted in Phase 5:

```yaml
- nn: 62
  class: real-bug
  cluster_slug: patient-register
  cluster_members: [62, 63, 64, 65, 66, 69]
  cluster_comment: |
    **Cluster proposal:** could be fixed together with #63, #64, #65, #66, #69
    **Why:** the same registration-page form
    **Next:** if you agree, add the `cluster` label by hand → `/ow-fix-issue #62 #63 #64 #65 #66 #69`
    — Proposed by `/ow-triage-issues`
```

🔴 **Never `gh issue comment` in Phase 3** — hold it and apply with Phase 5 after the user says yes

🔴 **Never apply the `cluster` label yourself** — the user decides (a manual gate)

---

## Phase 4 — Preview + confirmation gate (🔴 mandatory before applying)

Show the user the whole plan **before touching GitHub**, in 3 sections — then **STOP and ask** before Phase 5

### 4.1 Full classification table (every issue processed)

```
✅ Triage Complete — N issues processed

| #                                          | Title (truncated)    | Class            | Action                  |
|--------------------------------------------|----------------------|------------------|-------------------------|
| [#74](https://github.com/<REPO>/issues/74) | <title>              | real-bug         | kept `bug` (no comment) |
| [#73](https://github.com/<REPO>/issues/73) | <title>              | wontfix          | + wontfix, closed       |
| [#72](https://github.com/<REPO>/issues/72) | <title>              | real-bug         | kept `bug` (no comment) |
| [#71](https://github.com/<REPO>/issues/71) | <title>              | real-bug         | kept `bug` (cluster ⇄ [#63](https://github.com/<REPO>/issues/63)) |
| [#67](https://github.com/<REPO>/issues/67) | <title>              | not-implement-yet| + not implement yet (comment) |
```

🔴 **The "Action" column must read "(no comment)" for every real-bug** — so the user sees the skill deliberately did not comment (rather than skipping or losing it)

### 4.2 🎯 Ready to fix (real bugs) — **this section is the pool for `/ow-fix-issue`**

```
🎯 Ready to fix — N real bugs (click a number to open the issue / copy the command below)

Standalone:
  [#74](https://github.com/<REPO>/issues/74) — <title> (mobile, P2)
  [#72](https://github.com/<REPO>/issues/72) — <title> (web, P0 data loss)

Cluster A — Patient Registration form (web):
  [#62](https://github.com/<REPO>/issues/62) [#63](https://github.com/<REPO>/issues/63) [#64](https://github.com/<REPO>/issues/64) [#65](https://github.com/<REPO>/issues/65) [#66](https://github.com/<REPO>/issues/66) [#69](https://github.com/<REPO>/issues/69)

Suggested commands:
  /ow-fix-issue #74                                  # standalone (mobile)
  /ow-fix-issue #72                                  # standalone (web, P0 first)
  /ow-fix-issue #62 #63 #64 #65 #66 #69              # Cluster A (web)
```

🔴 **This section lists every real bug — commented or not.** A real bug with "no comment" means "nothing to add, ready to fix" and must always appear in this list

### 4.3 Handled (closed by triage) — informational only

```
✅ Handled by triage — N closed/parked:
  [#73](https://github.com/<REPO>/issues/73) — wontfix (closed)
  [#67](https://github.com/<REPO>/issues/67) — not implement yet (waiting customer spec)
```

🔴 **`<REPO>` in the template is the literal `$REPO`** from Phase 0.1 — substitute it before rendering; never leave the placeholder

🔴 **Every issue number in every section's output** → always wrapped in a markdown link

🔴 **Real-bug selection rule:** "no comment" on an issue is **not** a signal of "skip / not actionable" — it signals "real bug, nothing to add, ready to fix". Section 4.2 must include every issue whose class is `real-bug`

### 4.4 🛑 Confirmation gate (mandatory — STOP + ask the user)

After 4.1-4.3 are all shown → **STOP** and ask (render in `$PROJECT_LANG`; the answer keywords stay as written):

```
─────────────────────────────────────────────
🔍 The above is the plan, before applying (GitHub is untouched so far)

Apply all of it?
- "yes" / "y" / "ok"   → apply the whole batch (labels + comments + closes per the plan + cluster comments)
- "no" / "n" / "cancel" → cancel; GitHub stays untouched
- "skip #NN #MM ..."    → apply everything except the numbers named
- "reclassify #NN as <class>" → reclassify, then re-show the preview and ask again
─────────────────────────────────────────────
```

🔴 **Never apply until the user answers yes/skip explicitly** — if the answer is unclear, ask again. Never guess

🔴 **The `--dry-run` flag skips Phase 5 entirely** — show the preview and stop, without the gate question (for when the user only wants to inspect the plan)

---

## Phase 5 — Apply the approved changes (after the user says yes)

Runs only when the user answered `yes` (or a `skip #...` excluding some)

### 5.1 Per-issue apply (parallel-safe, batch ≤ 7)

For each issue in the approved list:

```bash
NN=<from plan>
# 1. Apply labels (add before remove)
[ -n "<add_labels>" ]    && gh issue edit "$NN" --add-label "<add_labels>"
[ -n "<remove_labels>" ] && gh issue edit "$NN" --remove-label "<remove_labels>"

# 2. Post the classification comment (when the plan has one)
[ -n "<comment>" ]         && gh issue comment "$NN" --body "<comment>"

# 3. Post the cluster proposal comment (when the plan has one)
[ -n "<cluster_comment>" ] && gh issue comment "$NN" --body "<cluster_comment>"

# 4. Close if plan.close = true
[ "<close>" = "true" ]     && gh issue close "$NN"
```

🔴 **Order matters:** labels before comments — so the comment lands on an issue already in its new class

### 5.2 Report apply result

Show the user:
```
✅ Applied N/M issues
  ✅ #62 — labels updated, cluster comment posted
  ✅ #73 — wontfix label + comment + closed
  ✅ #67 — not implement yet label + comment
  ⚠️ #74 — failed: <gh error>  → the user retries it themselves
  ⏭️ #71 — skipped (per user request)
```

---

## Output (short bullets, in `$PROJECT_LANG`)

Close /ow-triage-issues with **short, quickly readable bullets** in the configured language (`$PROJECT_LANG` from Phase 0). Only:

- **What was done** — the issues classified + the labels/closes applied (after the gate)
- **Result** — the apply result table (5.2), the issue URLs actually changed, labels before/after
- **Open** — issues whose class was unclear (defaulted to need-info), clusters the user has not confirmed
- **Next** — `/ow-fix-issue` on the real bugs in section 4.2

🔴 Apply only after the user clears the confirmation gate — **never fabricate** an issue URL or label; cite what `gh` actually returned.

## Rules

- 🔴 **Read-only with respect to code** — never edit a file in the repo, not even to "check the root cause"
- 🔴 **Triage verifies nothing itself** (read-only against the filesystem) — the red→green trail starts at `/ow-fix` / `/ow-fix-issue`,
  **one folder per task** (`fix-<NN>-<slug>/`) reused by implement+test across the whole flow (#28); triage merely hands real bugs to `/ow-fix-issue`
- 🔴 **Frozen pool** — `gh issue list` runs exactly once (Phase 1.1), snapshotted into `POOL` (Phase 1.3); every batch/apply iterates over `POOL` alone. Never re-query mid-run; an issue arriving after the snapshot is out of scope (picked up on the next run)
- 🔴 **The confirmation gate is mandatory** — Phase 2/3 are plan-only (in memory); Phase 5 applies only after the user says yes
- 🔴 **Never `gh issue edit/comment/close` in Phase 2/3** — every write belongs to Phase 5
- 🔴 **The `cluster` label is applied by the user only** — the skill merely posts a cluster proposal comment in Phase 5
- 🔴 **--dry-run is honoured whenever the user passes it** — preview, then stop: no gate question, no apply
- **Batches of ≤ 7 parallel agents** in Phase 2 (classify) — eases rate limits + keeps the output readable
- **Batches of ≤ 7 parallel `gh` calls** in Phase 5 (apply) — same reason
- **Conservative classification:** unclear = `need info` (never guess real vs not-a-bug)
- **Comments are rendered in `$PROJECT_LANG`** (`.ow.yml` `project.language` — default `th`). GitHub comments are user-facing, so they follow `$PROJECT_LANG`, never `$VAULT_LANG`
- **End every comment with `— Triaged by /ow-triage-issues`** for auditability
- **Never touch an issue that already carries a triage/fix label** (the Phase 1 filter handles this, but double-check)
- **Never touch an issue without the `bug` label** — `enhancement`, `documentation` etc. are out of scope
- **Never put an implementation suggestion in a comment** — classification + reasoning only (`/ow-fix-issue` works out the how later)
- **Never fabricate issue content / a label / a comment that was not actually posted** — the no-fake-results rule

## Never

- Never edit code or any file in the repo — triage is read-only with respect to code
- Never re-run `gh issue list` after Phase 1.3 — the pool is frozen; never pull new issues in mid-loop (the preview must match the apply exactly)
- Never `gh issue edit/comment/close` before the confirmation gate (Phase 4.4) — Phase 2/3 are in-memory planning only
- Never apply until the user answers yes/skip explicitly — an unclear answer means ask again, never guess
- Never apply the `cluster` label yourself — propose it in a comment and let the user apply it
- Never guess an unclear class — default to `need info` (conservative)
- Never fabricate issue content / a label / a comment that was not actually posted (no fake results)
- Never open a fix-log or start fixing a bug during triage — that is `/ow-fix-issue`'s job
