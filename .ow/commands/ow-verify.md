---
description: Full verify (tests + vault + security + DS) — does not create a handoff report (use /ow-handoff separately)
---

# /ow-verify — Full Verify

Check every dimension before handing work off — tests, vault, security, design system

> Need a Handoff Report for a reviewer/exec? → `/ow-handoff <plan-or-fix-path>`

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules testing)
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
/ow-verify <plan-or-fix-path>      # check specific work
/ow-verify --since <ref>           # check everything in the diff range
/ow-verify --feature <name>        # check a feature scope
```

## Phase 1 — Scope identification

Read:
- The plan/fix file the user named
- Files changed (`git diff`)
- The vault docs it links to (Feature, Function, PRD)

### 1.1 Rollup mode — the target plan carries `## Phases` (a phased plan — `/ow-plan` Phase 2.5)

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
# the phase table is the status source — read it, never each phase's body; that cost is exactly
# what the phase breakdown existed to avoid
grep -m1 '^status:' "$PLAN_DIR/<plan-basename>.md"            # the plan's own status
sed -n '/^## Phases/,/^### /p' "$PLAN_DIR/<plan-basename>.md" # the table = one status per phase
```

1. Read the `## Phases` table → every row's `status` cell, plus the `## Shared Contract` table when present
2. Any phase not at `status: done` → report which phases are still outstanding and **STOP**: do not verify, and
   🔴 **never flip the plan** to `done`
3. Any `## Shared Contract` row still `state: planned` → same **STOP**: its producer phase never wrote back,
   so at least one consumer was built against an assumed value
4. Every phase done → run Phases 2-6 normally, scoped to the **union of all phases** — with particular
   attention to the integration *between* phases that no single phase verified (does the web phase really
   reach the api phase?)
5. All checks pass → set the plan's `status: done` + `completed_at: YYYY-MM-DD HH:mm`

## Phase 2 — Test verification

Run (or confirm already run):
- Unit tests (relevant scope)
- Integration tests
- Lint
- Build
- Type check

**Never fake** — if it cannot be run, state the blocker + reason

## Phase 3 — Vault-is-text audit

🔴 **HARD GATE: the vault must hold TEXT only — no binaries.** Fail non-zero
on any hit (base64 `data:image/` is also banned; `preview.html` / `audit-<date>.md` are the
only allowed markup):

```bash
if find "$VAULT_ABS" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
  -o -name '*.har' -o -name '*.zip' -o -name '*.trace' -o -name '*.log' -o -name '*.txt' \
  -o -name 'manifest.json' \) | grep -q .; then
  echo "FAIL: binaries found in the vault — the vault holds text only"; exit 1
fi
grep -rIl 'data:image/' "$VAULT_ABS" 2>/dev/null | grep -qv -e 'preview.html' && { echo "FAIL: base64 raster in vault"; exit 1; } || true
echo "OK: vault is text-only"
```

Then audit what the vault records about this work:
- [ ] Every test-plan / fix-log result quotes real output — no number without a run behind it
- [ ] PII masked in anything quoted
- [ ] Route source trace stated
- [ ] Status taxonomy correct (PASS/FAIL/BLOCKED_*/NOT_RUN_RISK)

## Phase 4 — Vault consistency + Spec audit

```bash
# check every [[...]] link in the scope's docs
# check the IMPLEMENTATION-STATUS update
# check for new docs that should be added (function spec of a new feature)
```

If an inconsistency is found → list it for the user → propose `/ow-doc` to fix it

**Spec audit (if the scope has FRs):**
- Is every FR implemented in this scope bound to a task ID?
- Is the terminology consistent with the PRD? (e.g. "member" vs "patron")
- Orphan FR found → flag a warning; does not block but is stated in the output

## Phase 5 — Security pre-flight

Call the /ow-secure logic — check secrets, PII, masking, public-repo, prod guardrails

If the result is BLOCKED → STOP the verify, the user must fix it first

## Phase 6 — Design system audit (if there is frontend/mobile)

If `<vault>/70-Reference/DesignSystem/` exists + the scope touches UI:
- Call the /ow-design audit logic
- Check component compliance, contrast, focus state
- Report violations

## Phase 7 — Summarize the result and the next step

Show the overall result:
- ✅ / ❌ per phase (test, vault, security, DS)
- The items not passing yet (if any) + how to fix them
- Next step: `→ /ow-handoff <path>` to create the Handoff Report for the reviewer

## Output (short bullets, in `$PROJECT_LANG`)

At the end of /ow-verify answer with **short bullets, quick to read**, in the configured language (`$PROJECT_LANG` from Phase 0; `en` → English). Only:

- **Result** — each layer (test · lint · build · security · DS) pass/fail + the command that produced it
- **Open** — the items not passing yet (only if any)
- **Next** — `→ /ow-handoff`

🔴 **Never fake a result** · every result must be parsed from a command actually run · tests failing → STOP and tell the user (never keep verifying).

## Never

- Never verify when the tests are failing — STOP, tell the user
- Never fake a result
- Never create a Handoff Report in this command — use `/ow-handoff` separately
