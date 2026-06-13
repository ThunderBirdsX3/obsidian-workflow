---
description: Vault-first research + create implementation plan file (no code touch)
---

# /ow-plan — Plan a task (no code)

อ่าน vault → clarify → สร้าง plan file → **หยุดก่อนแก้โค้ดเสมอ**

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble — identical across all commands. Do NOT edit per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/ow-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)" || {
  echo "FATAL: resolver missing/failed — run /ow-init"; exit 1; }
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-plan <task description>
/ow-plan <task> --worktree   # opt-in: implement+test ทำงานใน git worktree แยก + auto-merge ตอน test PASS
/ow-plan fix:<slug>          # plan ที่ escalate มาจาก fix-log — ingest + ผูก link สองทาง
/ow-plan --from-fix <path>   # เหมือน fix: แต่ระบุ path เต็มของ fix-log
/ow-plan <task> --revise <plan-path>
```

ว่าง → ถาม "วางแผนงานอะไร?"

## `--worktree` mode (opt-in — set ครั้งเดียวที่ plan, inherit ทั้ง flow)

`/ow-plan <task> --worktree` → เขียน `worktree: true` ลง plan frontmatter (Phase 3). field นี้ทำให้
**ทั้ง flow ทำงานใน git worktree แยก** โดยไม่ต้องพิมพ์ flag ซ้ำ:

- `/ow-implement <plan>` → สร้าง worktree `worktrees/plan-<slug>` + branch `plan/<slug>` (แตกจาก HEAD ปัจจุบัน)
  แล้ว implement + commit **ในนั้น** — main working tree ไม่ถูกแตะ (งาน uncommitted คู่ขนานปลอดภัย)
- `/ow-test <plan>` → รัน test ใน worktree → **PASS = auto-merge กลับ base branch (local, ไม่ push) + cleanup**;
  FAIL = เก็บ worktree ไว้ให้แก้ต่อ

🔴 **`/ow-plan` ไม่สร้าง worktree เอง** — แค่บันทึก intent; worktree สร้างตอน `/ow-implement` (plan = text only เสมอ)
🔴 override ได้รายคำสั่ง: `/ow-implement <plan> --no-worktree` (บังคับ in-tree) / `--worktree` (บังคับเปิดแม้ frontmatter ไม่มี)

## `--revise` mode

1. Read existing plan file
2. Re-run Phase 1 (vault อาจเปลี่ยน)
3. Skip Phase 2 ถ้า task description ไม่เปลี่ยน
4. **Update in-place** — ไม่สร้างไฟล์ใหม่
5. แสดง diff → STOP รอ user review

## `fix:` / `--from-fix` source mode (escalate จาก /ow-fix)

เมื่อ plan ถูก escalate มาจาก `/ow-fix` → สร้าง plan จาก fix-log + ผูก link **สองทาง** เพื่อให้ `/ow-implement` ปิด fix-log อัตโนมัติตอน plan done (ไม่ปล่อยค้าง `in-progress`)

1. **Resolve fix-log** — `fix:<slug>` → หาไฟล์ `<slug>.md` ใน `$FIX_DIR`; `--from-fix <path>` → ใช้ path ตรง. หาไม่เจอ → STOP + แจ้ง user (อย่าเดา)
2. **Ingest (pre-fill, ไม่ถามซ้ำ)** — อ่าน fix-log: `Symptom` / `Root Cause` → Task · `Affected Files` → Affected Files · `Success Criteria` → Success Criteria · `Test Cases` → Test Plan
3. **Link plan → fix** — เขียน `source_fix: "[[<fix-log-slug>]]"` ลง plan frontmatter (structured — `/ow-implement` ใช้ปิด fix-log, `/ow-git --bump` ใช้ stamp version)
4. **Link fix → plan (back-link)** — หลังเขียน plan file (Phase 3) เขียน `related_plan: "[[<plan-slug>]]"` กลับลง fix-log frontmatter (แทนค่า `none`/เก่า)

🔴 ทั้ง `source_fix:` (plan) **และ** `related_plan:` (fix-log) ต้องถูกเขียน — มัดความสัมพันธ์สองทาง ไม่งั้น fix-log orphan
🔴 escalation เป็น **1:1** — 1 fix-log ↔ 1 plan; บั๊กที่ 2 → fix-log ใหม่ + plan ใหม่ (อย่ายัด 2 fix-log เข้า plan เดียว)

## Phase 1 — อ่าน vault context (บังคับ)

1. อ่าน `$IMPL_STATUS`
2. **FR coverage check** — grep `FR-[0-9]+` จาก SRS ที่เกี่ยวข้อง แล้วตรวจว่า FR ไหน:
   - **orphan** — ไม่มี plan step หรือ task ID มัดอยู่ → warn user ใน output
   - **underspecified** — ไม่มี acceptance criteria → เสนอ `/ow-clarify` ก่อน plan
   - ไม่ต้อง block — แค่แสดงให้ user รู้ก่อนเริ่มเขียน plan
   - **task ไม่มี SRS รองรับเลย** → เสนอ `/ow-new` หรือ `/ow-doc SRS` ก่อน (spec-first)
3. อ่านเอกสารที่เกี่ยวกับ task:
   - Feature/PRD/SRS → `$PRD_DIR` + `$FEAT_DIR`
   - Role/menu → `$ROLE_DIR`
   - Function/API → `$FN_DIR`
   - Phase task → `$PHASE_DIR`
   - Flow → `$FLOW_DIR`
   - Auth → `$REF_DIR/REF-AuthorizationMatrix.md`
   - API contracts → `$REF_DIR/REF-APIIntegration.md`
   - Tech stack → `$REF_DIR/REF-TechStack.md`
   - **Design system** → `$DS_DIR` (ถ้ามี — บังคับ frontend/mobile ใช้)
4. อ่านทุก doc ที่เกี่ยวข้องเต็มๆ (ไม่ใช่แค่ skim)
5. List ทุก doc ใน plan file (เป็นหลักฐาน)
6. **Policy Check** — ตรวจ plan vs `.ow/policies/` (no-fake-evidence, source-of-truth, working-result):
   plan ต้องไม่ขัด policy ใด; task มี irreversible/destructive step → flag + require explicit approval
   ใน plan frontmatter `risk_level: high`

> **Vault ตอบอยู่แล้ว → ห้ามถาม user ใหม่**

## Phase 2 — Clarifying questions (1 batch)

หลังอ่าน vault, ถามคำถามทั้งหมด **ในข้อความเดียว** ห้ามทยอย

ถามเฉพาะที่ vault ไม่ตอบ:
- Roles ที่เกี่ยวข้อง?
- Edge cases นอกเหนือ spec?
- Submodule scope (ถ้ามี submodules)?
- Constraints (deadline, ต้อง reuse component ไหน)?
- Design system ต้องเพิ่ม component ใหม่ไหม?

## Phase 3 — สร้าง plan file

Path: `$PLAN_DIR/YYYY-MM-DD-HHmm-<slug>.md` (slug = kebab-case, ≤ 5 คำ)

Template:
```markdown
---
tags: [type/plan]
date: YYYY-MM-DD HH:mm
title: <one-line task title>
status: planning            # planning | approved | in-progress | done | abandoned
subagent_target: <backend | frontend | mobile | docs | design | all>
worktree: true                              # ⬅ ใส่เฉพาะเมื่อเรียกด้วย --worktree (ไม่งั้นตัด field นี้ออก)
source_fix: <"[[fix-log-slug]]" or none>   # set เมื่อ /ow-plan fix:<slug>
related_docs:
  - <SRS / FEAT / FN ที่อ่าน>
