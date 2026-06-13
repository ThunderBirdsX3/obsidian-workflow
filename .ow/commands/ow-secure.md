---
description: Security pre-flight — scan secrets, PII, screenshot masking, public-repo and prod guardrails
---

# /ow-secure — Security Pre-flight

ตรวจ secrets, PII, public-repo guardrails, screenshot masking ก่อน commit/handoff

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble — identical across all commands. Do NOT edit per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/ow-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)" || {
  echo "FATAL: resolver missing/failed — run /ow-init"; exit 1; }
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules security)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-secure                    # full scan
/ow-secure secrets            # scan secrets only
/ow-secure pii                # scan PII only
/ow-secure evidence           # check evidence masking
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

Report findings → BLOCK commit ถ้าเจอ (ระบุ file:line)

## Phase 2 — PII scan ใน vault docs

```bash
# Thai-specific PII patterns
patterns=(
  "[0-9]{1}-[0-9]{4}-[0-9]{5}-[0-9]{2}-[0-9]{1}"   # Thai citizen ID
  "[0-9]{10}"                                       # 10-digit phone (refine)
  "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}" # Email
  "(HN|VN|AN)[0-9]{6,}"                             # Hospital numbers
)

# Scan the staged evidence (binaries live under EVIDENCE_ROOT — local-only, gitignored) +
# the vault text notes. The vault holds no binaries — scan its *.md link-notes only.
find "$(dirname "$EVIDENCE_ROOT")" -type f \
  \( -name "*.png" -o -name "*.jpg" -o -name "*.log" -o -name "*.txt" -o -name "*.json" \) 2>/dev/null
find "$VAULT_ABS"/{85-FixLog,90-TestPlan,95-Handoff} -type f -name "*.md" 2>/dev/null
```

Report PII findings → BLOCK ถ้าไม่ได้ mask + ไม่มี `pii_masked: true` ใน manifest
> Gate: the mask requirement follows `guardrails.pii_masking_required != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.pii_masking_required // true'` (default true). Secret
> detection is a floor and is never waived regardless of this flag.

## Phase 3 — Screenshot masking check

ตรวจ screenshots under `EVIDENCE_ROOT` (test-artifacts/, gitignored — local-only; binaries are NOT in the vault):
- ทุก image ต้องมี an index row in its folder's `EVIDENCE.md` manifest table
- ถ้า manifest `## Notes` ระบุ PII ยังไม่ mask → flag
- ถ้า `safe_to_share: no` → flag ห้าม push

```bash
ART_ROOT=$(dirname "$(dirname "$EVIDENCE_ROOT")")                        # → test-artifacts
find "$ART_ROOT" -name '*.png' 2>/dev/null                              # screenshots (staged)
# index (text) = the EVIDENCE.md manifest in each evidence folder
for n in $(find "$ART_ROOT" -name 'EVIDENCE.md' 2>/dev/null); do echo "== $n =="; cat "$n"; done
```

## Phase 4 — Public-repo guardrails

ถ้า repo เป็น public (ตรวจจาก `.git/config` remote URL):
- Block ถ้ามี `confidential` หรือ `internal-only` tag ใน vault docs
- Block ถ้ามีชื่อลูกค้า/คู่สัญญาที่ติด NDA
- Block ถ้ามี real customer email/contact

```bash
remote=$(git config --get remote.origin.url 2>/dev/null)
echo "Remote: $remote"

# Check if public (heuristic — adjust ตาม project)
if grep -rlE "tags:.*\b(confidential|internal-only|nda)\b" "$VAULT_ABS"; then
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

ไม่ block แต่ report high/critical vulnerabilities

## Phase 6 — Production-write guardrails

> Gate: active when `guardrails.prod_write_blocked != false` —
> `echo "$GUARDRAILS_JSON" | jq -r '.prod_write_blocked // true'`. When `false`, this phase
> WARNs instead of BLOCKs (default = true / block when the key is absent).

ตรวจ:
- มี `.env.production` ที่ committed?
- มี config file ที่ point ไป prod database?
- มี script ที่ deploy ขึ้น prod โดยไม่มี confirm step?

```bash
git ls-files | grep -E '\.env\.prod|production\.config|deploy-prod' | head -10
```

Report ถ้าเจอ → require explicit user confirm

## Phase 7 — Report + decision

แสดง report:
```
Security pre-flight
===================
✅ Secret scan: clean (5 files scanned)
✅ PII scan: clean (12 docs scanned)
🟡 Screenshot masking: 2 screenshots missing PII flag
   - test-artifacts/2026-05-20/fix-12-search/TC-001-03-results.png
   - test-artifacts/2026-05-20/fix-12-search/TC-002-01-detail.png
✅ Public-repo guardrails: ok
🟡 npm audit: 3 high-severity (express@4.17 — upgrade to 4.19)
✅ Production guardrails: ok

Verdict: REVIEW NEEDED (2 yellow)
```

| Verdict | Action |
|---|---|
| ✅ ALL GREEN | OK to commit/handoff |
| 🟡 REVIEW NEEDED | แก้/justify ก่อน proceed |
| ❌ BLOCKED | ห้าม commit — ต้องแก้ก่อน |

## Output (3 หัวข้อบังคับ)

1. **Result** — verdict (ALL GREEN / REVIEW NEEDED / BLOCKED) + findings count ต่อ scan (secrets, PII, masking, public-repo, deps, prod)
2. **Verification / Evidence** — grep/find/audit commands ที่รันจริง + scan output + รายชื่อไฟล์ที่ scan; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — secret patterns ไม่ครอบคลุม custom secrets, PII regex อาจ false-positive, รายการที่ต้องแก้/mask ก่อน commit

## ห้าม

- ห้ามรัน scan โดย skip files (transparent — list ทุก file ที่ scan)
- ห้าม fix secrets เอง — แจ้ง user ให้ revoke + rotate
- ห้าม commit ถ้า BLOCKED — ต้องผ่าน manual override + log reason
