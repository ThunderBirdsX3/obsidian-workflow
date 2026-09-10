# `_shared/context-refs.md` — CONTEXT_REFS (conditional vault reads)

> **Single source of truth** for the include-when table below. Every command that selects a
> conditional vault read **cites this file** — whether for a spawned subagent (`/ow-implement`,
> `/ow-fix-issue`) or for its own budgeted read set (`/ow-plan` Phase 1) — never copy the table
> into its own file (a duplicated table = silent drift)

## Why

A spawned subagent **does not share context with the orchestrator** → every doc it reads = a
**cold cache write (~1.25× base)**. An unconditional "read every ref before working" list therefore
multiplies the most expensive token class on every spawn. The orchestrator already holds these docs
at cache-read price (~90% cheaper) → let it be the one that decides which doc is load-bearing for
this task

**Vault-first stays fully intact** — the rule is "read the refs relevant to the task", not "read
every ref"

## Contract — 3 states

| `CONTEXT_REFS` in the §0 block | the agent must |
|---|---|
| lists files | read only those files (in addition to the ALWAYS list in §3) |
| `(none)` | no conditional ref is relevant — read the ALWAYS list only |
| **line absent entirely** | 🔴 read **all** conditionals — fail-safe is to read everything, not to skip |

## 🔴 `CONTEXT_SKIPPED` is not a ban on reading

The orchestrator merely judged it irrelevant. If, while working, the agent finds a doc is
**genuinely needed** → **read it immediately**, but it **must** report the line:

```
context gap: <doc> — needed for <reason>
```

- Never read silently (the criteria stay wrong round after round and nobody knows)
- Never guess the content instead of reading it

⇒ **worst case = the full-read behaviour + 1 reported line** — a constraint can never go missing
silently. The orchestrator keeps every `context gap:` line in its output so the table below can be
fixed next round

## include-when table (canonical)

**Uncertain ⇒ include.** Skipping is the only move that loses information — when unsure, include it

| Conditional ref | include when the task… |
|---|---|
| `REF-APIIntegration.md` | adds/changes an endpoint, route, controller or schema (REST/GraphQL/OpenAPI) |
| `REF-AuthorizationMatrix.md` | touches auth, role, permission, scope, token or session |
| `REF-TechStack.md` | adds/upgrades a dependency or picks a lib/framework/version |
| `FLOW-*.md` | orchestrates across services/submodules or changes a multi-step user flow |
| `30-Roles/<platform>/<role>/` | adds/moves a screen — menu placement + IA |
| `IMPLEMENTATION-STATUS.md` | **never** — it is a file that is **written** at the end of the work; reading it before coding gains nothing |

**Not in this table = ALWAYS** — the plan file, the FN/FEAT the plan names, existing code+test to
mirror, and the DS docs of an agent whose core mandate is the design system (`frontend` / `mobile` /
`design`). These are never skipped

## Classification while no diagnosis exists yet

`/ow-fix-issue` builds the context block **before** the agent diagnoses — the issue body is the only
information available. Classify from the issue text as far as it goes, then let the escalation rule
catch the rest (uncertain ⇒ include). Never delay the spawn to wait for a diagnosis