estimate_hours: <number>
risk_level: <low | medium | high>
---

# <Task title>

## Vault Context Read
- <ทุก doc ที่อ่านจริง + section/FR ids>

## Task
<clear one-paragraph task description>

## FR Coverage
- FR-### ที่ plan นี้ implement: <list>
- FR orphan/underspecified ที่เจอ: <list หรือ none>

## Goals
- [ ] Goal 1

## Non-goals
- ทำอะไรที่ **จะไม่ทำ** ใน plan นี้

## Doc Gaps Found
- (vault inconsistent ที่เจอระหว่างอ่าน — /ow-implement จะ fix ก่อน)

## Affected Files
- `path/to/file1.ts` — <what changes>

## Implementation Steps
1. <step — กึ่ง declarative ไม่ใส่โค้ดยาว>
... (5-15 steps for medium task; 3-5 for small)

## Design System Compliance (ถ้า frontend/mobile)
- [ ] ใช้ tokens จาก `DS-Tokens.md` เท่านั้น (สี/font/spacing)
- [ ] ใช้ components จาก `DS-Components.md`
- [ ] ต้อง component ใหม่ → log ใน "Design Additions" ก่อน
- [ ] WCAG AA contrast ผ่านทุก state

## Design Additions (ถ้ามี)
- <component/token ใหม่ — trigger /ow-design ก่อน /ow-implement>

