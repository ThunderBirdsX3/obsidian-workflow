# `_shared/worker-cli.md` — external CLI worker backend (`--codex` · `--claude`)

Read this **only when `/ow-implement` runs with `--codex` or `--claude`** (`WORKER=codex|claude`, resolved in
Phase 2.7.1). No flag ⇒ nothing here applies — delegation, if chosen, uses the native Agent tool exactly as
`_shared/delegation.md` describes.

This fragment changes **one thing**: *who* executes a chunk. The contract around the chunk — CONTEXT_REFS,
partition, PROJECT CONTEXT / WORKTREE / CHUNK blocks, RETURN PROTOCOL, the chunk loop, `## Chunk Progress` —
is `_shared/delegation.md`, read in full first. Nothing below restates it.

## 0. Host check + preflight (before any plan read)

- `--codex` on a Codex host, or `--claude` on a Claude host ⇒ 🔴 **STOP**: "same host — this flag dispatches to the
  *other* CLI; drop it to run natively". Both flags at once ⇒ STOP.
- Then: `bash "$(git rev-parse --show-toplevel)/scripts/ow-worker.sh" $WORKER --preflight` — exit ≠ 0 ⇒ 🔴 **STOP**
  with its message (CLI missing / not logged in). Never fall back to the native agent or inline silently: the user
  asked for that provider's quota.
- Record the printed `<backend> <version>` for the Phase 7 output.

## 1. Mode: external worker forces delegated mode

3.0's inline/delegate judgment is replaced: the work **is delegated**, to the external CLI. `.claude/agents/<area>.md`
may be absent — that is fine; the worker reads the area rules from the `RULES(<area>)` line of the PROJECT CONTEXT
block (it has a shell and can open those files). Everything else in 3.0 (area gates, rules, 3.1 rules) still applies.

## 2. The prompt file

Write one file per chunk: `$RUN_DIR/<TAG>.prompt.md` where `RUN_DIR="$MAIN_ROOT/.ow/local/runs/$(basename "$PLAN_PATH" .md)"`
and `TAG="<phase-id or P0>-chunk<n>"` (fix chunk: `…-fix<n>`). Contents, in order:

1. PROJECT CONTEXT block — `delegation.md` §3, verbatim
2. WORKTREE block — `worktree.md` §3, worktree mode only
3. CHUNK block — `delegation.md` §4. 🔴 **Always emitted, even when §2 laid out a single chunk** (`CHUNK 1/1`):
   the external worker has no agent file carrying the RETURN PROTOCOL, and `ow-worker.sh` locates the result by
   the `STATUS:` line that protocol mandates
4. `Plan file:` / `Task:` lines + Instructions 1–11 of `ow-implement.md` 3.1 verbatim + items 12–13 from
   `delegation.md` §5, then rule 14:

```
14. You are an external worker (no MCP, no host agents, no vault access by contract). Change **code files under the
    Working tree only** — never edit `docs/`, the vault, or the plan file; never `git commit` / `merge` / `push`.
    Project rules are the files named on the RULES line above — open and follow them. The orchestrator writes
    the vault and runs the final checks.
```

Codex reads `AGENTS.md` and Claude reads `CLAUDE.md` on their own — do not paste either into the prompt.

## 3. Spawn

```bash
bash "$MAIN_ROOT/scripts/ow-worker.sh" "$WORKER" "$WORK_ROOT" "$RUN_DIR" "$TAG" "$RUN_DIR/$TAG.prompt.md"
```
🔴 Run it **in the background** — Claude Code: the Bash tool with `run_in_background: true`, then read its stdout when
the completion notice arrives; Codex: a shell call whose timeout is longer than `worker_timeout_min`. A chunk easily
outlives the host's foreground tool timeout (2–10 min), and a call cut off by that timeout returns no `STATUS:` line.
The script's own watchdog (`worker_timeout_min`; `0` = no timeout, a hung worker then runs until the user stops it) is the only timeout; never start another chunk or `EXIT_STATE` while
one is still running (killing the script kills its CLI tree too).
instead of the Agent tool. Its stdout is **exactly** `STATUS:` + the 7 HANDOFF lines (a `BLOCKED` it raised itself —
timeout, non-zero exit, no `STATUS:` line — adds one `REASON:` line after `STATUS:`) — treat it as the agent's
return (`delegation.md` §6 step 2). Exit 2/3/4 ⇒ STOP with the script's stderr line (preflight / usage / secret-like
token in the prompt — fix the prompt source, never strip and retry blindly).

