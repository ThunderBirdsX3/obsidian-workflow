---
description: Agent management — list, enable, disable, create, regenerate intelligent specialized agents based on project context
---

# /ow-agent — Subagent Management

Manage subagents: list/enable/disable + **create new agents specialized to the real project context**

> **Problem this solves:** a shipped `backend` agent has to be generic enough for .NET, Django, Rails and
> Express at once — so it is deep in none of them, and every project pays its context whether or not it does
> backend work. obsidian-workflow therefore ships **only the four always-on bodies** (`docs` `verifier` `security`
> `gh-issue`). Everything else — `backend` `frontend` `mobile` `design` `test-runner`, or any name this
> project invents — is **written by `/ow-agent create <name>` against the stack this project actually runs**,
> once `/ow-init` has detected it and a PRD/SRS exists.

🔴 **Enabled ⟺ a file in `.claude/agents/` ⟺ spawnable — one condition, and this command is its only writer.**
A `subagents.<name>` flag with no body behind it promises an agent Claude Code cannot spawn; install/upgrade
report that combination and never quietly fill it in (only a body written against a real stack is worth having).

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
/ow-agent                                # interactive — show the menu
/ow-agent list                           # show every agent + enabled status
/ow-agent enable <name>                  # enable agent
/ow-agent disable <name>                 # disable agent
/ow-agent create <name>                  # WRITE a new agent body from the detected stack (interactive)
/ow-agent regenerate <name>              # rewrite the agent from the current vault context
/ow-agent audit                          # check that agent definitions are complete
/ow-agent suggest                        # detect the stack → recommend which agents to create
```

## Phase 0 — Resolve state

```bash
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)"
ls .claude/agents/*.md          # every agent that EXISTS — exactly what Claude Code can spawn
yq '.subagents' .ow.yml   # the flags — a name here with no file above is NOT created yet
bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --agent-models   # name<TAB>model
```

Show a table. **State** is the whole point of it — three values, never collapsed into a tick:

| State | means | fix |
|---|---|---|
| `✓ live` | flag on **and** a body in `.claude/agents/` | — |
| `— not created` | flag on/off, no body: a name, not an agent | `/ow-agent create <name>` |
| `✗ broken` | flag **on**, no body — the config is promising a spawn that cannot happen | `/ow-agent create <name>` |

```
Agent          State           Model    Written      Spec lines   Notes
-----          -----           -----    -------      ----------   -----
docs           ✓ live          sonnet   shipped      231          always-on, vault keeper
verifier       ✓ live          sonnet   shipped      288          always-on
security       ✓ live          opus     shipped      296          always-on
gh-issue       ✓ live          haiku    shipped      147          always-on, GitHub issue+image reader
backend        ✓ live          sonnet   2026-05-19   180          created: .NET 8 API, `dotnet test`
frontend       ✗ broken        sonnet   —            —            enabled with no body → create it
mobile         — not created   sonnet   —            —            no mobile surface detected
design         — not created   sonnet   —            —            create, then /ow-design init
test-runner    — not created   sonnet   —            —            no E2E runner in the repo yet
```

`Written` = `shipped` for the always-on four, otherwise the date `create`/`regenerate` last wrote the body.

## Phase 1 — `list` / `enable` / `disable`

`.claude/agents/<name>.md` present ⟺ the agent is spawnable ⟺ `subagents.<name>` is on.
`enable` moves BOTH sides or neither — a flag with no agent body is a config that lies.

`enable` never *authors* a body — it only turns on one that already exists here: the file
`/ow-agent create` wrote, or the dated backup `disable` left behind. **A name that has
never been created cannot be enabled**, and the command says so and stops rather than
copying in a generic stand-in: an agent that does not know this project's stack is worse
than no agent, because the orchestrator will trust it.

`list` reads the config and `.claude/agents/`, and shows each agent's resolved model
(`bash scripts/ow-paths.sh --agent-models`) beside the 3-state above. An agent enabled in
config with no file under `.claude/agents/` is reported **broken**, never as enabled.

### enable

```bash
ROOT="$(git rev-parse --show-toplevel)"; NAME="<name>"
# 1) find a body — but do NOT write it yet. obsidian-workflow ships no specialized body, so the only
#    sources are this project's own: the file `/ow-agent create` wrote, and the dated backup
#    `disable` leaves behind.
SRC=""
for c in "$ROOT/.claude/agents/$NAME.md" \
         "$(ls -t "$ROOT/.claude/agents/$NAME.md.bak-"* 2>/dev/null | head -1)"; do
  [ -n "$c" ] && [ -f "$c" ] && { SRC="$c"; break; }
done
[ -n "$SRC" ] || {
  echo "FATAL: no agent body for '$NAME' — there is nothing to enable."
  echo "       obsidian-workflow ships only docs/verifier/security/gh-issue; every other agent is written"
  echo "       against THIS project's stack. Run:  /ow-agent create $NAME"
  echo "       (or /ow-agent suggest first, to see which agents this stack actually warrants)"
  echo "       Nothing was written — the project is unchanged."; exit 1; }
# 2) flip the flag FIRST — the config is the half that can silently refuse. Surgical sed on
#    the ONE line (yq -i strips every comment in this file), covering BOTH documented forms:
#    the map `<name>: { enabled: false, ... }` and the scalar shorthand `<name>: false`,
#    each with or without a trailing `# comment`.
sed -i.bak -E \
  -e "s/^([[:space:]]+$NAME:[[:space:]]*[{][[:space:]]*enabled:[[:space:]]*)false/\\1true/" \
  -e "s/^([[:space:]]+$NAME:[[:space:]]*)false([[:space:]]*(#.*)?)$/\\1true\\2/" \
  "$ROOT/.ow.yml"
rm -f "$ROOT/.ow.yml.bak"
# 3) read the flag back — an unmatched substitution is silent, and writing the body on top of
#    a flag that never moved is the exact "config that lies" this command exists to prevent.
#    The resolver knows only the nine names obsidian-workflow ships, so a custom agent is read straight
#    from the config. Nothing has been written yet: STOP here leaves the project untouched.
if ! bash "$ROOT/scripts/ow-paths.sh" --subagents 2>/dev/null | grep -qx "$NAME" \
   && ! grep -qE "^[[:space:]]+$NAME:[[:space:]]*([{][^}]*enabled:[[:space:]]*true|true([[:space:]]*(#.*)?)$)" "$ROOT/.ow.yml"; then
  echo "FATAL: $NAME is still disabled in .ow.yml — either it has no subagents entry"
  echo "       (a custom agent needs one: see Phase 2.4) or the entry is in a shape the flag"
  echo "       rewrite does not recognise. Set it to \`{ enabled: true }\` by hand, then re-run."
  echo "       Nothing was written — the project is unchanged."; exit 1
fi
# 4) NOW the body, so config and file move together or neither does
[ -f "$ROOT/.claude/agents/$NAME.md" ] || cp "$SRC" "$ROOT/.claude/agents/$NAME.md"
# 5) post-condition — enable is done only when the agent is actually spawnable
[ -f "$ROOT/.claude/agents/$NAME.md" ] || { echo "FATAL: $NAME still not spawnable"; exit 1; }
# 6) sync the agent's model: frontmatter to whatever config now resolves to
. "$ROOT/scripts/ow-claude-manifest.sh"
apply_agent_models "$ROOT"
```

### disable

```bash
ROOT="$(git rev-parse --show-toplevel)"; NAME="<name>"
# The always-on four have no off switch, and this is a gate rather than a note because the
# two halves cannot both be turned off: install/upgrade re-copy their bodies on every run
# while nothing rewrites .ow.yml (it is in SAFE_PATHS). A flipped flag would leave the
# config off and the agent still spawnable — the invariant above, broken by us.
case " docs verifier security gh-issue " in
  *" $NAME "*) echo "FATAL: $NAME is always-on and cannot be disabled"; exit 1 ;;
esac
sed -i.bak -E \
  -e "s/^([[:space:]]+$NAME:[[:space:]]*[{][[:space:]]*enabled:[[:space:]]*)true/\\1false/" \
  -e "s/^([[:space:]]+$NAME:[[:space:]]*)true([[:space:]]*(#.*)?)$/\\1false\\2/" \
  "$ROOT/.ow.yml"
rm -f "$ROOT/.ow.yml.bak"
bash "$ROOT/scripts/ow-paths.sh" --subagents 2>/dev/null | grep -qx "$NAME" && {
  echo "FATAL: $NAME is still enabled in .ow.yml — set it to \`{ enabled: false }\` by hand"; exit 1; }
# the body goes too: Claude Code spawns whatever sits in .claude/agents/, so a flag on
# its own disables nothing. Dated backup, because the file may have been regenerated.
[ -f "$ROOT/.claude/agents/$NAME.md" ] && mv "$ROOT/.claude/agents/$NAME.md" \
  "$ROOT/.claude/agents/$NAME.md.bak-$(date +%Y%m%d)"
```

The always-on four (`docs` `verifier` `security` `gh-issue`) have no off switch: `disable`
refuses them, and install/upgrade re-copy their bodies on every run.

To run an agent on a different model, edit the map form in `.ow.yml`
(`<name>: { enabled: true, model: opus }`) then re-run `apply_agent_models` — no need
to hand-edit the agent file.

`design` becomes live → follow up with (render in `$PROJECT_LANG`): "Run /ow-design init as well?" — the agent owns `<vault>/70-Reference/DesignSystem/`, which `/ow-design init` creates

## Phase 2 — `create <name>` (interactive)

Write the body of one specialized agent. **This is the only way a specialized agent comes into being** —
nothing ships one — so the run must end with a file that knows more about this project than a generic
agent ever could. The three inputs that make that true are §2.1 (detected stack), §2.2 (this project's
rules + vault), and §2.3 (what the user says the agent owns). Skipping any of them produces a body that
is just the template with a name on it — refuse to write that; say what is missing instead.

### 2.1 Detect the stack FIRST (before asking anything)

Ask the user only what the repo cannot answer for itself. Detect, then confirm:

```bash
ROOT="$(git rev-parse --show-toplevel)"
# manifest → stack. First match per line wins; a repo may legitimately hit several.
ls "$ROOT"/package.json "$ROOT"/*/package.json 2>/dev/null      # node/ts — read deps for the framework
ls "$ROOT"/pubspec.yaml 2>/dev/null                             # flutter/dart
ls "$ROOT"/go.mod "$ROOT"/Cargo.toml 2>/dev/null                # go / rust
ls "$ROOT"/*.csproj "$ROOT"/*/*.csproj "$ROOT"/*.sln 2>/dev/null # .NET
ls "$ROOT"/pyproject.toml "$ROOT"/requirements.txt 2>/dev/null   # python
ls "$ROOT"/build.gradle* "$ROOT"/pom.xml 2>/dev/null             # jvm
ls "$ROOT"/Podfile "$ROOT"/*.xcodeproj 2>/dev/null               # native ios
bash "$ROOT/scripts/ow-paths.sh" --submodules                   # multi-repo: which surface lives where
```

Then read the FRAMEWORK out of the manifest rather than guessing from the language: `package.json`
dependencies distinguish Next.js from Express from Playwright; `*.csproj` `<TargetFramework>` gives the
.NET version; `pubspec.yaml` gives the Flutter constraint. Also read `<vault>/70-Reference/REF-TechStack.md`
when it exists — a project that wrote its stack down outranks anything inferred from files.

Show what was detected and let the user correct it — detection is a signal, not truth:

```
Detected: TypeScript · Next.js 15 (app router) · Prisma + PostgreSQL · Vitest · Playwright
Verify commands found: `pnpm test` · `pnpm lint` · `tsc --noEmit` · `pnpm build`
Right? (edit anything wrong before I write the agent)
```

🔴 Nothing detected and the user cannot name a stack ⇒ **STOP**. Do not write a generic body as a
placeholder: a body that names no stack, no verify command and no owned path is exactly the shipped-generic
agent this design removed, and once written it will be trusted.

### 2.2 Read this project's own rules + vault

The generated gates must come from what this project already decided, not from a stock list:

```bash
ls "$ROOT/.ow/rules/"                       # project rules — the agent's gates start here
bash "$ROOT/scripts/ow-paths.sh" --rules "$AREA" # what the orchestrator will inject for this area
grep -rl -i "$DOMAIN_KEYWORDS" "$VAULT_ABS"/{10-PRD,20-Features,40-Functions,70-Reference}/*.md
ls "$VAULT_ABS/70-Reference/DesignSystem/" 2>/dev/null   # a UI agent must enforce the DS if one exists
grep -rl "subagent_target: $AREA" "$PLAN_DIR"/*.md       # how past plans scoped this area
```

### 2.3 Ask as one batch — only what §2.1/§2.2 could not answer (render in `$PROJECT_LANG`)

1. **Agent name** (kebab-case, e.g. `data-pipeline`, `infra-aws`, `seo-content`) — skip if given as the argument
2. **One-line role** ("Maintain ETL pipelines for the Snowflake warehouse")
3. **Files/paths the agent owns** (`etl/`, `dags/`, `src/api/`) — offer the detected paths as the default
4. **Paths it must NOT touch** (usually production data, generated code, another agent's surface)
5. **Gates that must never be skipped** — beyond what §2.2 already found in the rules
6. **Tools** (Read, Write, Edit, Glob, Grep + an ALLOWLISTED Bash set — never bare `Bash`)
7. **Linked vault docs**, if any beyond what §2.2 found

Confirm the stack summary from §2.1 in the same batch, so the whole interview is one round.

### 2.4 Derive the gates (§5) — from this project, per a fixed taxonomy

The agent's value is its gates, and a stock gate list is what made a shipped agent shallow. Fill **each**
row below from §2.1/§2.2 for the area at hand; a row with nothing real to say is dropped, never padded:

| Gate class | ask of THIS project |
|---|---|
| Verification | which command proves the change works, and what "clean" looks like (from §2.1) |
| Test | what must exist before a production change may be called done — floor: `.ow/commands/_shared/coding-discipline.md` §3, raised by the project's own rule for area `coding` under `.ow/rules/` |
| Irreversibility | what this stack can do that cannot be undone — migration, deploy, published artifact |
| Contract | which shared surface must not silently change — API shape, schema, DS token, public export |
| Project-specific | whatever `.ow/rules/<area>.md` and the vault REF docs already mandate |

Each gate is written as a **STOP condition**, in the shape `<observable situation> ⇒ STOP` — never as advice.

### 2.5 Generate the agent file

Path: `.claude/agents/<name>.md`

🔴 **Where the project-specificity goes — the one rule that keeps this safe:**

| Section | content | why |
|---|---|---|
| §1 role · §5 gates · §6 process · §9 examples | **the detected stack, named** — its framework, idioms, failure modes, the verify commands from §2.1, the gates from §2.4 | this is the depth a shipped generic agent could never have; it is why the agent is created per project |
| §2 project context · paths · submodules · rules | **a pointer to the §0 injected block — never baked** | these are resolved per RUN (worktree, submodule, external vault). A copy in the file is a second source that drifts, and the agent has no bash tool to tell which one is right |

Baking a *framework* is the point; baking a *path* is the bug.

🔴 **Never write the `<!-- obsidian-workflow:agent` signature into a created agent.** That marker means
"obsidian-workflow authored this file and install/upgrade may replace it". A created agent is the PROJECT's —
it must survive every upgrade untouched, which is exactly what the absence of that line guarantees.

Structure:
```markdown
---
name: <name>
description: Use this agent when <role>. Examples: <2-3 invocation patterns>
model: <resolved>          # see "Model" note below — from `ow-paths.sh --agent-model <name>`
tools: Read, Write, Edit, Glob, Grep, Bash[selective allowlist]
---

# <Name> Agent

## §0. Context (injected — authoritative)

The **PROJECT CONTEXT block injected into your prompt at spawn time is the sole source**
of this project's paths, stack, submodules, verification commands, guardrails, and rules.
You have **no bash tool** and cannot self-resolve — never rediscover or guess.

- If the injected PROJECT CONTEXT block is **absent**, **STOP** and hand back
  "missing injected context — re-spawn with PROJECT CONTEXT"; do not proceed on defaults.
- Rules listed in the block (resolved for your area) **override** the generic guidance below.
- The vault holds text only — never write a binary into it.
- **`LANG` / `VAULT_LANG`** — report back in `LANG`; text you write into files under `VAULT_ABS`
  is in `VAULT_LANG`. No `VAULT_LANG` line in the block ⇒ use `LANG` (fail-safe). Headings,
  frontmatter, code, and commit messages stay English regardless of both.
- A single-repo project has **no** SUBMODULES line — that is normal, not missing context.
- A **`=== CHUNK n/N ===` block** scopes this spawn to one slice of the plan: do only the
  `STEPS:` range, read `READ_FULL` + `READ_NAMED`, and close with the block's RETURN PROTOCOL
  (`STATUS: DONE|CONTINUE|BLOCKED` + HANDOFF, every field, empty value written `(none)`).
  **No CHUNK block ⇒ do the whole plan** — fail-safe, same 3-state pattern as `CONTEXT_REFS`.

## §1. Role
<one paragraph, naming the ACTUAL stack from §2.1 — its framework and version, the idioms this
project follows, and the 3-5 failure modes that matter in it. "Backend specialist" is not a role;
"Django 5 + DRF service layer, Celery for async, the failure modes are N+1 in serializers and
migrations that lock" is.>

## §2. Project context awareness

> Owned paths, submodules, rule files and vault refs come from the **§0 injected
> PROJECT CONTEXT block** — never from this section. They are resolved per run (worktree,
> submodule, external vault), and this agent has no bash tool to re-resolve them, so a copy here
> is a second source that silently drifts. The stack expertise lives in §1/§5/§6; the resolved
> values live in §0.

## §3. Read context first (vault-first rule)

**ALWAYS — every task, no exception:**
1. The whole active plan file (when spawned from `/ow-implement`) — Success Criteria + Implementation Steps
2. Docs the plan names explicitly (FN-*, FEAT-*) — acceptance criteria + schema
3. Existing code + tests in the owned paths the task will touch — follow the existing pattern before creating anything new

**CONDITIONAL — read only the files named by `CONTEXT_REFS` (§0 block):**
<table: doc → read when the task touches which surface. e.g. REF-AuthorizationMatrix → when the task touches auth/role/permission>

🔴 **`CONTEXT_SKIPPED` is not an order not to read** — the orchestrator merely judged it
irrelevant to this task. If while working you find you **actually need** it → read it right
away, but you **must** report the line `context gap: <doc> — needed for <reason>` in your
output. Never read it silently (the criteria stay wrong from then on) and never guess the
content instead of reading it
🔴 **No `CONTEXT_REFS` line at all** (spawned outside `/ow-implement`) → read **all** the
conditional docs — fail-safe = read everything, never skip

🔴 **A CHUNK block is present** → the ALWAYS list = the `READ_FULL` + `READ_NAMED` the block
names; a doc already summarized in `DIGEST` need not be re-read. Suspect the digest is not
enough → read the real file, then report `context gap:`

## §4. Scope rules
- MAY touch: <list of paths>
- MUST NOT touch: <list — usually production data, shared/published>
- MUST coordinate with: <agents/humans for shared resources>

## §5. Gates (must-not-skip) — one per non-empty row of the §2.4 taxonomy
- <verification — e.g. "`pnpm test && tsc --noEmit` not run and pasted ⇒ STOP">
- <test — e.g. "Production code change without a test that fails before it ⇒ STOP">
- <irreversibility — e.g. "A migration that drops a column without an approved plan step ⇒ STOP">
- <contract — e.g. "A change to a `src/api/**` response shape without updating its FN doc ⇒ STOP">
- <project-specific — from `.ow/rules/<area>.md`>

### §5.1 Test creation
<for code agents: when production code changes, what tests must exist before commit — never weaker than
`.ow/commands/_shared/coding-discipline.md` §3: a reproducible bug gets a test that FAILs first>

## §6. Process
1. <Phase 1>
2. <Phase 2>
3. ...

## §7. Vault Update Checklist (after work)
- [ ] Update the related FN-* docs
- [ ] Update IMPLEMENTATION-STATUS.md
- [ ] Update related REF-* docs
- [ ] Prose written into these vault docs is in `VAULT_LANG`; headings + frontmatter stay English

## §8. Hand-back format to main Claude
- Files changed (production vs test): ...
- Vault docs updated: ...
- Build/test result (as the run reported it): ...
- Risks / Limitations / Next steps: ...
- Short bullet summary inherited via main Claude (in `LANG`)

## §9. Examples (good vs bad)
**✓ Good invocation:**
<example use case>

**✗ Bad — refuse:**
<example out-of-scope>

## Never
- Never <forbidden 1>
- Never <forbidden 2>
```

### 2.6 Update .ow.yml + set the agent's model

Enable the agent. Use the map form when you also want to pin a non-default model;
otherwise the scalar form keeps the built-in default. **Edit `.ow.yml` surgically
(do NOT `yq -i` the whole subagents block — it strips comments/blank lines):**

```yaml
subagents:
  <name>: true                       # scalar — uses the built-in default model
  # or, to override the model:
  # <name>: { enabled: true, model: opus }   # map form (alias: opus|sonnet|haiku)
```

Then write the resolved model into the new agent's frontmatter:

```bash
ROOT="$(git rev-parse --show-toplevel)"
MODEL="$(bash "$ROOT/scripts/ow-paths.sh" --agent-model <name>)"   # default: sonnet for an unknown name
# set the agent's model: line to "$MODEL" (or `apply_agent_models` for the owned set)
```

> **Model resolution** — `subagents.<name>.model` in `.ow.yml` (local override wins)
> beats the built-in default. Defaults: backend/frontend/mobile/security/design → `opus`,
> docs/verifier/test-runner → `sonnet`, gh-issue → `haiku`. Values are family aliases
> (no version pin) so each tracks the latest of its family. A new specialized agent that
> is code/infra-heavy should use `opus`.

### 2.7 Suggest commands that may benefit
- Which kinds of task can use this agent as `/ow-plan`'s `subagent_target`
- Add the agent to the `/ow-implement` mapping

## Phase 3 — `regenerate <name>`

Rewrite an existing agent against the **stack and vault as they are now**

Do this when:
- The stack moved under the agent — a framework major, a new ORM, a test runner swapped out
- After `/ow-doc` PRD/SRS/Tech — the acceptance criteria the agent must honour got sharper
- After `/ow-design init` — a UI agent must now enforce the DS it did not have before
- `/ow-agent audit` reported a defect

Process:
1. Read the existing `.claude/agents/<name>.md`. Absent ⇒ there is nothing to regenerate:
   **STOP** — the agent is disabled or was never created. Tell the user which, and name the
   fix (`/ow-agent enable <name>` when a `.bak-<date>` exists, otherwise
   `/ow-agent create <name>`).
2. **Re-run §2.1 + §2.2** — detect the stack and read the rules again from scratch. Do not
   carry the old body's stack claims forward: a stale framework version in §1 is precisely
   the defect this command exists to clear.
3. Rewrite §1/§5/§6/§9 against what §2.1/§2.2 just found, using the §2.4 gate taxonomy.
   🔴 §2 stays a **pointer** to the §0 injected block — no baked paths, submodules or rule
   files, no `<TBD>`. The stack is baked; the resolved values are not.
4. Verify the injected-context contract survived the rewrite: §0 present + states "injected
   block is authoritative / absent ⇒ STOP / no bash tool" + carries the `LANG` / `VAULT_LANG`
   bullet.
5. Show the diff → confirm → write. Back up the old body as
   `.claude/agents/<name>.md.bak-<date>` (gitignored) — that backup is also what
   `/ow-agent enable` reads if the agent is later disabled and re-enabled.

> Paths, submodules, verification roots and rule files are resolved at runtime by the
> spawning command and injected — they are never written into the agent file.

## Phase 4 — `suggest`

Read the stack + vault → recommend which agents this project should **create**, each with the
signals behind it. A suggestion with no signal is noise: never propose an agent this repo
shows no sign of needing, and never propose one that already exists.

### 4.1 Gather signals (both halves — code AND vault)

```bash
ROOT="$(git rev-parse --show-toplevel)"
# — code side: what does this repo actually contain? (same detection as §2.1)
ls "$ROOT"/package.json "$ROOT"/*/package.json "$ROOT"/pubspec.yaml "$ROOT"/go.mod \
   "$ROOT"/Cargo.toml "$ROOT"/*.csproj "$ROOT"/*/*.csproj "$ROOT"/pyproject.toml \
   "$ROOT"/build.gradle* "$ROOT"/pom.xml "$ROOT"/Podfile 2>/dev/null
