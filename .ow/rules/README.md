# Project rules layer (`.ow/rules/`)

Record **this project's own** coding / frontend / backend / mobile / testing / security /
design conventions here. A rule resolved for an area **overrides** the generic guidance
baked into the command and agent specs for that area — so project facts never have to be
hardcoded into core (which would be lost on upgrade).

> Core ships only this scaffold. **No project-specific rule content lives in core.**
> Put yours here, git-tracked: `.ow/rules/<area>.md`.

## Format

Markdown with an `applies_to` front-matter list (or `'*'` for every area). The body is
**your** project's convention — keep concrete conventions here, never in core:

```markdown
---
applies_to: [backend, security]
---
# <area> conventions for THIS project

- <your project's rule here> — it overrides the generic guidance the agent/command
  would otherwise apply for this area.
```

## Area taxonomy

Areas are derived at runtime from the **enabled subagents** (`ow-paths.sh --subagents`)
plus any configured areas — a flat set: `coding`, `frontend`, `backend`, `mobile`,
`testing`, `security`, `design`. Disabling a subagent drops its area.

### Area → filename (each area maps to exactly one canonical file)

The canonical rule file for an area is always `<area>.md` under this directory. `ow-init`
scaffolds a stub for each **enabled** area (idempotent — never overwrites yours):

| Enabled subagent | Area | Canonical file |
|---|---|---|
| `backend` | backend | `.ow/rules/backend.md` |
| `frontend` | frontend | `.ow/rules/frontend.md` |
| `mobile` | mobile | `.ow/rules/mobile.md` |
| `design` | design | `.ow/rules/design.md` |
| `security` | security | `.ow/rules/security.md` |
| `docs` | docs | `.ow/rules/docs.md` |
| `test-runner` | testing | `.ow/rules/testing.md` |

`verifier` and `gh-issue` are not rule areas. Print the resolved/expected path for any area
(even when the file is absent) with `ow-paths.sh --rules-expected <area>`.

> **Registered rules must resolve.** Any file listed in `.ow.yml` `rules.files` MUST
> exist — `ow-paths.sh --rules-validate` (and `--selftest`) fail loud on a registered
> rule that does not resolve, so a load-bearing convention can never be silently dropped.

## How it is consumed

```bash
# every command Phase 0 + every spawned agent reads the resolved rules for its area:
bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules backend
```

- Commands `Read` each printed file in their Phase 0 Load-Context step.
- Spawned subagents receive the resolved rule paths in their injected PROJECT CONTEXT
  block (agents have no bash tool — the injection is their only channel).

With the `rules` registry empty in `.ow.yml`, the resolver globs
`.ow/rules/*.md` and binds each file by its `applies_to`.
