---
description: Interactive help — recommend a command for the situation + explain how each command is used + show common workflows
---

# /ow-help — Interactive Help

A question-and-answer helper: "what do you want to do → which command → how does it work"

Everything `/ow-help` prints is user-facing → rendered in `$PROJECT_LANG` (Phase 0); it never writes to the vault.

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
/ow-help                          # interactive — asks what you want to do
/ow-help <command>                # explain that command in depth
/ow-help workflow                 # show the common workflows
/ow-help workflow <name>          # explain one workflow (new-project, bug-fix, github-issue, design, etc.)
/ow-help search <keyword>         # search for a related command/concept
/ow-help cheatsheet               # short 1-page cheatsheet
/ow-help tree                     # decision tree "if X → use Y"
```

## Phase 0 — Detect intent

If `$ARGUMENTS` is empty → ask the user one single question (render in `$PROJECT_LANG`):

```
What would you like me to help with?

  1) Recommend a command for my situation  (if you don't know which one to use)
  2) Explain one specific command          (if you know it but want its options/phases)
  3) Show the common workflows             (e.g. "how do I start a whole new project")
  4) 1-page cheatsheet                     (command list + when to use each)
  5) Search by keyword                     (e.g. "worktree", "obsidian", "submodule")
```

Then do whatever the user picked, in the relevant Phase

## Phase 1 — Mode "recommend by situation"

Ask a batch of 3-5 questions:

1. **Where are you in the project?**
   - Nothing at all yet (empty folder) → `/ow-init` or the installer
   - Code exists but no docs → `/ow-init` in brownfield mode
   - Vault already exists → go to 2
   - Been working on it for a while → go to 2

2. **What are you about to do?** (multi-select)
   - [ ] Start a new feature/task
   - [ ] Fix a bug
   - [ ] Write/update docs (PRD, SRS, ADR, etc.)
   - [ ] Run tests / check the implementation
   - [ ] Executive report
   - [ ] commit/push code
   - [ ] Security / pre-flight check
   - [ ] Hand off the work
   - [ ] Design UI / design system
   - [ ] Update obsidian-workflow itself (commands/templates)

3. (if "new feature/task" was picked) **Do you already have a PRD/spec?**
   - Not yet → `/ow-new` (brainstorm)
   - Yes → `/ow-new --import <path>` (import + continue with SRS/Tech)
   - Vault feature already exists → `/ow-plan <task>` directly

→ Recommend the command + cite the link path of `.ow/commands/<name>.md` for further reading

### Decision tree (used in `tree` mode)

```
Ask: does the project already have a .ow.yml?
├─ No → /ow-init  (or run the installer first)
└─ Yes → ask next: what do you want to do?
    ├─ "new idea"                    → /ow-new
    ├─ "already have a PRD"          → /ow-new --import
    ├─ "plan a feature"              → /ow-plan <task>
    ├─ "the plan is too big / small-context model" → /ow-split <plan-file>
    ├─ "work through a plan"         → /ow-implement <plan-file>
    ├─ "fix a bug"                   → /ow-fix <bug>
    ├─ "fix GitHub issues in bulk"   → /ow-triage-issues → /ow-fix-issue #NN → /ow-git --bump (auto ready-for-test)
    ├─ "write/edit a doc"            → /ow-doc <type>
    ├─ "smoke test"                  → /ow-test
    ├─ "design UI"                   → /ow-design [init|tokens|component]
    ├─ "security check"              → /ow-secure
    ├─ "verify + handoff"            → /ow-verify
    ├─ "commit/push"                 → /ow-git [--plan|--fix|--branch]
    └─ "update obsidian-workflow"            → /ow-sync
```

## Phase 2 — Mode "explain one specific command"

Read `.ow/commands/<cmd>.md`, then summarize it for the user in this shape:

```
## /ow-<name>

Use when: <one-line>

Trigger:
  <list trigger forms>

What it does: (Phase summary — no long detail)
  1. <Phase 1 in a single sentence>
  2. <Phase 2 ...>

