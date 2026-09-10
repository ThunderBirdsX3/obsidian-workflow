---
description: Design system architect — tokens, components, patterns, accessibility, preview.html, Figma export import
---

# /ow-design — Design System

Create + maintain the design system: tokens, components, patterns, accessibility, preview, Figma export import

Mode-gated detail lives in `_shared/` fragments. 🔴 **Read a fragment the moment its phase says so** — it is
authoritative for what it covers and this file never restates it:

| Fragment | Read when |
|---|---|
| `.ow/commands/_shared/design-process.md` | any DS work runs — the gates + the per-action process, Phases 1-5 |
| `.ow/commands/_shared/delegation.md` | the 0.1 judgment lands on the `design` subagent |
| `.ow/commands/_shared/vault-doc-style.md` | any DS doc under `$DS_DIR` is written or edited — Phases 2-5 |

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules design)
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
/ow-design init                          # bootstrap the DS for the first time (tokens + components + preview)
/ow-design tokens [add|edit]             # manage design tokens
/ow-design component <name>              # add/edit a component spec
/ow-design pattern <name>                # add a pattern (composition)
/ow-design audit [path]                  # scan code for DS drift
/ow-design preview                       # regenerate preview.html
/ow-design import-figma <export-path>    # import Figma export → DS-Tokens (contrast-gated)
```

Empty → ask (render in `$PROJECT_LANG`) "which action?" + list the current DS state

## Phase 0 — Resolve DS state

```bash
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)"
DS_DIR="$VAULT_ABS/70-Reference/DesignSystem"
ls "$DS_DIR"/ 2>/dev/null || echo "DS not initialized"
```

| Situation | Action |
|---|---|
| `$DS_DIR` missing + user asked for tokens/component/audit | STOP → direct them to `/ow-design init` first |
| `$DS_DIR` exists but DS files are missing/empty | Flag as corrupt → ask whether to re-init or repair just those files |
| import-figma but the export path does not exist | STOP (Phase 5) |

### 0.1 Decide how to run it (your judgment — 🔴 no mandate either way)

Do the DS work yourself, or delegate it to the `design` agent — **whichever fits this action**.
Same trade-off as `/ow-implement` 3.0, nothing here forces either one:

- a spawn shares no context with you — the agent starts from zero, re-reads the DS docs you are already
  holding, and pays a cold-cache write. On a one-token edit or a single component that is cost with little gained
- what it buys back — a separate context budget (a full `init`, a whole-codebase `audit`, a large Figma
  export are all long, noisy jobs) and the DS rules already written for the job
- either way **the gates are identical**: G2 contrast on every color, G3-G4 DS compliance, WCAG 2.2 AA,
  the a11y section per component, and the no-fake-results rule that a recorded ratio is recomputed, never trusted

🔴 **The process and the gates live in `.ow/commands/_shared/design-process.md`** — read it before
touching a DS file, in EITHER mode. It is the command's own spec, not an agent's: `design` is created per
project by `/ow-agent create design` and may not exist here, and even when it does it executes exactly that
fragment. 🔴 **Running inline** — read that fragment plus every file `bash scripts/ow-paths.sh --rules design`
names, *before* touching a DS file; the action blocks below tell you what to produce either way.
`.claude/agents/design.md` absent ⇒ inline is the only mode, and that is normal, not a failure. 🔴 **Delegating** — prepend the authoritative PROJECT CONTEXT block assembled from
the Phase-0 resolved vars (the agent has no bash tool — assemble it exactly as
`.ow/commands/_shared/delegation.md` §3, with `AREA=design`).

## Phase 1 — `init` mode

Create the DS skeleton:
1. `DS-Tokens.md` — primitive + semantic tokens
2. `DS-Components.md` — component catalog
3. `DS-Patterns.md` — composition patterns
4. `DS-Accessibility.md` — a11y rules
5. `DS-Voice.md` — microcopy guide
6. `preview.html` — visual reference

Do the work per `_shared/design-process.md` — inline, or delegated to the `design` agent (0.1). Component shape: the `component-add` section of that fragment

## Phase 2 — `tokens` / `component` / `pattern` modes

The action (do it inline, or hand it to the `design` agent — 0.1):
```
Action: tokens-add | tokens-edit | component-add | component-edit | pattern-add
Target: <name>
Context: read DS-Tokens.md + DS-Components.md first
```

## Phase 3 — `audit` mode

Always a two-layer audit (`_shared/design-process.md` → Audit, Layer A + Layer B) — inline or delegated (0.1):
```
Action: audit
Scope: self (DS docs — always run) + <source path, or detected from config — never hardcode the stack>
Output: <VAULT_PATH>/70-Reference/DesignSystem/audit-<date>.md
        Must include: Score /100 (the deterministic Layer A formula: 100 − 8×HIGH − 4×MED − 1×LOW, floor 0,
        every deduction carrying a finding that names file:line) + the 6-dimension self-audit
        (token-reference integrity / claim re-verify / preview sync / naming /
         completeness per component / required files) + code drift findings (when source is in scope)
