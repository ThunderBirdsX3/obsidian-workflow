# AI-README.md — obsidian-workflow usage guide for any AI

obsidian-workflow ทำงานกับ AI ตัวใดก็ได้ที่อ่าน markdown ได้

## Source of truth

ทุก command มี source-of-truth ที่ `.ow/commands/<verb>.md`

แต่ละไฟล์เป็น self-contained markdown — อธิบาย Phase, validations, output requirements, restrictions

> **v0.4.1+:** commands moved from root `commands/` into `.ow/commands/` to keep all obsidian-workflow machinery in one place. Root `commands/` ยังใช้ได้เป็น optional override layer (resolver fallback)

## วิธีใช้กับแต่ละ AI

### Claude Code (interactive)

ใช้ slash commands ได้เลย (shim อยู่ที่ `.claude/commands/ow-*.md` ซึ่ง `@`-reference `.ow/commands/`):

```
/ow-help                        ← ถามว่าใช้ command ไหน / อธิบาย / workflow
/ow-init
/ow-reverse-engineer                ← brownfield: อ่านโค้ดที่มีอยู่ → สร้าง vault docs draft
/ow-new
/ow-clarify <doc>               ← spec-kit taxonomy ambiguity scan
/ow-plan <task>
/ow-checklist <domain>          ← unit tests for English (ux/api/security/perf)
/ow-implement <plan-path>          ← plan ที่แตก phase: + --phase P1 เพื่อรันทีละ phase (ไม่ใส่ = ทุก phase)
/ow-fix <bug>
/ow-triage-issues               ← batch-triage GitHub issues → classify + label + comment
/ow-fix-issue <issue>           ← แก้ GitHub issue แบบขนาน (worktree) → merge → handoff
/ow-doc <type> <name>
/ow-test
/ow-design
/ow-secure
/ow-verify <scope>
/ow-handoff <plan-path>             ← สร้าง Handoff Report ส่งต่อ reviewer/exec
/ow-git <args>
/ow-sync
/ow-agent <action>              ← list/enable/create/regenerate intelligent agents
```

### Claude Code (print mode `claude -p`)

Slash commands ไม่ทำงาน — reference path แทน:

```bash
claude -p "$(cat .ow/commands/ow-plan.md)\n\nTask: เพิ่ม search feature"
```

หรือใช้:
```bash
claude -p "Follow @.ow/commands/ow-plan.md\n\nTask: เพิ่ม search feature"
```

### Codex CLI / Cline / Kimi Code

ทั้งสามตัวอ่าน **`AGENTS.md` ที่ root** + skill ที่ `.agents/skills/<verb>/SKILL.md`
(generated จาก `.ow/commands/`) — ชุดเดียวกัน ต่างกันแค่วิธีเรียก

```bash
codex run "ow-plan: เพิ่ม search feature"   # Codex CLI
```

| Tool | เรียกยังไง |
|---|---|
| Cline (VS Code) | `/ow-plan` |
| Kimi Code CLI | `/skill:ow-plan` |
| Codex CLI | `codex run 'ow-plan'` |

แต่ละ SKILL.md ชี้กลับไปที่ `.ow/commands/ow-plan.md` — หรือ `commands/ow-plan.md`
ถ้า project override ไว้

### Gemini CLI / API

ใช้ prompts ที่ `gemini/prompts/` หรือชี้ไปที่ `.ow/commands/<verb>.md` ตรงๆ:

```bash
gemini chat --system "$(cat .ow/commands/ow-plan.md)" "Task: ..."
```

### Cursor / Windsurf / ChatGPT / อื่นๆ

Paste content ของ command markdown เป็น system prompt:

```
[Paste content of .ow/commands/ow-plan.md]

Task: เพิ่ม search feature
Project root: /path/to/project
```

> **Paste mode + `_shared/`:** บาง spec (`ow-implement`, `ow-test`, `ow-fix`, `ow-fix-issue`, `ow-git`, `ow-design`) เก็บรายละเอียด
> ของโหมด/phase นั้นๆ ไว้ที่ `.ow/commands/_shared/<file>.md` แล้วสั่งอ่านตอนถึงจุดที่ต้องใช้.
> AI ที่มี file access อ่านเองได้ — ถ้า paste ล้วน ให้ paste fragment ที่ตรงกับโหมดที่จะใช้ตามไปด้วย
> (ไม่ถึง phase นั้น = ไม่ต้อง); fragment ที่ตัวมันชี้ fragment อื่นต่อ ต้อง paste ตัวที่ถูกชี้ด้วย

หรือ reference file path ถ้า AI ตัวนั้นมี file access:

```
Follow the instructions in .ow/commands/ow-plan.md

Task: ...
```

### Generic prompts สำหรับ AI ใดๆ

`prompts/general-ai/start-here.md` — เริ่มต้นทั่วไป
`prompts/general-ai/review-output.md` — pattern review output

## Universal rules ที่ทุก AI ต้องปฏิบัติ

