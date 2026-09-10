# /ow-plan

> **Vault-first research + สร้าง plan file** — อ่าน vault → clarify → เขียน plan → **หยุดก่อนแตะโค้ดเสมอ**

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-plan.md`](../.ow/commands/ow-plan.md)

## เมื่อไหร่ใช้

- ก่อน implement feature/task — บังคับมี plan file ที่ approve แล้ว
- มี PRD/SRS ครบแล้ว → ขั้นถัดไปคือวางแผน implement
- ต้องการ revise plan เดิม (`--revise`)
- หลัง `/ow-fix` → สร้าง mini-plan ที่ link ไปยัง fix-log

## Quick start

```
/ow-plan "เพิ่ม search สำหรับ book inventory"
```

ตัวอย่างไฟล์ที่ได้:
```
docs/obsidian-vault/80-ImplementPlan/2026-05-21-1430-add-search-feature.md

---
tags: [type/plan]
status: planning            ← user ต้อง set เป็น approved ก่อน /ow-implement
submodule_target: web
subagent_target: frontend
related_docs: [...]
---

# เพิ่ม search สำหรับ book inventory
## Vault Context Read · Task · Goals · Affected Files · Steps · DS Compliance · Test Plan · Risks · Approvals
```

## รูปแบบเต็ม

```
/ow-plan "<task description>"
/ow-plan <task> --worktree        # opt-in: implement+test ทำงานใน git worktree แยก + auto-merge ตอน test PASS (#31)
/ow-plan <task> --revise docs/obsidian-vault/80-ImplementPlan/<file>.md
/ow-plan fix:<slug>                # plan ที่ escalate จาก fix-log (ingest + link สองทาง)
/ow-plan --from-fix docs/obsidian-vault/85-FixLog/<file>.md   # เหมือน fix: แต่ระบุ path เต็ม
/ow-plan <task> --budget <n>       # เพดาน token ของ vault read-set ใน Phase 1 (default 40000)
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--worktree` | off | เขียน `worktree: true` ลง frontmatter → `/ow-implement`+`/ow-test` inherit: build ใน worktree แยก (กัน main tree), auto-merge ตอน test PASS (#31). `/ow-plan` ไม่สร้าง worktree เอง |
| `--revise <path>` | n/a | update plan in-place (ไม่สร้างไฟล์ใหม่) |
| `fix:<slug>` / `--from-fix <path>` | n/a | escalate จาก fix-log — pre-fill + เขียน `source_fix:` (plan) ↔ `related_plan:` (fix-log); fix-log ปิด auto ตอน plan done (#30) |
| `--budget <n>` | 40000 | เพดาน token ของ vault read-set ใน Phase 1 — เกินแล้วตัด conditional ก่อน → เสนอ `/ow-clarify` → สุดท้ายเขียน `split_advised: true` **ไม่เคยอ่าน doc แบบตัดครึ่ง** (คนละตัวกับ `--budget` ของ `/ow-split` ซึ่งเป็น context ต่อ execution unit) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — อ่าน vault context (บังคับ แต่มี budget): `IMPLEMENTATION-STATUS` + **FR coverage check** (warn orphan/underspecified FR) → **เลือก read set ก่อนเปิด** (ALWAYS = PRD/FEAT/FN ที่ task ระบุ + code/test เดิม · CONDITIONAL = ตามตาราง include-when ใน `.ow/commands/_shared/context-refs.md` · DS docs ถ้าเป็น frontend/mobile) → วัดด้วย `est_read_set()` เทียบ `BUDGET` → doc ที่เข้า set อ่านเต็มเสมอ, doc ที่ถูกตัดต้อง list ไว้ใน plan พร้อมเหตุผล
2. **Phase 2** — Clarifying questions **1 batch** (ถามที่ vault ไม่ตอบเท่านั้น)
3. **Phase 3** — เขียน plan file ตาม template (Vault Context Read, Task, Goals, Non-goals, Affected Files, Steps, DS Compliance, Test Plan, Risks, Approvals)
   - **Phase 3.5** (fix-source mode เท่านั้น) — เขียน `related_plan: "[[<plan-slug>]]"` กลับลง fix-log (back-link สองทาง)
4. **Phase 4** — Doc gap detection (จด ใน `Doc Gaps Found` — implement จะ fix ก่อน)
5. **Phase 5** — **STOP** — แสดง path + ขอ user review + set `status: approved`

## Output ที่ได้

- `docs/obsidian-vault/80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md` (status: planning, ≤ 5 คำ slug)
- **ห้ามแตะโค้ด** — plan file เท่านั้น

## Plan file structure

```
Frontmatter:
  tags: [type/plan]
  status: planning | approved | in-progress | done | abandoned
  submodule_target: api | web | mobile | docs | all
  subagent_target: backend | frontend | mobile | docs | design | all
  worktree: true                          ← เฉพาะ --worktree: implement+test ทำงานใน git worktree แยก (#31)
  source_fix: "[[fix-log-slug]]" | none   ← set เมื่อ fix:<slug> (/ow-implement ปิด fix-log นี้ตอน done)
  split_advised: true                     ← เฉพาะตอน read-set เกิน budget: ให้รัน /ow-split ก่อน implement
  related_docs: [list]
  estimate_hours: <number>
  risk_level: low | medium | high

Body:
  ## Vault Context Read       ← ทุก doc ที่อ่าน + doc ที่ budget ตัดออก พร้อมเหตุผล
  ## Task                     ← clear one-paragraph
  ## Goals / Non-goals
  ## Doc Gaps Found           ← จะ fix ก่อน implement
  ## Affected Files
  ## Implementation Steps     ← 5-15 steps medium / 3-5 small
  ## Design System Compliance ← ถ้า frontend/mobile
  ## Design Additions          ← component ใหม่ที่ต้อง /ow-design ก่อน
  ## Test Plan
  ## Success Criteria         ← observable outcomes ที่ตรวจได้จริง
  ## Verification             ← map กลับไปยัง success criteria แต่ละข้อ
  ## Risks
  ## Approvals
```

## Workflow ที่นิยม

ตัวอย่าง 1: feature ใหม่
```
1. /ow-new                    ← PRD/SRS/Tech
2. /ow-clarify                 ← resolve ambiguity
3. /ow-plan FEAT-Checkout      ← คุณอยู่ที่นี่
4. [user review + set status: approved ใน frontmatter]
5. /ow-implement <path>
```

ตัวอย่าง 2: revise plan ที่ค้าง
```
1. /ow-plan "เพิ่ม search" --revise docs/obsidian-vault/80-ImplementPlan/2026-05-20-1430-add-search.md
   → re-read vault (อาจมีการ update)
   → update in-place + แสดง diff
   → STOP รอ review
```

ตัวอย่าง 3: bug fix
```
1. /ow-fix "search ค้าง"             ← สร้าง fix-log
2. /ow-plan fix:<slug>                ← mini-plan link ไปยัง fix-log
3. [approve]
4. /ow-implement <plan>
```

ตัวอย่าง 4: worktree flow (กัน main tree, auto-merge ตอน test PASS — #31)
```
1. /ow-plan "เพิ่ม search" --worktree   ← frontmatter worktree: true
2. [approve]
3. /ow-implement <plan>                  ← build ใน worktrees/plan-<slug>/ (main tree ไม่ถูกแตะ) + commit
4. /ow-test <plan>                       ← test ใน worktree → PASS = auto-merge กลับ branch (local) + cleanup
5. /ow-git --bump                        ← push (— /ow-test ไม่ push)
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามแตะโค้ด ห้ามรัน build/test/lint** — `/ow-plan` text-only
- 🚫 **ห้าม spawn subagent** — plan file เท่านั้น
- 🚫 **ห้าม set `status: approved` ให้ user** — user ต้องทำเอง (gate manual)
- ⚠️ Vault-first: ถ้า vault ตอบอยู่แล้ว → ห้ามถาม user
- ⚠️ คำถามใน Phase 2 ต้อง **batch** (ต่างจาก `/ow-clarify` ที่ 1-at-a-time)
- 💡 ถ้า plan มี Design Additions → ต้องรัน `/ow-design component <name>` ก่อน `/ow-implement`
- 💡 Doc Gaps ที่ list ใน plan → `/ow-implement` Phase 2 จะแก้ให้ก่อน (inline หรือ `docs` subagent ถ้ารายการใหญ่)

## Related

- ก่อน `/ow-plan`: [/ow-new](./ow-new.md), [/ow-clarify](./ow-clarify.md), [/ow-fix](./ow-fix.md)
- หลัง `/ow-plan` (approve แล้ว): [/ow-implement](./ow-implement.md)
- Template: `templates/plan.md` (fallback `.ow/templates/plan.md`)
- Vault path: `docs/obsidian-vault/80-ImplementPlan/`

## FAQ

**Q: ทำไม `/ow-plan` ไม่เขียนโค้ดให้?**
A: obsidian-workflow แยก plan/implement เคร่งครัด — plan = thinking, implement = doing เปลี่ยน plan ก่อน implement = `--revise` mode

**Q: ผมอยาก skip plan ทำเลยได้ไหม?**
A: ไม่แนะนำ — `/ow-implement` ต้องการ plan file ที่ `status: approved` ถ้าจริงๆ ต้องการ → ใช้ `/ow-implement --from-fix` (เฉพาะ P3 polish)

**Q: ต้อง read full doc หรือ skim ก็ได้?**
A: **อ่านเต็ม** — Phase 1 บังคับ list ทุก doc ที่อ่านใน plan file (เป็นหลักฐาน)
