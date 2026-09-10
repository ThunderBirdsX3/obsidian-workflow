# `_shared/vault-doc-style.md` — a vault doc states the present (cross-verb contract)

> **Single source of truth** for the rule below. Every verb that writes a note under `$VAULT_ABS`
> reads this file at its doc-writing phase and never restates the rule in its own words — a second
> copy drifts silently (same contract as `context-refs.md` in this directory).
>
> Read by: `/ow-init` 2 · `/ow-new` 1 · `/ow-clarify` 3 · `/ow-doc` 3 ·
> `/ow-reverse-engineer` 6 · `/ow-implement` 2 · 6.2 · `_shared/design-process.md`
>
> 🔴 The project's own rule file under `.ow/rules/` for the area **that verb loads in its
> Phase 0** — `docs` for `/ow-doc`, `design` for `/ow-design`, `coding` for the rest —
> **overrides** anything in this file. This is the floor that applies when a project has written no
> rule of its own.

## 1. The rule

A vault doc describes the project **as it is now**. Someone opening it cold must be able to read every
sentence as current truth without knowing what an earlier version of the file said.

🔴 **Never write the edit itself into a spec doc:**

- `changed from X to Y` · `previously used X` · `used to be` · `formerly` · `renamed from FN-Search-Old`
- `(replaces the old flow)` · `instead of the previous 3-day window`
- a `## Changelog` / `## Revision History` / `## What changed` section
- an old value kept struck-through, commented out, or parenthesised "for reference"

The same forms in `$VAULT_LANG` are the same violation — the gate in §5 carries the pattern list for
every language it knows, and a doc written in Thai, Japanese or Spanish is held to this rule exactly
as an English one is.

**Write instead:** the value that is true today, alone, in the place the old one occupied. Delete what
is no longer true — git holds the previous version of the file, and the reason it changed is already
written in the plan or fix-log of the run that changed it.

## 2. Where change history lives instead

| The record | Its home |
|---|---|
| why a value changed · what was tried · before/after | the `80-ImplementPlan` plan or `85-FixLog` fix-log of that run |
| what a test run actually observed | `90-TestPlan` |
| what one delivery round shipped | `95-Handoff` |
| the previous wording of the doc itself | git history |

Those four folders (`$PLAN_DIR` `$FIX_DIR` `$TEST_DIR` `$HANDOFF_DIR`) are the **only** exemption:
prose there is the record of one run at one moment, so `X → Y` is its subject matter. Every other
folder under the vault — `00-Index` `10-PRD` `20-Features` `30-Roles` `40-Functions` `50-Phases`
`60-Flows` `70-Reference` — is present-tense only.

The reader still needs the trail? Wikilink the plan/fix-log from the doc (`related:` frontmatter or a
`[[…]]` in place) — the history stays one hop away instead of inline.

## 3. Updating a doc that is now wrong

1. Read the section that no longer matches reality.
2. **Overwrite it** with what is true today — never append a correction underneath the old text.
3. Bump `version:` / `date:` in the frontmatter: that is the change marker the vault keeps.
4. Fix everything the change breaks elsewhere in the same pass — a wikilink, an IMPLEMENTATION-STATUS
   row, a glossary term. A second doc left stating the old truth is the same defect.

## 4. Decision docs (ADR) — name the alternative, do not narrate the past

An ADR must be able to explain why one option won. It does that by **naming the options**, not by
telling the story of what the project used to do:

| ✅ write this | ❌ not this |
|---|---|
| `## Alternatives considered — Option B: 3-day window. Rejected: misses the weekend batch.` | `Previously used a 3-day window; changed to 5.` |
| `## Consequences — the 5-day window costs one extra nightly job.` | `Replaced the old nightly job with two.` |
| frontmatter `status: superseded` + `Superseded by [[ADR-0007-…]]` | `This ADR used to say 3 days.` |

Both columns carry the same information; only the left one still reads as true a year from now, and
only the left one passes the §5 gate. The story of the migration itself belongs in the plan that ran it.

## 5. The gate

```bash
bash "$(git rev-parse --show-toplevel)/scripts/ow-verify-vault-style.sh"
```

Scans **new/modified** vault notes outside the four exempt folders for the forms in §1 and BLOCKs on a
hit; `/ow-secure` Phase 2.6 runs it before a push. It never re-flags pre-existing content (the same
grandfathering as the vault-language gate). A hit is cleared by rewriting the sentence in the present
tense — never by moving it into a code fence to hide it from the scan.
