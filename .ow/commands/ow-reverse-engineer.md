---
description: Read existing code and build vault docs in reverse — TechStack, API, Features, Functions, SRS (draft)
---

# /ow-reverse-engineer — Code → Vault Docs

Read the real code, then create Obsidian vault docs as drafts for a brownfield project that has no spec

> **Read-only on code** — never touches source files; creates docs in the vault only

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
/ow-reverse-engineer                        # scan the whole project
/ow-reverse-engineer --area api             # API/routes only
/ow-reverse-engineer --area ui              # UI components/screens only
/ow-reverse-engineer --area models          # domain models/schemas only
/ow-reverse-engineer --area all             # every dimension (default)
/ow-reverse-engineer --depth shallow        # structure only (fast)
/ow-reverse-engineer --depth deep           # read the real file contents (detailed)
```

Empty → ask (render in `$PROJECT_LANG`) for area + depth, then start the scan

## Phase 0 — Project structure detection

```bash
# Manifests
ls package.json requirements.txt pyproject.toml go.mod Cargo.toml \
   pubspec.yaml pom.xml build.gradle composer.json Gemfile *.csproj 2>/dev/null

# Source roots
find . -maxdepth 3 -type d \( \
  -name src -o -name lib -o -name app -o -name api \
  -o -name server -o -name client -o -name backend -o -name frontend \
  -o -name mobile -o -name packages -o -name services \
\) 2>/dev/null | grep -v node_modules | grep -v .git

# Entry points
ls main.* index.* app.* server.* 2>/dev/null | grep -v node_modules
```

Show the structure found + ask (render in `$PROJECT_LANG`) which part to scan first (if `--area` was not given)

## Phase 1 — Tech stack scan

Read the manifest files, then draft `REF-TechStack.md`:

```bash
# Node/JS
[ -f package.json ] && cat package.json | grep -A 50 '"dependencies"'

# Python
[ -f requirements.txt ] && cat requirements.txt
[ -f pyproject.toml ] && grep -A 30 '\[tool.poetry.dependencies\]' pyproject.toml

# Go
[ -f go.mod ] && cat go.mod

# Dart/Flutter
[ -f pubspec.yaml ] && grep -A 20 'dependencies:' pubspec.yaml

# Java/Kotlin
[ -f build.gradle ] && grep -E 'implementation|api' build.gradle | head -20
```

**Output draft:**
```
<vault>/70-Reference/REF-TechStack.md
```

State only what is actually visible in the files — never guess a version or a dependency that was not found

## Phase 2 — API / Routes scan

```bash
# Express / Fastify / Hapi (JS)
find . -type f \( -name "routes.*" -o -name "*.routes.*" -o -name "router.*" \) \
  2>/dev/null | grep -v node_modules | head -20

# NestJS controllers
find . -type f -name "*.controller.*" 2>/dev/null | grep -v node_modules | head -20

# FastAPI / Flask (Python)
grep -r "@app\.\(get\|post\|put\|delete\|patch\)" --include="*.py" -l 2>/dev/null | head -10
grep -r "@router\." --include="*.py" -l 2>/dev/null | head -10

# Go (gin/echo/chi)
grep -r "\.\(GET\|POST\|PUT\|DELETE\|PATCH\)(" --include="*.go" -l 2>/dev/null | head -10

# Laravel (PHP)
[ -f routes/api.php ] && cat routes/api.php | head -50
[ -f routes/web.php ] && cat routes/web.php | head -50

# Rails
[ -f config/routes.rb ] && cat config/routes.rb | head -50
```

If `--depth deep` → read the real route files and extract:
- method + path (`GET /api/users/:id`)
- the parameters seen
- response shape (if visible)

**Output draft:**
```
<vault>/70-Reference/REF-APIIntegration.md
```

## Phase 3 — Domain model scan

```bash
# TypeScript interfaces / types
find . -type f \( -name "*.types.*" -o -name "*.interface.*" -o -name "*.model.*" -o -name "*.entity.*" -o -name "*.schema.*" \) \
  2>/dev/null | grep -v node_modules | head -20

# Prisma schema
find . -name "schema.prisma" 2>/dev/null

# SQLAlchemy / Django models (Python)
grep -r "class.*Model\|class.*Base" --include="*.py" -l 2>/dev/null | head -10

# Go structs (domain layer)
find . -path "*/domain/*.go" -o -path "*/model/*.go" -o -path "*/entity/*.go" 2>/dev/null | head -10

# Dart/Flutter models
find . -name "*.dart" -path "*/models/*" 2>/dev/null | head -10
```

If `--depth deep` → read the fields from the real model/schema

**Output draft (1 file per domain entity found):**
```
<vault>/40-Functions/FN-<EntityName>.md   ← status: draft
```

Include only the fields actually seen — never guess business logic

## Phase 4 — Feature area detection

Group the files found in Phase 2-3 into feature clusters, based on:
- folder structure (`/checkout/`, `/auth/`, `/users/`, `/products/`)
- naming patterns (`checkout*.`, `auth*.`, `user*.`)
- route prefix (`/api/checkout/`, `/api/auth/`)

Each cluster → one draft `FEAT-*.md`

**Output draft:**
```
<vault>/20-Features/FEAT-<Area>.md   ← status: draft
```

Data to include:
- Feature name + slug (from the folder/prefix found)
- The files in this cluster
- API endpoints mapped in (from Phase 2)
- Related domain models (from Phase 3)
- The parts that are **unknown** (left blank for a human to fill in): business rules, acceptance criteria, non-goals

## Phase 4.5 — SRS draft (from the clusters)

Runs when Phase 2 found endpoints (`--area api` or `all`); otherwise skip and say so in Phase 5.

🔴 **Read `.ow/commands/_shared/srs-layout.md` first** — it owns the layout decision, the file
names, the FR ranges and the duplicate-FR-id check. This phase only maps what the scan found onto it.

1. **Draft one FR per endpoint found**, grouped by the Phase 4 cluster that owns it:
   - title from method + path (`FR-### — GET /api/orders/:id`), inputs/outputs from what Phase 2 saw
   - **Acceptance** = `<!-- TODO: fill in -->` — never infer Given/When/Then from code; `/ow-plan`
     flags the FR as underspecified, `/ow-clarify` gets the answers, `/ow-doc --edit` writes them into the FR
   - pre/post-conditions only when a guard/validation is visible in the code, citing the file
