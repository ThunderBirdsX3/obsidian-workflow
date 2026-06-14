# Getting Started — obsidian-workflow

เริ่มใช้ toolkit ตั้งแต่ติดตั้งจนปิด feature แรก — ใช้เวลาอ่าน ~5 นาที
Reference ฉบับเต็มอยู่ที่ [USAGE.md](USAGE.md)

## ต้องมีก่อน

| เครื่องมือ | ทำไม | ติดตั้ง |
|---|---|---|
| Claude Code | ตัวรัน command ทั้งหมด | [claude.com/claude-code](https://claude.com/claude-code) |
| `yq` | hard requirement — ทุก command อ่าน `.ow.yml` ผ่าน `scripts/ow-paths.sh` | `brew install yq` |
| `jq` | สำหรับ output `--json` | `brew install jq` |
| `git` | version control + worktree mode | มากับ Xcode CLT |
| `gh` CLI | เฉพาะถ้าใช้ `/ow-triage-issues`, `/ow-fix-issue` | `brew install gh` |
| Obsidian | (optional) เปิดดู vault สวยๆ — ไม่มีก็ใช้ได้ ไฟล์เป็น markdown ธรรมดา | [obsidian.md](https://obsidian.md) |

## ขั้น 1 — ติดตั้งเข้า project

```bash
cd /path/to/your-project
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/bootstrap.sh) .
```

> ไม่ต้อง clone ก่อน — bootstrap.sh ดึง toolkit มาเองแล้ว install ให้เลย  
> ใช้ `.` = project ปัจจุบัน, หรือระบุ path เต็มก็ได้

<details>
<summary>หรือ clone ก่อน (ถ้าต้องการ)</summary>

```bash
git clone https://github.com/ThunderBirdsX3/obsidian-workflow.git
bash obsidian-workflow/install.sh /path/to/your-project
```

</details>


install.sh จะ:

- copy `.ow/` (STANDARD, policies, checklists, templates, command specs)
- generate `.claude/commands/ow-*.md` shims + copy `.claude/agents/` (9 subagents)
- copy `scripts/ow-paths.sh` + ตัวช่วย + `scripts/ow-upgrade.sh`
- สร้าง `.ow.yml` (ถ้ายังไม่มี — ของเดิมไม่ทับ)
- สร้าง vault skeleton ที่ `docs/vault/` (ถ้ายังไม่มี)
- เติม `.gitignore` block (`test-artifacts/`, `worktrees/`, …)

> ไฟล์เดิมของ project ปลอดภัย: `.ow.yml`, `CLAUDE.md`, vault content ที่มีอยู่ —
> ไม่ถูกเขียนทับ

## ขั้น 2 — เปิด Claude Code แล้ว init

```bash
cd /path/to/your-project
claude
```

ใน Claude Code:

```
/ow-init
```

จะถามชื่อ project, ตำแหน่ง vault, subagents ที่จะเปิด แล้วเขียนลง `.ow.yml`

- โปรเจกต์ใหม่เอี่ยม → mode **greenfield** (default ถ้าไม่มี code)
- มี code อยู่แล้ว → `/ow-init --brownfield` แล้วต่อด้วย `/ow-reverse-engineer`
  เพื่อ extract spec จาก code (ดู [USAGE.md §3.2](USAGE.md#32-มี-code-อยู่แล้ว-ไม่มี-spec-brownfield))

## ขั้น 3 — สร้าง spec

```
/ow-new ระบบจัดการ todo สำหรับทีม มี assign + due date
```

Claude จะ brainstorm กับคุณ → สร้าง 3 ไฟล์ใน `docs/vault/10-PRD/`:

| ไฟล์ | ตอบคำถาม |
|---|---|
| `PRD-<slug>.md` | **ทำไม** ต้องมี (intent — สั้น) |
| `SRS-<slug>.md` | **ระบบทำอะไร แค่ไหน ตรวจยังไง** — FR/NFR + acceptance Given/When/Then ทุกข้อ |
| `Tech-<slug>.md` | สร้าง**ยังไง** — stack, architecture |

SRS คือ contract — ทุกงานหลังจากนี้ผูกกลับ FR-### ใน SRS

แนะนำต่อด้วย:

```
/ow-clarify
```

สแกนหาจุดกำกวมใน SRS แล้วถามทีละข้อ (มีคำตอบแนะนำให้) — ตอบเสร็จเขียนกลับเข้า spec ให้เอง

## ขั้น 4 — วางแผน feature แรก

```
/ow-plan สร้าง todo CRUD + assign ให้สมาชิกทีม
```

ได้ plan file ที่ `docs/vault/80-ImplementPlan/2026-06-13-1430-todo-crud.md` —
ระบุ FR ที่ครอบคลุม, ไฟล์ที่จะแตะ, ขั้นตอน, test plan **โดยไม่แตะโค้ดแม้แต่บรรทัดเดียว**

### 🔑 จุดสำคัญที่สุดของ workflow

เปิด plan file อ่าน → เห็นด้วย → แก้ frontmatter:

```yaml
status: approved        # จาก draft
```

`/ow-implement` ปฏิเสธ plan ที่ยังไม่ approved — นี่คือ gate ที่มนุษย์ควบคุม

## ขั้น 5 — ลงมือ

```
/ow-implement todo-crud
```

Claude execute plan ผ่าน subagent → เขียนโค้ด → รัน test จริง → เก็บ evidence ลง
`test-artifacts/<date>/plan-…-todo-crud/EVIDENCE.md` → sync status ใน vault

## ขั้น 6 — ตรวจ + ส่งมอบ

```
/ow-test                      ← smoke test ส่วนที่เปลี่ยน
/ow-secure                    ← scan secrets/PII ก่อน push
/ow-git --plan docs/vault/80-ImplementPlan/2026-06-13-1430-todo-crud.md
```

จบ — commit + push เรียบร้อย พร้อม trace ได้ครบ: SRS → plan → code → evidence → commit

## หลังจากนั้น

| สถานการณ์ | คำสั่ง |
|---|---|
| อยาก upgrade toolkit | `bash scripts/ow-upgrade.sh` |
| เจอบั๊ก | `/ow-fix "<อาการ>"` — diagnose ก่อน ไม่แตะโค้ด |
| มี GitHub issues ค้าง | `/ow-triage-issues` → `/ow-fix-issue` |
| อยากรู้ FR ไหนเสร็จ/ขาด | `/ow-trace --gaps` |
| ตรวจโค้ดเทียบ spec ก่อนปิดงาน | `/ow-review <plan>` |
| พร้อมปล่อย version | `/ow-release minor` |
| เลิกงานกลางคัน | `/ow-handoff` — session หน้าอ่านต่อได้ทันที |
| งง ไม่รู้ใช้ตัวไหน | `/ow-help` |

## สรุป mental model

```
spec (SRS = contract) ──► plan (ไฟล์, รอ approve) ──► implement (โค้ด + evidence)
                                                          │
        ship ◄── git/release ◄── verify/secure/review ◄───┘
```

กฎเหล็ก 3 ข้อ:

1. **ไม่มี spec → เขียน spec ก่อน** (`/ow-new`, `/ow-doc`, หรือ `/ow-reverse-engineer`)
2. **ไม่มี approved plan → ห้ามแตะโค้ด** (`/ow-plan` → คุณ approve → `/ow-implement`)
3. **ไม่มี evidence → งานยังไม่จบ** (ทุก claim ตรวจกลับได้ ไม่งั้นเขียน `pending evidence`)
