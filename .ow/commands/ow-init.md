---
description: Bootstrap obsidian-workflow — Obsidian vault + subagents (greenfield or brownfield) + Obsidian context manifest
---

# /ow-init — Bootstrap obsidian-workflow

Set up the project — supports both **greenfield** (empty folder) and **brownfield** (code already present)

> **Note**: by the time /ow-init runs, `scripts/install.sh` has usually done the scaffolding already.
> `/ow-init` is for **interactive config** and **brownfield gap analysis**

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
/ow-init
/ow-init <project-name>
/ow-init --greenfield        # force the mode
/ow-init --brownfield        # force the mode
/ow-init --reconfigure       # change the config of an already-initialised project
```

## Phase 0 — Check state + detect mode

```bash
# Runs from the project root
test -f .ow.yml && echo "EXISTS" || echo "FRESH"
test -d docs && ls docs | head -5
test -d .claude/commands && ls .claude/commands | grep -c '^ow-' || echo 0

# Detect brownfield indicators (code already in repo)
ls package.json requirements.txt pyproject.toml go.mod Cargo.toml \
   pubspec.yaml pom.xml build.gradle composer.json *.csproj *.sln \
   2>/dev/null | head -3

# Detect submodules
test -f .gitmodules && cat .gitmodules
```

| Condition | Decision |
|---|---|
| **No indicator at all** (empty folder) | **Greenfield, automatically** — no question asked |
| **At least one indicator** | **Ask the user** (render in `$PROJECT_LANG`) between 3 options: greenfield / brownfield / adopt-vault |
| `.ow.yml` already exists | **Reconfigure** — ask which parts to reset |

> **`--here` ≠ brownfield** — the folder the user runs in may be a project that was set up but never actually written yet (e.g. `git init` plus some scaffolding) — so **ask rather than assume**

### Indicators checked (at least one present → ask the user)

**Manifests:**
- `package.json`, `requirements.txt`, `pyproject.toml`, `Pipfile`
- `pom.xml`, `build.gradle`, `build.gradle.kts`
- `go.mod`, `Cargo.toml`, `composer.json`, `Gemfile`
- `pubspec.yaml`, `mix.exs`, `*.csproj`, `*.sln`

**Source folders:** `src/`, `lib/`, `app/`, `frontend/`, `backend/`, `mobile/`, `server/`, `client/`, `api/`, `packages/`, `apps/`, `services/`

**VCS state:** a `.git` directory + ≥ 1 commit (an empty init does not count — it can still be greenfield)

**Multi-repo:** `.gitmodules`

**Existing docs:** a `docs/` containing markdown (it may already be an Obsidian vault)

### The 3 options put to the user (rendered in `$PROJECT_LANG`)

```
🔍 Indicators detected in this folder:
   • package.json
   • src/
   • .git (47 commits)
   • docs/ (existing content)

Which mode matches your situation?

  1) greenfield   — the project is set up but has no real content yet (safe to start fresh)
  2) brownfield   — real code/docs are in use (adopt + never touch what exists)
  3) adopt-vault  — an Obsidian vault already lives in docs/ (reuse it + add the obsidian-workflow commands)

