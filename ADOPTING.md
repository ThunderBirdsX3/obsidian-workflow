# ADOPTING.md — Installing / Adopting obsidian-workflow into a Project

> **Audience:** an AI agent (or developer) instructed to add obsidian-workflow to a project.
> **Trigger keywords** (apply this doc when you see any of these): `adopt obsidian-workflow`,
> `install obsidian-workflow`, `set up obsidian-workflow`, `migrate project to obsidian-workflow`, `obsidian-workflow onboarding`,
> `bootstrap obsidian-workflow`, `add obsidian-workflow to this repo`.
>
> **Version note:** This guide describes the current release line (**v2.x**). The resolver
> subcommands (`--selftest`/`--rules`/`--submodules`) and the conformance lint have been in
> place since v0.7 — on an install older than that, upgrade first.
>
> obsidian-workflow is a generic, config-driven AI dev workflow toolkit. It works for **any** project —
> greenfield or brownfield, single-repo or submodule monorepo, any stack — because all
> project-specific knobs live in config or local rules, never in core. This guide is stack-neutral.

## 0. What you are about to do (one paragraph)

You will run a one-line installer that drops a small set of **additive** files into the project
(config templates, a path resolver script, command/agent definitions, a docs vault skeleton),
then fill in the config file, then verify. The installer is **non-destructive**: it never
deletes the project's source, never wipes existing AI settings, and skips files that already
exist unless you explicitly force overwrite. Everything project-specific is expressed through
config (`.ow.yml`) and project rule files (`.ow/rules/`).

## 1. Preconditions check (run first, STOP on failure)

```bash
# 1. yq is a HARD prerequisite (the resolver parses YAML lists/nested keys — no awk fallback)
command -v yq >/dev/null || echo "MISSING: yq — install before continuing (brew install yq / apt / download)"

# 2. git repo present (resolver roots itself at the git toplevel / first ancestor with .ow.yml)
git rev-parse --show-toplevel >/dev/null 2>&1 || echo "MISSING: run inside a git repo (git init first for greenfield)"

# 3. detect adoption mode
ls package.json pyproject.toml go.mod Cargo.toml *.csproj pom.xml build.gradle pubspec.yaml composer.json 2>/dev/null | head -1   # any hit => brownfield
[ -d docs ] && find docs -maxdepth 2 -name '*.md' | head -1   # existing notes => possibly adopt-vault
```

Classify the project:

- [ ] **greenfield** — empty/near-empty repo, no real source or commits.
- [ ] **brownfield** — existing source, manifests, or commit history. Installer must not touch existing code.
- [ ] **adopt-vault** — there is already a docs/notes vault (any folder layout). Reuse it; do not overwrite notes.

> If `yq` is missing, **STOP** and tell the user to install it. Do not proceed — list-shaped
> config (submodules, roles, verification entries) will silently read as empty.

## 2. Safe install

```bash
# from the project root
bash <(curl -fsSL <obsidian-workflow-installer-url>) --mode auto   # <obsidian-workflow-installer-url>  # FILL IN: the published raw installer URL for this release
#   alternatively, clone + run the installer directly:
#   git clone <obsidian-workflow-repo-url> .ow-src && bash .ow-src/scripts/install.sh --mode auto
#   --mode greenfield|brownfield|auto   (auto detects; asks when ambiguous)
#   --yes                               (non-interactive; picks safe defaults)
#   --dry-run                           (print actions, change nothing — run this first to preview)
```

### What it WILL add (additive only)

- [ ] `.ow.yml` — shared project config (git-tracked).
- [ ] `scripts/` + `bin/` — only the obsidian-workflow-owned helper files (path resolver, upgrade,
      rollup, conformance lint, `bin/ow`). These are **mixed-ownership** dirs: install
      copies only the owned files and upgrade refreshes only those **per-file** — any custom script
      you drop into `scripts/` or `bin/` survives every upgrade and rollback (owned set is defined in
      `scripts/ow-owned.sh`).
- [ ] `.ow/` — core machinery (commands, templates, policies, version pin) **and `.ow/rules/` with starter `<area>.md` scaffolds for the enabled areas** (git-tracked; idempotent, never overwrites yours).
- [ ] AI front-end shims (command shims + a baseline set of always-on agent docs).
- [ ] A docs vault skeleton (numbered folders) — only created if absent; sample content only for greenfield.
- [ ] `.gitignore` — a **marker-delimited managed block** (obsidian-workflow-internal paths only: per-machine
      runtime state, worktrees, sync backups). install/upgrade MERGE this block and **never touch your
      existing lines** — a brownfield `.gitignore` is preserved in full. Stack/OS/editor ignores
      (`node_modules`, `dist`, `.env`, `.DS_Store`, …) stay yours to manage, outside the markers.

