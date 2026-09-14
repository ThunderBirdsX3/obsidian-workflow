---
description: Taxonomy-driven ambiguity scan + 1-at-a-time question with recommended answer → write Clarifications log back into spec
---

# /ow-clarify — Ambiguity Scan (1-at-a-time)

Scan a spec/plan/PRD, then ask one question at a time (max 5) with a **Recommended answer** to cut decision fatigue
Write the answers back into the doc as a `## Clarifications` list — one entry per question, the answer that holds today

> **inspired by:** spec-kit `/clarify`

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
/ow-clarify                          # scan latest active plan
/ow-clarify <path-to-doc>            # scan specific doc (PRD/SRS/FEAT/plan/etc.)
/ow-clarify --feature <slug>         # scan all docs of a feature
/ow-clarify --max 3                  # override max questions (default: 5)
/ow-clarify --resume                 # continue a pending session
```

## Phase 0 — Resolve target

```bash
# Use scripts/ow-paths.sh if available
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)"

if [ -z "$ARGUMENTS" ]; then
  # default: latest plan in 80-ImplementPlan with status: planning|approved
  TARGET=$(ls -t "$VAULT_PATH/80-ImplementPlan"/*.md 2>/dev/null | head -1)
fi
test -f "$TARGET" || echo "target not found"
```

Show the user (render in `$PROJECT_LANG`):
> Will scan: `<TARGET>`
> Type: PRD / SRS (hub · module) / Feature / Plan / Function / Fix-log
> Existing clarifications: <N> session(s)
> Continue?

🔴 Target is an SRS with `srs_layout: split` (the hub, or a file with `srs_hub:`) → read
`.ow/commands/_shared/srs-layout.md` § Clarifying a `split` SRS — it sets which files Phase 1 scans
and which file each answer is written to in Phase 3.

## Phase 1 — Taxonomy scan (read-only)

Check for ambiguity across 9 categories (from spec-kit):

| Category | Example ambiguity to hunt for |
|---|---|
| **1. Functional Scope** | "support multiple X" — how many? every type? |
| **2. Domain & Data** | "user" — which role? "order" — what is in the schema? |
| **3. UX / Behavior** | "show notification" — modal/toast/banner? auto-dismiss? |
| **4. Non-functional Requirements** | "fast" — how many ms? "secure" — which threat model? |
| **5. Integration** | "send to API" — endpoint? auth? retry? |
| **6. Edge Cases** | empty state, network fail, concurrent edit, permission denied |
| **7. Constraints** | budget, deadline, team size, must-reuse |
| **8. Terminology** | "member" vs "user" vs "account" — which one do we use |
| **9. Completion / DoD** | what does "done" mean? — code merged? deployed? approved? |

For each category:
1. Grep target doc + linked docs (frontmatter `related:` + wikilinks)
2. Find weasel words: "should", "could", "may", "fast", "many", "appropriate", "TBD", "?"
3. Find `[NEEDS CLARIFICATION]` markers
4. Collect candidate questions

Reduce the list → **max 5 questions**, selected by:
- Severity (Critical > High > Medium)
- Block downstream (e.g. affects the data model or API contract)
- Cheap to answer (1 sentence)

## Phase 2 — Ask 1 question at a time

**Never batch** — ask one at a time (unlike /ow-new and /ow-plan, which batch)

Format of each question (render in `$PROJECT_LANG`):

```markdown
🔍 Clarification 2/5 — Category: UX / Behavior

**Question:**
When checkout succeeds, how should the system present the result?

**Options:**
  A) Toast (auto-dismiss 3 seconds) — discrete, does not block the flow
  B) Modal dialog (user must click close) — explicit confirmation
  C) Inline message on the same page — suits an embedded flow
  D) Redirect to /checkout/success page — most complete, includes receipt

**Recommended:** B) Modal dialog
**Reasoning:** The librarian needs explicit confirmation before proceeding; matches DS-Components Modal pattern; aligned with FN-Web-Lib-Checkout state diagram.

**Your answer:** [A/B/C/D or free text]
```

User answers → record + move to the next question

If the user answers `skip` or `TBD` → record as `[DEFERRED]` in the Clarifications log

## Phase 3 — Write back to source doc

After the session ends (5 questions, or the user stops earlier):

```markdown
<!-- in the source doc — add the section before "Acceptance Criteria" -->

## Clarifications

- **Q1 (UX):** Toast vs modal for checkout success? **A:** Modal. Reasoning: explicit confirmation needed. *(2026-05-21)*
- **Q2 (Edge):** Behavior when the network fails during checkout? **A:** Show inline error + retry button; keep form state. *(2026-05-21)*
- **Q3 (NFR):** Acceptable checkout latency? **A:** p95 ≤ 800ms. *(2026-05-21)*
- **Q4 (Domain):** "Overdue" definition — plain due_date or business day? **A:** Calendar day (grace period 1 day weekend). *(2026-05-21)*
- **Q5 (Terminology):** "Member" vs "Patron" — which one? **A:** Member (consistent with the PRD glossary). *(2026-05-21)*
```

The date stamp records **when the answer that stands was given** — it is a field, not a history: an
entry carries exactly one answer, never a previous one beside it.

Question/answer text written into the source doc is in `$VAULT_LANG` (Phase 0); the `## Clarifications`
heading, the `Q#`/`A` labels and frontmatter stay English.

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** — a doc outside
`$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now; a
"was X, now Y" / "changed from … to …" sentence belongs in the plan or fix-log of the run that
made the change, never in the doc.

`## Clarifications` already exists → **append the new questions, and update in place any question this
session re-answered** (overwrite that entry's answer + date stamp). Never leave two answers to the same
question in the doc: the entry states what holds today, and the answer it replaced stays in git and in
the plan of the run that changed it.

## Phase 4 — Update affected docs

If an answer affects:
- **Data model** → flag in the plan: "data-model.md needs update (Q4)"
- **API contract** → flag in REF-APIIntegration.md
- **DS component** → flag if new variant needed
- **FR list** → suggest FR-### addition/refinement (a split SRS → name the module + an ID inside its FR range)

Do not edit the other docs yourself — only **flag** them so the user runs `/ow-doc` or `/ow-plan --revise`

## Phase 5 — Update IMPLEMENTATION-STATUS

Update IMPLEMENTATION-STATUS.md if the target doc changes status (e.g. planning → approved-pending-update)

## Phase 6 — Next-step suggestion

> ✅ Clarifications saved → `<target>`
>
> Next:
>   • Revise plan: `/ow-plan --revise <target>`
>   • Re-verify consistency: `/ow-verify --feature <slug>`
>   • If data-model changed: `/ow-doc data-model <feature>`
>   • If unblocked: `/ow-implement <plan>` (only if status: approved)

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-clarify, reply with **short bullets, quick to read**, in the config language (`$PROJECT_LANG` from Phase 0; `en` → English). Include only:

- **What was done** — how many clarifications were added to the spec + answer log path
- **Impact** — affected/downstream docs that need revising (only if any)
- **Next** — `/ow-plan` (or revise the affected docs first)

🔴 Every recommended answer must cite vault content (link doc/section) — never guess.

## Never

- Never batch questions — **one at a time only**
- Never give a recommended answer that is not grounded in vault content (every reasoning must cite a link to a doc/section)
- Never edit the source doc outside the `## Clarifications` section — do not touch FR, Goals, etc.
- Never ask a question the vault already answers — Phase 1 must filter those out first
- Never edit any other doc — flag only
- Never invent an unrealistic option — if unsure → offer just 2 options + "[OTHER]" for the user to type their own
