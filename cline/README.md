# obsidian-workflow — Cline (VS Code)

Cline picks this project up with no configuration: it reads **`AGENTS.md` at the
repository root** and the skills under **`.agents/skills/`**, both of which the
installer put in place.

## Use

Open the project in VS Code, open Cline, then type the verb as a slash command:

```
/ow-init      set up the vault
/ow-help      not sure which verb you need
/ow-plan      plan a feature or task
```

Cline registers each `.agents/skills/<verb>/SKILL.md` as a bare `/<verb>` command.
Each one delegates to the authoritative spec at `.ow/commands/<verb>.md`, or
to the project's `commands/<verb>.md` override when one exists.

## Notes

- One slash command per message. `/ow-fix` will tell you to run `/ow-implement
  --from-fix` afterwards rather than chaining it itself.
- Rules can be toggled off per user in Cline's Rules panel, so nothing load-bearing
  relies on a rule alone — the result-honesty constraints live in the command
  specs as well as in `AGENTS.md`.
- Cline's subagents are built-in and not user-definable. `AGENTS.md` covers persona
  switching instead.
- Per-command and per-subagent model pins in `.ow.yml` are Claude Code
  features and are ignored here.
