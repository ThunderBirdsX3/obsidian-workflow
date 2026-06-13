# Project rules layer (`.ow/rules/`)

บันทึก convention **ของ project นี้เอง** (coding / docs / testing / security / frontend /
backend / mobile) ไว้ที่นี่. Rule ที่ resolve ได้สำหรับ area หนึ่ง **overrides** generic
guidance ที่ฝังอยู่ใน command/agent spec ของ area นั้น — project facts ไม่ต้อง hardcode
ลงใน command spec

## Location

Layer เดียว: `.ow/rules/<area>.md` (git-tracked) — 1 area ต่อ 1 ไฟล์ canonical

| Area | Canonical file |
|---|---|
| coding | `.ow/rules/coding.md` |
| docs | `.ow/rules/docs.md` |
| testing | `.ow/rules/testing.md` |
| security | `.ow/rules/security.md` |
| frontend | `.ow/rules/frontend.md` |
| backend | `.ow/rules/backend.md` |
| mobile | `.ow/rules/mobile.md` |

## Format

Markdown + frontmatter `applies_to` เป็น list ของ area (หรือ `'*'` = ทุก area):

```markdown
---
applies_to: [backend, security]
---
# <area> conventions for THIS project

- <rule ของ project คุณ> — override generic guidance ที่ command/agent
  จะใช้กับ area นี้
```

Rule file อ้าง vault note ได้ — resolver จะ expand ตาม vault path ที่ resolve แล้ว

## How it is consumed

```bash
# ทุก command Phase 0 + ทุก spawned subagent อ่าน rules ของ area ตัวเอง:
bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules <area>
```

- `--rules <area>` คืน path ของทุกไฟล์ใน `.ow/rules/*.md` ที่ `applies_to` match area นั้น
- Commands `Read` ทุกไฟล์ที่ resolver คืนมาใน Phase 0 Load-Context
- Spawned subagents รับ resolved rule paths ผ่าน injected PROJECT CONTEXT block