Result in the vault:
  - <files it creates/edits>

Never: (top 2-3)
  - <most important>

Follow with: → /ow-<next>

Read the full spec: .ow/commands/ow-<name>.md
```

## Phase 3 — Mode "workflows"

Show the workflow card the user picked:

### `workflow new-project` — start a new project from scratch

```
1. bash <(curl ... install.sh)         ← bootstrap
2. /ow-init                            ← config (vault location, subagents)
3. /ow-new                             ← brainstorm → PRD + SRS + Tech-spec
4. /ow-design init                     ← (optional) bootstrap design system
5. /ow-plan FEAT-X                     ← plan the first feature
6. [user review plan, set status: approved]
7. /ow-implement docs/80-.../plan.md   ← execute (inline, or a subagent when the work earns one)
8. /ow-test                            ← smoke test
9. /ow-secure                          ← pre-flight
10. /ow-verify                         ← handoff report
11. /ow-git --plan <path>              ← commit + push
```

### `workflow bug-fix` — fix a bug, red→green

```
1. /ow-fix "search hangs on underscore"  ← diagnose + fix-log (no code)
2. /ow-plan fix:<slug>                   ← small plan referencing fix-log
3. /ow-implement <plan>                  ← execute
4. /ow-test --since <sha>                ← verify fix
5. /ow-secure                            ← scan
6. /ow-verify                            ← handoff
7. /ow-git --fix <fix-log-path>          ← commit (prefix: fix:)
```

### `workflow github-issue` — triage + fix GitHub bugs through to tester handoff

```
1. /ow-triage-issues                     ← pull the bug pool (one snapshot) → classify + label + propose clusters
   → STOP + confirm before touching GitHub (Phase 4.4)
2. /ow-fix-issue #62 #63                  ← one worktree per group → diagnose → test → RED/GREEN record → fix → merge locally
   → no push / no comment / no label flip (hands back)
3. /ow-test --since <ref>                 ← smoke only the area/role the fix touched
4. /ow-git --bump patch                   ← push + bump version
   → 🟢 AUTO (Phase 8.5): commit contains `Closes #NN` → comment "fixed in vX.Y.Z" + flip label `ready for test`
      (disable with --no-ready-for-test; the version comes from --bump, the most precise source)
5. [tester verifies on vX.Y.Z] → the tester/user closes the issue themselves

ℹ️ If auto was disabled at push time / the version is not out yet → trigger the handoff manually later:
   /ow-fix-issue #62 #63 --ready-for-test [--version X.Y.Z]

🔴 triage = read-only on code · fix-issue does not push · closing = tester only (verify first)
```

### `workflow design` — create/use the design system

```
1. /ow-design init                       ← bootstrap minimal DS
   → creates DS-Tokens.md, DS-Components.md, ..., preview.html
2. Open <vault>/70-Reference/DesignSystem/preview.html in a browser
3. /ow-design tokens                     ← adjust tokens (brand colors, type)
4. /ow-design component <name>           ← add a new component
5. /ow-design audit                      ← check implementation vs DS

After init → every UI change is forced to use the DS (the gate is on the work, so it binds inline runs too — not only a frontend/mobile subagent this project created)
Never do ad-hoc styling — if a new component is needed → STOP, run /ow-design first
```

### `workflow brownfield-adopt` — adopt an existing codebase into obsidian-workflow

```
1. cd existing-project
2. bash <(curl ... install.sh)             ← brownfield mode auto-detect
   → the installer asks for the vault location (A/B/C/D)
   → pick B (docs/ow-vault/) if docs/ is already in use
3. /ow-init                                ← interactive — detects the stack, asks about importing the README
4. (if a README exists) → review the generated PRD draft
5. /ow-doc PRD-<slug>                      ← fill in the missing sections
6. /ow-plan <first task>                   ← start the normal workflow
```

### `workflow submodule` — obsidian-workflow as a submodule inside a larger repo

```
1. cd parent-repo
2. git submodule add https://github.com/.../obsidian-workflow .ow
3. cd .ow
4. /ow-init                                ← pick mode: submodule
   → the vault may be external (D), pointing outside the submodule
