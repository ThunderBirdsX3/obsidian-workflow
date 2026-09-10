<!--
  obsidian-workflow — CLAUDE.md

  The block between the OW markers below is the SAME block that
  install/upgrade inject into a host project (scripts/ow-claude-md.sh is the
  single source of truth for the merge). Everything a consumer project needs
  belongs INSIDE it.

  Everything OUTSIDE the markers is this source repo's own dev prose and never
  reaches a host project; in a host project that space belongs to the host.
-->

<!-- OW START: workflow -->
# CLAUDE.md — obsidian-workflow

โปรเจกต์นี้ใช้ **obsidian-workflow** — AI + Obsidian docs-driven development ตาม spec-kit philosophy

## หัวใจ 3 ข้อ

1. **Vault-first** — อ่าน doc ใน `docs/` ที่เกี่ยวกับ task ก่อนถามหรือก่อนเขียนโค้ด (เฉพาะที่เกี่ยว ไม่ใช่ทั้ง vault)
2. **Plan/Implement แยกกัน** — `/ow-plan` สร้าง plan ไม่แก้โค้ด · **`/ow-implement` เท่านั้นที่แก้โค้ด** · `/ow-fix` diagnose + fix-log แล้วถามก่อน
3. **Log everything** — ทุก plan/fix มี log ใน vault บอกว่ารันอะไรจริง ผลออกมาอย่างไร

## คำสั่งทั้งหมด (21 ตัว)

ไม่รู้จะใช้ตัวไหน → `/ow-help` · spec ของแต่ละ verb อยู่ที่ `.ow/commands/<verb>.md` (โหมดย่อยอยู่ใน `_shared/` อ่านตอนโหมดนั้นยิง) · วิธีใช้อยู่ที่ `usage/`

```
ตั้งค่า:       /ow-init  /ow-sync  /ow-agent
spec-driven:  /ow-new  /ow-clarify  /ow-plan  /ow-split  /ow-checklist  /ow-implement  /ow-fix
GitHub:       /ow-triage-issues  /ow-fix-issue
เอกสาร+ทดสอบ: /ow-doc  /ow-test  /ow-design
ย้อนกลับ:      /ow-reverse-engineer   ← extract spec จาก code/db ที่มีอยู่
ส่งมอบ:        /ow-secure  /ow-verify  /ow-git  /ow-handoff
ช่วยเหลือ:     /ow-help
```

## คุยกับ user

ภาษาตาม `project.language` (`$PROJECT_LANG`, th default) — เขียนให้คนที่ไม่ได้อยู่ในโค้ดอ่านแล้วเข้าใจ ศัพท์เทคนิคใช้เท่าที่เลี่ยงไม่ได้ (ครั้งแรกวงเล็บอธิบายสั้น ๆ)

**สรุป / ตอบ** — ≤7 bullets · bullet ละ 1 บรรทัด ห้ามซ้อนย่อย · ผลลัพธ์ขึ้นก่อน เหตุผลตามหลังเฉพาะที่จำเป็น: ทำอะไร · หลักฐานที่รันจริง · เสี่ยง/ค้าง (มีค่อยเขียน)
- ห้าม: เกริ่นนำ · ทวนคำถาม user · เล่าสิ่งที่ไม่ได้ทำ · ตาราง (เว้นแต่เทียบ ≥3 อย่างจริง ๆ)
- ยาวได้เมื่อ user ขอรายละเอียด หรือต้องยก output ของ test/error มาตรง ๆ

**ถาม** — ถามเฉพาะที่ "ตอบต่างกัน ⇒ งานออกมาต่างกัน" ที่เหลือเลือกเองแล้วบอกว่าเลือกอะไร
- 1 คำถามต่อครั้ง (เว้นแต่ spec ของคำสั่งนั้นระบุให้ถามรวด) · ≤2 บรรทัด · ตัวเลือก ≤4 พร้อมผลที่ตามมา 1 วลี
- มี **แนะนำ: <ตัวเลือก>** + เหตุผล 1 บรรทัดเสมอ ⇒ user ตอบ "เอาตามนั้น" แล้วจบได้

