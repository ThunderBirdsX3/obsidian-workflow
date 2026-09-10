# /ow-split

> **แตก plan ใหญ่เป็น sub-plan ที่จบในตัว** — แต่ละตัวรันจบได้ใน session เดียว (หรือ local model 200K) โดยไม่ต้องไปสืบอะไรเอง · **ไม่แตะโค้ด**

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-split.md`](../.ow/commands/ow-split.md)

## เมื่อไหร่ใช้

- plan ข้ามหลาย area (เช่น api + web + mobile) หรือยาวเกิน ~15 steps
- จะรัน `/ow-implement` ด้วย **model ที่ context เล็ก** (local 200K/256K)
- อยากลด token สะสม — session ยาวจ่าย context ซ้ำทุก turn, N session สั้นถูกกว่ามาก
- plan มี `split_advised: true` ใน frontmatter — `/ow-plan` วัดแล้วพบว่า read-set เกิน budget จึงแนะนำให้แตกก่อน
  (คนละ budget กัน: `/ow-plan --budget` default 40000 = vault read-set ตอนวางแผน · `/ow-split --budget` default 120000 = context ต่อ execution unit)

**ไม่ต้องใช้เมื่อ**: plan อยู่ area เดียว ≤ ~8 steps ไม่มี cross-area dependency → `/ow-split` จะปฏิเสธเอง
(แตกย่อยเกินไป = จ่าย cold start ต่อ unit ฟรี ขาดทุนล้วน)

## Quick start

```
/ow-split docs/obsidian-vault/80-ImplementPlan/2026-08-06-1430-patient-reg.md
```

ไฟล์ที่ได้ (flat ใน `80-ImplementPlan/` เรียงติดกับ parent):

```
2026-08-06-1430-patient-reg.md                          ← parent (แก้ in-place: + ## Sub-Plans)
2026-08-06-1430-patient-reg-CONTRACT.md                 ← ค่าที่ใช้ร่วม (~40 บรรทัด)
2026-08-06-1430-patient-reg-a-api-patient-endpoints.md
2026-08-06-1430-patient-reg-b-web-patient-list.md
2026-08-06-1430-patient-reg-c-web-patient-detail.md
```

## Flags

```
/ow-split <plan>                    # auto — เลือกแกนตามรูปงานจริง
/ow-split <plan> --by area|feature|file
/ow-split <plan> --max <N>          # จำนวน unit สูงสุด (default 8)
/ow-split <plan> --budget <tokens>  # context budget ต่อ unit (default 120000)
```

`--by area` = ตาม `subagent_target` · `--by feature` = ตาม feature/หน้าจอ (web หลายหน้า → หลาย unit) ·
`--by file` = ตามกลุ่มไฟล์ (refactor กว้าง)

## แกนการแตกไม่ fix

`api / web / mobile` เป็นแค่ตัวอย่างที่อ่านง่าย — **1 sub-plan = 1 concern ที่ execute จบในตัว**
ชื่อ unit ตั้งตามเรื่องที่แก้ ไม่ใช่ชื่อ stack

| งาน | unit ที่ได้ |
|---|---|
| multi-repo แก้ทั้ง 3 stack | `a-api` · `b-web` · `c-mobile` |
| single-repo แต่ web หลายหน้าเกินไป | `a-api-patient-endpoints` · `b-web-patient-list` · `c-web-patient-detail` |
| single-repo ไม่มี stack แยกเลย | `a-db-migration` · `b-domain-model` · `c-worker-queue` |

1 stack แตกได้หลาย unit — เกณฑ์คือ budget + "จบในตัว" ไม่ใช่จำนวน stack
🔴 1 unit = 1 `subagent_target` เสมอ (unit ห้ามคร่อม area)

## CONTRACT — ค่าที่ใช้ร่วมกัน

ค่าที่ unit หนึ่งกำหนดแล้ว unit อื่นต้องใช้ตาม (field name, response shape, enum, label, ลำดับ UI)
อยู่ใน **ไฟล์เดียว** ไม่ฝังใน parent (consumer อ่านทุกรอบ — ฝังในไฟล์ใหญ่ = จ่าย token ทิ้ง)

```markdown
| id | key | planned | actual | state | producer | consumers |
|---|---|---|---|---|---|---|
| R1 | `Patient` PK field | `hn` | `hospitalNumber` | actual  | a-api | b-web, c-web |
| R2 | `GET /patients` resp | `{items,total}` |   | planned | a-api | b-web |
```

**วงจร living contract:**

1. `/ow-split` เดาค่าไว้ก่อน → `state: planned`
2. `/ow-implement <a-api>` ทำจริง → **step สุดท้ายเขียน `actual` กลับ + set `state: actual`**
   (เป็น Implementation Step + Success Criteria checkbox ⇒ Phase 6.0 open-checkbox gate บังคับให้ทำ)
3. `/ow-implement <b-web>` → **step 0 อ่าน CONTRACT ก่อน**
   - row ที่ตัวเองเป็น consumer ยัง `planned` → 🛑 STOP "รัน a-api ก่อน"
   - `actual` ต่างจากที่ plan เขียนไว้ → **ใช้ค่าจาก CONTRACT** (CONTRACT ชนะเสมอ) ไม่ต้องหยุด ไม่ต้อง regen

⇒ contract เปลี่ยน = **แก้ CONTRACT ไฟล์เดียวจบ** sub-plan ที่เหลือถูกเองอัตโนมัติ

## Context budget — ทำไม sub-plan ถึงพอดี model เล็ก

`/ow-split` **วัดจริง** ไม่ได้เดา: `wc -c` ทุกไฟล์ใน read-set ของแต่ละ unit (นับทั้งไฟล์ เพราะ Read tool
โหลดทั้งไฟล์) → แปลงเป็น token → บวก fixed overhead 25k (system + Phase 0 + rules + agent file ถ้ามี — ไม่มี agent ก็ยังใช้ตัวเลขเดิม เพราะ inline run อ่าน command spec แทนในปริมาณใกล้กัน)

- เกิน `BUDGET` (default 120000 = 200K × 0.6) → แตกต่อ
- ต่ำกว่า 15k → รวมกับ sibling ที่ **`subagent_target` เดียวกัน**
- ผลลัพธ์เขียนลง `context_est_tokens:` ของแต่ละ sub-plan

🔴 ตัวเลขนี้เป็น **heuristic จาก byte** ไม่ใช่การวัดด้วย tokenizer จริง — คำสั่งจะบอกเสมอเวลารายงาน

## ทำไม implement ถึงไม่อ่านไฟล์เกินจำเป็น

sub-plan มี `context_closed: true` + `context_refs:` ⇒ `/ow-implement` **ข้าม include-when re-resolution**
ทั้งหมด (ปกติกฎคือ "uncertain ⇒ read it" ซึ่งเป็นท่อรั่ว) — `/ow-split` ตัดสินให้แล้วตอนแตก

escape hatch เดิมยังอยู่: ต้องอ่านไฟล์นอก list จริงๆ → อ่านได้ แต่ต้อง report `context gap: <doc> — needed for <reason>`

## Workflow เต็ม

```
/ow-plan "ระบบลงทะเบียนผู้ป่วย"              ← plan ใหญ่
/ow-split docs/.../2026-08-06-1430-patient-reg.md
# [review sub-plan แต่ละตัว → set status: approved]

/ow-implement <...-a-api-patient-endpoints.md>
/clear                                        ← 🔴 สำคัญ ไม่ clear = ไม่ประหยัด token เลย
/ow-implement <...-b-web-patient-list.md>
/clear
/ow-implement <...-c-web-patient-detail.md>

/ow-verify docs/.../2026-08-06-1430-patient-reg.md   ← ปิดงานที่ parent
```

`/ow-verify` เจอ `## Sub-Plans` → grep `status:` ทุก sub-plan (ไม่เปิดไฟล์) → ไม่ครบ = บอกว่าเหลือ unit ไหน
แล้ว STOP · ครบ = verify integration ระหว่าง unit ด้วย → ผ่านจึง flip parent เป็น `done`

## ขั้นตอนภายใน (Phase summary)

| Phase | ทำอะไร |
|---|---|
| 0 | Load context (resolver) |
| 1 | อ่าน parent + vault docs ที่ parent อ้าง · เจอ `## Sub-Plans` แล้ว → ไป 5.5 |
| 2 | ออกแบบการแตก + สกัด Shared Contract + ลำดับ dependency |
| 2.5 | วัด read-set ต่อ unit เทียบ budget → แตกต่อ / รวมเข้าด้วยกัน |
| 3 | Clarify (เฉพาะที่ parent ไม่ตอบ, ถามรวมครั้งเดียว) |
| 4 | เขียน CONTRACT + sub-plan ทุกไฟล์ |
| 5 | แก้ parent เป็น orchestrator (+ `## Shared Contract` + `## Sub-Plans`) |
| 5.5 | รันซ้ำ = incremental — เขียนทับเฉพาะ unit ที่ `status: planning` เท่านั้น |
| 6 | Output + STOP |

## Gotchas / ข้อควรระวัง

- **ไม่ `/clear` = ไม่ประหยัด** — ประโยชน์เรื่อง token มาจากการที่ context สะสมของแต่ละ session เล็กลง
- **plan เล็กอย่าแตก** — cold start ต่อ session ~15-30k tokens × N อาจแพงกว่ารันรวดเดียว
- **รันเรียงตัว** — consumer ที่ producer ยังไม่เสร็จจะ STOP ที่ step 0 (ตั้งใจ ไม่ใช่บั๊ก)
- **`/ow-split` ไม่ set `status: approved` ให้** — ต้อง review เอง เหมือน `/ow-plan`
- **รันซ้ำปลอดภัย** — เขียนทับเฉพาะ `status: planning` · `approved`/`in-progress`/`done` ปลอดภัยหมด
  (`/ow-implement` ไป `approved` → `done` ไม่เคยแวะ `in-progress` ⇒ unit ที่ implement ตายกลางทาง
  ค้างที่ `approved` พร้อมงานจริงในโค้ด) · unit ที่มี `## Step Progress`/`## Chunk Progress` ไม่ถูกแตะทุกกรณี
- **worktree** — sub-plan สืบ `worktree:` จาก parent; ต้องรันเรียงตัว (a merge เสร็จ b ค่อยเริ่ม)

## Related

- [/ow-plan](./ow-plan.md) — สร้าง plan ที่จะเอามาแตก
- [/ow-implement](./ow-implement.md) — รัน sub-plan ทีละตัว
- [/ow-verify](./ow-verify.md) — ปิดงานที่ parent

## FAQ

**Q: ต่างจาก chunk ใน delegated implement ยังไง?**
A: chunk (`_shared/delegation.md` §2) อยู่ใน context ของ orchestrator — session เดียว, delegated mode เท่านั้น,
หมดไปเมื่อจบ. sub-plan เป็น **ไฟล์** → ข้าม session, ข้ามเครื่อง, รันด้วย model คนละตัวได้

**Q: ประหยัดเครดิตเท่าไหร่?**
A: ขึ้นกับขนาด plan. หลักการ: session ยาวจ่าย context สะสมซ้ำทุก turn (โตแบบ quadratic) — split + `/clear`
ทำให้แต่ละ session เหลือ ~1/N. หักต้นทุน cold start ต่อ session แล้วยังคุ้มเมื่อ plan ใหญ่จริง
วัดของจริงได้ด้วยการดู `/cost` ต่อ session แล้วรวม เทียบกับรันรวดเดียว

**Q: ถ้า api เปลี่ยนชื่อ field หลังจากเขียน sub-plan ไปแล้ว?**
A: a-api เขียน `actual` กลับ CONTRACT → b-web/c-mobile ใช้ค่าจาก CONTRACT ทันที (CONTRACT ชนะเสมอ)
ไม่ต้อง regen ไฟล์ ไม่ต้องรันอะไรเพิ่ม
