# obsidian-workflow — Kimi Code CLI (Moonshot)

Kimi Code reads **`AGENTS.md` at the repository root** and the skills under
**`.agents/skills/`**, both of which the installer put in place. Note that Kimi does
**not** read `CLAUDE.md`.

## Use

Run `kimi` in this folder, then invoke a verb with the skill prefix:

```
/skill:ow-init      set up the vault
/skill:ow-help      not sure which verb you need
/skill:ow-plan      plan a feature or task
```

Each `.agents/skills/<verb>/SKILL.md` delegates to the authoritative spec at
`.ow/commands/<verb>.md`, or to the project's `commands/<verb>.md` override
when one exists.

## Notes

- Kimi's project skill search reads `.agents/skills/` as a generic group, in
  addition to whichever brand directory it finds. Nothing else needs configuring.
- Per-command and per-subagent model pins in `.ow.yml` are Claude Code
  features and are ignored here.