5. Set a submodules: list in .ow.yml
6. /ow-git --update-submodules             ← sync submodules inside the parent
```

## Phase 4 — Mode "cheatsheet"

Show a 1-page table (as short as possible):

```
| Command         | Use when                              | Main result              |
|-----------------|---------------------------------------|--------------------------|
| /ow-init       | first-time project setup              | .ow.yml + vault   |
| /ow-new        | start a new project/feature           | PRD + SRS + Tech        |
| /ow-clarify    | scan a spec for ambiguity             | clarified spec          |
| /ow-plan       | plan work (before touching code)      | plan file in 80-...     |
| /ow-split      | a plan too big for one session        | sub-plans + CONTRACT    |
| /ow-checklist  | spec-quality gate per domain          | checklist file          |
| /ow-implement  | execute a plan (the only code editor) | code + build/test + log |
| /ow-fix        | diagnose a bug (no code change)       | fix-log in 85-FixLog    |
| /ow-triage-issues | triage GitHub bugs in bulk         | label+comment+cluster   |
| /ow-fix-issue  | fix GitHub bugs in parallel (worktree)| fix branches (local)    |
| /ow-reverse-engineer | extract spec from existing code  | FEAT/FN/REF drafts      |
| /ow-doc        | write/edit a doc                      | doc file in vault       |
| /ow-test       | smoke test the diff                   | test report             |
| /ow-design     | create/update DS + Figma import       | DS-*.md + preview.html  |
| /ow-secure     | security pre-flight                   | secure report           |
| /ow-verify     | verify (tests/vault/security/DS)      | verify report           |
| /ow-handoff    | executive handoff report              | HOR-*.md in 95-Handoff  |
| /ow-git        | submodule-aware commit/push           | git history             |
| /ow-sync       | pull the latest snapshot from the obsidian-workflow repo | .ow/ updated |
| /ow-agent      | manage subagents                      | .claude/agents/ updated |
| /ow-help       | this help                             |                          |
```

## Phase 5 — Mode "search"

Read the description + frontmatter of every `.ow/commands/*.md` + their key sections — search the keyword:

```bash
grep -l "$KEYWORD" .ow/commands/*.md
grep -l "$KEYWORD" .claude/agents/*.md
```

Show the result:
```
🔎 Keyword: "worktree"

Commands that mention it:
  • /ow-implement  — build in an isolated worktree
  • /ow-test       — test in the worktree + auto-merge on PASS
  • /ow-fix-issue  — one worktree per issue group, in parallel
  • /ow-git        — commit/push after the merge

Subagents that mention it (only those that exist here — the grep above is the truth):
  • verifier        — runs the checks inside the worktree
  • test-runner     — smoke run in the worktree (present only if /ow-agent create wrote it)

Rule files that may apply:
  • .ow/rules/testing.md
  • .ow/rules/security.md
```

## Output (short bullets, in `$PROJECT_LANG`)

`/ow-help` is **read-only** — it never creates or edits a file in the vault. Answer in **short bullets** in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English):

- Answer exactly what the user asked — the command that fits the situation / tree / cheatsheet
- Nothing is written (read-only) — no result section needed

Close with a small reminder (render in `$PROJECT_LANG`):

> 💡 Still not sure → try `/ow-help tree` or `/ow-help cheatsheet`
> 📖 Read in full: `cat commands/<name>.md`

## Never

- Never edit any file — help is read-only
- Never guess a command that does not exist — list only verbs that have a file in `.ow/commands/`
- Never invent a workflow that is not in the Phase 3 cards — if the user asks outside that scope → use Phase 1 to keep asking
- Never explain a command's internal phases beyond what is needed — send the user to read `.ow/commands/<name>.md` themselves
