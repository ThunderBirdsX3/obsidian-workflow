# obsidian-workflow

Personal spec-driven development toolkit สำหรับ Claude Code + Obsidian —
เอกสารเป็น source of truth (ลึกถึงระดับ SRS), แผนแยกจากการลงมือทำ, ทุกผลลัพธ์มี evidence ตรวจได้

## ติดตั้ง

ต้องมี: `yq` · `git` · Claude Code

```bash
# cd เข้า project ก่อน แล้วรัน
cd /path/to/your-project
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/bootstrap.sh) .
```

แล้วรัน `/ow-init` ใน Claude Code

<details>
<summary>หรือ clone ก่อนแล้ว install (ถ้าอยากเก็บ toolkit ไว้ upgrade ทีหลัง)</summary>

```bash
git clone https://github.com/ThunderBirdsX3/obsidian-workflow.git
bash obsidian-workflow/install.sh /path/to/your-project
```

</details>

หรือใช้ repo นี้เป็น project เลย — แก้ `.ow.yml` `project.name/slug` แล้ว `/ow-new`

📚 **เอกสาร:**
[Getting Started](GETTING-STARTED.md) — ติดตั้ง → ปิด feature แรก ·
[Usage Guide](USAGE.md) — reference ครบ 22 commands + workflows + กติกา ·
หรือพิมพ์ `/ow-help` ใน Claude Code

## แนวคิด

```
PRD (ทำไม — สั้น)
 └─ SRS (ระบบทำอะไร แค่ไหน ตรวจยังไง — เอกสารทำงานหลัก)
     ├─ FEAT / FN specs (รายละเอียดต่อ feature/function — ผูก FR-###)
     ├─ Plan (80-ImplementPlan — ผ่าน approve ก่อน implement)
     ├─ Fix log (85-FixLog — diagnose ก่อนแก้)
     └─ Evidence (test-artifacts/ — manifest ต่อ task, นอก vault)
```

- **Vault-first** — AI อ่าน vault ก่อนถาม/เขียนโค้ดเสมอ
- **SRS คือ contract** — ทุก FR มี inputs/outputs/pre/post + acceptance Given/When/Then
  (รวม sad path) + error handling; NFR มี threshold วัดได้; มี State & Lifecycle + Error Catalog
- **Plan ≠ Implement** — `/ow-plan` เขียนแผน (ไม่แตะโค้ด) → user approve → `/ow-implement`
- **No fake evidence** — test count/commit hash/URL ต้องมาจากการรันจริง

### Upgrade install เดิม

```bash
# จาก toolkit checkout เวอร์ชันใหม่ → refresh เฉพาะไฟล์ที่ toolkit เป็นเจ้าของ
bash scripts/ow-upgrade.sh /path/to/your-project              # apply (backup อัตโนมัติ)
bash scripts/ow-upgrade.sh /path/to/your-project --dry-run    # ดูก่อนว่าจะเปลี่ยนอะไร
bash scripts/ow-upgrade.sh /path/to/your-project --rollback   # ย้อนกลับ backup ล่าสุด
```

upgrade ไม่แตะ: CLAUDE.md, vault content, `.ow/rules/` content,
agent ที่ project customize (specialized), ค่าใน `.ow.yml` ที่มีอยู่แล้ว (backfill เฉพาะ block ใหม่)

## คำสั่ง (22)

| กลุ่ม | คำสั่ง |
|---|---|
| ช่วยเหลือ | `/ow-help` |
| ตั้งค่า | `/ow-init` |
| Spec-driven | `/ow-new` · `/ow-clarify` · `/ow-plan` · `/ow-checklist` · `/ow-implement` · `/ow-fix` |
| GitHub issues | `/ow-triage-issues` · `/ow-fix-issue` |
| เอกสาร + ทดสอบ | `/ow-doc` · `/ow-test` · `/ow-design` · `/ow-evidence` |
| ย้อนกลับ | `/ow-reverse-engineer` |
| ส่งมอบ | `/ow-trace` · `/ow-review` · `/ow-secure` · `/ow-verify` · `/ow-git` · `/ow-release` · `/ow-handoff` |

Workflow ตัวอย่าง (project ใหม่):