bash "$ROOT/scripts/ow-paths.sh" --submodules          # one row per surface in a monorepo
# — vault side: what has the project committed to building?
ls "$VAULT_ABS/70-Reference/DesignSystem/" 2>/dev/null   # a real DS ⇒ design + a UI agent to enforce it
grep -rl -iE "ETL|pipeline|warehouse|dbt|airflow"  "$VAULT_ABS"/{10-PRD,20-Features,40-Functions}/*.md 2>/dev/null
grep -rl -iE "deploy|kubernetes|terraform|infra"   "$VAULT_ABS"/{10-PRD,70-Reference}/*.md 2>/dev/null
grep -rl -iE "e2e|playwright|maestro|smoke test"   "$VAULT_ABS"/90-TestPlan/*.md 2>/dev/null
# — what already exists, so nothing is proposed twice
ls "$ROOT/.claude/agents/"*.md 2>/dev/null
```

### 4.2 Map signals → agent

A row fires only when its signal is actually present. `frontend` and `mobile` are separate
agents because a repo can hold both, and their gates disagree (WCAG vs HIG/Material).

| Signal found | Suggest | Because |
|---|---|---|
| a server framework in a manifest (Express/Nest/Django/DRF/Rails/ASP.NET/Gin/Axum), or a `migrations/` dir | `backend` | API + schema work has gates (idempotency, migration safety, contract) no generic agent applies |
| a web UI framework (Next/Nuxt/Remix/Vite+React/Vue/Svelte/Astro) | `frontend` | UI work has an a11y + DS-drift surface |
| `pubspec.yaml`, `react-native`/`expo` in deps, `*.xcodeproj`, or an Android `build.gradle` | `mobile` | platform conventions + offline/deep-link concerns are not the web's |
| `<vault>/70-Reference/DesignSystem/` exists, or a Figma export in the repo | `design` | tokens/components need one owner or they drift |
| `playwright`/`@playwright/test`/`cypress`/`maestro` in a manifest, or a `90-TestPlan` with E2E flows | `test-runner` | E2E has its own reporting + flake contract |
| vault mentions ETL/warehouse/dbt/Airflow | `data-pipeline` | lineage + data-quality gates |
| terraform/k8s manifests, or a deploy-heavy REF doc | `devops` | irreversible actions need a gate |

Anything outside the table: propose it only when the grep result is concrete, and **show the
matching files** as the justification.

### 4.3 Report + hand off

Show each suggestion with its signal, and mark the ones already covered so the list is honest:

```
Suggested for this project
  backend      ← package.json: express 5, prisma · prisma/migrations/ (14 files)
  frontend     ← package.json: next 15, react 19
  test-runner  ← package.json: @playwright/test · 90-TestPlan/TP-Checkout.md
Not suggested
  mobile       — no mobile manifest found
  design       — no 70-Reference/DesignSystem/ yet (run /ow-design init first)
Already created
  (none)
```

Then let the user pick, and run `/ow-agent create <name>` for each pick — one at a time, so
each interview is scoped to one agent. 🔴 `suggest` **never writes an agent itself** and never
flips a config flag: it reports, the user chooses, `create` writes.

## Phase 5 — `audit`

Check the agent definition (injected-context contract, #12):
- **§0 present** — states the injected PROJECT CONTEXT block is authoritative, "absent ⇒ STOP",
  and "no bash tool / cannot self-resolve". MISSING §0 ⇒ **defect**.
- **§0 carries the `LANG` / `VAULT_LANG` bullet** — report back in `LANG`; text written into
  files under `VAULT_ABS` is in `VAULT_LANG`; no `VAULT_LANG` line ⇒ fall back to `LANG`.
  MISSING bullet ⇒ **defect** (the agent writes vault docs in the wrong language silently).
- **§2 is a pointer** to §0 — NOT baked facts and NO `<TBD>`. A generic/empty §2 is **correct**;
  a §2 carrying baked paths/submodules/rule files is the defect.
- **§1 names a real stack** — a specialized agent whose role paragraph could be pasted into any
  project was never specialized: it is the template with a name on it. MISSING ⇒ **defect**
  (`/ow-agent regenerate <name>`). The always-on four are exempt: they are stack-independent
  by design.
- **§5 gates are STOP conditions**, in the shape `<situation> ⇒ STOP` — advice is not a gate.
- §1 and §3–§8 all present?
- §5 has at least 2 gates
- The `Never` section has at least 3 items
- `tools:` in the frontmatter is sensible (and bare `bash`/`sh` NOT granted — agents resolve via the
  injected block, not the resolver)

Report findings in this shape:
```
docs.md          ✓ ok (always-on · §0 present, §2 is a pointer)
verifier.md      ✓ ok (always-on)
backend.md       ✓ ok (created 2026-05-19 · §1 names Express 5 + Prisma)
frontend.md      ✗ §1 names no stack — the template with a name on it, run /ow-agent regenerate frontend
mobile.md        ✗ §2 bakes paths / has <TBD> — regenerate
data-pipeline.md ✗ §0 has no LANG / VAULT_LANG bullet — regenerate
(config)         ✗ subagents.test-runner is enabled with no body — /ow-agent create test-runner
```

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-agent answer with **short, quick-to-read bullets** in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was done** — which agent was created/enabled/disabled/regenerated + the model set
- **Stack the body was written against** (`create`/`regenerate` only) — what §2.1 detected and the user confirmed
- **Files** — `.claude/agents/<name>.md` written/edited + the `.ow.yml` flag
- **Check** — audit result (§0 header, `LANG`/`VAULT_LANG` bullet, §1 names a stack, §2 bakes no paths, gates complete)
- **Next** — enabled-with-no-body names still to create, or suggestions not acted on (if any)

## Never

- Never create an agent whose `tools` grants unrestricted `Bash` — commands must be allowlisted
- Never write the `<!-- obsidian-workflow:agent` signature into an agent this command creates — that marker hands the file to install/upgrade to overwrite, and a created agent belongs to the project
- Never overwrite an existing agent without a backup (.bak-<date>)
- Never create an agent without detecting the stack (§2.1) and reading this project's rules (§2.2) — they shape §1 role + §5 gates; without them the output is the template with a name on it, and STOP is the right answer
- Never write a body for a stack nobody could name — no placeholder agent, ever
- Never bake a resolved path, submodule or rule file into §2 — those come from the §0 injected block (the stack is baked; the resolved values are not)
- Never suggest an agent the project shows no sign of needing (Phase 4 must be grounded in the §4.1 results, and must show them)
- Never let `suggest` write a body or flip a flag — it reports, the user chooses, `create` writes
- Never edit the §2 project context of another agent that is not being regenerated
- Never put a secret/credential in an agent prompt