2. **Layout** — existing SRS decides first:

| `$PRD_DIR` has | Action |
|---|---|
| no `SRS-<project>.md` | apply the split trigger: ≥ 2 clusters **and** more than ~10 draft FRs ⇒ `split` (hub + `SRS-<project>-<cluster-slug>.md` per cluster); otherwise `single` |
| `SRS-<project>.md` with `srs_layout: split` | a cluster with no module file ⇒ new module in the next free FR range + a row in the hub's `## 3. Modules`; a cluster that already has one ⇒ propose only the endpoints its FRs do not cover yet |
| `SRS-<project>.md`, `single` (or no key) | propose the new FRs for that file; if the split trigger now fires, offer the split as a separate choice at Phase 5 — never split on your own |

3. **Hub content from the scan** — § 5 Data Model lists the Phase 3 entities (link the `FN-*`);
   § 6 External Integrations lists only clients/SDKs seen in the manifest or code; § 4 NFRs =
   `<!-- TODO: fill in -->` (a threshold is never visible in code)
4. Module frontmatter `related_features:` links the cluster's `FEAT-*`

## Phase 5 — Review checkpoint (mandatory)

Show the whole mapping before writing anything (render in `$PROJECT_LANG`):

```
📋 Reverse Engineer Summary — <project>

Tech Stack:
  → REF-TechStack.md (Node.js 20, Express 4, PostgreSQL, Prisma)

API Endpoints found: 23
  → REF-APIIntegration.md

Domain Models found: 6 (User, Order, Product, Cart, Payment, Review)
  → FN-User.md, FN-Order.md, FN-Product.md ... (6 files)

Feature clusters detected: 4
  → FEAT-Auth.md       (src/auth/, /api/auth/*, User model)
  → FEAT-Checkout.md   (src/checkout/, /api/orders/*, Order+Cart+Payment)
  → FEAT-Catalog.md    (src/catalog/, /api/products/*, Product model)
  → FEAT-Reviews.md    (src/reviews/, /api/reviews/*, Review model)

SRS: split — 4 clusters, 23 draft FRs (acceptance left TODO)
  → SRS-<project>.md            (hub: data model 6 entities, NFR TODO)
  → SRS-<project>-auth.md       FR-100..FR-104
  → SRS-<project>-checkout.md   FR-200..FR-208
  → SRS-<project>-catalog.md    FR-300..FR-306
  → SRS-<project>-reviews.md    FR-400..FR-402

⚠️  Uncertain (needs input from the user):
  - src/utils/ → unclear which feature it belongs to
  - /api/admin/* → endpoints found but no matching source folder

Create all drafts? [y/n] or name the clusters you want (e.g. "Auth, Checkout"):
```

Wait for the user to confirm before writing any real file

## Phase 6 — Write vault docs

Write only what the user confirmed. Prose written into the files is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** — a doc outside
`$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now; a
"was X, now Y" / "changed from … to …" sentence belongs in the plan or fix-log of the run that
made the change, never in the doc.

- Every file's frontmatter must carry `status: draft` and `source: reverse-engineered`
- Content that is not known yet gets `<!-- TODO: fill in -->`
- Do not overwrite an existing file — ask first
- SRS files: after writing, run the duplicate-FR-id check from `_shared/srs-layout.md`; a duplicate ⇒ renumber before Phase 7

```yaml
---
tags: [type/feature]
status: draft
source: reverse-engineered
date: YYYY-MM-DD
reverse_engineered_from:
  - src/checkout/checkout.controller.ts
  - src/checkout/checkout.service.ts
---
```

## Phase 7 — Summary and next steps

```
✅ Reverse Engineer done

Created:
  1 × REF-TechStack.md
  1 × REF-APIIntegration.md
  6 × FN-*.md (domain models)
  4 × FEAT-*.md (feature clusters)
  1 × SRS hub + 4 × SRS modules (23 FRs, acceptance TODO)

⚠️  All drafts — must be reviewed and filled in before use in plan/implement

Next steps (recommended order):
  1. Review FEAT-*.md — delete the wrong clusters, add business rules
  2. /ow-clarify <SRS module or FEAT-*.md> — resolve ambiguity in the drafts (answers land in ## Clarifications)
  3. /ow-doc --edit <SRS module> — write the FR acceptance from those answers
  4. /ow-new --import-prd — if an existing PRD/spec exists → merge it into the vault
  5. /ow-plan <task> — start planning the first feature
```

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-reverse-engineer answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was extracted** — the spec extracted from code/db (PRD/SRS/FN created)
- **Files** — list the docs created + the source files used to generate each one
- **Risks / next** — the docs are drafts, business logic must be filled in by hand → `/ow-clarify` before implement

🔴 **Never fabricate** requirements that are not really in the code/db — inference is allowed, but mark it `<TBD>`/draft.

## Never

- Never modify any source code — read-only throughout
- Never overwrite an existing vault doc without asking
- Never guess business rules, acceptance criteria, or behavior not visible in the code
- Never write a file without passing the Phase 5 review checkpoint
- Never mark any status other than `draft` — the user must promote it themselves
