# obsidian-workflow Commands — Usage Guide

คู่มือใช้งาน 20 คำสั่งของ obsidian-workflow แบบจริงจัง — 1 ไฟล์ต่อ command พร้อมตัวอย่าง, workflow, gotchas

> ใช้คู่กับ [`.ow/commands/ow-*.md`](../.ow/commands/) (source-of-truth พร้อม Phase รายละเอียดเต็ม)
> ถ้าไม่รู้จะเริ่มจากไหน → อ่าน [/ow-help](./ow-help.md) ก่อน

---

## หาคำสั่งที่ต้องการ

### ตั้งค่า + ช่วยเหลือ

| Command | ใช้เมื่อ |
|---|---|
| [/ow-help](./ow-help.md) | ถามว่าจะใช้ command ไหน / cheatsheet / decision tree |
| [/ow-init](./ow-init.md) | bootstrap project ครั้งแรก (greenfield หรือ brownfield) |
| [/ow-sync](./ow-sync.md) | อัพเดต obsidian-workflow snapshot จาก obsidian-workflow repo |
| [/ow-agent](./ow-agent.md) | จัดการ subagent — `suggest`/`create` เขียน agent ให้ตรง stack จริง (obsidian-workflow ship มาแค่ always-on 4 ตัว) |

### Spec-driven cycle (อิง spec-kit)

| Command | ใช้เมื่อ |
|---|---|
| [/ow-new](./ow-new.md) | brainstorm จาก idea หรือ import PRD ที่มีอยู่ |
| [/ow-clarify](./ow-clarify.md) | scan ambiguity 9 หมวด ถามทีละข้อพร้อม recommended answer |
| [/ow-plan](./ow-plan.md) | research vault แล้วสร้าง plan file (ไม่แตะโค้ด) |
| [/ow-checklist](./ow-checklist.md) | "unit tests for English" per domain (ux/api/security/...) |
| [/ow-implement](./ow-implement.md) | execute plan ที่ approve แล้ว — inline หรือ delegate ให้ subagent ตามงาน |
| [/ow-fix](./ow-fix.md) | diagnose bug + สร้าง fix-log (ไม่แก้โค้ด) |
| [/ow-reverse-engineer](./ow-reverse-engineer.md) | extract spec (FEAT/FN/REF) จาก code ที่มีอยู่ |

### GitHub issues

| Command | ใช้เมื่อ |
|---|---|
| [/ow-triage-issues](./ow-triage-issues.md) | batch-triage GitHub bug → classify + label + comment + cluster |
| [/ow-fix-issue](./ow-fix-issue.md) | แก้ GitHub bug แบบขนาน (worktree) → auto-merge local → handoff |

### เอกสาร + ทดสอบ + ออกแบบ

| Command | ใช้เมื่อ |
|---|---|
| [/ow-doc](./ow-doc.md) | สร้าง/แก้ doc (PRD/SRS/ADR/Feature/Function/Role/Flow/Phase) |
| [/ow-test](./ow-test.md) | smoke test เฉพาะส่วน diff + รายงานผลจริง |
| [/ow-design](./ow-design.md) | design system (tokens, components) + preview.html |

### ส่งมอบ

| Command | ใช้เมื่อ |
|---|---|
| [/ow-secure](./ow-secure.md) | security pre-flight (secret/PII/dep scan + gate ภาษา vault + gate "vault เขียนสถานะปัจจุบัน") |
| [/ow-verify](./ow-verify.md) | verify ครบ (tests/vault/security/DS) |
| [/ow-handoff](./ow-handoff.md) | สร้าง Handoff Report ส่งต่อ reviewer/exec/QA |
| [/ow-git](./ow-git.md) | submodule-aware commit/push/branch/merge |

---

## Workflows ที่พบบ่อย

### เริ่ม project ใหม่ (greenfield)

```
1. bash <(curl ... install.sh)              ← bootstrap จาก installer
2. /ow-init                                ← interactive config (vault location) + ติดตั้ง always-on subagents
3. /ow-new                                 ← brainstorm → PRD + SRS + Tech-spec
4. /ow-design init                         ← (optional) bootstrap design system
4b. /ow-agent suggest → create <name>       ← (optional) agent เฉพาะทางที่ stack นี้ต้องการจริง
5. /ow-plan FEAT-X                         ← research vault + plan file
6. [user review plan, set status: approved ใน frontmatter]
7. /ow-implement docs/...                  ← execute (inline/subagent ตามงาน) + รัน build/test จริง
8. /ow-test                                ← smoke test ส่วนที่แก้
9. /ow-secure                              ← pre-flight scan
10. /ow-verify                             ← ตรวจครบ (tests/vault/security/DS)
11. /ow-handoff                            ← สร้าง HOR-*.md ส่ง reviewer
12. /ow-git --plan <path>                  ← commit + push
```

