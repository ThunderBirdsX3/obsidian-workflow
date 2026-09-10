# obsidian-workflow

**AI + Obsidian docs-driven development workflow** สำหรับทีมที่ใช้ AI ทำงาน — รวม spec-kit philosophy และ Obsidian vault patterns

> 21 slash commands · 4 always-on + 5 on-demand AI subagents (per-agent + per-command AI model in `.ow.yml`) · 7 AI front-ends (Claude · Codex · Gemini · GPT · GLM · Cline · Kimi) · config-driven, works for any project (single-repo or submodule monorepo) · the vault stays text-only — command output is quoted into the doc, never stored as a file

---

## ⚡ Quick start

> **Prerequisite (v0.7+):** `yq` is required — the resolver parses YAML lists/nested keys and
> fails closed without it. `brew install yq` / `apt install yq` / https://github.com/mikefarah/yq

### 1. ติดตั้ง (one-line)

```bash
# 0. ติดตั้ง yq ก่อน (จำเป็น): brew install yq
# Greenfield (folder ใหม่)
mkdir my-project && cd my-project
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)

# Brownfield หรือ folder ที่ setup ไว้แล้ว
cd existing-project
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
```

> หรือ clone เองแล้ว install จาก local source:
>
> ```bash
> git clone --depth 1 https://github.com/ThunderBirdsX3/obsidian-workflow.git /tmp/obsidian-workflow
> bash /tmp/obsidian-workflow/scripts/install.sh --source /tmp/obsidian-workflow .
> ```

ตอน install จะถาม **3 คำถาม:**

1. **โหมดไหน?** ถ้าตรวจเจอ indicators (package.json, src/, .git+commits, docs/) → ถาม greenfield / brownfield / adopt-vault
2. **Vault อยู่ที่ไหน?**
   - A) `docs/obsidian-vault/` (default — แยกจาก docs/ เผื่อมีเอกสารอื่น)
   - B) `docs/` (project เล็ก)
   - C) ระบุ path เอง
   - D) external vault (path นอก repo)
3. **AI agent?** เลือกได้หลายตัว: claude / codex / google / gpt / glm / all (default: claude)

### 2. รัน command แรก

เปิด Claude Code (หรือ AI ตัวที่ติดตั้ง) ใน folder แล้ว:

```
/ow-init        ← interactive config + Obsidian context manifest
```

ถ้าไม่รู้จะใช้ command ไหน:

```
/ow-help        ← ถาม "จะทำอะไร" แล้วแนะนำ command
```

### 3. ทดสอบ install สำเร็จ

```bash
ow doctor     # health check (also lists missing personal/gitignored files)
```

> `ow test` (smoke tests) เป็นคำสั่งของ **source checkout** เท่านั้น — ไม่ได้ติดตั้งในโปรเจกต์ของคุณ ใช้ `ow doctor` เพื่อ verify install

---

## 🎯 21 Commands

| กลุ่ม | Commands |
|---|---|
| **ช่วยเหลือ + ตั้งค่า** | `/ow-help` `/ow-init` `/ow-reverse-engineer` `/ow-sync` `/ow-agent` |
| **Spec-driven cycle** | `/ow-new` `/ow-clarify` `/ow-plan` `/ow-split` `/ow-checklist` `/ow-implement` `/ow-fix` |
| **GitHub issues** | `/ow-triage-issues` `/ow-fix-issue` |
| **เอกสาร + ทดสอบ + ออกแบบ** | `/ow-doc` `/ow-test` `/ow-design` |
| **ส่งมอบ** | `/ow-secure` `/ow-verify` `/ow-handoff` `/ow-git` |

**Usage guide ละเอียด:** [`usage/README.md`](./usage/README.md) — 1 ไฟล์ต่อ command

---

## 📋 Workflows พบบ่อย

### A. เริ่ม project ใหม่

```bash
ow init my-app                    # install
cd my-app
# เปิด Claude Code
```

```
/ow-init                                ← config
/ow-new                                 ← brainstorm → PRD + SRS + Tech-spec
/ow-design init                         ← (optional) design system + preview.html
/ow-plan FEAT-X                         ← วางแผน feature
# [user review plan ใน docs/obsidian-vault/80-ImplementPlan/, mark status: approved]
/ow-implement docs/obsidian-vault/80-ImplementPlan/... ← ลงมือทำจริง (inline หรือ delegate ให้ subagent ตามงาน)
/ow-test                                ← smoke test
/ow-verify                              ← ตรวจครบ (tests/vault/security/DS)
/ow-handoff                             ← สร้าง HOR-*.md ส่ง reviewer
/ow-git --plan <path>                   ← commit + push
```

