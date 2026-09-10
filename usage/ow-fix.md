# /ow-fix

> **Diagnose bug + สร้าง fix-log** — บันทึก RED baseline, หา root cause; P2/P3 ถามต่อว่าแก้เลยไหม แล้วเรียก `/ow-implement --from-fix` ให้

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-fix.md`](../.ow/commands/ow-fix.md)

## เมื่อไหร่ใช้

- เจอ bug → อยาก document + diagnose ก่อนแก้
- ลูกค้า report — ต้องเก็บ trail สำหรับ exec/QA
- บั๊ก regression — track ครั้งที่ 2, 3 ของ bug เดียวกัน (`--update`)
- P0/P1 → `/ow-fix` → `/ow-plan fix:<slug>` → `/ow-implement` (= แก้จริง)
- P2/P3 → `/ow-fix` → ตอบ `y` → แก้จบในคำสั่งเดียว

## Quick start

```
/ow-fix "search ค้างเมื่อใส่ขีดล่าง"
```

ตัวอย่างไฟล์ที่ได้:
```
docs/obsidian-vault/85-FixLog/2026-05-21-1430-search-stuck-underscore.md

---
status: in-progress
severity: P1
area: web
---

# search ค้างเมื่อใส่ขีดล่าง
## Symptom · Reproduction · Root Cause · Vault Context · RED baseline · Fix Approach · Affected Files · Test Cases · Risk · Next
```

## รูปแบบเต็ม

```
/ow-fix "<bug description>"
/ow-fix <bug> --update docs/obsidian-vault/85-FixLog/<file>.md
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--update <path>` | new file | append investigation/findings/status change ใน fix-log เดิม (append-only) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Detect mode (new vs --update)
2. **Phase 2** — Diagnose (read-only): identify area, reproduce (read code preferred), grep/Read root cause, draft fix approach + test cases
3. **Phase 2.5** — RED baseline: บันทึกสภาพที่บั๊ก **ยังเกิดอยู่** (quote output จริงที่ fail) — ยังไม่แก้โค้ด · เป็นหลักฐานฝั่ง RED ที่ `/ow-implement` เอาไปเทียบตอน GREEN
4. **Phase 3** — สร้าง fix-log `docs/obsidian-vault/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md`
5. **Phase 4** — Auto-fix gate + ถาม: gate ผ่าน (P2/P3 + scope เล็ก + มี reproduce/regression test) → ถาม `แก้เลยไหม? y / plan / pause`; `y` = รัน `/ow-implement --from-fix` ทันที (gate ครบทุกด่าน, ปิด fix-log เองตอนเสร็จ). gate ไม่ผ่าน → เสนอ `/ow-plan fix:<slug>` (ผูก link สองทาง `source_fix:` ↔ `related_plan:`) (#30)
6. **Phase 5** — Update mode (append section: investigation update, new findings, status change)

## Fix-log structure

```
Frontmatter:
  status: in-progress | fixed | wont-fix | regressed
  severity: P0 blocker | P1 major | P2 minor | P3 polish
  area: api | web | mobile | cross
  reported_by: user | qa | self | customer
  related_plan: "[[plan-slug]]" | none   ← /ow-plan fix: เขียน (back-link); ปิด fix-log auto โดย /ow-implement
  # fixed_commit / fixed_in_version — เติม auto โดย /ow-git --bump ตอนปิด

Body:
  ## Symptom               ← what user sees
  ## Reproduction          ← steps + expected vs actual
  ## Root Cause            ← file:function:line จาก grep/read
  ## Vault Context Read    ← FN-*, REF-Auth, similar fix-logs
  ## RED baseline          ← failing test output (quote จริง) + สภาพที่ผิดบนจอ
  ## Fix Approach          ← paragraph (ยังไม่ใช่โค้ด)
  ## Affected Files
  ## Test Cases            ← พิสูจน์ว่า fix ใช้ได้
  ## Risk                  ← ของ fix นี้ + mitigation
  ## Next                  ← /ow-plan fix:<slug> → /ow-implement
