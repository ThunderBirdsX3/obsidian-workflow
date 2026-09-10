# /ow-init

> **Bootstrap obsidian-workflow** — ตั้งค่า project ครั้งแรก + สร้าง Obsidian vault + ติดตั้ง subagent always-on

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-init.md`](../.ow/commands/ow-init.md)

## เมื่อไหร่ใช้

- หลังรัน `bash <(curl ... install.sh)` แล้ว — `/ow-init` ทำ interactive config
- เริ่ม project ใหม่จากศูนย์ (greenfield — folder ว่าง)
- รับ codebase เดิมเข้า obsidian-workflow (brownfield — มี code/docs อยู่แล้ว)
- อยาก reconfigure project ที่ init แล้ว (`--reconfigure`)

## Quick start

```
/ow-init
```

ตัวอย่าง output:
```
🔍 ตรวจพบ indicators ใน folder นี้:
   • package.json
   • src/
   • .git (47 commits)

โหมดไหนตรงกับสถานการณ์?
  1) greenfield   — project setup ไว้ แต่ยังไม่มี content จริง
  2) brownfield   — มี code/docs ใช้งานอยู่
  3) adopt-vault  — มี Obsidian vault เดิม

เลือก (1/2/3) [default: 2]:
```

## รูปแบบเต็ม

```
/ow-init                     # auto-detect mode (ถามถ้า ambiguous)
/ow-init <project-name>      # ระบุชื่อ project
/ow-init --greenfield        # บังคับ greenfield mode
/ow-init --brownfield        # บังคับ brownfield (ห้ามแตะของเดิม)
/ow-init --reconfigure       # แก้ config ของ project ที่ init แล้ว
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--greenfield` | auto | บังคับ — สร้าง vault skeleton ใหม่ |
| `--brownfield` | auto | บังคับ — ห้ามแตะ code เดิม |
| `--reconfigure` | n/a | reset ส่วนใดส่วนหนึ่งของ `.ow.yml` |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect mode (greenfield/brownfield/adopt-vault) จาก indicators (`package.json`, `.git`, `docs/`, etc.)
2. **Phase 1** — ถามคำถามขั้นต่ำ batch เดียว (project name, mode, stack, vault location, language, brownfield import)
3. **Phase 2** — สร้าง vault skeleton (12 folders ใน `<vault_path>/`)
4. **Phase 3** — Brownfield adoption (stack scan + import README + suggest first task)
5. **Phase 4** — Verify the obsidian-workflow snapshot (`.ow/commands`, `.ow/templates`)
6. **Phase 5** — Subagents: ติดตั้ง always-on 4 ตัว (docs/verifier/security/gh-issue); ตัวเฉพาะทางสร้างทีหลังด้วย `/ow-agent suggest` → `/ow-agent create <name>` เมื่อรู้ stack + มี PRD แล้ว
7. **Phase 6** — เขียน `.ow.yml` (shared) + `.ow.local.yml` (personal)
8. **Phase 7** — Verification + แสดง summary

## Output ที่ได้

- `<vault_path>/` (12 folders ครบ — `00-Index/`, `10-PRD/`, …, `95-Handoff/`)
- `.ow.yml` (gitTracked — shared กับ team)
- `.ow.local.yml` (gitignored — personal paths)
- `.claude/commands/`, `.claude/agents/` (จาก installer)
- (brownfield) PRD draft จาก README ใน `docs/obsidian-vault/10-PRD/PRD-<slug>.md`

## Vault location options (Phase 1.2)

| ตัวเลือก | เก็บที่ | ใช้เมื่อ |
|---|---|---|
| A) `docs/` | `<project>/docs/` | greenfield, default |
| B) `docs/ow-vault/` | `<project>/docs/ow-vault/` | brownfield ที่ `docs/` ใช้อยู่ |
| C) custom in-repo | path ที่ user ระบุ | brownfield + มี vault อยู่ |
| D) external | absolute path นอก repo | shared org vault, iCloud sync |

ถ้าเลือก D → path ไป `.ow.local.yml` `paths.external_vault:` (personal)

## Workflow ที่นิยม

ตัวอย่าง 1: เริ่ม project ใหม่
```
1. mkdir my-app && cd my-app
2. bash <(curl ... install.sh)     ← copy scaffolding
3. /ow-init                        ← คุณอยู่ที่นี่
4. /ow-new                         ← brainstorm PRD
5. /ow-plan FEAT-X                 ← เริ่ม implement cycle
```

ตัวอย่าง 2: รับ codebase เดิม (brownfield)
```
1. cd existing-project
2. bash <(curl ... install.sh)
3. /ow-init                        ← ตอบ "brownfield" + ระบุ vault B
4. (ตรวจ PRD draft + REF-TechStack ที่ generate มา)
5. /ow-doc PRD-<slug>              ← เติม section ที่ขาด
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามเล่าการแก้ในเอกสาร vault** — "เดิม X → ใหม่ Y" / หัวข้อ `## Changelog` ให้ทับด้วยค่าปัจจุบันแทน · before/after อยู่ใน plan (`80-ImplementPlan`) หรือ fix-log (`85-FixLog`) · `/ow-secure` Phase 2.6 บล็อกให้
- ⚠️ `--here` ≠ brownfield — installer/init จะ**ถาม** แม้รันใน cwd เดิม (อาจเป็น scaffolding ที่ยังไม่เริ่ม)
- 🚫 ห้ามแตะ code เดิมใน brownfield — `/ow-init` เพิ่มเฉพาะ `docs/`, `.claude/`, `.ow/`, `templates/`, `.ow.yml`
- 🚫 ห้ามแต่ง dependencies/framework version ที่ไม่ได้เห็นจริงในไฟล์
- 💡 มี `CLAUDE.md` อยู่แล้ว → installer **merge เฉพาะ block ที่ marker `<!-- OW START: workflow -->` ครอบ** (มี block เดิม = refresh · ไม่มี = append ต่อท้าย) — prose ของคุณนอก marker ไม่ถูกแตะ · ถ้ามี START แต่ไม่มี END = หยุด ไม่เดา span
- 💡 `.ow.local.yml` gitignored แล้ว — เก็บ external vault path / secrets file ที่นี่
- 💡 มี `.claude/agents|commands` เดิมของคุณ (ไม่ใช่ของ obsidian-workflow)? installer ถาม **keep-all / remove-all (backup) / select per item** — non-interactive default = keep + warn; user agent ที่ไม่มี `§0` จะไม่ทำให้ install ล้ม (เป็น note)
- 💡 `/ow-init` สร้าง scaffold `.ow/rules/<area>.md` ให้ทุก area ที่ enable (เช่น `docs.md`, `security.md`) — เติม convention ของ project ตรงนั้น (override generic guidance) หรือลบทิ้งถ้าไม่ใช้

