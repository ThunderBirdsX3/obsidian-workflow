---
description: Security pre-flight — scan secrets, PII, screenshot masking, public-repo and prod guardrails
---

# ow-secure — Security Pre-flight

Check secrets, PII, public-repo guardrails, and screenshot masking before commit/handoff

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules security)
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
/ow-secure                    # full scan
/ow-secure secrets            # scan secrets only
/ow-secure pii                # scan PII only
/ow-secure --since <ref>      # scan diff since ref
```

## Phase 1 — Secret scan

```bash
# Common secret patterns (extend as needed)
patterns=(
  "AKIA[0-9A-Z]{16}"                           # AWS access key
  "-----BEGIN [A-Z ]+ PRIVATE KEY-----"        # RSA/EC private keys
  "ghp_[A-Za-z0-9]{36,}"                       # GitHub PAT
  "ghs_[A-Za-z0-9]{36,}"                       # GitHub server token
  "sk-[A-Za-z0-9]{32,}"                        # Generic API key (Anthropic/OpenAI)
  "xox[bpoa]-[0-9a-zA-Z-]{10,}"                # Slack token
  "AIza[0-9A-Za-z-_]{35}"                      # Google API key
  "[A-Za-z0-9_]*(password|secret|api_key|token)[A-Za-z0-9_]*\\s*=\\s*['\"][^'\"]{8,}['\"]"
)

# Scan changed files (since ref or staged)
target_files=$(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)

for f in $target_files; do
  for p in "${patterns[@]}"; do
    grep -HnE "$p" "$f" 2>/dev/null
  done
done
```

Report findings → BLOCK the commit if any are found (name `file:line`)

## Phase 2 — PII scan in docs/

```bash
# Thai-specific PII patterns
patterns=(
  "[0-9]{1}-[0-9]{4}-[0-9]{5}-[0-9]{2}-[0-9]{1}"   # Thai citizen ID
  "[0-9]{10}"                                       # 10-digit phone (refine)
  "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}" # Email
  "(HN|VN|AN)[0-9]{6,}"                             # Hospital numbers
)

# The vault holds text only — scan its *.md notes (fix-logs, test-plans, handoffs quote
# real command output, which is where PII leaks in).
find "$VAULT_ABS"/{85-FixLog,90-TestPlan,95-Handoff} -type f -name "*.md" 2>/dev/null
```

Report PII findings → BLOCK if it is not masked
> Gate (#13): the mask requirement follows `guardrails.pii_masking_required != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.pii_masking_required // true'` (default true). Secret
> detection is a floor and is never waived regardless of this flag.

## Phase 2.5 — Vault language gate (#33)

`project.vault_language` is advisory-only in prose — an agent can read `$VAULT_LANG`
and still default to `$PROJECT_LANG` when writing. This is the mechanical check, so
it doesn't rely on the writing agent remembering to self-police. Scope: only
new/modified vault files (diff since HEAD + untracked) — never pre-existing content.

```bash
bash "$(git rev-parse --show-toplevel)/scripts/ow-verify-vault-lang.sh"
```

Report findings → BLOCK if it exits non-zero (name `file:line`, the offending script,
and `$VAULT_LANG` it should have been written in instead)

## Phase 2.6 — Vault present-tense gate

A vault doc states the project as it is now; the before/after of a change lives in the plan,
fix-log, test-plan or handoff of the run that made it. Same reason as 2.5: the rule is advisory
in prose until a script reads it. Scope: new/modified vault files outside those four folders.

```bash
bash "$(git rev-parse --show-toplevel)/scripts/ow-verify-vault-style.sh"
```

Report findings → BLOCK if it exits non-zero (name `file:line` and the sentence rewritten as
present tense). Contract: `.ow/commands/_shared/vault-doc-style.md`

## Phase 3 — Quoted-output masking check

Vault docs quote real command output — that is where an unmasked value reaches git:

```bash
# fenced blocks + inline quotes in the docs this work touched
grep -rn -A2 '```' "$VAULT_ABS"/{85-FixLog,90-TestPlan,95-Handoff} 2>/dev/null
```

- a quoted line carrying a secret/PII pattern from Phase 1/2 → flag, never push
- a doc that states a result with no command behind it → flag (unverifiable claim)

## Phase 4 — Public-repo guardrails

If the repo is public (check the `.git/config` remote URL):
- Block if there is a `confidential` or `internal-only` tag in the vault docs
- Block if there is `OW-internal` or a customer name under NDA
- Block if there is a real customer email/contact

```bash
remote=$(git config --get remote.origin.url 2>/dev/null)
echo "Remote: $remote"

# Check if public (heuristic — adjust for org)
if grep -lE "tags:.*\b(confidential|internal-only|nda)\b" docs/ -r; then
  echo "BLOCK: confidential content"
fi
```

## Phase 5 — Dependency vulnerability quick-check

```bash
# Quick scan (does not replace full SCA tool)
test -f package-lock.json && npm audit --audit-level=high 2>/dev/null | head -30
test -f requirements.txt && pip list --outdated 2>/dev/null | head -20
test -f Cargo.lock && cargo audit 2>/dev/null
```

Does not block, but reports high/critical vulnerabilities

## Phase 6 — Production-write guardrails

> Gate (#13): active when `guardrails.prod_write_blocked != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.prod_write_blocked // true'`. When `false`, this phase
> WARNs instead of BLOCKs (default = true / block when the key is absent).

Check:
- is there a committed `.env.production`?
- is there a config file pointing at a prod database?
- is there a script that deploys to prod with no confirm step?

```bash
git ls-files | grep -E '\.env\.prod|production\.config|deploy-prod' | head -10
```

Report if found → require an explicit user confirm

## Phase 7 — Report + decision

Show the report:
```
Security pre-flight
===================
✅ Secret scan: clean (5 files scanned)
✅ PII scan: clean (12 docs scanned)
✅ Vault language gate: clean (2 new/modified vault files, VAULT_LANG=en)
✅ Vault present-tense gate: clean (2 new/modified vault files scanned)
🟡 Quoted output: 2 unmasked values in quoted logs
   - 85-FixLog/2026-05-20-1430-search-returns-empty.md:41
   - 90-TestPlan/2026-05-20-1500-search.md:88
✅ Public-repo guardrails: ok
🟡 npm audit: 3 high-severity (express@4.17 — upgrade to 4.19)
✅ Production guardrails: ok

Verdict: REVIEW NEEDED (2 yellow)
```

| Verdict | Action |
|---|---|
| ✅ ALL GREEN | OK to commit/handoff |
| 🟡 REVIEW NEEDED | fix/justify before proceeding |
| ❌ BLOCKED | Never commit — must fix first |

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-secure answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **What was scanned** — scope (staged/changed/full) + verdict (PASS/REVIEW/BLOCKED)
- **Findings** — the real counts (secrets/PII/CVE/vault-language/vault present-tense) + scan output
- **Risks / next** — the secret patterns do not cover custom ones, the PII regex may false-positive; BLOCKED → fix before committing

🔴 the verdict must come from a real scan — **never claim** PASS without running it.

## Never

- Never run the scan while skipping files (transparent — list every file scanned)
- Never fix secrets yourself — tell the user to revoke + rotate
- Never commit when BLOCKED — requires a manual override + a logged reason
