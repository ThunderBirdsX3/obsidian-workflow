# `_shared/delegation.md` — delegated mode (subagent execution)

Read this **only when the 3.0 judgment lands on delegation**. Running inline ⇒ none of it applies:
the context here is already yours, and 🔴 **an inline run never chunks** (you can compact and you can see
your own context — the whole chunk machinery exists because a subagent can do neither).

A spawned agent **shares no context with the orchestrator** and has **no bash tool** ⇒ the injected blocks
below are its only context channel (#12).

## 1. Resolve CONTEXT_REFS

🔴 Read `.ow/commands/_shared/context-refs.md` — it holds the **canonical include-when table**, the 3-state
contract, and the escalation rule. Do NOT restate the table here or in the verb spec (a second copy drifts
silently).

Read the plan, classify each conditional ref against that table (**uncertain ⇒ include**), and set
`CONTEXT_REFS` / `CONTEXT_SKIPPED` for the block in §3. `CONTEXT_REFS` is *additive* to the ALWAYS list in
each agent's §3 — the plan file, the FN/FEAT docs the plan names, existing code+tests, and DS docs for UI
agents are never skippable.

🔴 The plan carries `context_closed: true` (a `/ow-split` sub-plan) → do not classify anything: set
`CONTEXT_REFS` to its `context_refs:` list verbatim and `CONTEXT_SKIPPED=(closed by /ow-split)`. The split
already resolved the read set and measured it against the agent's context budget; re-resolving would grow it
back to the very size the split existed to bound. The `context gap:` escape hatch below is unchanged.

Collect any `context gap:` line the agent reports into the Phase 7 output, so the table can be corrected.

## 2. Partition the plan → chunks

The only way to bound the context an agent accumulates across a long job is to **split the work into several
rounds**: each round the agent starts with fresh context and passes on via a handoff.

**A chunk boundary is correct only when all 3 hold:**
1. The code at that point builds/compiles
2. The tests for the area touched can run — no half-written test referencing a symbol that does not exist yet
3. No step of the next chunk is one this chunk depends on to make its own success criteria true

**Algorithm:** walk `Implementation Steps` in order, close a chunk at the last step that satisfies all 3.

**Size — target 3–6 steps/chunk** (splitting finer pays the cold-cache write again and again for no gain):
- plan ≤6 steps → **1 chunk, emit no CHUNK block** (single-spawn)
- a correct boundary makes a chunk >6 steps → allow it to be large · **never cut at a non-verifiable point**
- no legal boundary found at all → 1 chunk + log the reason in the Phase 7 output
- no `Implementation Steps` (`--from-fix` mode — fix-log P2/P3) → 1 chunk, emit no CHUNK block

**Never cut through the middle of:** a refactor spread across many files · a migration together with the code
that uses the new schema · a test paired with the same production change

🔴 **1 chunk = 1 agent, always** — `subagent_target: all` (sequence backend→frontend→mobile→docs) → partition
**separately per agent**; a chunk boundary must never straddle agents
🔴 Every chunk's `STEPS:` is a **contiguous range** (`4-6`), not a jumped list (`4,6,9`) — a non-contiguous
range means the cut point is not a verifiable state
🔴 One plan on one tree is **sequential work** ⇒ one agent at a time, never a fan-out

## 3. Assemble the PROJECT CONTEXT block

```bash
RES="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
AREA="$subagent_target"                                   # backend|frontend|mobile|design|docs
SUBS=$(bash "$RES" --submodules | cut -f1 | paste -sd' ' -)
RULES=$(bash "$RES" --rules "$AREA" | paste -sd' ' -)
RULES_EXP=$(bash "$RES" --rules-expected "$AREA" | cut -f1)   # canonical file, named even when absent (#22)
{
  echo "=== PROJECT CONTEXT (resolved — authoritative, do NOT rediscover) ==="
  echo "PROJECT=$PROJECT_NAME  LANG=$PROJECT_LANG  VAULT_LANG=$VAULT_LANG  PREFIX=$COMMAND_PREFIX"
  # LANG = reports back to the user · VAULT_LANG = documents written under VAULT_ABS
  echo "VAULT_ABS=$VAULT_ABS"
  echo "PLAN_DIR=$PLAN_DIR  FIX_DIR=$FIX_DIR  TEST_DIR=$TEST_DIR  FN_DIR=$FN_DIR  REF_DIR=$REF_DIR"
  [ -n "$SUBS" ]  && echo "SUBMODULES: $SUBS"             # omitted entirely on single-repo (single-repo = default, not an error)
  echo "GUARDRAILS=$GUARDRAILS_JSON"
  # RULES line is ALWAYS emitted — names the specific file so a missing rule cannot vanish silently (#22)
  if [ -n "$RULES" ]; then
    echo "RULES($AREA): $RULES   # Read each — they OVERRIDE the generic agent guidance"
  else
    echo "RULES($AREA): (none resolved) — expected file: $RULES_EXP (create it to add project $AREA conventions)"
  fi
  # Fail loud: a rule REGISTERED in .ow.yml rules.files that fails to resolve is a STOP-RISK,
  # never a silent skip — the agent must surface it, not proceed as if no rule existed.
  bash "$RES" --rules-validate >/dev/null 2>&1 || \
    echo "⚠ STOP-RISK: a rule registered in .ow.yml rules.files did not resolve — run: bash \"$RES\" --rules-validate"
  # Conditional vault refs resolved in §1. BOTH lines are ALWAYS emitted — an absent
  # CONTEXT_REFS line means "spawned outside /ow-implement" and the agent then reads every
  # conditional ref (fail-safe = read all). Empty value ⇒ emit the word (none), never omit.
  echo "CONTEXT_REFS: ${CONTEXT_REFS:-(none)}          # read each before code — additive to §3 ALWAYS list"
  echo "CONTEXT_SKIPPED: ${CONTEXT_SKIPPED:-(none)}    # judged not-applicable — NOT a read ban; read + report 'context gap:' if needed"
  echo "=== END CONTEXT ==="
}
```

Worktree mode → append the WORKTREE block from `_shared/worktree.md` §3 right after this one.

## 4. CHUNK block — emit only when §2 split into >1 chunk

Appended to the PROJECT CONTEXT (+ WORKTREE) block — same channel, no extra one.
**1 chunk → emit nothing** ⇒ the agent does the whole plan (same fail-safe as the `CONTEXT_REFS` 3-state)

🔴 **This block is the real contract** — `.claude/agents/{backend,frontend,mobile,design}.md` are written by
`/ow-agent create` against this project and install/upgrade **must not overwrite** them
(`ow-claude-manifest.sh` refreshes only the always-on four) ⇒ an agent written before this contract
existed, or not yet regenerated, must work correctly from this block alone. The RETURN PROTOCOL therefore
lives **inside the block** — never moved out to depend on the agent file

```
=== CHUNK 2/4 (authoritative — your scope) ===
STEPS: 4-6                    # do only these — never spill into step 7+
EXIT_STATE: `pnpm test src/api/__tests__/checkout.test.ts` passes + `tsc --noEmit` clean
READ_FULL: <PLAN_DIR>/2026-07-21-1430-checkout.md    # the full plan — read every chunk
READ_NAMED:                   # besides the plan, read only these — a doc already summarized in DIGEST need not be re-read
  - <FN_DIR>/API/checkout/FN-API-Checkout-Submit.md   # not yet digested
  - src/api/cart.ts                                   # code to mirror
=== HANDOFF (chunk 1) ===
DONE: steps 1-3 — CartService.reserve() + unit test, 3 cases
FILES: src/api/cart.ts (+82) · src/api/__tests__/cart.test.ts (+61)
DIGEST: FN-API-Cart-Reserve.md → AC-3 reserve must be idempotent · AC-5 insufficient stock → 409
DECISIONS: idempotency key read from the header, not the body (FN §4.2)
DEVIATIONS: (none)
OPEN: stock lock not done yet → step 7
CONTEXT_GAPS: (none)
=== RETURN PROTOCOL (mandatory — the tail of your output) ===
STATUS: DONE | CONTINUE | BLOCKED
  DONE     = all STEPS done + EXIT_STATE run and passing (paste the real command output — never claim it blind)
  CONTINUE = reached a verifiable state before all STEPS done (the work was larger than estimated) — name the steps actually done
  BLOCKED  = could not reach a verifiable state — state why · never guess, never keep hacking
then follow with your own HANDOFF — exactly the same shape as the HANDOFF above: 7 fields, one field per line,
in order DONE / FILES / DIGEST / DECISIONS / DEVIATIONS / OPEN / CONTEXT_GAPS
every line always present, empty value written (none) — never merge lines, never drop a line
=== END CHUNK ===
```

- `CHUNK n/N` — `N` = the number of chunks §2 laid out. A chunk born from `CONTINUE` uses a **letter suffix**
  (`2a/4`, `2b/4`) — never renumber the originals (a Chunk Progress already written would reference the wrong ones)
- **chunk 1** has no HANDOFF · `READ_NAMED` = the full ALWAYS list (the FN/FEAT the plan names + existing
  code/test + `CONTEXT_REFS`) → the first chunk always reads the real sources in full
- **DIGEST accumulates** — chunk 3 gets the digest of chunks 1+2 (the orchestrator holds it in its own context,
  writes no file)

**Guard against a warped summary:**
- every DIGEST line names its **source file** → the agent can open the real thing instantly if in doubt
- copy acceptance criteria **verbatim** — the orchestrator must not paraphrase
- the agent finds the digest insufficient → it may read the real file, then report
  `context gap: <doc> — needed for <reason>` (the mechanism in `.ow/commands/_shared/context-refs.md`)

## 5. The prompt sent to the agent

```
<PROJECT CONTEXT block — §3>
<WORKTREE block — worktree.md §3, worktree mode only>
<CHUNK block — §4, only when >1 chunk>

Plan file: <path>
Task: <task field from frontmatter>

Instructions:
<items 1-11 of "Implementation rules" in ow-implement.md Phase 3.1 — paste verbatim>
12. **Worktree mode only** — change the code in the worktree and **leave it uncommitted** — the orchestrator
    audits (5.2/5.3) then commits it itself at Phase 6.4 · 🔴 you must not commit / push / merge yourself
13. **CHUNK block present** → close the output with the RETURN PROTOCOL the block names:
    `STATUS: DONE|CONTINUE|BLOCKED` + HANDOFF every field (empty value = `(none)`) · `DONE` must paste the
    real output of `EXIT_STATE`
    🔴 **No CHUNK block → do the whole plan as normal** (fail-safe) — no need to return a STATUS
```

## 6. Chunk loop

The next chunk spawns **only after the previous one closes** (never parallel — continuous work on the same tree):

1. Spawn the agent with the blocks + prompt above
2. The agent returns `STATUS:` + HANDOFF
3. 🔴 **The orchestrator runs `EXIT_STATE` itself** — it does not trust the agent's claim (no fake results).
   It fails → treat as `BLOCKED`
4. Write `## Chunk Progress` into the plan **before** spawning the next one
5. Absorb the HANDOFF into the orchestrator's context → use it to build the next round's CHUNK block
6. All steps done → Phase 4

| STATUS | orchestrator does |
|---|---|
| `DONE` | verify EXIT_STATE → write progress → next chunk |
| `CONTINUE` | verify → write progress **for only what was actually done** → spawn a new one (suffix `2a/4`) to pick up `OPEN` |
| `BLOCKED` | **stop at once, ask a human** · never auto-retry · never rollback (leave the code in place for someone to inspect) |

**Guard against an endless loop:**
- a `CONTINUE` that actually did **0 steps** → treat as `BLOCKED` (no progress)
- total spawns exceed `max(2 × N, N + 3)` (`N` = the chunks §2 laid out) → stop, ask a human
- wrong partition (chunk 2 needs something chunk 1 did not do) → the agent returns `BLOCKED` + reason → the
  orchestrator re-partitions the remaining steps **once** → still broken = ask a human
- a `context gap:` the agent reports → collect it into the Phase 7 output **and** add that doc to the
  `READ_NAMED` of the remaining chunks

**`## Chunk Progress` — resume marker** (written the moment a chunk returns `DONE`/`CONTINUE`):
```markdown
## Chunk Progress (written by /ow-implement — resume marker)
- [x] chunk 1/4 · steps 1-3 · 2026-07-21 14:20 · exit: `pnpm test src/api/cart` passes
- [x] chunk 2/4 · steps 4-6 · 2026-07-21 14:48 · exit: `tsc --noEmit` clean
```
🔴 Write `- [x]` **only**, never `- [ ]` → the Phase 6.0 gate (`grep -c "- [ ]"` must = 0) is unaffected
🔴 Always write to the plan in `$VAULT_ABS` (MAIN_ROOT) — worktree mode must never write `docs/` inside the worktree
🔴 Chunks do not commit — worktree mode commits once at Phase 6.4; scope isolation (rule 5) is enforced per chunk
