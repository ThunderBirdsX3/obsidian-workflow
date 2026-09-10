# /ow-agent

> **Subagent management** — list/enable/disable + **เขียน agent ใหม่ให้ตรง tech stack จริงของ project**

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-agent.md`](../.ow/commands/ow-agent.md)

## obsidian-workflow ship agent มาแค่ 4 ตัว

`docs` `verifier` `security` `gh-issue` — always-on, ทุก project ต้องใช้ ไม่ว่าเขียนด้วยอะไร

**`backend` `frontend` `mobile` `design` `test-runner` ไม่ได้ ship มา** — มันเป็นแค่ *ชื่อ* ใน `.ow.yml`
จนกว่า `/ow-agent create <name>` จะเขียน body ให้ ทำไมถึงทำแบบนี้: agent `backend` ที่ต้อง generic พอจะรองรับ
.NET, Django, Rails, Express พร้อมกัน = ไม่ลึกกับอันไหนเลย และทุก project ต้องแบก context ของมันไม่ว่าจะทำ
backend หรือเปล่า — เขียนตอนที่รู้ stack แล้วดีกว่า

## เมื่อไหร่ใช้

- หลัง `/ow-init` + มี PRD/SRS แล้ว → `suggest` แล้ว `create` agent ที่ stack นี้ต้องการจริง
- stack เปลี่ยน (major version, เปลี่ยน ORM/test runner) → `regenerate` ให้ body ตามทัน
- อยากเพิ่ม agent ที่ไม่ใช่ชื่อมาตรฐาน (เช่น `data-pipeline`, `infra-aws`, `seo-content`)
- ตรวจ agent definition ครบไหม (audit)

## Quick start

```
/ow-agent list
```

ตัวอย่าง output (Model = ค่าที่ resolve จาก config override > built-in default):
```
Agent          State           Model    Written      Spec lines   Notes
docs           ✓ live          sonnet   shipped      231          always-on, vault keeper
verifier       ✓ live          sonnet   shipped      288          always-on
security       ✓ live          opus     shipped      296          always-on
gh-issue       ✓ live          haiku    shipped      147          always-on, GitHub issue reader
backend        ✓ live          sonnet   2026-05-19   180          created: .NET 8 API, dotnet test
frontend       ✗ broken        sonnet   —            —            enabled แต่ยังไม่มี body → create
mobile         — not created   sonnet   —            —            ไม่มี mobile ใน project นี้
```

**3 สถานะ ไม่ใช่ 2** — `✗ broken` คือ flag เปิดไว้แต่ไม่มีไฟล์: config สัญญา agent ที่ spawn ไม่ได้จริง
install/upgrade จะรายงานให้เห็น ไม่เติมให้เงียบๆ (แก้ด้วย `/ow-agent create <name>`)

## รูปแบบเต็ม

```
/ow-agent                      # interactive — แสดง menu
/ow-agent list                 # ตาราง agents + enabled status
/ow-agent enable <name>        # เปิด body ที่ "มีอยู่แล้ว" + update .ow.yml (ไม่ได้เขียน body ให้)
/ow-agent disable <name>       # disable — flag off + ย้าย body ออกเป็น .bak-<date>
/ow-agent create <name>        # ★ เขียน body ใหม่ตาม stack ที่ detect ได้ (interactive)
/ow-agent regenerate <name>    # เขียนใหม่ตาม stack + vault ปัจจุบัน (backup ตัวเก่า)
/ow-agent audit                # ตรวจ agent definition (sections, gates, §1 ระบุ stack จริงไหม)
/ow-agent suggest              # ★ detect stack + vault → บอกว่าควร create ตัวไหน พร้อมหลักฐาน
```

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Resolve state (ls `.claude/agents/`, `yq` `.subagents`) → ตาราง 3 สถานะ
2. **Phase 1** — `list`/`enable`/`disable` (flag + body ต้องขยับพร้อมกันเสมอ)
3. **Phase 2** — `create`: 2.1 detect stack จาก manifest จริง → 2.2 อ่าน `.ow/rules/` + vault →
   2.3 ถามเฉพาะที่ repo ตอบเองไม่ได้ → 2.4 ปั้น gates ตาม taxonomy → 2.5 เขียนไฟล์
4. **Phase 3** — `regenerate` (detect stack ใหม่ทั้งหมด + diff + write w/ backup `.bak-<date>`)
5. **Phase 4** — `suggest` (หลักฐาน 2 ฝั่ง: manifest/lockfile ในโค้ด **และ** vault → map เป็น agent)
6. **Phase 5** — `audit` (check §1-§8, §5 gates ≥ 2, §1 ต้องระบุ stack จริง, Never section ≥ 3)

## Output ที่ได้

- `.claude/agents/<name>.md` (สร้างใหม่หรือ regenerate)
- `.claude/agents/<name>.md.bak-<date>` (backup ก่อน regenerate, gitignored)
- `.ow.yml` update `subagents.<name>` (enabled + optional `model` — ดู "AI model ต่อ agent" ด้านล่าง)

## Agent structure (ที่ generate)

```
§1. Role (one paragraph specific)
§2. Project context awareness (THIS PROJECT'S SPECIFICS — tech stack, owned paths, vault refs)
§3. Read context first (vault-first rule)
§4. Scope rules (MAY/MUST NOT touch)
§5. Gates (must-not-skip)
§5.1 Test creation
§6. Process (phases)
§7. Vault Update Checklist
§8. Hand-back format
§9. Examples (good vs bad)
Never section
```

## Workflow ที่นิยม

ตัวอย่าง 1: ทางหลัก — มี PRD แล้ว ค่อยสร้าง agent
```
1. /ow-new                     ← สร้าง PRD + SRS + Tech-spec
2. /ow-agent suggest           ← อ่าน manifest + vault → บอกว่าควรมีตัวไหน พร้อมหลักฐาน
     backend      ← package.json: express 5, prisma · prisma/migrations/ (14 files)
     frontend     ← package.json: next 15, react 19
     test-runner  ← package.json: @playwright/test · 90-TestPlan/TP-Checkout.md
3. /ow-agent create backend    ← ยืนยัน stack ที่ detect ได้ → ตอบคำถามที่เหลือ → เขียนไฟล์
4. /ow-agent create frontend
5. /ow-agent audit             ← ตรวจว่า §1 ระบุ stack จริง ไม่ใช่ template เปล่าๆ
```

ตัวอย่าง 2: สร้าง agent ที่ไม่ใช่ชื่อมาตรฐาน
```
/ow-agent create data-pipeline
  → detect stack (pyproject.toml: dbt-core, apache-airflow)
  → อ่าน .ow/rules/ + vault docs ที่เกี่ยว
  → ถามเฉพาะที่ repo ตอบเองไม่ได้ (role, owned paths, gates เพิ่มเติม, tools)
  → generate .claude/agents/data-pipeline.md
  → update .ow.yml subagents.data-pipeline: true
```

ตัวอย่าง 3: stack ขยับ → regenerate
```
/ow-agent regenerate frontend
  → detect stack ใหม่ทั้งหมด (ไม่เอาของเดิมมาใช้ต่อ — version ค้างคือ bug ที่คำสั่งนี้มีไว้แก้)
  → เขียน §1/§5/§6/§9 ใหม่ → diff → confirm → backup ตัวเก่าเป็น .bak-<date>
```

## Agents

| Agent | ship มาไหม | Default model | หมายเหตุ |
|---|---|---|---|
| `docs` | ✓ always-on | sonnet | vault keeper |
| `verifier` | ✓ always-on | sonnet | test/lint/build runner |
| `security` | ✓ always-on | opus | secret/PII scanner |
| `gh-issue` | ✓ always-on | haiku | GitHub issue+image reader (triage/fix-issue) |
| `backend` | ✗ create เอง | sonnet | API/server |
| `frontend` | ✗ create เอง | sonnet | web UI |
| `mobile` | ✗ create เอง | sonnet | mobile app |
| `design` | ✗ create เอง | sonnet | design system — create แล้วค่อย `/ow-design init` |
| `test-runner` | ✗ create เอง | sonnet | Playwright/Maestro automation |
| ชื่ออื่นๆ | ✗ create เอง | sonnet | default model = sonnet |

🔴 คำสั่งที่เคยพึ่ง agent เหล่านี้ (`/ow-implement` `/ow-test` `/ow-design`) **ทำงานได้ปกติเมื่อไม่มี agent** —
มันรัน inline แล้ว gate เดิมทั้งหมดยังบังคับใช้ (`/ow-design` มี process เต็มอยู่ที่
`.ow/commands/_shared/design-process.md`) ไม่มี agent ≠ ขาด gate

## AI model ต่อ agent

กำหนด model ที่แต่ละ agent รันได้จาก `.ow.yml` — 2 รูปแบบต่อ agent (ผสมกันได้):

```yaml
subagents:
  backend:  { enabled: true, model: opus }   # map form — เห็น+แก้ model ตรงนี้
  docs:     true                             # scalar form — ใช้ default model
```

- `model` รับ **family alias** (`opus | sonnet | haiku`) ไม่ระบุ version → track รุ่นล่าสุดอัตโนมัติ (หรือ pin full id เช่น `claude-opus-4-8` ได้)
- ค่าผิด → fallback เป็น default + WARN
- ค่าถูก **sync ลง `.claude/agents/<name>.md` frontmatter อัตโนมัติ** โดย install / upgrade / `/ow-sync` / `/ow-agent` — **ห้ามแก้ `model:` ในไฟล์ agent เอง** (จะโดนทับ)
- ดู model ที่ resolve แล้ว: `bash scripts/ow-paths.sh --agent-models`

## Gotchas / ข้อควรระวัง

- 🚫 ห้าม create agent ที่ `tools:` มี `Bash` แบบ unrestricted — ต้อง allowlist commands
- 🚫 ห้าม overwrite agent เดิมโดยไม่ backup (`.bak-<date>`)
- 🚫 ห้าม suggest agent ที่ไม่มีสัญญาณรองรับ — Phase 4 ต้องอิงผล detect จริง และต้อง**แสดง**สัญญาณนั้น
- 🚫 ห้ามใส่ secret/credential ใน agent prompt
- 🚫 `create` ที่ detect stack ไม่ได้ + user ระบุไม่ได้ ⇒ **STOP** ไม่เขียน placeholder — body ที่ไม่รู้ stack
  แย่กว่าไม่มี agent เพราะ orchestrator จะเชื่อมัน
- ⚠️ `enable <name>` ที่ยังไม่เคย `create` จะ **หยุดและบอกให้ create** ไม่ได้เติม body กลางๆ ให้
- ⚠️ **stack ฝังได้ / path ห้ามฝัง** — §1/§5/§6 เขียน framework ตรงๆ ได้เต็มที่ แต่ §2 ต้องชี้ไป §0
  (paths/submodules/rules resolve ใหม่ทุกรอบ ฝังไว้ = มี 2 แหล่งที่จะเพี้ยนเงียบๆ)

## Related

- ก่อน `/ow-agent`: [`/ow-init`](./ow-init.md), [`/ow-new`](./ow-new.md), [`/ow-doc`](./ow-doc.md) (ให้มี vault context ก่อน)
- หลัง `/ow-agent create`: ทดลองด้วย [`/ow-implement`](./ow-implement.md) (set `subagent_target: <name>` ใน plan)
- Subagent specs: [`.claude/agents/*.md`](../.claude/agents/)

## FAQ

**Q: agent ที่ create มา ใช้กับ Codex/Gemini ได้ไหม?**
A: Subagent เป็น Claude Code-specific (`.claude/agents/`) — Cline/Kimi/Codex ใช้ `AGENTS.md` + `.agents/skills/`, Gemini/GPT/GLM ใช้ `<tool>/prompts/` แทน

**Q: `disable` ทำอะไรกับไฟล์ agent?**
A: ย้ายออกเป็น `.claude/agents/<name>.md.bak-<date>` พร้อมกับ set `subagents.<name>: false` — ต้องย้ายทั้งสองข้าง เพราะ Claude Code spawn ทุกไฟล์ที่อยู่ใน `.claude/agents/` การปิดแค่ flag จึงไม่ได้ปิดอะไรเลย. `.bak-<date>` คือแหล่งที่ `enable` อ่านกลับ — เปิดใหม่ได้ตลอด (ไฟล์ backup gitignored)

**Q: always-on 4 ตัว disable ได้ไหม?**
A: ไม่ได้ — `disable` ปฏิเสธ เพราะ install/upgrade คัดลอก body กลับมาทุกรอบ แต่ไม่มีอะไรเขียน `.ow.yml` (อยู่ใน SAFE_PATHS) ⇒ ถ้าปล่อยให้ปิด flag ได้ จะได้ config ที่บอกปิดแต่ agent ยัง spawn ได้

**Q: `audit` แจ้ง "§1 names no stack" แปลว่าอะไร?**
A: body นั้นคือ template ที่ใส่ชื่อเข้าไปเฉยๆ — ตอน `create` ยังไม่รู้ stack. รัน `/ow-agent regenerate <name>`
หลังมี PRD/manifest แล้ว (always-on 4 ตัวยกเว้นจากกฎนี้ — มันเป็น stack-independent โดยตั้งใจ)

**Q: upgrade มาจากเวอร์ชันเก่าที่เคยมี `.ow/agents/` — ของเดิมหายไหม?**
A: `.ow/agents/` (library ของ body ที่เคย ship) ถูกเลิกใช้และลบทิ้ง โดย backup ไว้ก่อนและ `--rollback` ได้
แต่ **agent ที่ enable ไว้จริงไม่โดนแตะ** — มันอยู่ที่ `.claude/agents/` ซึ่ง upgrade ไม่เคยเขียนทับ
