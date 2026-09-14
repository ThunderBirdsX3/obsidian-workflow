---
description: Write or update vault doc (PRD/SRS/Tech/ADR/Feature/Function/Role) using template
---

<!--
Obsidian behaviour this command must honour:
- Read Obsidian context manifest BEFORE writing — preserve frontmatter/links/tags conventions
- Update the note per the manifest's "Structure Map"
- Preserve link graph — never break wikilinks; if rename → leave alias
-->


# /ow-doc — write/edit a vault document

Works with every document type in the vault using its designated template.

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules docs)
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
/ow-doc                              # interactive — asks for the type
/ow-doc <type> <name>                # e.g. /ow-doc PRD CheckoutFlow
/ow-doc --edit <path>                # edit an existing file
/ow-doc --review <path>              # review only, no edits
```

## Phase 0 — Choose the type

| Type | Folder | Template |
|---|---|---|
| `PRD` | `10-PRD/PRD-<slug>.md` | `prd.md` |
| `SRS` | `10-PRD/SRS-<slug>.md` | `srs.md` |
| `SRS-module` | `10-PRD/SRS-<slug>-<module>.md` | `srs-module.md` |
| `Tech` | `70-Reference/REF-Architecture.md` | `tech-spec.md` |
| `ADR` | `70-Reference/ADR/ADR-NNNN-<slug>.md` | `adr.md` |
| `Feature` | `20-Features/FEAT-<slug>.md` | `feature.md` |
| `Function` | `40-Functions/<area>/FN-<slug>.md` | `function.md` |
| `Role` | `30-Roles/<platform>/<role>.md` | `role.md` |
| `Flow` | `60-Flows/FLOW-<slug>.md` | `flow.md` |
| `Phase` | `50-Phases/PHASE-<n>-<slug>.md` | `phase.md` |
| `TestPlan` | `90-TestPlan/TP-<slug>.md` | `test-plan.md` |
| `Reference` | `70-Reference/REF-<slug>.md` | `tech-spec.md` (there is no separate `reference.md` in the shipped set) |

Template lookup: `templates/<name>.md` first, fallback `.ow/templates/<name>.md`

## Phase 1 — Determine action

| Condition | Action |
|---|---|
| File does not exist yet | **Create** mode |
| File exists, `--edit` | **Edit** mode — add/change sections |
| File exists, `--review` | **Review** mode — check for gaps, change nothing |
| File exists, no flag | Ask (render in `$PROJECT_LANG`) whether to edit or review |

## Phase 2 — Read context

Read:
1. The template to use (`templates/<name>.md` or `.ow/templates/<name>.md`)
2. Related docs it links to — e.g. creating a Feature → read the PRD first
3. `00-Index/IMPLEMENTATION-STATUS.md`
4. Docs in the same folder with a similar pattern (to keep consistency)

## Phase 3 — Create / Edit

Prose written into the file is in `$VAULT_LANG` (Phase 0); headings, frontmatter, and IDs stay English.

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** — a doc outside
`$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now; a
"was X, now Y" / "changed from … to …" sentence belongs in the plan or fix-log of the run that
made the change, never in the doc.

🔴 **SRS / SRS-module** → read `.ow/commands/_shared/srs-layout.md` first: it decides which file an
FR goes in, when a `single` SRS should split (ask the user before moving content), and the
duplicate-FR-id check to run after the write.

### Create mode:
1. Copy template → target path
2. Fill frontmatter (`status: draft`, `date`, `version`, `authors`)
3. Fill the body from context + ask the questions the template names (its `<TODO: ...>` placeholders)
4. Ask in a batch — 3-5 questions in a single message, rendered in `$PROJECT_LANG`

### Edit mode:
1. Show the current outline → ask (in `$PROJECT_LANG`) which section to change
2. Show the diff before saving
3. Preserve unrelated frontmatter (e.g. bump `version` only on a substantive change)
4. Update `last_modified`, `modified_by`

### Review mode:
1. Compare the actual sections against the template
2. List missing sections + sections that are too shallow
3. Check link integrity (links pointing at docs that do not exist)
4. Check frontmatter completeness
5. **Change no file** — output a report only

## Phase 4 — Update MOC + link graph

After create/edit:
1. Update the relevant MOC (`00-Index/MOC-PRD.md`, `MOC-Features.md`, etc.) with the new link
2. Update `00-Index/IMPLEMENTATION-STATUS.md` when the status changes
3. Update outgoing/incoming wiki links — verify every `[[link]]` points at a real file
4. For a Function → update the related Feature and Role
5. For a PRD/SRS update → flag dependent Features that may need review
6. For an SRS-module create/rename → update the hub's `modules:` frontmatter + its `## 3. Modules` row (link + FR range)

## Phase 5 — Design system bind (when the doc is a Function/Feature with UI)

If `<vault>/70-Reference/DesignSystem/` exists:
- The doc's "UI Components Used" section → name components from `DS-Components.md`
- The "Design Tokens Used" section → name tokens from `DS-Tokens.md`
- Validate that every referenced component actually exists in the design system

## Output (short bullets, in `$PROJECT_LANG`)

Close /ow-doc with **short, quickly readable bullets** in the configured language (`$PROJECT_LANG` from Phase 0). Only:

- **What was done** — the doc created/edited (type + slug) + the sections filled
- **File** — path + how many sections were filled
- **Checks** — link integrity + frontmatter completeness
- **Risks/next** — `draft` needs review, dependent docs that were flagged

## Never

- Never fabricate a stakeholder name, business rule, or requirement the user did not state
- Never overwrite a section the user wrote themselves without confirming
- Never bump the frontmatter version without confirming (preserves version control)
