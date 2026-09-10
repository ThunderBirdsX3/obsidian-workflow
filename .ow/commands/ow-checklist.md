---
description: Generate domain checklist — "unit tests for English" to validate spec quality before implementation
---

# /ow-checklist — Spec Quality Checklist Generator

Generate a checklist that works as **"unit tests for English"** — it tests spec quality, not code behavior.
Each CHK item is a question the author answers themselves: ✅ Yes / ❌ No → every item ✅ before implementing

> **inspired by:** spec-kit `/checklist`

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
/ow-checklist                        # interactive — ask for the domain
/ow-checklist <domain>               # generate a new one
/ow-checklist <domain> --append      # add items to an existing checklist
/ow-checklist review <path>          # check a checklist the user has answered
/ow-checklist list                   # list every checklist in the project
```

## Phase 0 — Detect domain

Default domains:

| Domain | What it checks |
|---|---|
| **ux** | clarity, accessibility, error handling, copy, loading states |
| **api** | versioning, auth, errors, idempotency, rate limit, schema |
| **security** | secrets, PII, threat model, audit log, OWASP top 10 |
| **performance** | latency, throughput, payload size, cache, query N+1 |
| **data** | schema migration, retention, backup, GDPR, integrity |
| **a11y** | WCAG AA, keyboard, screen reader, contrast, focus |
| **observability** | logs, metrics, traces, alerts, dashboards |
| **rollout** | feature flag, rollback, monitoring, canary, comms |
| **<custom>** | user-defined — create your own |

If `$ARGUMENTS` is empty → ask (render in `$PROJECT_LANG`): "Which domain?" (multi-select allowed)

## Phase 1 — Determine scope

Ask (render in `$PROJECT_LANG`):
1. **Target**: which feature / which PRD / project-wide?
2. **Phase**: pre-design / pre-implementation / pre-release?
3. **Append or new file**?

## Phase 2 — Generate items (CHK### format)

Item format + section layout follow `templates/checklist.md` (lookup chain: `templates/` > `.ow/templates/`).

Each item is a **question that tests the spec, not the implementation**

Examples for `ux`:
```markdown
- [ ] CHK001 Does every action button in the spec state "what happens when the user clicks" (not just its label)?
- [ ] CHK002 Does every form field state its validation rule + the error message the user will see?
- [ ] CHK003 Does every state (idle/loading/success/error/empty) have a wireframe or a description?
- [ ] CHK004 Is all copy in the designated language (th/en) + does it pass the tone guideline?
- [ ] CHK005 Does loading > 1 second show a loading indicator + estimated time?
- [ ] CHK006 Does the error message tell the user "what to do next", not just "an error occurred"?
- [ ] CHK007 Does every destructive action (delete/cancel) have a confirmation dialog?
- [ ] CHK008 Does every dialog specify keyboard behavior (Escape, Enter, Tab focus trap)?
- [ ] CHK009 Is the mobile layout specified from width < 640px?
- [ ] CHK010 Does the empty state have a call-to-action that tells the user what to do next?
```

Examples for `api`:
```markdown
- [ ] CHK001 Does every endpoint specify HTTP method + path pattern + auth requirement?
- [ ] CHK002 Does the request schema specify field type + required/optional + max length?
- [ ] CHK003 Does the response schema specify success format + every error code + message structure?
- [ ] CHK004 Idempotency — do POST/PUT specify idempotency-key behavior?
- [ ] CHK005 Is the rate limit specified (per-user / per-IP) + the response when it is exceeded?
- [ ] CHK006 Is pagination specified — format (offset/cursor) + max page size?
- [ ] CHK007 Backward compatibility — does a breaking change specify versioning?
- [ ] CHK008 Does every timestamp specify a timezone (UTC vs local)?
- [ ] CHK009 Do PII fields in the response specify a masking rule?
- [ ] CHK010 Are webhook retry policy + signature verification specified?
```

Examples for `security`:
```markdown
- [ ] CHK001 Does every secret/credential specify its source (env var / secret manager) + stay out of the vault?
- [ ] CHK002 Are PII fields specified + masking rule + retention?
- [ ] CHK003 Does every endpoint that reads data specify an authorization rule (role × resource)?
- [ ] CHK004 Is input validation specified + sanitization for SQL/XSS/SSRF?
- [ ] CHK005 Does the audit log specify what/who/when/where for every mutation?
- [ ] CHK006 Rate limit + brute-force protection for auth endpoints?
- [ ] CHK007 Are CSRF token / SameSite cookie specified?
- [ ] CHK008 Does the dependency CVE scan pass?
- [ ] CHK009 Is there a threat model of at least 1 page?
- [ ] CHK010 Are backup + recovery procedures specified?
```

The examples above are English because this spec is English — the CHK item text that ships in the
checklist file is written in `$VAULT_LANG` (Phase 0); CHK IDs and section headings stay English.

Item count: 10-30 per domain (custom domain → ask the user how many items they want)

## Phase 3 — Write file

Path: `<vault>/95-Handoff/checklists/<domain>-<scope>-<YYYY-MM-DD>.md`

Or append if `--append`

Prose written into the file is in `$VAULT_LANG` (Phase 0); headings and frontmatter stay English.

Frontmatter:
```yaml
---
tags: [type/checklist, domain/<domain>]
date: 2026-05-21
scope: feature:<slug> | project
domain: ux
generated_by: /ow-checklist
items_total: 10
items_passed: 0
items_failed: 0
items_pending: 10
status: in-review                # in-review | passed | blocked
---
```

## Phase 4 — Review mode (`/ow-checklist review`)

Read the checklist after the user has marked `[X]` → summarize (render in `$PROJECT_LANG`):

```markdown
## Review Summary — ux-FEAT-Checkout-2026-05-21

- **Total:** 10
- **Passed [X]:** 7
- **Failed [N]:** 1 — CHK004 "All copy is in the designated language" (user marked failed)
- **Pending [ ]:** 2 — CHK008, CHK010

**Blocking issues:**
- CHK004 → /ow-doc copy-guide or fix the PRD copy section
- CHK008, CHK010 → answer in PR review

**Next:** re-run /ow-checklist review after fixing
```

## Phase 5 — Integration with /ow-verify

`/ow-verify` checks the checklist:
- If a `domain` checklist exists in scope → every item is required to pass (`[X]`)
- If any [ ] or [N] remains → block handoff, emit WARNING

`/ow-implement` checks the checklist:
- If the plan's status == approved but the checklist is `status: in-review` → ask (render in `$PROJECT_LANG`): "Continue while the checklist has not fully passed?"

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-checklist, reply with **short bullets, quick to read**, in the config language (`$PROJECT_LANG` from Phase 0; `en` → English). Include only:

- **What was checked** — domain (ux/api/security/perf) + the scope scanned
- **Checklist** — path created + item count
- **Result** — items still pending = spec-quality risks not yet closed
- **Next** — fix the spec per the items → re-run or `/ow-plan`

🔴 A pending item = a real spec risk — **never** mark it passed while it is unfixed.

## Never

- Never generate an item that tests the implementation (e.g. "POST /api/checkouts returns 201") — a checklist is a spec-quality test only
- Never let a checklist grow > 30 items in a single domain — split it into sub-checklists
- Never mark an item `[X]` on the user's behalf (the user must answer themselves)
- Never edit the source spec during the checklist process — use /ow-doc or /ow-clarify
- Never block /ow-implement automatically — only WARN if the checklist does not pass
