# `_shared/srs-layout.md` — SRS layout: single file or hub + modules

> **Single source of truth** for how an SRS is laid out on disk. `/ow-new`, `/ow-doc` and
> `/ow-reverse-engineer` write by it; `/ow-plan`, `/ow-clarify` and `/ow-verify` read by it — never
> restate these rules in a verb spec.

## Why

`/ow-plan` Phase 1 reads the vault inside a 40,000-token budget, and `Read` loads a whole file.
A project-wide SRS grows with every functional area, so one long file ends up eating the budget
on a task that touches a single area. Splitting by module lets a run read only the part it needs.

## Two layouts

| Layout | Files | Use when |
|---|---|---|
| `single` | `$PRD_DIR/SRS-<project>.md` — everything | the split trigger below does not fire |
| `split` | hub `$PRD_DIR/SRS-<project>.md` + one module `$PRD_DIR/SRS-<project>-<module>.md` per functional area | the split trigger fires |

The frontmatter key `srs_layout:` (`single` | `split`) on `SRS-<project>.md` records which one
is in use; a file with no key is `single`.

### Split trigger

Split when **both** hold:

1. the FRs cover **≥ 2 functional areas** (a module = an area a task can change on its own:
   catalog, checkout, reporting, auth…)
2. the SRS is estimated at **> 10,000 tokens** — a quarter of the `/ow-plan` read budget:

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PRD_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
f="$PRD_DIR/SRS-<project>.md"
echo "SRS est: $(( $(wc -c <"$f") / 2 )) tokens"   # same ~2 bytes/token heuristic as /ow-plan 1.4
```

At creation (`/ow-new`) with no file yet, estimate from the planned content: ≥ 2 areas **and**
more than ~10 FRs ⇒ start `split`. Splitting a `single` SRS later is a `/ow-doc --edit` on it —
ask the user first (it moves content across files).

## What goes where (`split`)

| Hub `SRS-<project>.md` (`srs.md` template) | Module `SRS-<project>-<module>.md` (`srs-module.md` template) |
|---|---|
| System overview · scope · NFR-### · data model (high-level) · external integrations · system-level dependencies · out of scope · acceptance for release | the module's scope · its FR-### (full blocks with Given/When/Then) · the NFR/entities/integrations it relies on, as **links back to the hub** · its UX flows · its clarifications |
| `## 3. Modules` — one row per module: link + FR range + one-line purpose | no copy of hub content — link to it |
| `## Clarifications` — questions about hub content (NFR, data model, integrations, scope) | `## Clarifications` — questions about this module's FRs and flows |
| **no** `### FR-###` heading | **no** `### NFR-###` heading |

A section that concerns one module only lives in that module; a section shared by ≥ 2 modules
lives in the hub.

## FR IDs stay unique across the project

`/ow-plan` binds plan steps to `FR-###` IDs, so an ID must name one requirement project-wide:

- the hub assigns each module a **range** (e.g. `FR-100..FR-199` checkout, `FR-200..FR-299`
  catalog); every FR in a module falls inside its range
- a module that fills its range takes a further free range, listed in the hub's `## 3. Modules` row
- never reuse a retired ID for a different requirement

Check after any write to an SRS file (prints nothing when clean):

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PRD_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
cat "$PRD_DIR"/SRS-<project>.md "$PRD_DIR"/SRS-<project>-*.md 2>/dev/null \
  | grep -oE '^#{2,4} FR-[0-9]+' | grep -oE 'FR-[0-9]+' | sort | uniq -d \
  | sed 's/^/duplicate FR id: /'
```

A duplicate is a blocking finding for the writer (`/ow-new`, `/ow-doc`, `/ow-reverse-engineer`): renumber before finishing.

## Reading a `split` SRS (`/ow-plan`, `/ow-clarify`, `/ow-verify`)

- Read the hub — it is short by construction and carries the NFRs every module is held to
- Read **only the module(s) the task touches** — pick them from the hub's `## 3. Modules` table
  (FR range + purpose); **uncertain ⇒ include** the module
- FR coverage (`/ow-plan` 1.2) runs over the modules in the read set, not every module — an FR in
  an unread module is out of this task's scope, not an orphan
- A doc that links the SRS (`FEAT` `srs:`, plan `related:`) links the **module** it implements;
  a link to the hub alone ⇒ resolve the module from the hub's `## 3. Modules` table

## Clarifying a `split` SRS (`/ow-clarify`)

- Target = module ⇒ scan the module + the hub sections it links; target = hub ⇒ scan the hub only
  (never every module — ask which module when the question is about FRs)
- Each answer goes into the `## Clarifications` of the file that holds the ambiguous text (table
  above) — an NFR answer found while scanning a module is written to the hub
- A suggested new FR names its module and an ID inside that module's FR range

## Auditing a `split` SRS (`/ow-verify` Phase 4 spec audit)

- run the duplicate-FR-id check above — a duplicate is a finding
- every `### FR-###` in a module falls inside its `fr_range:` (or a further range listed in the hub row)
- the hub has no `### FR-###` heading; every module file is linked from the hub's `## 3. Modules`
  and `modules:` frontmatter, and every module's `srs_hub:` resolves