> ✂️ **Plan ใหญ่เกินไป?** — `/ow-split <plan>` แตกเป็น sub-plan ที่จบในตัว + CONTRACT ร่วม 1 ไฟล์
> รันทีละตัวคนละ session (`/clear` คั่น) → พอดี model context 200K และลด token สะสม · ปิดงานด้วย `/ow-verify <parent>`

> 🌳 **Worktree mode** (#31) — เติม `--worktree` ที่ `/ow-plan` → `/ow-implement` build ใน worktree แยก
> (กัน main tree ไม่ถูกแตะ — งาน uncommitted คู่ขนานปลอดภัย), `/ow-test` **auto-merge กลับ branch ตอน smoke PASS**
> (local, ไม่ push). conflict/dirty = STOP เก็บ worktree ไว้ (ไม่ลบงาน uncommitted ของคุณ)

> 👥 **ทำงานหลายคน** — `/ow-git` fetch + rebase กับ origin ให้ก่อน commit/push **ทุกครั้ง** (`--no-sync` ปิดเฉพาะรอบนั้น);
> push โดน teammate แซง → sync ใหม่แล้ว push ซ้ำเอง **ไม่เคย force**; conflict ที่ไม่มีกฎตายตัว = rebase ค้างไว้ให้คนแก้ (ไม่ commit อะไรทั้งนั้น)
> · งาน uncommitted ตอน sync = `--autostash` คืนให้เอง; คืนแล้วชน → หยุดเหมือน conflict ปกติ และงานอยู่ครบทั้งใน marker และใน stash
> · แค่ดึงงานล่าสุด → `/ow-git --pull` · ดูว่าตามหลังแค่ไหน → `/ow-git --status`
> · auto-resolve เฉพาะที่มีกฎตายตัว (version / lock / CHANGELOG / ตาราง-ลิสต์ใน vault) และ **ขึ้นรายงานทุกไฟล์** — ปรับที่ `git.auto_resolve`

### B. แก้บั๊ก

```
/ow-fix "search ค้างเมื่อใส่ขีดล่าง"     ← diagnose + fix-log (no code)
/ow-plan fix:<slug>                     ← small plan
/ow-implement <plan>                    ← แก้จริง
/ow-test --since <ref>                  ← verify
/ow-verify                              ← handoff
```

### C. GitHub issues — triage → fix → ส่ง tester

```
/ow-triage-issues                       ← snapshot bug pool → classify + label + cluster (STOP ยืนยันก่อนแตะ GitHub)
/ow-fix-issue #62 #63                    ← worktree แยก → diagnose + test + RED/GREEN + fix + merge local
/ow-test --since <ref>                  ← smoke เฉพาะ area/role ที่ fix แตะ
/ow-git --bump patch                    ← push + bump
                                            └─ 🟢 auto: commit มี Closes #NN → comment "fixed in vX.Y.Z" + flip label ready-for-test
# [tester verify บน vX.Y.Z แล้ว close issue]
```

> `/ow-git --no-ready-for-test` ปิด auto-handoff · สั่งเองภายหลังได้ด้วย `/ow-fix-issue #NN --ready-for-test [--version X.Y.Z]`
> 🔴 triage = read-only ต่อโค้ด · fix-issue ไม่ push เอง · close = tester เท่านั้น (verify ก่อน)

### D. Brownfield adopt (มี code อยู่แล้ว)

```bash
cd existing-project
bash <(curl -fsSL .../install.sh)
# เลือก mode: brownfield หรือ adopt-vault
# เลือก AI: claude (หรือ multi)
# ถ้ามี .claude/agents|commands เดิมของคุณ → installer ถาม keep-all / remove-all / select
#   (ไม่ใช่ของ obsidian-workflow จะไม่ถูกแตะ; user agent ไม่มี §0 ไม่ทำให้ install ล้ม)
```

```
/ow-init --brownfield                   ← config + vault skeleton + rules scaffolds
/ow-reverse-engineer                    ← scan โค้ด → draft FEAT/FN/REF docs
/ow-clarify FEAT-<slug>                 ← scan ambiguity ใน draft
/ow-plan <first task>                   ← เริ่ม workflow ปกติ
```

> **เพื่อนร่วมทีม clone repo ที่ adopt แล้ว?** ไฟล์ส่วนตัว (gitignored) จะยังไม่มี —
> รัน `ow init --local` เพื่อสร้างเฉพาะไฟล์ที่ขาด (`.ow.local.yml`, `.ow/local/`)
> โดยไม่แตะไฟล์ shared เลย (idempotent — รันซ้ำได้ no-op)

---

## ⚙️ Configuration

| ไฟล์ | gitTracked? | ใช้สำหรับ |
|---|---|---|
| `.ow.yml` | ✅ | shared — project name, vault path, subagents, submodules, AI agents, `git:` sync (ทีมหลายคน) |
| `.ow.local.yml` | ❌ | personal — external vault, GDrive folder, secrets path |
| `.ow/local/commands/` | ❌ | personal slash commands |
| `.ow/local/templates/` | ❌ | personal template overrides |

**Template lookup chain (สูง → ต่ำ):**
1. `.ow/local/templates/<name>.md` (personal)
2. `templates/<name>.md` (project — แก้ + commit ได้)
3. `.ow/templates/<name>.md` (org canonical — read-only, sync override)

ดูตัวอย่างใน [`.ow.local.yml.example`](./.ow.local.yml.example)

---

## 🤖 Multi-AI

obsidian-workflow ทำงานกับ AI ทุกตัวที่อ่าน markdown ได้:

| AI | Reads | Entry point |
|---|---|---|
| Claude Code | `.claude/` | slash commands `/ow-*` |
| Cline (VS Code) | `AGENTS.md` + `.agents/skills/` | slash commands `/ow-*` |
| Kimi Code CLI | `AGENTS.md` + `.agents/skills/` | `/skill:ow-init` |
| Codex CLI | `AGENTS.md` + `.agents/skills/` | `codex run "ow-init"` |
| Google Gemini | `gemini/prompts/` | `gemini chat --system "$(cat gemini/prompts/system.md)"` |
| ChatGPT | `gpt/prompts/` | paste `gpt/prompts/system.md` ใน chatgpt.com |
| Zhipu GLM | `glm/prompts/` | paste `glm/prompts/system.md` ใน chatglm.cn |

Cline · Kimi · Codex share ONE neutral bundle — a root `AGENTS.md` plus generated
`.agents/skills/<verb>/SKILL.md`. Only the invocation syntax differs.

รายละเอียด: [`AI-README.md`](./AI-README.md)

---

## 🛡️ กฎที่บังคับใช้

ทุก command ตอบเป็น **bullet สรุปสั้น** ภาษาตาม `project.language` — ทำอะไร/แก้อะไร · หลักฐานที่ตรวจจริง · เสี่ยง/ต่อไป (เมื่อมี). ไม่บังคับ 5-header ยาว

**Policies (ห้ามฝ่าฝืน):**
- ห้าม fake ผลลัพธ์ — ห้ามอ้าง test ผ่านโดยไม่รัน, ยังไม่ได้ตรวจ = `pending verification`
- ห้ามแต่ง commit hash, URL, token count
- Plan/Implement แยกกัน — `/ow-plan` ไม่แตะโค้ด
- Vault-first — อ่าน `<vault_path>/` (default `docs/obsidian-vault/`) ก่อนถามคำถาม

อัพเดท obsidian-workflow: `/ow-sync` หรือ `ow sync`

ดู:
- [`CHANGELOG.md`](./CHANGELOG.md) — version history

---

## 📦 Distribution (สำหรับ maintainer ของ obsidian-workflow)

obsidian-workflow ใช้ pattern คล้าย **spec-kit** — distribute ผ่าน git + bash installer

### Release flow

```bash
# 1. Update VERSION + CHANGELOG.md
echo "0.3.0" > VERSION
# Edit CHANGELOG.md เพิ่ม section ใหม่

# 2. Commit
git add -A
git commit -m "release: v0.3.0"

# 3. Tag
git tag v0.3.0
git push origin main --tags

# 4. Done — users ได้ updated version ผ่าน /ow-sync หรือ ow upgrade
```

### User install URL patterns

```bash
# Latest from main
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)

# Pinned version
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/v0.2.0/scripts/install.sh)

# Local development (after git clone)
bash obsidian-workflow/scripts/install.sh --source obsidian-workflow --target ./my-app
```

### Upgrade existing project

```bash
# In any obsidian-workflow project:
ow upgrade              # pull latest, preserves templates/ docs/ configs
ow upgrade --version v0.3.0
ow upgrade --rollback   # restore from backup
```

---

## 🧪 Development

```bash
# Test suite
bash scripts/test.sh           # 531 smoke tests
bash scripts/test.sh -v        # verbose
bash scripts/test.sh --filter <kw>  # filter by keyword

# Doctor
bash bin/ow doctor

# Paths config
bash scripts/ow-paths.sh --json
bash scripts/ow-paths.sh --check VAULT_ABS

# Try install locally (dry-run)
bash scripts/install.sh --source $(pwd) --target /tmp/test-ow --dry-run
```

### Helper scripts — inventory

รายละเอียดของแต่ละตัว (rationale · contract · exit codes) อยู่ใน **header comment ของสคริปต์เอง** — ตารางนี้เก็บแค่ว่ามีอะไร ใครเรียก

`scripts/` + `bin/` เป็น **mixed-ownership**: upgrade refresh **ทีละไฟล์ตาม manifest** (`ow-owned.sh`) ไม่เคย `rm -rf` ทั้ง dir ⇒ สคริปต์ที่ host เขียนเองรอดทุกรอบ upgrade + rollback

| ไฟล์ | หน้าที่ |
|---|---|
| `ow-paths.sh` | config + path resolver — single source ของทุก path/flag (`--shell` `--rules` `--submodules` `--agent-model` `--command-model` `--selftest`) |
| `ow-safe-paths.sh` | protected-set (`SAFE_PATHS`) — install + upgrade + sync ใช้ร่วมกัน |
| `ow-owned.sh` | owned-file manifest ของ `scripts/` + `bin/` |
| `ow-claude-md.sh` | canonical `CLAUDE.md` managed-block merge — block content อยู่ใน `CLAUDE.md` ที่ ship มา, นอก marker ไม่เคยถูกแตะ |
| `ow-gitignore.sh` | canonical `.gitignore` managed-block — merge เฉพาะ block นี้ ไม่แตะบรรทัดเดิมของ host |
| `ow-git-sync.sh` | multi-person git sync — fetch + rebase ก่อน stage, auto-resolve เฉพาะ class ที่มีกฎ deterministic. **exit code คือ contract** (0 ok · 3 conflict → caller STOP · 4 skipped · 5 tag collision). ไม่เคย force-push ไม่เคย resolve เงียบ |
| `ow-version.sh` | canonical version-file writer ของ `/ow-git --bump` — tag = `v<X.Y.Z>` แต่ **ไฟล์เป็น bare `<X.Y.Z>`** (pubspec/package.json ไม่รับ `v`). **ตัวเดียวที่หายแล้ว `--bump` ต้อง STOP** ไม่ใช่ degrade |
| `ow-claude-manifest.sh` | `.claude` ownership + `generate_shims` (override-first) + `apply_agent_models` |
| `ow-shims.sh` · `ow-frontends.sh` | สร้าง shim · จัดการ AI frontend dir ที่เปิดใช้ |
| `ow-config-merge.sh` | additive block merge ของ `.ow.yml` + `.ow.local.yml` — backfill block ใหม่ ไม่ทับค่าที่ user กรอกไว้ ไม่ใช้ `yq -i` (คอมเมนต์รอด) |
| `conformance-lint.sh` | 12-check hard gate — รันโดย sync/install/upgrade |
| `ow-verify-vault-lang.sh` | gate ภาษา vault (#33) — เรียกจาก `/ow-secure` Phase 2.5 |
| `ow-verify-vault-style.sh` | gate "vault เขียนสถานะปัจจุบัน" — เรียกจาก `/ow-secure` Phase 2.6 |
| `upgrade.sh` | bump version + re-exec handoff ⇒ migration ใหม่สุดรันจบใน **รอบเดียว** |
| `bin/ow {doctor,lint}` | health check + conformance lint |

**source-only — ไม่ติดตั้งลง user project:** `scripts/install.sh` (bootstrap ที่ curl ดึง) · `scripts/test.sh` (smoke test ของ repo นี้)

> **hard prerequisite:** ต้องมี `yq` — resolver + installer fail-closed ถ้าไม่มี

> **install:** `.claude` agents/commands ของ user ที่มีอยู่ก่อน จะถูกถามว่า keep-all / remove-all / select (non-interactive default = keep + warn, บันทึกที่ `.ow/local/adopt.marker`) · `init` scaffold `.ow/rules/<area>.md` ตาม area ที่เปิด · `ow init --local` สร้างเฉพาะไฟล์ส่วนตัวที่ขาด สำหรับเพื่อนร่วมทีมบน repo ที่ clone มา

---

## 📂 โครงสร้าง

```
.
├── README.md                  ← คุณอยู่ที่นี่
├── AI-README.md               ← Multi-AI usage
├── CLAUDE.md                  ← Claude project entry
├── CHANGELOG.md               ← version history
├── .ow.yml              ← shared config (gitTracked)
├── .ow.local.yml.example← personal config template
├── .gitignore
│
├── usage/                     ← 20+1 user-facing usage docs (Quick start, FAQ, gotchas)
├── .claude/
│   ├── commands/              ← Claude slash command shims (5 lines each, @.ow/commands/…)
│   ├── agents/                ← every subagent that exists. obsidian-workflow ships the 4 always-on ones; specialized agents are written here by /ow-agent create <name> against this project's stack, disable moves one away. Per-agent AI model: .ow.yml subagents.<name>.model
│   └── settings.json
├── AGENTS.md                  ← shared entry point (Cline · Kimi · Codex)
├── .agents/skills/            ← generated skill per verb (Cline · Kimi · Codex)
├── codex/                     ← Codex notes (routing lives in root AGENTS.md)
├── cline/                     ← Cline notes
├── kimi/                      ← Kimi Code notes
├── gemini/                    ← Gemini prompts + generated router
├── gpt/                       ← ChatGPT prompts + generated router
├── glm/                       ← Zhipu GLM prompts + generated router
├── prompts/general-ai/        ← Generic AI prompts
│
├── .ow/                         ← all obsidian-workflow machinery
│   ├── templates/                     ← canonical templates
│   ├── rules/                         ← project's own rules (never synced)
│   └── commands/                      ← 21 source-of-truth verb specs (Phase descriptions)
│       └── _shared/                   ← fragments a verb spec reads on demand at the phase that needs them (coding-discipline · context-refs · vault-doc-style · worktree · worktree-merge · worktree-cleanup-gate · delegation · design-process · build-test · fixlog-close · fix-issue-fix-flow · fix-issue-ready-for-test · git-sync · git-post-push)
├── commands/                  ← OPTIONAL project override layer (lookup: root → .ow/commands/)
├── templates/                 ← OPTIONAL project override layer (lookup: root → .ow/templates/)
│
├── scripts/                   ← bash helpers
│   ├── ow-paths.sh           ← config resolver [installed to user project]
│   ├── upgrade.sh             ← bump obsidian-workflow [installed to user project]
│   ├── install.sh             ← one-line bootstrap (obsidian-workflow source-only; fetched via curl)
│   └── test.sh                ← smoke tests for obsidian-workflow source (NOT installed)
├── bin/
│   └── obsidian-workflow               ← CLI wrapper
│
└── docs/                      ← top-level docs folder
    └── obsidian-vault/        ← Obsidian vault (default vault_path)
        ├── 00-Index/          ← MOCs + IMPLEMENTATION-STATUS
        ├── 10-PRD/ 20-Features/ 30-Roles/ 40-Functions/
        ├── 50-Phases/ 60-Flows/
        ├── 70-Reference/      ← TechStack, Auth, API, DesignSystem
        ├── 80-ImplementPlan/ 85-FixLog/
        ├── 90-TestPlan/ 95-Handoff/
```

> 🔴 **เอกสารใน vault = สถานะปัจจุบัน** — โฟลเดอร์ `00-Index` … `70-Reference` เขียนได้เฉพาะสิ่งที่จริง ณ วันนี้
> (ห้าม "เดิม X → ใหม่ Y" ห้ามหัวข้อ `## Changelog`) · before/after อยู่ใน `80-ImplementPlan` `85-FixLog`
> `90-TestPlan` `95-Handoff` เท่านั้น — สัญญา: `.ow/commands/_shared/vault-doc-style.md` ·
> gate: `scripts/ow-verify-vault-style.sh` (`/ow-secure` Phase 2.6)

> Default vault path = **`docs/obsidian-vault/`** — แยกออกจาก `docs/` เพื่อให้ใช้ `docs/` เก็บเอกสารอื่นได้
> (README, ARCHITECTURE.md, public API docs, build docs, contribution guides, ฯลฯ)
> เปลี่ยน path ตอน install ได้ (4 options A/B/C/D)

---

## 🔗 Acknowledgements

- [spec-kit](https://github.com/github/spec-kit) — Plan-driven AI development philosophy

## License

MIT — see `LICENSE`
