# /ow-implement

> **Execute plan ที่ approve แล้ว** — ทำ inline เองหรือ delegate ให้ subagent (Claude ตัดสินตามงาน) + รัน build/test จริง + sync vault + update IMPLEMENTATION-STATUS

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-implement.md`](../.ow/commands/ow-implement.md)

## เมื่อไหร่ใช้

- Plan file `status: approved` แล้ว (user set เองใน frontmatter)
- เมื่อต้องการแก้โค้ดจริง — **command เดียวที่ได้รับอนุญาตให้แตะโค้ด**
- หลัง `/ow-fix` → `/ow-plan fix:<slug>` → `/ow-implement` chain

## Quick start

```
/ow-implement docs/obsidian-vault/80-ImplementPlan/2026-05-21-1430-add-search.md
```

หรือ auto-locate by slug:
```
/ow-implement add-search
```

ถ้าไม่ระบุ args:
```
/ow-implement
→ list 5 plans ล่าสุดที่ status: approved
```

## รูปแบบเต็ม

```
/ow-implement <plan-path>            # หรือ auto-locate
/ow-implement <slug>                 # search by slug
/ow-implement <plan> --phase P2      # รัน phase เดียวของ plan ที่แตก phase — ไม่ใส่ = รันทุก phase ตามลำดับ
/ow-implement <plan> --worktree      # บังคับ build ใน git worktree แยก (#31)
/ow-implement <plan> --no-worktree   # บังคับ build ใน main tree (override plan ที่มี worktree: true)
/ow-implement --from-fix <fix-log>   # P2/P3 เท่านั้น (skip plan) — /ow-fix เรียกให้เอง
```

## 📐 Phased plan (`--phase`)

plan ที่ `/ow-plan` แตกเป็น phase จะมีตาราง `## Phases` (id · area · depends_on · est tokens · status)
และ `## Shared Contract` สำหรับค่าที่ใช้ข้าม phase

- `/ow-implement <plan> --phase P2` → รัน **เฉพาะ section ของ P2** — context_refs, Affected Files, Steps,
  Test Plan, Success Criteria, doc ที่ P2 เป็นเจ้าของ · 🔴 ห้ามแตะไฟล์/doc ของ phase อื่น
- **gate ก่อนเริ่ม** — `depends_on` ต้อง `done` ครบ และ Shared Contract row ที่ P2 เป็น consumer ต้อง
  `state: actual` แล้ว (ยัง `planned` = producer ยังไม่รัน → **STOP** ไม่ implement ทับค่าที่ยังเดาอยู่)
- **จบ phase** — gates ผ่าน → ติ๊ก `status: done` ให้ row นั้นในตาราง · plan frontmatter จะเป็น `done`
  ก็ต่อเมื่อ **ทุก row** done เท่านั้น
- **ไม่ใส่ `--phase`** → รันทุก phase ตามลำดับในหนึ่ง session · รวม est tokens เกิน ~120k จะ **เตือน** ให้แยก session
- 🔴 ประหยัด token จริงต่อเมื่อ `/clear` คั่นระหว่าง phase
- resume marker (`## Step Progress`) ของ plan แบบนี้ต้องมี phase id นำหน้า: `- [x] P2 steps 1-4 · …`

## 🌳 Worktree mode (#31)

ถ้า plan มี `worktree: true` (จาก `/ow-plan --worktree`) หรือใส่ `--worktree` → `/ow-implement` จะ:
1. สร้าง worktree `worktrees/plan-<slug>` + branch `plan/<slug>` แตกจาก **HEAD ปัจจุบัน**
2. build **ในนั้น** (inline หรือ subagent) — **main working tree ไม่ถูกแตะ** (งาน uncommitted คู่ขนานปลอดภัย)
3. orchestrator commit โค้ดใน worktree (Phase 6.4) หลัง gates ผ่าน — **ไม่ push, ไม่ merge**
4. handoff → `/ow-test <plan>` (มัน auto-merge กลับ base ตอน smoke PASS)