```
/ow-init → /ow-new → /ow-clarify → /ow-plan <feature>
→ [review + approve plan] → /ow-implement <plan> → /ow-test
→ /ow-secure → /ow-verify → /ow-git --plan <plan>
```

แก้บั๊ก:

```
/ow-fix "<อาการ>" → (เล็ก: แก้เลย | ใหญ่: /ow-plan fix:<slug> → /ow-implement)
→ /ow-test --since <sha> → /ow-git --fix <fix-log>
```

## โครงสร้าง repo

```
.ow/                 toolkit core
├── STANDARD.md        5-step pipeline + Definition of Done
├── policies/          no-fake-evidence · source-of-truth · working-result
├── checklists/        before-start · before-commit · before-release · before-handoff · code-review
├── templates/         doc templates (ที่เดียว — customize แก้ไฟล์ในนี้ตรงๆ)
├── commands/          full command specs (22)
└── rules/             กติกาเฉพาะ project ต่อ area
.claude/
├── commands/          shims → .ow/commands/ (GENERATED — model pin มาจาก .ow.yml commands:)
└── agents/            subagents 9 ตัว (backend, frontend, mobile, design, docs,
                       security, test-runner, verifier, gh-issue)
scripts/
├── ow-paths.sh        config/path resolver (yq) — ทุก command ใช้ตัวนี้ ไม่ hardcode path
├── ow-claude-manifest.sh  gen shims + sync agent model จาก .ow.yml (--apply)
├── ow-config-merge.sh additive backfill block ใหม่เข้า .ow.yml เดิม (ใช้โดย upgrade)
├── ow-upgrade.sh      refresh install เดิม (--dry-run / --rollback)
└── test.sh            smoke tests ของ toolkit (bash scripts/test.sh)
docs/vault/            Obsidian vault skeleton (00-Index … 95-Handoff)
.ow.yml              project config (vault path, subagents+model, commands model, guardrails, …)
CLAUDE.md              คำสั่งหลักสำหรับ Claude Code
install.sh             copy toolkit เข้า project อื่น
```

## Vault layout

| Folder | เก็บอะไร |
|---|---|
| `00-Index/` | MOCs + IMPLEMENTATION-STATUS (single source of truth ของ status) |
| `10-PRD/` | `PRD-*.md` (intent) + `SRS-*.md` (system contract) |
| `20-Features/` | `FEAT-*.md` |
| `30-Roles/` | มุมมองต่อ role |
| `40-Functions/` | `FN-*.md` — spec ละเอียดต่อ screen/endpoint ผูก FR |
| `50-Phases/` | `PHASE-*.md` |
| `60-Flows/` | `FLOW-*.md` |
| `70-Reference/` | TechStack · AuthorizationMatrix · APIIntegration · `ADR/` · `DesignSystem/` · `Runbooks/` |
| `80-ImplementPlan/` | plan files (สร้างโดย `/ow-plan`) |
| `85-FixLog/` | fix logs (สร้างโดย `/ow-fix`) + postmortems (`PM-*.md` ผ่าน `/ow-doc`) |
| `90-TestPlan/` | `TP-*.md` |
| `95-Handoff/` | `HANDOFF-*.md` — session handoff notes |

Evidence (screenshot/log) อยู่นอก vault: `test-artifacts/<date>/<source>-<NN>-<slug>/EVIDENCE.md` (gitignored, local-only)

## ปรับแต่ง

- **Template ต่อ project** — copy `.ow/templates/<name>.md` → `templates/<name>.md` แล้วแก้
- **กติกาต่อ area** — เขียน `.ow/rules/<area>.md` (`applies_to` frontmatter) — override generic guidance
- **Model ต่อ command** — `.ow.yml` `commands.model` (default ทุกตัว; `inherit` = ตาม session)
  + `commands.overrides.<verb>: opus|sonnet|haiku|claude-*` แล้วรัน
  `bash scripts/ow-claude-manifest.sh --apply`
- **Model ต่อ agent** — `.ow.yml` `subagents.<name>.model: opus|sonnet|haiku` แล้วรัน
  `bash scripts/ow-claude-manifest.sh --apply` (อย่าแก้ frontmatter ตรงๆ — sync รอบถัดไปจะทับ)
- **Vault นอก repo** — `.ow.yml` `vault_path:` เป็น absolute path ได้
