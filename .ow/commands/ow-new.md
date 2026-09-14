---
description: Start new project from idea (brainstorm) or existing PRD — builds PRD → SRS → Tech spec chain
---

# /ow-new — Start a new project, from an idea or a PRD

Use when:
- You have an idea but no documents yet → **Brainstorm mode**
- You already have a PRD and want to continue into SRS/Tech spec → **Import mode**

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
/ow-new
/ow-new <one-line description>
/ow-new --import <path-to-existing-prd>
```

## Phase 0 — Detect mode

| Argument | Mode |
|---|---|
| empty | ask (render in `$PROJECT_LANG`): "Do you already have a PRD? (`brainstorm` / `import` / `show-existing`)" |
| free text | **Brainstorm** with seed |
| `--import <path>` | **Import** existing PRD file |

If `<vault>/10-PRD/` already holds files → tell the user + ask (render in `$PROJECT_LANG`) whether to start a new one or continue from the existing one

## Phase 1 (Brainstorm mode) — Open up the idea

Ask **all 5 questions in one go** (never one at a time), rendered in `$PROJECT_LANG`:

1. **Problem**: What problem do you want to solve? Who hits it?
2. **Target users**: Who are the primary users? (1-3 personas)
3. **Goals**: What do users get once they use it? (3-5 outcomes)
4. **Non-goals**: What will **not** be done in this MVP? (guards the scope)
5. **Constraints**: deadline, budget, tech stack, compliance, mandated language?

From the answers → create the documents below. Prose written into these files is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** — a doc outside
`$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now; a
"was X, now Y" / "changed from … to …" sentence belongs in the plan or fix-log of the run that
made the change, never in the doc.

### 1.1 PRD draft

`<vault>/10-PRD/PRD-<project-slug>.md` following `templates/prd.md` (if it is not in `templates/`, use `.ow/templates/prd.md`)

Frontmatter:
```yaml
---
tags: [type/prd]
status: draft           # draft | review | approved | superseded
version: 0.1.0
date: YYYY-MM-DD
authors: [<user>]
---
```

### 1.2 Ask for clarification (round 2, if questions remain)

If detail on business rules, scale, or integration is still missing → ask **one more round only** (in `$PROJECT_LANG`), then keep writing

### 1.3 Create the SRS

`<vault>/10-PRD/SRS-<project-slug>.md` following `templates/srs.md`

Section: System overview, User stories, Functional requirements (FR-001, FR-002, ...), Non-functional requirements, Acceptance criteria

🔴 **Read `.ow/commands/_shared/srs-layout.md` before writing** — it decides `single` (one file) or
`split` (hub `SRS-<project-slug>.md` + one `SRS-<project-slug>-<module>.md` per functional area,
template `srs-module.md`), and it holds the duplicate-FR-id check to run once the files are written.

### 1.4 Create the Tech spec

`<vault>/70-Reference/REF-TechStack.md` + `<vault>/70-Reference/REF-Architecture.md` following `templates/tech-spec.md`

Section: Tech stack, Architecture diagram (Mermaid), Data model, API contracts (REST/GraphQL), Auth, Deployment

### 1.5 Create the Phase plan

`<vault>/50-Phases/PHASE-1-MVP.md` — break the SRS into features for Phase 1

### 1.6 Update 00-Index/IMPLEMENTATION-STATUS.md

Add the project entry, link to the files created, status: `planning`

## Phase 1 (Import mode) — Take in an existing PRD

```bash
# if the user's path is wrong or missing → ask for a new path
test -f "$PRD_PATH" || echo "file not found"
```

1. Read the PRD the user provided
2. Copy/move → `<vault>/10-PRD/PRD-<slug>.md`
3. If the frontmatter is incomplete → fill it in from the template (ask the user if necessary)
4. **Gap analysis** — compare against `templates/prd.md`:
   - Find the missing sections (Goals, Non-goals, Personas, KPIs, Risks, etc.)
   - Show the user every gap
   - Ask in one batch (render in `$PROJECT_LANG`): "Which sections do you want filled in?"
5. Fill in the sections the user picked, asking for content one section at a time (or generate a suggestion). Prose written into the file is in `$VAULT_LANG`; headings and frontmatter stay English.
6. Continue **as in Phase 1.3 onward** — create SRS → Tech spec → Phase plan
7. Update `IMPLEMENTATION-STATUS.md`

## Phase 2 — Recommend the next step

Show the next-step menu (render in `$PROJECT_LANG`):

> The foundation documents are ready. Next steps:
>
> - Plan the first feature → `/ow-plan <feature>`
> - Create the design system → `/ow-design`
> - Start building right away (skip planning) → `/ow-implement` (not recommended for an MVP)
> - Add more PRD detail → `/ow-doc PRD-<slug>`

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-new answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — documents created (PRD/SRS/Tech) + paths + number of main sections
- **Open / risks** — only if any: the draft needs stakeholder review · the tech stack is not yet confirmed with the team
- **Next** — review → `/ow-clarify` (if there is ambiguity) or `/ow-plan`

🔴 **Never fabricate** user data / stakeholders / requirements the user did not state — asking beats guessing.

## Never

- Never modify any code in this command — `/ow-new` only creates documents
- Never fabricate user data, stakeholders, or requirements the user did not state — ask instead
- Never overwrite an existing PRD without confirmation