1. **Vault-first** — อ่าน `docs/` (00-Index, PRD, Features, Reference) ก่อนถามคำถาม
2. **Output = bullet สรุปสั้น** ภาษาตาม `project.language` — **≤7 bullets · bullet ละ 1 บรรทัด ห้ามซ้อนย่อย**: ทำอะไร/แก้อะไร · หลักฐานที่ตรวจจริง · เสี่ยง/ต่อไป (เมื่อมี). ไม่บังคับ 5-header ยาว · ห้ามเกริ่นนำ/ทวนคำถาม user
   **ถาม** — เฉพาะที่ตอบต่างกันแล้วงานออกมาต่างกัน · 1 คำถามต่อครั้ง ≤2 บรรทัด · ตัวเลือก ≤4 · ต้องมี **แนะนำ: <ตัวเลือก>** + เหตุผล 1 บรรทัดเสมอ
3. **No fake results** — ห้ามแต่ง commit hash, URL, test result, token count
4. **Thai-first reporting** — รายงาน + log ภาษาไทย (เว้นแต่ project ตั้ง `language: en`)
5. **Plan/Implement separation** — `/ow-plan` ไม่แตะโค้ด, `/ow-implement` เท่านั้นที่แก้โค้ด, `/ow-fix` แค่ diagnose
6. **Design system compliance** — ถ้ามี `docs/obsidian-vault/70-Reference/DesignSystem/` → frontend/mobile ต้องใช้ token/component จากนั้น
7. **Coding discipline** — ก่อนแก้ระบุ success criteria ที่ตรวจได้; เลือก minimum correct change; ทุก changed line ต้อง trace กลับไปยัง request/bug/criteria ได้; ห้ามเพิ่ม speculative abstraction/config/feature; ห้าม unrelated refactor/format churn; verification ต้อง map กลับไปยัง success criteria
   สัญญาเต็ม (untestable list + audit ก่อน mark done) อยู่ที่ `.ow/commands/_shared/coding-discipline.md` — อ่านก่อนแก้โค้ด ทุกครั้ง

## Config

`.ow.yml` ที่ root — ทุก AI อ่านได้:
- `mode`: standalone หรือ submodule
- `vault_path`: ตำแหน่ง Obsidian vault
- `subagents`: agents ที่ enable (เฉพาะ AI ที่ support sub-agents)
- `submodules`: list submodule + branch
- `ow.version`: obsidian-workflow release ที่ติดตั้ง
- `ow.source`: URL ที่ `/ow-sync` ใช้ดึง snapshot ใหม่

## Sub-agents

Claude Code อ่าน `.claude/agents/*.md` ซึ่งเก็บเฉพาะ agent ที่ **มีตัวตนจริง**
obsidian-workflow ship มาแค่ always-on **(4 agents** — docs/verifier/security/gh-issue) เท่านั้น

agent เฉพาะทาง (`backend` `frontend` `mobile` `design` `test-runner` หรือชื่อที่ project ตั้งเอง) **ไม่ได้ ship มา** —
`/ow-agent suggest` อ่าน stack จริงของ repo แล้วบอกว่าควรมีตัวไหน, `/ow-agent create <name>` เขียน body ให้ตรง stack นั้น
`enabled` ใน `.ow.yml` แต่ไม่มีไฟล์ = flag ที่ไม่มีอะไรอยู่เบื้องหลัง — install/upgrade รายงาน ไม่เติมให้เงียบๆ

AI ตัวที่ไม่ support sub-agents → main AI ทำเองทั้งหมดโดยอ่าน guidance ผ่าน `.ow/commands/<verb>.md` (+ `_shared/`) — gate เดียวกัน

## Project structure (ทุก AI เห็นเหมือนกัน)

```
.
├── AI-README.md           ← คุณอยู่ที่นี่
├── CLAUDE.md              ← Claude-specific entry
├── .ow.yml          ← config (all AIs read)
├── .ow/                       ← all obsidian-workflow machinery
│   ├── templates/                   ← canonical templates (lookup fallback)
│   ├── rules/                       ← project's own rules (never synced)
│   └── commands/                    ← source-of-truth verb specs (neutral)
│       ├── ow-init.md
│       ├── ow-new.md
│       └── ... (21 verbs)
├── .claude/
│   ├── commands/          ← Claude Code slash shims (5-line each, @.ow/commands/…)
│   ├── agents/            ← Claude sub-agents (always-on 4 + ที่ /ow-agent create ไว้)
│   └── settings.json
├── AGENTS.md              ← Codex / Cline / Kimi entry (routes to .ow/commands/)
├── .agents/
│   └── skills/ow-<verb>/ ← skill ต่อ verb — ชี้กลับไปที่ .ow/commands/
├── gemini/ gpt/ glm/
│   └── prompts/           ← router.md + system.md ของ AI ที่ paste เอา
├── prompts/
│   └── general-ai/        ← generic prompts
├── commands/              ← OPTIONAL project override layer (lookup: root → .ow/commands/)
├── templates/             ← OPTIONAL project override layer (lookup: root → .ow/templates/)
├── scripts/               ← runtime helpers
│   ├── ow-paths.sh
│   ├── upgrade.sh
└── docs/obsidian-vault/   ← Obsidian vault (default vault_path)
    ├── .obsidian/
    ├── 00-Index/
    ├── 10-PRD/
    ├── ... (12 folders)
    └── 95-Handoff/
```

## Update obsidian-workflow across AIs

Run `/ow-sync` (Claude Code) — ดึง snapshot **จาก obsidian-workflow repo**:

```
obsidian-workflow repo → user project syncs .ow/{commands,templates}
```

ทุก AI shim จะใช้ spec ใหม่อัตโนมัติ — เพราะ `.ow/commands/<verb>.md` อ้าง `.ow/` ที่ relative path