```

The G2-G4 gates (DS compliance) + WCAG 2.2 AA are enforced either way — the gate is on the work, not on who does it — and **an audit is read-only against source** (the frontend/mobile work applies fixes). A contrast claim in the DS docs that does not survive recomputation is a HIGH finding (no fake results applies to design docs too — never trust a recorded ratio without recomputing it)

## Phase 4 — `preview` mode

Regenerate `preview.html` — inline, or delegated to the `design` agent (0.1)

### 4.1 Preview ↔ token drift check
After regenerating → verify the CSS vars in preview.html cover DS-Tokens.md:
```bash
comm -23 <(grep -oE '`[a-z][a-z0-9-]+`' "$DS_DIR/DS-Tokens.md" | tr -d '`' | sort -u) \
         <(grep -oE -- '--[a-z][a-z0-9-]+' "$DS_DIR/preview.html" | sed 's/--//' | sort -u)
```
A non-empty result = DS tokens not yet present in the preview → the preview is stale → flag + regenerate until complete

## Phase 5 — `import-figma` mode

`/ow-design import-figma <export-path>` — import a Figma export as DS tokens (the design agent owns this; there is no separate figma agent)

```bash
[ -e "$EXPORT_PATH" ] || { echo "Figma export not found: $EXPORT_PATH — supply a valid path"; exit 1; }
```

Action `figma-import` (`_shared/design-process.md` → Figma import) — inline, or delegated to the `design` agent (0.1):
```
Action: figma-import
Export: <export-path>   (tokens.json / variables.json / Style Dictionary)
Rules:
  - parse export → diff vs DS-Tokens.md
  - Every color passes the G2 contrast gate before saving (FAIL = not saved + reported)
  - An existing token with a conflicting value = STOP and report the conflict (never overwrite silently)
  - DS gap: a Figma component absent from the DS → flag + propose component-add
  - Save only what passed → bump tokens_version → regenerate preview.html
```

🔴 **The user is always shown the diff (add N / conflict M / orphan K) before saving** — inline or delegated

(If the user has a brand guideline instead of Figma → use `init` or `tokens add` and extract the palette from it)

## Output (short bullets, in `$PROJECT_LANG`)

Close /ow-design with **short, quickly readable bullets** in the configured language (`$PROJECT_LANG` from Phase 0). Only:

- **What was done** — the action (init/tokens/component/audit/import-figma) + what changed
- **DS files** — the files edited + the `preview.html` path
- **Checks** — contrast result (WCAG), figma-import diff (if any)
- **Risks/next** — token version bump, components still missing, conflicts awaiting the user's decision

🔴 Contrast/preview must be genuinely rendered — **never claim** a result that was not checked.

## Never

- Never edit source code in /ow-design — spec only (frontend/mobile work applies what the audit finds)
- 🔴 Never treat the `design` agent as mandatory — it is not even shipped (this project creates it or it does not exist); how the work runs is a judgment call (0.1), and no phase may make either mode mandatory · never drop a `_shared/design-process.md` gate because the work ran inline
- Never add/import a color token without the contrast check (G2 — inline or delegated)
- Never skip the accessibility section in a component
- Never overwrite an existing DS without confirming
- Never import a Figma token whose value conflicts with an existing one without confirming — G10 STOP and report
- Never edit the Figma source / call a Figma API — import from an export file only (read-only on Figma)
