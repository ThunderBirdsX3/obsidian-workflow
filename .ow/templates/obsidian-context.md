<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/obsidian-context.md` (lookup priority สูงกว่า)
-->

# Obsidian Context Manifest

Default file name: `00-Agent-Context.md`

> ใช้ไฟล์นี้เป็น canonical Obsidian context manifest ให้ command อื่นอ่านก่อนทำงาน
> เมื่อ project ใช้ Obsidian เป็น knowledge base

## Project

- Project name:
- Vault path:
- Project folder:
- Source repo path:
- Owner:
- Last updated:

## Scope

- In scope:
- Out of scope:
- Shared vault/repo write rule:

## Structure Map

- Home/index note:
- Architecture/docs:
- Requirements/specs:
- Plans/fix logs:
- Changelog/release notes:
- Test reports/evidence:
- Decisions/ADR:
- References:

## Naming, Links, And Metadata

- File naming pattern:
- Folder naming pattern:
- Link style:
- Required frontmatter:
- Tags:
- Existing templates:

## Command Integration

- `/ow-plan`: อ่าน manifest นี้ก่อน plan; ระบุ target note/evidence path ใน plan เมื่อเกี่ยวข้อง
- `/ow-fix`: บันทึก root cause, fix summary, regression check, evidence ใน fix-log
- `/ow-implement`: update plan file + vault docs + IMPLEMENTATION-STATUS หลัง execute
- `/ow-doc`: create/update vault note โดยรักษา links/frontmatter เดิม
- `/ow-test`: เขียน report + evidence manifest ใต้ EVIDENCE_ROOT (gitignored)
- `/ow-handoff`: สร้าง session handoff note ใน 95-Handoff

## Current Work

- Active plan/fix file:
- Active evidence folder:
- Related task/issue:

## Verification / Evidence Rules

- Testcase storage path:
- Screenshot/media storage path:
- Command output/log storage path:
- Evidence that must be captured:
- Pending evidence wording:

## Known Risks / Limits

-

## Change Log

-