Choose (1/2/3) [default: 2 brownfield]:
```

What each mode means:

- **greenfield** — may remove unneeded existing scaffolding, copies the sample vault, creates the vault skeleton
- **brownfield** — **never touches** what exists; adds only `.ow/` (machinery + commands/), `.claude/`, and a vault skeleton (new, or in a sub-folder)
- **adopt-vault** — brownfield + uses the vault path the user names (the existing `docs/`); creates no new vault

## Phase 1 — Ask for the minimum (all questions in a single message, rendered in `$PROJECT_LANG`)

### 1.1 Common (both greenfield and brownfield):

1. **Project name** + slug (unless already given in `$ARGUMENTS`)
2. **Mode**: `standalone` (the vault lives in this repo) or `submodule` (obsidian-workflow is a submodule of a larger repo)
3. **Stack/scope** (multi-select):
   - [ ] Backend / API
   - [ ] Web frontend
   - [ ] Mobile app
   - [ ] Design system (tokens/components — supports Figma export import)
   - [ ] Multi-repo (has submodules)
4. **Design system** → bootstrap a minimal one? (it can also be created later with `/ow-design`)
5. **Language** for chat/reports (`project.language`): `th` (default) / `en`.
   Then **vault document language** (`project.vault_language`): leave it unset to follow `language`, or
   set `en` — vault docs are re-read far more often than written, and English costs ~2.7× fewer
   tokens per character than Thai.

### 1.2 Vault location (always asked — independent of green/brownfield):

6. **Where does the Obsidian vault live?** (4 options)

   | Option | Stored at | Use when |
   |---|---|---|
   | **A) Create new in `docs/`** | `<project>/docs/` (default, in-repo) | greenfield or a new project |
   | **B) Create new in `docs/ow-vault/`** | `<project>/docs/ow-vault/` | brownfield where `docs/` is already in use |
   | **C) Use an existing vault in this repo** | `<project>/<path>` the user names | brownfield with a vault already present |
   | **D) Use an external vault (path outside the repo)** | an absolute path, e.g. `/Volumes/.../MyVault` | shared org vault, iCloud sync, multi-project vault |

   Record the choice in `.ow.yml` under `vault_path:` (git-tracked — the whole team shares one path):
   A/B/C → the in-repo relative path · D → the absolute path

### 1.3 Brownfield-specific (added when a code indicator is present):

7. **A README or docs already exist** — import them into a PRD?
   - `yes` → analyse the README + propose a PRD draft in Phase 3
   - `no` → skip; use /ow-new later
8. **Submodules** — list what exists (auto-detected from `.gitmodules`, confirmed by the user, plus each submodule's branch)

## Phase 2 — Create the vault skeleton

At the `vault_path` the user chose:

```
<vault_path>/
├── .obsidian/                  basic config
├── 00-Index/
│   ├── IMPLEMENTATION-STATUS.md   single source of truth
│   ├── MOC-PRD.md
│   ├── MOC-Features.md
│   ├── MOC-Functions.md
│   └── README.md
├── 10-PRD/
├── 20-Features/
├── 30-Roles/
├── 40-Functions/
├── 50-Phases/
├── 60-Flows/
├── 70-Reference/
│   ├── REF-TechStack.md
│   ├── REF-AuthorizationMatrix.md
│   ├── REF-APIIntegration.md
│   └── DesignSystem/ (when 1.1 answered yes)
├── 80-ImplementPlan/
├── 85-FixLog/
├── 90-TestPlan/
└── 95-Handoff/
```

Put a `_README.md` in each folder describing its purpose + naming convention. Its prose is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

🔴 **Read `.ow/commands/_shared/vault-doc-style.md` and follow it** — a doc outside
`$PLAN_DIR` / `$FIX_DIR` / `$TEST_DIR` / `$HANDOFF_DIR` states the project as it is now; a
"was X, now Y" / "changed from … to …" sentence belongs in the plan or fix-log of the run that
made the change, never in the doc.

## Phase 3 — Brownfield adoption (skipped for greenfield)

Brownfield mode only:

### 3.1 Stack scan (read-only — never edits code)

```bash
# Auto-detect frameworks
[ -f package.json ] && cat package.json | head -30
[ -f requirements.txt ] && cat requirements.txt | head -20
[ -f pyproject.toml ] && grep -A 20 'dependencies' pyproject.toml
[ -f go.mod ] && cat go.mod | head -10
[ -f pubspec.yaml ] && head -30 pubspec.yaml
[ -f *.csproj ] && head -20 *.csproj 2>/dev/null

# Detect API surface
find . -type f \( -name "*.controller.*" -o -name "*Controller.*" -o -name "routes.*" -o -path "*/api/*" \) 2>/dev/null | grep -v node_modules | head -20

# Detect UI components
find . -type d \( -name "components" -o -name "screens" -o -name "pages" \) 2>/dev/null | grep -v node_modules | head -10
```

From the scan → create drafts of (prose in `$VAULT_LANG`; headings, frontmatter, and dependency names stay English):
- `<vault>/70-Reference/REF-TechStack.md` (auto-filled from dependencies)
- `<vault>/70-Reference/REF-APIIntegration.md` (auto-filled from the endpoints found)
- `<vault>/00-Index/IMPLEMENTATION-STATUS.md` (mark project as: `adopted from existing codebase`)

### 3.2 Import the README (when the user answered yes in 1.2)

Read the project's `README.md`, then propose:
- Find the product-description section → place it in `<vault>/10-PRD/PRD-<slug>.md`
- Find the install/usage section → reference it in `REF-TechStack.md`
- Find the feature list → create `<vault>/20-Features/FEAT-*.md` drafts

Show the user the mapping → ask for confirmation (in `$PROJECT_LANG`) before creating anything

### 3.3 Suggest first task

> "Adopted brownfield project — code already exists, but the docs are incomplete"
>
> Propose:
> - As the first task: `/ow-plan reverse-engineer existing X` or `/ow-doc PRD` to fill in the PRD

### 3.4 Never touch existing code — the iron rule

- /ow-init never edits an existing code file
- Never move/rename an existing code file
- Add only: `docs/`, `.claude/`, `.ow/`, `templates/`, `scripts/`, `.ow.yml`, `CLAUDE.md`
- If `CLAUDE.md` already exists → merge the obsidian-workflow managed block into it (`scripts/ow-claude-md.sh`); the host's own prose outside the markers is never renamed, moved or rewritten

## Phase 4 — Verify the obsidian-workflow snapshot

The installer already copied `.ow/{commands,templates}` — confirm it is there
rather than recreating it:

```bash
test -d .ow/commands  || { echo "STOP: .ow/commands missing — re-run the installer"; exit 1; }
test -d .ow/templates || { echo "STOP: .ow/templates missing — re-run the installer"; exit 1; }
```

To update it later → `/ow-sync`

## Phase 5 — Subagents

obsidian-workflow installs exactly **four** agent bodies, and they are the four every project needs whatever it is
built in: `docs` (vault) · `verifier` (test/lint/build) · `security` (secret/PII) · `gh-issue`. They are
always-on and this phase does not ask about them.

Specialized agents are **not shipped and not enabled here.** `backend` `frontend` `mobile` `design`
`test-runner` are names in `.ow.yml`, nothing more, until `/ow-agent create <name>` writes a body
against the stack this project actually runs — which is knowable only after Phase 1 detected it and a
PRD/SRS exists. Enabling a flag now would promise an agent Claude Code cannot spawn.

So: leave every specialized flag `false`, and close the init by pointing at the two commands that finish
the job (render in `$PROJECT_LANG`):

```
Subagents: docs · verifier · security · gh-issue (always-on, installed)
Specialized agents for <stack from Phase 1> — not created yet:
  /ow-agent suggest              → which ones this stack warrants, and why
  /ow-agent create <name>        → write one against this stack