## Related

- ก่อน `/ow-init`: `bash scripts/install.sh` (bootstrap CLI)
- หลัง `/ow-init` (greenfield): [/ow-new](./ow-new.md) — brainstorm PRD
- หลัง `/ow-init` (brownfield): [/ow-doc](./ow-doc.md) — เติม PRD/SRS
- Reconfigure ทีหลัง: `/ow-init --reconfigure` หรือ [/ow-agent](./ow-agent.md) สำหรับ subagent
- Vault path: `docs/` (ดู [`README`](../README.md) section "โครงสร้าง")

## FAQ

**Q: ผมรันใน folder ที่มี `git init` แล้วแต่ยังไม่มี code — เป็น greenfield หรือ brownfield?**
A: Greenfield — `.git` ว่างไม่นับเป็น indicator init จะถามให้ confirm

**Q: External vault (option D) ใส่ตรงไหน?**
A: `.ow.local.yml` ที่ `paths.external_vault: "<absolute path>"` — gitignored

**Q: ถ้าอยากได้ subagent เฉพาะทาง (backend/frontend/...) ทีหลัง?**
A: มันไม่ได้ ship มา — รัน [/ow-agent suggest](./ow-agent.md) เพื่อดูว่า stack นี้ควรมีตัวไหน แล้ว
`/ow-agent create &lt;name&gt;` เขียน body ให้ตรง stack จริง (`enable` ใช้เปิดตัวที่ create ไว้แล้วเท่านั้น)

**Q: ผม clone repo ที่ทีมงาน adopt obsidian-workflow ไว้แล้ว ต้องรัน init ใหม่ทั้งหมดไหม?**
A: ไม่ต้อง — ไฟล์ shared มีครบใน repo แล้ว สิ่งที่ขาดคือไฟล์ส่วนตัว (gitignored) ของคุณเอง รัน `ow init --local` จะสร้างเฉพาะที่ขาด (`.ow.local.yml`, `.ow/local/`) โดยไม่แตะไฟล์ shared (idempotent — รันซ้ำ no-op) ดูว่าขาดอะไรด้วย `ow doctor`