🔴 The orchestrator **runs `EXIT_STATE` itself** after every return (`delegation.md` §6 step 3) — a `STATUS: DONE`
from the worker, like a process exit 0, is a report, not proof.
`claude -p --permission-mode acceptEdits` edits files but denies shell commands, so a Claude worker usually
returns `DEVIATIONS: EXIT_STATE not verified` — expected; your own `EXIT_STATE` run is the check. Never widen its
permissions to let it run the command.

🔴 Context hygiene: the raw events / stdout / stderr live in `$RUN_DIR`. **Never `cat` the events or stderr file
into your context** — if a `BLOCKED` needs diagnosis, `tail -40 "$RUN_DIR/$TAG.stderr"` is the ceiling.

### 3.1 Quota exhausted — fall back to the host, retry the worker next chunk

`REASON: quota-exhausted` (either backend — Codex on a Claude host, Claude on a Codex host — is out of credits / at its usage limit) is **not** a failed chunk. Under `--auto`
(`AUTO_MODE=on`):

1. Run the **same chunk** on the host instead — inline or native agent per `ow-implement.md` 3.0 — same prompt, same
   `EXIT_STATE`. It does not count as a re-partition, a fix attempt or a `timeout`/`blocked` strike.
   The worker may have edited files before it stopped: the host starts from the tree as it is and `EXIT_STATE` is the judge.
2. The **next chunk tries the external worker again** (no sticky switch, no cool-down file): credits that came back
   are used from the very next chunk. A refusal costs one fast failed call.
3. Progress line suffix: `worker: native (<backend> quota)` for the fallback chunk (`codex quota` on a Claude host, `claude quota` on a Codex host).

Without `--auto` the BLOCKED stands as written — ask the user. Preflight (`--preflight`) only checks the login, not the
balance, so a drained account passes preflight and is caught here.

## 4. Progress line

`## Chunk Progress` lines (`delegation.md` §6) get a suffix naming the backend, the provider session and the log:
```markdown
- [x] P2 chunk 2/4 · steps 4-6 · 2026-10-15 14:48 · exit: `tsc --noEmit` clean · worker: codex · session: 019a…f3 · log: .ow/local/runs/<slug>/P2-chunk2.events.jsonl
```
The session id is `$RUN_DIR/$TAG.session`; the codex model actually used is `$RUN_DIR/$TAG.model` — with a family
alias in `auto.codex_model` (`sol`) the script picks the newest listed model and falls back when the account rejects
it, so append ` · model: <that slug>` to the line. Paths are repo-relative; `.ow/local/` is gitignored, so the log is
same-machine evidence only — the `exit:` command is the portable proof.

## 5. Resume a chunk

A chunk that returned `CONTINUE`, or one being re-run after a crash, may continue the **same provider session**:
```bash
bash "$MAIN_ROOT/scripts/ow-worker.sh" "$WORKER" "$WORK_ROOT" "$RUN_DIR" "$TAG" "$RUN_DIR/$TAG.prompt.md" --resume "$(cat "$RUN_DIR/$TAG.session")"
```
Only the id from **that chunk's** `.session` file — never `--last` / "most recent": another run may own it.
No `.session` file ⇒ start a fresh session with the next chunk letter (`2a/4`), as `delegation.md` already says.

## 6. Vault writes

3.1 rule 9 (update the vault per the plan's checklist) is **not** delegated to the external worker — the
orchestrator performs it after the chunk loop, exactly as it does the plan-file writes. Single writer, no
`--add-dir` for the vault.

## Never

- Never promote process exit 0 / a non-empty last message / parsable JSON to DONE — `EXIT_STATE` decides
- Never pass `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-skip-permissions`, or `-s danger-full-access`
- Never fall back to the native agent or the main tree when preflight fails — STOP
- Never put the raw log in the plan, the vault, or your own context