> **Pre-existing `.claude/agents` / `.claude/commands` of your own?** The installer
> detects any agent/command it does **not** own and asks **keep-all / remove-all (backed up first) /
> select per item** — independently for agents and commands. Non-interactive (`--yes` / no TTY)
> default = **keep all + warn** (the new `ow-*` commands inject the `§0` context block only into
> obsidian-workflow-owned agents, so a non-conforming user agent may not interoperate). The choice is recorded
> in `.ow/local/adopt.marker` so re-runs/upgrades don't re-prompt. A user-owned agent missing
> `§0` is a lint **note**, never a hard-abort. Ownership is decided by a **signature inside the
> file** (`<!-- obsidian-workflow:agent -->`, or the `§0` header obsidian-workflow writes) — never by filename, so
> your own `.claude/agents/backend.md` stays yours — and obsidian-workflow ships no specialized body at all now, so
> it installs none of its own under
> that name. Anything the installer does overwrite is copied first to
> `.ow/backups/install-<timestamp>/`; undo by hand with
> `cp -R .ow/backups/install-<timestamp>/. .`

### What it will NOT touch (protected paths)

The installer/upgrade/sync must treat these as **protected** and never overwrite or delete them:

- [ ] Project **source code** and existing manifests.
- [ ] The project's root **VERSION** file (if any) — preserved, not deleted (backed up before any migration).
- [ ] Existing **AI settings** (never wipe the whole settings dir; never touch the per-machine local settings file, hooks, MCP perms, or project-enabled agents).
- [ ] `.ow.yml` — existing config is never overwritten. Upgrade may **additively backfill** newly-shipped blocks/knobs (e.g. `paths.vault_publish_dest`) — append-only, every existing value/comment preserved, backed up pristine for `--rollback`.
- [ ] `.ow/rules/` — project rules. `.ow/local/` — per-machine runtime state.
- [ ] Project-level `commands/` and `templates/` **override layers**.
- [ ] The **secrets env file** (the gitignored test-credentials env file) and any `*.local.*` config.

> Run `--dry-run` first and read the planned actions. If anything in the protected set appears
> under "would replace", stop and report it as a bug — do not proceed.

## 3. Configure: `.ow.yml` (shared, git-tracked)

Fill generic placeholders. **Every block is optional** — an empty/absent block means "fall back
to repo convention / prior default", so a minimal single-repo project needs almost nothing.

```yaml
project:
  name: "<project name>"
  slug: "<short-slug>"

# Vault location (where text notes live). Optional; default = a docs subfolder.
vault_path: "docs/obsidian-vault"

# Submodule monorepo only — list each child repo + whether it is read-only.
# OMIT entirely for single-repo projects (the default).
submodules: []
#   - { name: api, path: api/, branch: main, read_only: false }

# Build/test per area. OPTIONAL — empty = resolver falls back to repo convention.
verification_matrix: []
#   - { area: default, detect: "package.json", build: "<build cmd>", test: "<test cmd>", pass_regex: "<regex>", coverage_threshold_lines: 0 }

# Vault dir name overrides — only entries that differ from defaults.
vault_dirs: {}
#   phases: "50-Phases"
```

## 4. Vault outside the repo + secrets

```yaml
# .ow.yml
vault_path: "/Volumes/shared/MyVault"   # absolute path when the vault lives outside this repo

test_credentials:
  env_file: ".env.test"                 # gitignored credentials env file
```

> Keep secrets out of source. Test credentials go in the env file referenced by
> `test_credentials.env_file`, never in YAML or notes.

## 5. Migration tasks for an EXISTING (brownfield) project

Do these in order. Each is independently verifiable.

### 5.1 Command naming
- [ ] Confirm the installed command shims resolve to the core command specs. If the project needs renamed commands, use the override layer (project `commands/`) — do not edit core.

### 5.2 Vault directory overrides (generic)
- [ ] If the project already has a plans/phases folder under a **different name**, do NOT rename it. Map it via `vault_dirs` (e.g. `phases: "<existing-folder-name>"`).

### 5.3 REMOVE binaries from the vault (HARD constraint)
The vault must contain **text only**. Any screenshots, logs, traces, coverage, HAR or zip
currently inside the vault has to go.

```bash
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)"
find "$VAULT_ABS" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.har' \
  -o -name '*.zip' -o -name '*.log' -o -name '*.txt' \) -print
```
- [ ] Move every binary out of the vault (or delete it — obsidian-workflow keeps no artifact store).
- [ ] Replace it with text: the command that was run and its real output, trimmed to the relevant
      lines and PII-masked. No base64-embedded images.