## Test Plan
- [ ] Unit tests สำหรับ <X>
- [ ] Integration tests สำหรับ <Y>
- [ ] Manual checks: <scenarios>

## Success Criteria
- [ ] <เกณฑ์ที่ตรวจสอบได้จริง เช่น "unit test X ผ่าน", "endpoint ตอบ 200" — map กับ FR acceptance>

## Verification
- map กลับไปยัง Success Criteria แต่ละข้อพร้อมผลลัพธ์จริง

## Risks
- <risk> → mitigation: <plan>

## Approval
- [ ] Approved (set status: approved before /ow-implement)
```

### Phase 3.5 — Write back-link to fix-log (เฉพาะ fix-source mode)

ถ้าเป็น `fix:` / `--from-fix` mode → หลังเขียน plan file เสร็จ (รู้ plan slug แล้ว) เขียน `related_plan:` กลับลง fix-log:

```bash
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
PLAN_SLUG="<basename ของ plan file ที่เพิ่งสร้าง, ไม่มี .md>"
FIXLOG="$FIX_DIR/<fix-log-slug>.md"
[ -f "$FIXLOG" ] || { echo "FATAL: fix-log หาย: $FIXLOG"; exit 1; }
```

แก้ frontmatter `related_plan:` ของ `$FIXLOG` ด้วย **Edit (surgical)** → `"[[<PLAN_SLUG>]]"` — ไม่แตะ field อื่น

## Phase 4 — Doc gap detection

ระหว่าง Phase 1, ถ้าเจอ:
- Doc ที่กล่าวถึงใน PRD/SRS แต่ไม่มีไฟล์
- ข้อมูล contradict ระหว่าง docs (เช่น role ใน SRS ไม่ตรงกับ AuthorizationMatrix)
- FN spec ที่งานเกี่ยวข้องแต่ยังไม่มี

→ List ใน `Doc Gaps Found` ของ plan file
→ Plan file ระบุว่า `/ow-implement` จะเรียก `docs` subagent มา fix ก่อน

## Phase 5 — STOP

แสดง plan file ที่สร้าง + ข้อความ:

> Plan สร้างเสร็จ: `<plan path>`
>
> ขั้นต่อไป:
> - Review plan + set `status: approved` ใน frontmatter
> - แก้/เพิ่ม → `/ow-plan <task> --revise <path>`
> - Approve แล้ว → `/ow-implement <path>`

ถ้า plan มี `worktree: true` → เพิ่มบรรทัด:
> 🌳 **Worktree mode** — `/ow-implement` จะ build ใน worktree แยก (main tree ไม่ถูกแตะ),
> `/ow-test` จะ **auto-merge กลับ branch ปัจจุบันเมื่อ test ผ่าน** (local, ไม่ push)

**ห้าม** /ow-plan เริ่ม implement เอง · **ห้าม** /ow-plan สร้าง worktree (เป็นงาน /ow-implement)

## Output (3 หัวข้อบังคับ)

1. **Result** — plan file path + วาง plan ครอบ FR ไหนบ้าง
2. **Verification / Evidence** — list vault docs ที่อ่านจริง + FR coverage check result
3. **Limitations / Next steps** — risks จาก plan + "ต้อง approve ก่อน /ow-implement"

## ห้าม

- ห้ามแก้โค้ด ห้ามรัน build/test/lint ใน /ow-plan
- ห้าม spawn subagent — plan file เป็น text only
- ห้าม set `status: approved` ให้ user — user ต้องทำเอง
- ห้ามเพิ่ม Implementation Steps นอก scope ที่ขอ (ห้าม speculative abstraction/refactor)
- Success Criteria ต้องเป็น observable outcome ตรวจได้จริง ไม่ใช่ goal กว้างๆ
