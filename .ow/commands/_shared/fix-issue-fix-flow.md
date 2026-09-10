# `_shared/fix-issue-fix-flow.md` — the fix flow for one issue group (`/ow-fix-issue` Phase 4)

Read this at Phase 4, **whichever way the work runs** (the 4.0/"Decide how to run it" judgment does not change
the flow, only who carries it):

- **Delegating** → this is the prompt body sent to the agent. Substitute every `<placeholder>` from the issue +
  the vault path from config; the PROJECT CONTEXT block is the agent's only context channel (it has no bash tool).
- **Inline** → **you** carry steps 1-14 yourself inside that group's `<WORKTREE_DIR>`. The PROJECT CONTEXT block
  is then your own resolved-values checklist — you resolve those values with bash instead of being handed them,
  and the "no bash tool" line does not apply to you. Every 🔴 below binds identically.

The gates live here, not in the caller: red→green proof · test-first · minimum-fix scope discipline (#29) ·
commit-no-push.

```
You are implementing a fix in an isolated git worktree.

## PROJECT CONTEXT (resolved — authoritative, do NOT rediscover)
- Working tree: <WORKTREE_DIR>   (work ONLY here — never touch code outside it)
- Branch: <BRANCH>   ·   Submodule/repo: <SUBMODULE or main>   (omit if single-repo)
- GitHub issue: https://github.com/<REPO>/issues/<NN>
- VAULT_ABS: <MAIN_ROOT>/<VAULT_PATH>   (fix-log + test-plan TEXT notes only)
- LANG: <$PROJECT_LANG>   ·   VAULT_LANG: <$VAULT_LANG>   (report back in LANG; write vault docs — fix-log, test-plan — in VAULT_LANG)
- RULES(coding) / RULES(testing): <named rule file(s), or "(none) — expected file: …">   (Read each — they OVERRIDE generic agent guidance)
- CONTEXT_REFS: <conditional vault refs relevant to this issue, or "(none)">   (Read each before code — additive to §3 ALWAYS list)
- CONTEXT_SKIPPED: <ref(reason)…, or "(none)">   🔴 Not an order banning you from reading — if the work needs it, read it then report `context gap: <doc> — needed for <reason>`
- ⚠ STOP-RISK line present? A registered rule failed to resolve — surface it, do not proceed as if no rule existed.
- You have no bash tool — this block is your only context channel; if it is absent, STOP (§0).

## What to do (in order)

1. **Read issue** — use the `gh-issue` agent on #<NN> to get full body + image observations. Authoritative bug description.

2. **Diagnose root cause** — work inside `<WORKTREE_DIR>` only. Read code, grep, identify file:line.

3. **Create fix-log** at `<VAULT_PATH>/85-FixLog/<YYYY-MM-DD-HHMM>-<NN>-<slug>.md` using /ow-fix template.
   Prose written into the fix-log is in `VAULT_LANG` (context block); headings and frontmatter stay English.
   Add to frontmatter:
   ```yaml
   github_issue: https://github.com/<REPO>/issues/<NN>
   worktree: <WORKTREE_DIR>
   branch: <BRANCH>
   status: in-progress
   ```

4. **Write test FIRST** (🔴 read `.ow/commands/_shared/coding-discipline.md` §3 — a reproducing test must FAIL before the fix):
   - Locate test dir for the stack (web: src/__tests__/, api: *.Tests/, app: test/)
   - Add a test that reproduces the bug → must FAIL before fix
   - Keep the failing output — it is quoted verbatim (trimmed) in the fix-log `## RED baseline`

5. **Record the RED state** — the failing test output above, plus for a UI bug the wrong state actually
   observed on screen (what is shown vs what should be). Text only; nothing is stored as a file.

6. **Apply minimum correct fix** — 🔴 read `.ow/commands/_shared/coding-discipline.md` §2 and follow it:
   smallest change that satisfies Success Criteria, every changed line traceable, no speculative addition,
   no unrelated refactor/format churn, and out-of-scope churn reverted only by surgical **Edit** (never
   `git checkout`/`restore`/`stash`/`clean` — #29). That file is authoritative; this step adds no rule of its own.
   - 🔴 Worktree-specific: the same rules apply **inside `<WORKTREE_DIR>`** — a destructive git command there
     deletes the agent's own uncommitted work, not just a parallel task's

7. **Re-run test** — must PASS now. Keep the passing output for the fix-log.

8. **Record the GREEN state** (UI bug) — 🔴 **mandatory if step 5 recorded a wrong on-screen state** — re-check the
   **same screen/route** on the fixed build and describe what is shown now, so before/after are comparable
   - ❌ Never describe the fixed state from the issue text or from expectation — it must come from the fixed build only (no fake results)
   - Only one case may skip: step 5 was non-UI → note "non-UI, after = passing test output"
   - 🔴 **Pairing invariant:** a RED on-screen state recorded ⇒ the GREEN one MUST be too — a before with no after = incomplete (step 13 fail)

9. **Regression check (scoped)** — run tests only for the role/area related to the issue; never test every role.
   Document the scope in the fix-log `## Regression check` (roles/areas tested + why the rest were skipped)

10. **Create TestPlan vault file** at `<VAULT_PATH>/90-TestPlan/<YYYY-MM-DD-HHMM>-<NN>-<slug>.md` (flat — no `<slug>/` folder):
    frontmatter (tags: [type/test-plan], links → fix-log + github_issue) + Scope + Test Cases (TC-01..) layer/role/steps/expected/actual.
    Prose written into the file is in `VAULT_LANG` (context block); headings, frontmatter and IDs stay English.
    🔴 **TestPlan holds TEXT only** — no binaries, ever. Quote real output, trimmed to the relevant lines.
    Link back from fix-log: add `test_plan:` field.

11. **Update fix-log:** tick `## ✅ Verification` (except Push — user's step), set `status: fixed`, fill AI Usage, add test_plan field.

12. **Commit in worktree (NO PUSH):**
    ```bash
    cd <WORKTREE_DIR>
    git add -A
    git commit -m "fix(<scope>): <one-line> (#<NN>)

    Closes #<NN>

    Co-Authored-By: <AI signature per project convention>"
    ```
    🔴 DO NOT push — obsidian-workflow no-auto-git rule. STOP after commit.

13. **Verification record** in the fix-log — nothing here may be missing:
    - RED baseline (Step 4/5) — the failing test output, verbatim + trimmed, and the wrong on-screen state for a UI bug
    - GREEN result (Step 7/8) — the passing test output, and the fixed on-screen state for a UI bug
    - Build result — build command + EXIT, quoted from the real run
    - Regression check (Step 9) — roles/areas tested + why the rest were skipped
    - Success criteria → check map — which check proves which criterion
    🔴 **before/after pairing:** a RED record ⇒ there must always be a matching GREEN one — a before alone is
    incomplete, and the agent must loop back through step 8 before returning

14. **Vault sync** — only if fix changed documented behavior (UI label, API contract, permission, master-data). Otherwise skip per /ow-fix Rule 5. Prose written into vault docs is in `VAULT_LANG`; headings and frontmatter stay English.

## What you MUST NOT do
- ❌ DO NOT push to remote
- ❌ DO NOT change label on GitHub issue (orchestrator does that)
- ❌ DO NOT comment on / close the GitHub issue
- ❌ DO NOT modify files outside <WORKTREE_DIR> except the vault
- ❌ DO NOT touch other worktrees (parallel agents working)
- ❌ DO NOT skip test creation — required per `_shared/coding-discipline.md` §3 (RED before the fix)

## Output
Return structured summary (in LANG):
- ✅/❌ per step 1-13
- Commit hash, files changed (paths within worktree)
- Test result (before fail → after pass)
- Vault files synced
- Any blockers (if blocked: leave fix-log status: in-progress, do NOT commit broken state)
```