🔴 worktree create fail = **STOP** (ไม่ fallback เงียบไป main tree — เสีย isolation). vault ยังเขียนที่ MAIN_ROOT
(worktree เก็บ **โค้ดล้วน** → merge ไม่ชน docs/).

## 🧩 Chunked implement (เฉพาะตอน delegate + plan ยาว)

subagent สั่ง compact ตัวเองไม่ได้ — วิ่งยาวๆ context มันโตเองจนแพง. **ตอน delegate** plan ที่ยาวจึงถูก
**แบ่งเป็น chunk** แล้ว spawn ทีละตัว แต่ละตัวเริ่ม context ใหม่ ส่งต่อกันด้วย handoff

🔴 **ทำ inline ไม่แบ่ง chunk** — main loop compact ตัวเองได้ กลไกทั้งชุดนี้จึงข้ามไปเลย

- ตัดที่ **verifiable state เท่านั้น** — จุดที่ build ผ่าน + test ของพื้นที่นั้นรันได้ + ไม่ต้องพึ่ง step ถัดไป
- เป้า **3–6 steps/chunk** · **plan ≤6 steps = spawn ตัวเดียว เหมือนเดิมทุกอย่าง**
- 1 chunk = 1 agent (`subagent_target: all` แบ่งแยกต่อ agent)
- orchestrator **รันคำสั่ง exit ของแต่ละ chunk เอง** ไม่เชื่อคำประกาศของ agent
- agent ติด → คืน `BLOCKED` → **หยุด ถามคุณ** ไม่ retry เอง ไม่ rollback

## 🔖 ทำค้างแล้ว session ปิดไป — resume ได้

ทั้งสองโหมดเขียน **resume marker** ลง plan ระหว่างทาง รัน `/ow-implement <plan>` ซ้ำได้เลย ไม่ต้องไล่ดู
`git diff` เองว่าทำถึงไหน

| marker | ใครเขียน | หน่วย |
|---|---|---|
| `## Chunk Progress` | รอบที่ delegate | `chunk 2/4 · steps 4-6` |
| `## Step Progress` | รอบที่ทำ inline | `steps 1-3` — โหมด `--from-fix` ใช้ path ไฟล์จาก `## Affected Files` แทน |

```markdown
## Step Progress (written by /ow-implement — resume marker)
- [x] steps 1-3 · 2026-08-07 14:20 · exit: `pnpm test src/api/cart` passes
```

- เขียน **หลังรัน exit ผ่านจริงแล้วเท่านั้น** — marker ที่เขียนล่วงหน้าคือคำโกหกที่รอบหน้าจะเชื่อ
- ลงทุก **2-4 steps** ไม่ใช่ทุก step — plan 15 steps ควรได้ ~4-5 บรรทัด (ค่า token ~1-2% ของรอบ implement
  แลกกับการไม่ต้องเดาใหม่ทั้งหมดตอน session ตาย)
- เขียน `- [x]` เท่านั้น ไม่มี `- [ ]` → gate ตอนปิดงาน (Phase 6.0 ต้องไม่เหลือ checkbox เปิด) ไม่พัง
- resume ทุกครั้ง **รัน exit ของบรรทัดล่าสุดเช็คก่อน** — ไม่ผ่าน (โค้ดหาย/ถูก revert) = **หยุด ถามคุณ** ไม่ข้ามมั่ว
- ❌ ไม่ติ๊ก Goals / Success Criteria / Test Plan / DS Compliance ล่วงหน้าแทน — พวกนั้นต้องผ่าน gate จริงก่อน (Phase 5/6)

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Validate plan: **Refuse ถ้า status != approved**, ตรวจ Implementation Steps + subagent_target
   - **Phase 1.2** — resume gate: มี `## Chunk Progress` / `## Step Progress` → ตรวจ exit ของบรรทัดล่าสุด แล้วต่อจากจุดที่ค้าง
