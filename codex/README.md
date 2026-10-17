# obsidian-workflow — OpenAI Codex CLI

Codex reads **`AGENTS.md` at the repository root** automatically. That file is the
entry point; this folder holds nothing Codex loads on its own.

## Use

```bash
codex run 'ow-init'      # set up the vault
codex run 'ow-help'      # not sure which verb you need
```

Command specs live in `.ow/commands/<verb>.md` (a project may override any of
them with `commands/<verb>.md`). They are also generated as skills under
`.agents/skills/<verb>/SKILL.md`.

## Notes

- Codex has no user-definable subagents; `AGENTS.md` describes persona switching (the persona files under
  `.claude/agents/*.md` are plain markdown, readable whichever assistant is driving). To hand code work to a
  separate context anyway, run `ow-implement <plan> --claude` (or `ow-auto <target> --claude`): the chunk is
  executed by the Claude CLI through `scripts/ow-worker.sh`, and only its HANDOFF returns here.
- `ow-auto` isolates its `/ow-plan` and `/ow-test` steps in subagents on Claude Code only; with no Agent tool here
  they run inline.
- Per-command and per-subagent model pins in `.ow.yml` are Claude Code
  features and are ignored here.