### แก้บั๊ก (พิสูจน์ red→green)

```
1. /ow-fix "search ค้างเมื่อใส่ขีดล่าง"      ← diagnose + fix-log (ไม่แก้โค้ด)
2. /ow-plan fix:<slug>                       ← mini plan ที่ link ไปยัง fix-log
3. /ow-implement <plan>                      ← แก้จริง
4. /ow-test --since <ref>                    ← verify ว่า fix ได้
6. /ow-verify                                ← handoff
7. /ow-git --fix <fix-log-path>              ← commit prefix `fix:`
```

### Brownfield adoption (รับ codebase เดิม)

```
1. cd existing-project
2. bash <(curl ... install.sh)               ← installer auto-detect indicators
                                               (มี .claude เดิม? ถาม keep/remove/select — v0.7.1)
3. /ow-init --brownfield                    ← config + vault skeleton + rules scaffolds
4. /ow-reverse-engineer                     ← scan โค้ด → draft FEAT/FN/REF docs
5. [ตรวจ draft docs + เติม business rules]
6. /ow-clarify FEAT-<slug>                  ← scan ambiguity ใน draft
7. /ow-plan <first task>                    ← เริ่ม workflow ปกติ
```

---

## หลักการที่ทุก command บังคับ

1. **Vault-first** — อ่าน `docs/` ก่อนถามคำถาม
2. **Output = bullet สรุปสั้น** ภาษาตาม `project.language` — **≤7 bullets · bullet ละ 1 บรรทัด ห้ามซ้อนย่อย**: ทำอะไร/แก้อะไร · หลักฐานที่ตรวจจริง · เสี่ยง/ต่อไป (เมื่อมี)
   **ถาม** — เฉพาะที่ตอบต่างกันแล้วงานออกมาต่างกัน · 1 คำถามต่อครั้ง ≤2 บรรทัด · ตัวเลือก ≤4 · ต้องมี **แนะนำ: <ตัวเลือก>** เสมอ
3. **No fake results** — ห้ามแต่ง commit hash, URL, test result, token count
4. **Plan/Implement separation** — `/ow-plan` และ `/ow-fix` ไม่แตะโค้ด, `/ow-implement` เท่านั้นแก้โค้ด
5. **Thai-first** reports (เว้นแต่ `.ow.yml` `language: en`)
6. **Coding discipline** — ระบุ success criteria ก่อนลงมือ; minimum correct change; ทุก changed line trace กลับ request/criteria ได้; ห้าม speculative abstraction/refactor นอก scope — สัญญาเต็มที่ `.ow/commands/_shared/coding-discipline.md`
7. **เอกสาร vault = สถานะปัจจุบัน** — โน้ตนอก `80-ImplementPlan` `85-FixLog` `90-TestPlan` `95-Handoff` เขียนได้เฉพาะสิ่งที่จริงตอนนี้ · ห้าม "เดิม X → ใหม่ Y" ห้ามหัวข้อ `## Changelog` (ของเก่าอยู่ใน git + plan/fix-log) — สัญญาเต็มที่ `.ow/commands/_shared/vault-doc-style.md` · `/ow-secure` Phase 2.6 บล็อกให้

---

## Reference docs

- [Full README](../README.md) — overview + install
- [Multi-AI guide](../AI-README.md) — Claude/Codex/Gemini/GPT/GLM/Cline/Kimi
- [Changelog](../CHANGELOG.md)
- Command source-of-truth: [`../.ow/commands/ow-*.md`](../.ow/commands/)
- Subagent specs: [`../.claude/agents/*.md`](../.claude/agents/) — always-on 4 ตัวที่ ship มา + ที่ `/ow-agent create` เขียนไว้
- Templates: [`../.ow/templates/*.md`](../.ow/templates/) — layer override ของ project อยู่ที่ `templates/` ที่ root (สร้างเองเมื่ออยาก customize)
