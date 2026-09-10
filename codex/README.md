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

- Codex has no user-definable subagents. `AGENTS.md` describes persona switching —
  the persona files under `.claude/agents/*.md` are plain markdown and readable
  whichever assistant is driving.
- Per-command and per-subagent model pins in `.ow.yml` are Claude Code
  features and are ignored here.