```

## Phase 6 — Write the config (2 files)

### 6.1 `.ow.yml` (git-tracked — shared with the team)

Use the values the user gave:
- `project.name`, `project.slug`
- `mode` (standalone / submodule)
- `vault_path`: for A/B/C in Phase 1.2 → the in-repo relative path; for D (external) → the absolute path
- `subagents.*`
- `submodules` (auto-filled from `.gitmodules` when present)
- `ow.version` + `ow.source` + `ow.last_synced`

### 6.2 Check `.gitignore`

```bash
test -f .gitignore || cp .gitignore.template .gitignore
grep -q "^.ow/local/" .gitignore || echo "" >> .gitignore && cat >> .gitignore <<'EOF'

# obsidian-workflow per-machine runtime state
.ow/local/
EOF
[ -n "$TEST_ENV_FILE" ] && { grep -qxF "$TEST_ENV_FILE" .gitignore || echo "$TEST_ENV_FILE" >> .gitignore; }
```

### 6.3 Scaffold the test-credentials example file (only when `test_credentials.env_file` is set)

🔴 **Read `.ow/commands/_shared/test-credentials.md` and follow it** — it owns the schema, the
scaffold format, and the "never invent a credential" rule. Derive `$EXAMPLE_FILE`/`$ROLES` as it
describes and write `$EXAMPLE_FILE` with blank values, one block per role; never create
`$TEST_ENV_FILE` itself here — that file holds real credentials the user supplies.

## Phase 7 — Verification

```bash
ls docs/ | wc -l                    # expect ≥ 12 folders
test -f .ow.yml && echo OK
test -f CLAUDE.md && echo OK
ls .claude/commands | grep -c '^ow-'  # expect ≥ 13
ls .claude/agents | wc -l           # expect 4 (the always-on set — specialized agents are created later)
test -d .ow/commands && test -d .ow/templates && echo OK
```

Show a summary:

```
✅ ow init complete

Mode: <greenfield|brownfield>
Project: <name> (<slug>)
Vault: <vault_path>/
ow version: <0.4.1>
Subagents installed: docs, verifier, security, gh-issue (specialized: none yet — /ow-agent suggest)
Submodules: <list or none>

Next steps:
  • Greenfield → /ow-new (brainstorm a new idea)
  • Brownfield (with a README) → review the PRD draft + /ow-doc PRD-<slug> to add the missing sections
  • Brownfield (no README) → /ow-new --import <path-to-existing-doc>
  • To build the design system first → /ow-design
```

## Output (short bullets, in `$PROJECT_LANG`)

Close /ow-init with **short, quickly readable bullets** in the configured language (`$PROJECT_LANG` from Phase 0). Only:

- **What was done** — the mode (greenfield/brownfield/adopt), the vault created, the always-on subagents installed
- **Files** — `.ow.yml` + the vault skeleton
- **Checks** — the verification result (Phase 7)
- **Risks/next** — a brownfield PRD draft needs stakeholder review; obsidian-workflow may have updates → `/ow-sync`; then `/ow-new`

🔴 Brownfield: **never fabricate** a dependency/framework version that was not seen in a real file.

## Never

- Never edit existing code
- Never fabricate a dependency, framework, or version that was not actually seen in a file
- Never assume the project type when detection is ambiguous — ask the user