2. **Phase 2** — Fix doc gaps ถ้า `Doc Gaps Found` ไม่ว่าง (inline เป็น default · `docs` subagent เมื่อ gap เยอะ/แยกอิสระ)
3. **Phase 3** — **3.0 ตัดสินก่อนว่า inline หรือ delegate** (ดุลพินิจ ไม่บังคับทางไหน) → 3.1 กติกาการลงมือ (ใช้ทั้งสองโหมด) · delegate เมื่อนั้นถึงอ่าน `_shared/delegation.md` แล้วแบ่ง chunk + วน spawn พร้อม handoff · inline เขียน `## Step Progress` ระหว่างทาง (3.3)
4. **Phase 4** — Design system gate: งาน frontend/mobile ต้องอ่าน DS-Tokens + DS-Components ก่อนเขียน UI (บังคับทั้ง inline และ delegate) → STOP ถ้าต้อง component ใหม่
5. **Phase 5** — รัน build/test จริง (`_shared/build-test.md`) → coverage audit → discipline audit; output ลง scratch run dir ชั่วคราว ผลสรุปเข้า plan
6. **Phase 6** — Update plan (`status: done`, `Implementation Result` section) + IMPLEMENTATION-STATUS
   - **Phase 6.5** — ปิด fix-log อัตโนมัติเมื่อ plan มี `source_fix:` **หรือ** รันแบบ `--from-fix`: flip `status: fixed` + tick checkboxes + `fixed_commit: pending` (sha จริง/`fixed_in_version` เติมโดย `/ow-git --bump`) — ไม่ปล่อย fix-log ค้าง `in-progress` (#30)

## Area routing (`subagent_target`)

`subagent_target` = **พื้นที่งาน** ⇒ rules/gates ชุดไหนถูกใช้ — **ไม่ใช่คำสั่งให้ spawn**
Claude ตัดสินเอง (Phase 3.0) ว่างานนี้ทำ inline หรือ delegate — **ไม่บังคับทางไหน** โดยรู้ trade-off จริง:
spawn ไม่แชร์ context ⇒ agent เริ่มจากศูนย์ อ่านซ้ำ จ่าย cold-cache ทุกครั้ง (แบ่ง chunk = จ่ายทุก chunk) ·
สิ่งที่ได้กลับมา = context budget แยก + tool surface ของตัวเอง + agent file ที่เขียนไว้สำหรับพื้นที่นั้น
(คุ้มตอน plan ใหญ่ / gate ของ area หนักและครบในตัว / build-test loop ยาวใน worktree) · output บอกว่ารันแบบไหน

| `subagent_target` | rules ที่ใช้ (inline) / agent ที่ spawn (delegate) |
|---|---|
| `backend` | `.claude/agents/backend.md` |
| `frontend` | `.claude/agents/frontend.md` |
| `mobile` | `.claude/agents/mobile.md` |
| `docs` | `.claude/agents/docs.md` |
| `design` | `.claude/agents/design.md` |
| `all` | sequence: backend → frontend → mobile → docs |

🔴 **มีแน่ๆ ตัวเดียวคือ `docs`** — ที่เหลือเป็น agent ที่ project สร้างเองด้วย `/ow-agent create <name>`
obsidian-workflow ไม่ได้ ship มา · ไฟล์ไม่มี ⇒ **รัน inline** (เป็นเคสปกติ ไม่ใช่ error) area rules ยังบังคับครบเหมือนเดิม

## Output ที่ได้

- Code changes (production + test files)
- ตาราง Build/Test Result + Test Coverage Added ใน plan (มาจาก stdout จริง)
- Plan file update: `status: done` + `## Implementation Result` section
- `docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md` mark feature/phase done

## Workflow ที่นิยม

ตัวอย่าง 1: feature implement
```
1. /ow-plan FEAT-Checkout            ← plan file (status: planning)
2. [user review + set status: approved]
3. /ow-implement <path>              ← คุณอยู่ที่นี่
   → fix doc gaps (ถ้ามี)
   → read DS + implement + capture screenshots  (inline; งานใหญ่ค่อย delegate frontend agent)
   → update plan status: done
4. /ow-test --since HEAD             ← smoke test
5. /ow-verify                         ← handoff
```

ตัวอย่าง 2: bug fix
```
1. /ow-fix "search ค้าง"
2. /ow-plan fix:search-stuck
3. [approve]
4. /ow-implement <plan>
   → fix + add regression test (ตาม rules ของ backend)
   → Phase 6.5: ปิด fix-log ต้นทาง auto (status: fixed) — ไม่ต้องปิดมือ
```

ตัวอย่าง 3: multi-stack feature
```
plan: subagent_target: all
/ow-implement <plan>            ← ไล่ทีละพื้นที่ตามลำดับ (ไม่ยิงขนาน)
  → API (backend rules)
  → UI (frontend rules + DS gate)
  → mobile screen (mobile rules)
  → FN-* files update (docs rules)
  แต่ละพื้นที่จะทำ inline หรือ delegate agent ของพื้นที่นั้น — เลือกตามขนาดงาน (Phase 3.0)
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามเล่าการแก้ในเอกสาร vault** — "เดิม X → ใหม่ Y" / หัวข้อ `## Changelog` ให้ทับด้วยค่าปัจจุบันแทน · before/after อยู่ใน plan (`80-ImplementPlan`) หรือ fix-log (`85-FixLog`) · `/ow-secure` Phase 2.6 บล็อกให้
- 🚫 **Refuse ถ้า plan ไม่ approved** — ต้อง set `status: approved` ใน frontmatter manually ก่อน
- 🚫 **ห้ามแก้ scope** จาก plan โดยไม่ revise plan ก่อน — ใช้ `/ow-plan --revise`
- 🚫 **ห้าม fake ผล test/build** — ถ้า fail บอก blocker แทน
- 🚫 ห้ามแก้ shared/production env โดยไม่ confirm
- 🚫 **ห้ามเพิ่ม abstraction/config/feature** ที่ plan ไม่ได้ระบุ (minimum correct change)
- 🚫 **ห้าม refactor ไฟล์นอก scope** ของ plan
- ⚠️ Design system gate: ถ้าต้อง component ใหม่ → STOP → ต้องรัน `/ow-design component <name>` ก่อน
- ⚠️ Test creation **mandatory** ถ้า production code change — ดู `.claude/agents/{backend,frontend,mobile}.md` §5.1
- 💡 ทุก changed line ต้อง trace กลับไปยัง step ใน plan หรือ success criteria ได้
- 💡 ถ้า test fail: schema/mock outdated → แก้ test; regression/wrong logic → แก้ code (ห้ามลด assertion)
- 💡 plan ที่มี `source_fix:` (มาจาก `/ow-plan fix:<slug>`) → fix-log ต้นทางถูกปิด `status: fixed` อัตโนมัติตอน done (Phase 6.5) — ไม่ต้องไปปิดมือ (#30)

## Related

- ก่อน `/ow-implement`: [/ow-plan](./ow-plan.md) (บังคับ) — plan ต้อง approved
- หลัง `/ow-implement`: [/ow-test](./ow-test.md), [/ow-secure](./ow-secure.md), [/ow-verify](./ow-verify.md)
- Subagent specs: [`.claude/agents/{backend,frontend,mobile,docs,design}.md`](../.claude/agents/)

## FAQ

**Q: ทำไมต้อง approve plan ก่อน?**
A: Gate ให้ user review สิ่งที่จะเกิดขึ้น + เพิ่ม intentionality ป้องกัน AI ทำเกิน scope

**Q: ถ้า plan ใหญ่ใช้เวลานาน — แบ่งย่อยได้ไหม?**
A: ได้ — แบ่ง plan เป็นหลายไฟล์ (เช่น P1/P2/P3) แล้ว `/ow-implement` ทีละ plan

**Q: ถ้า subagent ไม่ได้ enable?**
A: `/ow-implement` จะ warn + แนะนำ `/ow-agent enable <name>` ก่อนรันใหม่
