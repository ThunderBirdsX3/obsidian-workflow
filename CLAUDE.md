# CLAUDE.md — obsidian-workflow

โปรเจกต์นี้ใช้ **obsidian-workflow** — spec-driven development ที่มี Obsidian vault เป็น source of truth: เอกสารลึกถึงระดับ SRS, แผนแยกจากการลงมือ, ทุกผลลัพธ์มี evidence

## หัวใจ 4 ข้อ

1. **Vault-first** — Claude อ่าน vault (`docs/vault/`) ก่อนถามคำถาม หรือเขียนโค้ด เสมอ
2. **SRS คือ contract** — PRD ตอบ "ทำไม" (สั้นได้); **SRS ตอบ "ระบบทำอะไร แค่ไหน ตรวจยังไง"** —
   ทุก FR มี acceptance Given/When/Then; งานที่ไม่มี spec รองรับ → เขียน spec ก่อน
3. **Plan/Implement แยกกัน** — `/ow-plan` สร้าง plan file (ไม่แก้โค้ด), `/ow-implement` เท่านั้นที่แก้โค้ด, `/ow-fix` แค่ diagnose
4. **No fake evidence** — ทุก claim มี evidence ตรวจได้; ไม่มี = เขียน `pending evidence`

## เริ่มต้น

| สถานการณ์ | คำสั่ง |
|---|---|
| Project ยังไม่มี vault | `/ow-init` |
| ไอเดียใหม่ ยังไม่มี PRD | `/ow-new` แล้วเลือก `brainstorm` |
| มี PRD อยู่แล้ว อยากต่อ SRS/Tech | `/ow-new --import <path>` |
| มี code อยู่แล้ว ไม่มี spec | `/ow-reverse-engineer` |
| spec กำกวม/ไม่ครบ | `/ow-clarify` |
| วางแผน feature/task | `/ow-plan <task>` |
| ลงมือทำตาม plan | `/ow-implement <plan-file>` |
| แก้บั๊ก | `/ow-fix <bug>` |
| อยากรู้ว่า FR ไหนทำแล้ว/ขาดอะไร | `/ow-trace` |
| ตรวจโค้ดเทียบ SRS ก่อนปิดงาน | `/ow-review` |
| ปล่อย version ใหม่ | `/ow-release` |
| พักงาน/ต่อ session หน้า | `/ow-handoff` |

## คำสั่งทั้งหมด (22 ตัว)

```
ช่วยเหลือ:        /ow-help        ← ถ้าไม่รู้จะใช้ตัวไหน
ตั้งค่า:          /ow-init
spec-driven:     /ow-new         /ow-clarify    /ow-plan
                 /ow-checklist   /ow-implement  /ow-fix
GitHub issues:   /ow-triage-issues                /ow-fix-issue
เอกสาร+ทดสอบ:    /ow-doc         /ow-test       /ow-design     /ow-evidence
ย้อนกลับ:         /ow-reverse-engineer             ← extract spec จาก code ที่มีอยู่
ส่งมอบ:           /ow-trace       /ow-review     /ow-secure     /ow-verify
                 /ow-git         /ow-release    /ow-handoff
```

ดู `.ow/commands/` (source) หรือพิมพ์ `/ow-` ใน Claude Code แล้วกด Tab

**ไม่รู้จะเริ่มที่ไหน?** → `/ow-help` แล้วตอบคำถาม → จะแนะนำ command ที่ตรงสถานการณ์

## Spec-driven workflow

```
/ow-new        — สร้าง PRD (intent) → SRS (contract — FR/NFR/state/error) → Tech spec
/ow-clarify    — taxonomy ambiguity scan (1-at-a-time + recommended answer)
/ow-plan       — research vault + create plan ผูก FR-### + policy check gate
/ow-checklist  — "unit tests for English" — spec-quality gate per domain
/ow-implement  — execute approved plan via specialized subagent
```

## หลักการที่บังคับใช้

ทุก output ของ Claude ต้องมี **3 หัวข้อบังคับ**:

1. **Result** — สรุปสิ่งที่ทำ + ไฟล์ที่สร้าง/แก้
2. **Verification / Evidence** — command ที่รันจริง + ผลลัพธ์
3. **Limitations / Next steps** — ข้อจำกัด ความเสี่ยง งานต่อ

**ห้ามเด็ดขาด:**
- ห้ามอ้าง test ผ่านโดยไม่ได้รัน
- ห้ามแต่ง commit hash, URL, test count
- ถ้าไม่มี evidence ให้เขียน `pending evidence`
- ห้ามแก้ shared repo หรือ production โดยไม่ confirm scope

## โครงสร้าง vault (`docs/vault/`)

```
00-Index/         MOCs, IMPLEMENTATION-STATUS
10-PRD/           PRD-*.md (intent) + SRS-*.md (system contract)
20-Features/      FEAT-*.md
30-Roles/         Role-based views
40-Functions/     Granular function specs (FN-*.md) — ผูก FR ใน SRS
50-Phases/        Phase planning (PHASE-*.md)
60-Flows/         User flows
70-Reference/     TechStack, AuthorizationMatrix, APIIntegration, ADR/, DesignSystem/, Runbooks/
80-ImplementPlan/ Implementation plans (YYYY-MM-DD-HHmm-<slug>.md)
85-FixLog/        Bug fix logs (YYYY-MM-DD-HHMM-<slug>.md) + postmortems (PM-<date>-<slug>.md)
90-TestPlan/      Test plans (text) — evidence = EVIDENCE.md manifest ใต้ test-artifacts/
95-Handoff/       Session handoff notes (HANDOFF-*.md)
```

Evidence binaries อยู่ **นอก vault** เสมอ: `test-artifacts/<date>/<source>-<NN>-<slug>/` (gitignored)

## Configuration

`.ow.yml` ที่ root กำหนด:
- `project`: name, slug, language, timezone
- `vault_path`: ตำแหน่ง vault (default: `docs/vault`; absolute path = external vault ได้)
- `subagents`: ตัวไหน enabled + AI model ต่อ agent — `<name>: { enabled: true, model: opus|sonnet|haiku }`
  (scalar `true` ก็ได้ = default model) — always-on: `docs`, `verifier`, `security`, `gh-issue`;
  on-demand: `backend`, `frontend`, `mobile`, `design`, `test-runner`
- `commands`: AI model ต่อ slash command — `model:` default ทุกตัว (`inherit` = ตาม session)
  + `overrides.<verb>:` pin รายตัว — ค่าถูก inject ลง shim `.claude/commands/ow-*.md` ตอน gen
- `submodules`: list submodules ถ้ามี
- `guardrails`, `evidence`, `verification_matrix`, `integrity_gate`, `rules` — ดู comment ในไฟล์

แก้ model ใน `.ow.yml` แล้วรัน `bash scripts/ow-claude-manifest.sh --apply` เพื่อ sync ลง
shim + agent frontmatter (install.sh / scripts/ow-upgrade.sh ทำให้อัตโนมัติอยู่แล้ว) — ห้าม hand-edit
`model:` ใน `.claude/` ตรงๆ เพราะรอบ sync ถัดไปจะทับ

ทุก command resolve path ผ่าน `scripts/ow-paths.sh` (ต้องมี `yq`) — ห้าม hardcode path

## โครงสร้าง toolkit

- `.ow/STANDARD.md` — 5-step pipeline + Definition of Done
- `.ow/policies/` — no-fake-evidence, source-of-truth, working-result
- `.ow/checklists/` — before-start, before-commit, before-release, before-handoff, code-review
- `.ow/templates/` — doc templates (ที่เดียว — customize โดยแก้ไฟล์ในนี้ตรงๆ)
- `.ow/commands/` — full command specs (`.claude/commands/` เป็น shim ชี้มาที่นี่)
- `.ow/rules/` — กติกาเฉพาะ project ต่อ area (override generic guidance)

## ภาษา

เอกสาร + log เป็นภาษาตาม `project.language` (default ไทย); code comments + frontmatter เป็นอังกฤษได้