```

## Output ที่ได้

- `docs/obsidian-vault/85-FixLog/YYYY-MM-DD-HHMM-<slug>.md`
- RED baseline เป็น **text ใน fix-log** — quote output จริง trim เฉพาะบรรทัดที่เกี่ยว (ไม่เก็บไฟล์ ไม่มี binary ใน vault)
- **ไม่แตะโค้ด**

## Severity guide

| Level | ใช้เมื่อ |
|---|---|
| P0 — blocker | service ลม, data loss, security breach |
| P1 — major | feature broken, ผู้ใช้ได้รับผลกระทบกว้าง |
| P2 — minor | edge case, workaround มี |
| P3 — polish | cosmetic, copy, small UX |

## Workflow ที่นิยม

ตัวอย่าง 1: standard bug fix
```
1. /ow-fix "search ค้าง"              ← คุณอยู่ที่นี่ — diagnose + fix-log
2. /ow-plan fix:search-stuck           ← mini-plan link ไปยัง fix-log
3. [approve]
4. /ow-implement <plan>
5. /ow-test --since HEAD~              ← verify fix
6. /ow-git --fix <fix-log>             ← commit prefix `fix:`
```

ตัวอย่าง 2: P2/P3 แก้ในตัว (skip plan)
```
1. /ow-fix "typo ใน button"
   → severity P3, auto-fix gate ผ่าน
   → "แก้เลยไหม? y / plan / pause"
2. y                                    ← /ow-fix เรียก /ow-implement --from-fix ให้เอง
```

ตัวอย่าง 3: regression
```
1. /ow-fix "search ค้างอีกแล้ว" --update docs/obsidian-vault/85-FixLog/2026-05-10-search-stuck.md
   → append section: "Investigation update — regressed after refactor"
   → change status: in-progress → regressed
```

## Gotchas / ข้อควรระวัง

- 🚫 **`/ow-fix` ไม่แก้โค้ดเอง** — ตอบ `y` แล้วมันเรียก pipeline ของ `/ow-implement` (gate ครบ) ให้
- 🚫 ห้ามเดา root cause โดยไม่ verify ที่ source (grep/read)
- 🚫 ห้ามแต่ง error message หรือ stack trace
- 🚫 `--update` = append-only — ห้าม overwrite section เดิม
- ⚠️ Bug ไม่ชัด → ถาม **1-3 คำถามใน message เดียว**
- 💡 fix-log เป็น "lighter plan" ของ obsidian-workflow — โครงเล็กกว่า `/ow-plan` แต่หลักการเดียวกัน
- 💡 P0/P1 ต้องผ่าน `/ow-plan fix:<slug>` เสมอ — blast radius กว้าง ต้องมีคน review plan
- 🚫 ห้ามลด severity เพื่อให้ผ่าน auto-fix gate

## Related

- ก่อน `/ow-fix`: ผู้ใช้ report bug / `/ow-test` เจอ FAIL
- หลัง `/ow-fix`: [/ow-plan](./ow-plan.md) `fix:<slug>` → [/ow-implement](./ow-implement.md)
- Vault path: `docs/obsidian-vault/85-FixLog/`
- Template: `templates/fix-log.md`

## FAQ

**Q: ต่าง `/ow-fix` กับ `/ow-plan` ยังไง?**
A: `/ow-plan` = feature work (vault-driven, FR-### mapping, 5-15 steps); `/ow-fix` = bug (diagnose-first, lighter structure, root cause focus)

**Q: ผมแก้บั๊กเอง ไม่ผ่าน `/ow-fix` ได้ไหม?**
A: ได้ทางเทคนิค แต่จะไม่มี trail สำหรับ exec/audit — แนะนำผ่าน workflow แม้บั๊กเล็ก

**Q: P3 polish ต้องมี fix-log ไหม?**
A: ต้องมี — fix-log = หน่วยงานของ `--from-fix` (gate 5.0/5.2/5.3/6.0 รันกับมัน). ที่ skip ได้คือ `/ow-plan`; `--from-fix` รับ P2/P3 เท่านั้น