**ห้ามเด็ดขาด:** อ้าง test ผ่านโดยไม่ได้รัน · แต่ง commit hash / URL / token count · แก้ shared repo หรือ production โดยไม่ confirm scope — ยังไม่ได้ตรวจให้เขียน `pending verification`

## Vault (`docs/`)

`00-Index` MOC + IMPLEMENTATION-STATUS · `10-PRD` · `20-Features` FEAT-* · `30-Roles` · `40-Functions` FN-* · `50-Phases` PHASE-* · `60-Flows` · `70-Reference` ADR / TechStack / AuthorizationMatrix · `80-ImplementPlan` `YYYY-MM-DD-HHmm-<slug>.md` · `85-FixLog` `YYYY-MM-DD-HHMM-<slug>.md` · `90-TestPlan` · `95-Handoff` HOR-*

🔴 **เอกสารใน vault บอกสถานะ "ปัจจุบัน" เท่านั้น** — ห้ามเขียน "เดิม X → ใหม่ Y" / `## Changelog` ในเอกสาร spec · before/after อยู่ใน `80-ImplementPlan` `85-FixLog` `90-TestPlan` `95-Handoff` เท่านั้น (สัญญาเต็ม `.ow/commands/_shared/vault-doc-style.md` · gate `/ow-secure` Phase 2.6)

## Config + snapshot

- `.ow.yml` ที่ root — คอมเมนต์ในไฟล์อธิบายทุก key ไว้แล้ว อ่านที่ไฟล์จริง · 🔴 **ห้าม `yq -i` กับไฟล์นี้** (ลบคอมเมนต์ทิ้ง) แก้แบบ surgical เท่านั้น
- `subagents` — ship มา 4 ตัว: `docs` `verifier` `security` `gh-issue` · ที่เหลือเป็น **ชื่อ ไม่ใช่ไฟล์** จนกว่า `/ow-agent create <name>` จะเขียน body ให้ตรง stack (`/ow-agent suggest` บอกว่าควรมีตัวไหน) · enabled แต่ไม่มีไฟล์ = install/upgrade รายงาน ไม่เติมให้เงียบๆ
- `.ow/` = snapshot (`commands/` `templates/`) อัปเดตด้วย `/ow-sync` · `.ow/rules/` เป็นของ project นี้เอง sync ไม่แตะ · `templates/` ที่ root override `.ow/templates/`
- `scripts/` + `bin/` = mixed-ownership — upgrade refresh ทีละไฟล์ตาม manifest (`ow-owned.sh`) ไม่เคย `rm -rf` ทั้ง dir · รายละเอียดของแต่ละสคริปต์อยู่ใน header comment ของสคริปต์เอง · hard prerequisite: ต้องมี `yq`

## ภาษา

| อะไร | ภาษา |
|---|---|
| แชท / รายงาน / คำถามที่ถาม user | `project.language` (`$PROJECT_LANG`) |
| ไฟล์ใต้ `vault_path` ทุก folder | `project.vault_language` — ไม่ระบุ ⇒ ตาม `project.language` (`$VAULT_LANG`) |
| code comment · frontmatter · commit message · `.ow/commands` · `.claude/agents` | อังกฤษ |
<!-- OW END: workflow -->

## Design spec ของงานพัฒนา obsidian-workflow เอง (`.superpowers/`)

skill `superpowers:brainstorming` เขียน design spec ที่ `.superpowers/specs/` — **gitignored**

`docs/` ใน repo นี้คือ **sample vault** (`docs/obsidian-vault/`) ที่ greenfield install คัดลอกไปให้ project ใหม่ — ห้ามเอา spec ของงานพัฒนา obsidian-workflow ไปวางปน