### 5.4 Seed project rules instead of editing core
- [ ] `init` already scaffolds `.ow/rules/<area>.md` for each enabled area (the canonical file per area is `<area>.md` — `backend`→`backend.md`, `test-runner`→`testing.md`, etc.). Fill the scaffold with this project's conventions (front-matter `applies_to: [<areas>]`) — a resolved rule **overrides** the generic command/agent guidance for that area.
- [ ] Name the file, don't guess: `bash scripts/ow-paths.sh --rules-expected <area>` prints the exact path (even when absent). Any rule listed in `.ow.yml` `rules.files` **must resolve** — `--rules-validate` (and `--selftest`) fail loud on a registered rule that doesn't, so a load-bearing convention can never be silently dropped.
- [ ] **Never edit core command/agent/template files** to encode project facts — they refresh on upgrade and your edits would be lost.

### 5.6 Additional teammates on an already-adopted repo
- [ ] A new teammate who clones the repo already has everything obsidian-workflow reads — config is `.ow.yml` only. They should NOT re-run init; `.ow/local/` is recreated on the first command run. Only the test-credentials env file (gitignored) has to be filled in by hand.

### 5.5 Gitignore hygiene
- [ ] Remove any leftover artifact-store ignore rules (e.g. `test-artifacts/`) that no longer correspond to anything obsidian-workflow writes.

## 6. Verification (run all; every check maps to a non-zero-exit assertion)

```bash
ROOT="$(git rev-parse --show-toplevel)"
FAIL=0

# (a) doctor — overall health (must exit 0)
bash "$ROOT/bin/ow" doctor; [ $? -eq 0 ] || { echo "FAIL: doctor"; FAIL=1; }

# (b) resolver self-test — proves it reads YAML lists + nested keys + roots correctly (must exit 0)
bash "$ROOT/scripts/ow-paths.sh" --selftest; [ $? -eq 0 ] || { echo "FAIL: selftest"; FAIL=1; }

# (c) resolver output sanity
if ! eval "$(bash "$ROOT/scripts/ow-paths.sh" --shell)"; then echo "FAIL: resolver"; FAIL=1; fi
[ -n "${PLAN_DIR:-}" ] || { echo "FAIL: resolver returned empty (mis-rooted or yq missing)"; FAIL=1; }

# (d) conformance lint — version-gated (added in v0.7); skip cleanly if not yet installed
if [ -x "$ROOT/bin/ow" ] && bash "$ROOT/bin/ow" lint "$ROOT" >/dev/null 2>&1; then :; \
elif [ -x "$ROOT/scripts/conformance-lint.sh" ]; then bash "$ROOT/scripts/conformance-lint.sh" "$ROOT" || { echo "FAIL: lint"; FAIL=1; }; \
else echo "NOTE: conformance lint not available on this version — upgrade to v0.7"; fi

# (e) HARD GATE — the vault contains NO binaries (abort on any hit)
if find "$VAULT_ABS" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.har' \
  -o -name '*.zip' -o -name '*.log' -o -name '*.txt' \) | grep -q .; then
  echo "FAIL: binaries found in vault — the vault holds text only"; FAIL=1
else echo "OK: vault is text-only"; fi

[ "$FAIL" -eq 0 ] && echo "ALL CHECKS PASS" || { echo "VERIFICATION FAILED"; exit 1; }
```

- [ ] doctor exits 0.
- [ ] resolver `--selftest` exits 0 (lists + nested keys readable).
- [ ] resolver `--shell` succeeds and returns non-empty paths.
- [ ] conformance lint passes (or is cleanly noted as not-yet-available on a pre-v0.7 install).
- [ ] vault binary scan returns **nothing**.

## 7. Rollback & upgrade safety

- **Rollback the last upgrade:** `bash scripts/upgrade.sh --rollback` (restores from the most recent automatic backup).
- **Preview an upgrade:** `bash scripts/upgrade.sh --dry-run`.
- **Guarantee:** upgrade/sync/install **preserve** your config and rules. The following
  survive upgrades untouched: `.ow.yml`, `.ow/rules/`,
  `.ow/local/`, project `commands/` + `templates/` override layers, the root `VERSION`,
  and the secrets env file. If an upgrade ever modifies one of these, treat it as a
  release-blocking bug.

```bash
cp .ow.yml /tmp/before.yml
bash scripts/upgrade.sh --dry-run        # then a real upgrade if desired
diff -q /tmp/before.yml .ow.yml && echo "OK: shared config preserved"
```

## 8. TL;DR (for humans)

1. Install `yq`, be in a git repo. Run `--dry-run` first, then the installer.
2. It only **adds** files. It never deletes your code, your VERSION, your AI settings, or your config/rules.
3. Fill `.ow.yml`. Most blocks are optional.
4. Brownfield: map any oddly-named notes folder via `vault_dirs`; get any images/logs out of the vault (it is text-only); put project conventions in `.ow/rules/` (never edit core).
5. Verify: `doctor`, resolver `--selftest`, conformance lint, and "no binaries in the vault".
6. Upgrades are reversible (`--rollback`) and never clobber your config/rules.
