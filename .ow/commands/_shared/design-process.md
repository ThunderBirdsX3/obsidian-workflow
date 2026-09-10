# `_shared/design-process.md` — the Design System process `/ow-design` executes

Read this when a `/ow-design` mode actually fires (Phase 1-5). It is the process and the gate set
themselves — **not** an agent's copy of them: the work runs inline by default, and the `design` agent
(when this project created one with `/ow-agent create design`) executes exactly what is written here.
Neither mode may drop a gate; the gate is on the work, not on who does it.

Token/path/stack values come from the caller's Phase 0 resolver vars (`$DS_DIR`, `$VAULT_ABS`, …) —
never hardcode a vault or source path here.

## Gates (must-not-skip)

- **G1** A new component **MUST** have: Purpose (when/when-not), Anatomy, Variants (style intent), Sizes, States (default/hover/active/focus-visible/disabled/loading), Props table (name/type/default/required), an **Accessibility** section (role, ARIA attrs, keyboard map, focus management), Tokens used (semantic refs only), Example code (in this project's own UI framework), and a **Don't** section
- **G2 (contrast)** A new color token **MUST** pass the contrast check:
  - text vs background ≥ 4.5:1 (normal) or ≥ 3:1 (large ≥18pt regular or ≥14pt bold)
  - UI component vs adjacent ≥ 3:1
  - focus indicator ≥ 3:1 vs adjacent (WCAG 2.2 SC 1.4.11 + 2.4.13)
  - Compute with relative luminance (WCAG formula) before saving the token
- **G3** Duplicate detection: before adding → check the token name + component name. Conflict ⇒ **STOP**
- **G4** Token granularity: a **primitive** is never referenced directly from a component spec — use **semantics** only (`color-action-primary`, not `color-blue-500`). A component spec referencing a primitive ⇒ **STOP**, refactor first
- **G5** Version bump: a token added/changed ⇒ bump `tokens_version` in the DS-Tokens.md frontmatter; a component added/changed ⇒ bump `components_version` in DS-Components.md
- **G6** Audit mode (when scanning source) ⇒ **never edit the source** — report drift findings in `audit-<date>.md` only
- **G7** Target size: an interactive element carries a recommended hit target ≥ 24×24 CSS px (AA) in its Anatomy section — designing smaller requires a stated rationale + an alternative input method
- **G8** Reduced-motion: any animation/transition in a component spec must note a `@media (prefers-reduced-motion: reduce)` variant
- **G9** Preview.html regenerate: every edit to DS-Components.md / DS-Tokens.md ⇒ regenerate preview.html in the same run
- **G10 (Figma import — read-only on Figma)** import from a Figma **export file** only — never call a Figma write API or invoke a plugin. Extracted color tokens **MUST** pass the G2 contrast check before saving (never import a raw hex value into DS-Tokens.md unverified). If Figma carries a token whose name/value **conflicts** with one already in the DS ⇒ **STOP** and report the conflict for the user to decide — never overwrite silently. Asset binaries (PNG/SVG) ⇒ flag path + size for the caller to decide; never auto-commit

🔴 A DS doc under `$DS_DIR` is a spec doc: **read `.ow/commands/_shared/vault-doc-style.md`**
before writing one. `tokens-edit` / `component-edit` overwrite the token or the component section with
its current value — never "was #1A73E8, now #0B57D0"; that pair belongs in the plan of the run.

## Process — per action

Actions: `init` · `tokens-add` · `tokens-edit` · `component-add` · `component-edit` · `pattern-add` ·
`audit` · `preview-regen` · `figma-import`

### Tokens — `tokens-add` / `tokens-edit`
1. If primitive: assign `color-<hue>-<shade>` / `space-<step>` / `radius-<size>` / `font-<role>` / `weight-<step>` / `leading-<step>` / `shadow-<level>` / `duration-<step>` / `easing-<curve>`
2. If semantic: pattern `<category>-<role>-<modifier>`:
   - `color-text-{default,muted,inverse,danger,success,warning,link,disabled}`
   - `color-surface-{base,raised,sunken,overlay}`
   - `color-action-{primary,secondary,tertiary,destructive}-{default,hover,active,disabled}`
   - `color-border-{default,strong,subtle,focus}`
3. Compute contrast (relative luminance formula). Document ratio in token entry
4. Bump tokens_version

### Figma import — `figma-import`

Read the Figma export → propose tokens into DS-Tokens.md (through the G10 + G2 gates)

```bash
# 1. Locate + detect format (read-only)
find . -path '*figma*' \( -name 'tokens.json' -o -name 'variables.json' \) 2>/dev/null
file <export-file>                                    # confirm type
head -50 <export-file> | jq -r 'paths(scalars)' 2>/dev/null   # peek structure
```
If it cannot be parsed / no export is found → **STOP** + ask the user for the path (never guess)

```bash
# 2. Flatten tokens (W3C DTCG / Tokens Studio)
jq -r 'paths(scalars) as $p | "\($p|join(".")): \(getpath($p))"' <export-file>
```

For each token:
1. Split primitive (`color-blue-500`) from semantic (`color-action-primary`); resolve a `{primitive.blue.500}` reference one level deep (>1 level = flag for manual review)
2. Convert names to the DS kebab convention (`color.action.primary.default` → `color-action-primary-default`)
3. **Diff against the current DS-Tokens.md:**
   - New token (absent from the DS) → candidate add
   - Same token name, different value → **G10 conflict → STOP** and report (never overwrite)
   - Token in the DS but absent from Figma → flag as orphan (never delete)
4. **Every color token → G2 contrast check** before saving; FAIL → do not save that one + report it
5. **DS gap:** a Figma component absent from DS-Components.md → flag + propose `component-add <name>`
6. Show the diff summary (add N / conflict M / orphan K) → save only what passed → bump `tokens_version` → regenerate preview.html (G9)

Always show the user the diff summary before saving (the same way the Phase 5 audit shows findings first)

### Component — `component-add` / `component-edit` (and the shape `init` creates)
Use the `design-component.md` template from `$TEMPLATE_CHAIN`. Structure:
```markdown
## Button

**Purpose**
When to use: primary/secondary calls-to-action, form submission
When NOT: navigation between pages (use Link), file download with progress (use FileDrop)

**Anatomy**
- Container (min 44×44 px hit target on mobile; 24×24 minimum desktop)
- Label (semantic typography token)
- Optional leading icon
- Optional trailing icon
- Loading spinner (replaces icon when loading=true)

**Variants** (style intent)
- primary — color-action-primary
- secondary — color-action-secondary
- tertiary — text-only, no background
- destructive — color-action-destructive

**Sizes**
- sm — height 32, padding-x space-3, font-sm
- md — height 40, padding-x space-4, font-base
- lg — height 48, padding-x space-5, font-md

**States**
- default · hover · active · focus-visible · disabled · loading

**Props**
| name | type | default | required | description |
|---|---|---|---|---|
| variant | `'primary'\|'secondary'\|'tertiary'\|'destructive'` | `'primary'` | no | style intent |
| size | `'sm'\|'md'\|'lg'` | `'md'` | no | |
| disabled | `boolean` | `false` | no | |
| loading | `boolean` | `false` | no | shows spinner, blocks interaction |
| onPress | `() => void` | — | yes | |
| children | `ReactNode` | — | yes | label |
| leadingIcon | `ReactNode` | — | no | |
| trailingIcon | `ReactNode` | — | no | |

**Accessibility**
- role: `button` (implicit via `<button>`)
- ARIA: `aria-disabled="true"` when disabled (in addition to `disabled` attr)
- ARIA: `aria-busy="true"` when loading
- Keyboard: Enter + Space activate
- Focus: visible outline using `color-border-focus`, 2px offset, 3:1 contrast vs adjacent
- Target size: 44×44 px minimum on touch surfaces (overrides general 24×24)
- Reduced motion: spinner respects `prefers-reduced-motion: reduce` (fade instead of spin)

**Tokens used** (semantic only)
- background: color-action-{variant}-{state}
- text: color-text-{inverse|default}
- border: color-border-{default|focus}
- radius: radius-md
- spacing: space-{3,4,5} per size

**Example (React + Tailwind)**
```tsx
<Button variant="primary" size="md" onPress={handleSubmit}>
  Save
</Button>
```

**Don't**
- ✗ Using Button for navigation — use Link
- ✗ Setting text-color directly — the `color-text-inverse` token already handles it
- ✗ Disabling without setting `aria-disabled`
```

### Audit — `audit`

The audit has two layers — **5A DS self-audit (docs-level, always run)** + **5B code drift scan (when the scope includes source)** — both write into the same audit file

#### Layer A — DS self-audit (always first)

Check the integrity of the DS docs themselves across 6 dimensions:

1. **Token-reference integrity** — every token DS-Components.md / DS-Patterns.md references must be defined in DS-Tokens.md:
```bash
comm -13 <(grep -oE -- '--[a-z][a-z0-9-]+' "$DS_DIR/DS-Tokens.md" | sort -u) \
         <(grep -ohE -- '--[a-z][a-z0-9-]+' "$DS_DIR"/DS-Components.md "$DS_DIR"/DS-Patterns.md 2>/dev/null | sort -u)
```
   A templated token (`--color-<intent>-100`) → expand over the intent enum before diffing. Referenced but undefined = **HIGH**
2. **Claim re-verification** (no fake results applies to docs too) — every contrast ratio claimed in DS-Accessibility.md / DS-Tokens.md must be **recomputed** with the G2 formula — a ratio off by more than 0.1, or a flipped PASS/FAIL verdict, = **HIGH** (report the real value + propose a token that passes instead)
3. **DS ↔ preview sync (name + value)** — a token in DS-Tokens.md must appear in preview.html `:root` and its **value** (hex/px/ms) must match — normalize first if the preview uses a prefix alias (e.g. `color-` ↔ `c-`). Conflicting values = **HIGH** · name missing from the preview = **MED** · a preview var absent from the DS = **LOW** (orphan)
4. **Naming consistency** — one prefix convention system-wide (DS docs + preview) + one prop enum convention across every component (e.g. never mix `variant` and `intent`). A conflict = **MED**
5. **Completeness scoring** — per component, count the sections G1 mandates (10 sections = a score out of 10): Purpose, Anatomy, Variants, Sizes, States, Props, Accessibility, Tokens, Example, Don't → one table row per component. Missing **Accessibility = HIGH**; any other missing section = **MED** per component (counted once no matter how many are missing)
6. **Required files** — DS-Tokens / DS-Components / DS-Patterns / DS-Accessibility / DS-Voice / preview.html all present; each missing one = **MED**

**Score /100 (deterministic):** `100 − 8×HIGH − 4×MED − 1×LOW` (floor 0) — every deduction must have a finding naming file:line in the audit file; never deduct without one

#### Layer B — Code drift scan (when the scope includes source)
```bash
# Hardcoded color
rg -n --pcre2 '#[0-9a-fA-F]{3,8}\b|rgb\([^)]+\)|rgba\([^)]+\)|hsl\([^)]+\)|hsla\([^)]+\)' \
  src/ web/ mobile/ 2>/dev/null \
  | grep -v 'design-system\|tokens\.ts\|theme\.ts'

# Off-scale spacing (catch px values not in scale)
rg -n --pcre2 '\b(margin|padding|gap|top|bottom|left|right)(-[a-z]+)?:\s*([0-9]+)px' src/ \
  | awk -F'[: px]' '{n=$NF; if (n!=0 && n!=4 && n!=8 && n!=12 && n!=16 && n!=20 && n!=24 && n!=32 && n!=40 && n!=48 && n!=64 && n!=80 && n!=96) print}'

# Font family non-DS
rg -n 'font-family:\s*["\047][^"\047]+["\047]' src/ | grep -v 'var(--font'

# Inline shadow
rg -n 'box-shadow:\s*(?!var)' src/

# ad-hoc focus
rg -n 'outline:\s*(none|0)' src/  # outline:none without focus-visible replacement = violation
```

Compute drift score per file:
```
drift_score = (hardcoded_color + off_scale_spacing + non_token_font + inline_shadow) / total_style_lines
```

Output: `<vault>/70-Reference/DesignSystem/audit-<YYYY-MM-DD>.md` — must carry the **Score /100 + the 6-dimension self-audit table + the per-component completeness table** (Layer A) plus a per-file table + severity + suggested token replacement (Layer B, when source is in scope)

### Preview — `preview-regen`
Single-file HTML with embedded CSS variables + dark/light toggle. Render:
- color palette swatches (primitive + semantic, with contrast pairs)
- typography scale samples
- spacing scale visual rulers
- component grid: each component × all variants × all sizes × all states
- accessibility panel: keyboard nav order, focus ring visualization
