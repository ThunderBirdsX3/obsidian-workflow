# /ow-reverse-engineer

> **อ่านโค้ดที่มีอยู่ → สร้าง vault docs draft** — TechStack, API, domain models, feature clusters (brownfield)

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-reverse-engineer.md`](../.ow/commands/ow-reverse-engineer.md)

## เมื่อไหร่ใช้

- Brownfield project ที่มีโค้ดอยู่แล้วแต่ไม่มี spec/vault เลย
- หลัง `/ow-init --brownfield` เพื่อ generate docs ละเอียดกว่า Phase 3 ของ init
- ต้องการ map codebase → vault ก่อนเริ่มวางแผน feature ใหม่

> **Read-only บนโค้ด** — ไม่แตะ source files เด็ดขาด

## Quick start

```
/ow-reverse-engineer
```

แล้วตอบ:
```
Area: all
Depth: deep
→ scan → review checkpoint → สร้าง draft docs
```

## รูปแบบเต็ม

```
/ow-reverse-engineer                        # scan ทั้ง project
/ow-reverse-engineer --area api             # เฉพาะ API/routes
/ow-reverse-engineer --area ui              # เฉพาะ UI components/screens
/ow-reverse-engineer --area models          # เฉพาะ domain models/schemas
/ow-reverse-engineer --depth shallow        # โครงสร้างอย่างเดียว (เร็ว)
/ow-reverse-engineer --depth deep           # อ่านไฟล์จริง (ละเอียด)
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--area` | all | จำกัด scope (api/ui/models/all) |
| `--depth` | shallow | shallow = folder/file structure; deep = อ่านเนื้อหาจริง |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect project structure (manifests, source roots, entry points)
2. **Phase 1** — Tech stack scan → draft `REF-TechStack.md`
3. **Phase 2** — API/Routes scan → draft `REF-APIIntegration.md`
4. **Phase 3** — Domain model scan → draft `FN-*.md` per entity
5. **Phase 4** — Feature cluster detection (group by folder/prefix/route) → draft `FEAT-*.md` per cluster
6. **Phase 5** — **Review checkpoint** (บังคับ) — แสดง mapping รอ user confirm ก่อนเขียนจริง
7. **Phase 6** — Write vault docs (เฉพาะที่ confirm)
8. **Phase 7** — สรุป + next steps

## Output ที่ได้

| ไฟล์ | สร้างจาก |
|---|---|
| `docs/obsidian-vault/70-Reference/REF-TechStack.md` | package.json, go.mod, requirements.txt, pubspec.yaml ฯลฯ |
| `docs/obsidian-vault/70-Reference/REF-APIIntegration.md` | routes.*, *.controller.*, @app.get() ฯลฯ |
| `docs/obsidian-vault/40-Functions/FN-<Entity>.md` | *.model.*, *.schema.*, *.entity.*, schema.prisma ฯลฯ |
| `docs/obsidian-vault/20-Features/FEAT-<Area>.md` | folder clusters (src/checkout/, /api/auth/ ฯลฯ) |

ทุกไฟล์มี frontmatter:
```yaml
status: draft
source: reverse-engineered
reverse_engineered_from:
  - src/checkout/checkout.controller.ts
```

## Review checkpoint (Phase 5)

ก่อนเขียนจริง AI จะแสดง summary ให้ confirm:

```
📋 Reverse Engineer Summary

Tech Stack: Node.js 20, Express 4, PostgreSQL, Prisma
API Endpoints: 23  → REF-APIIntegration.md
Domain Models: 6   → FN-User.md, FN-Order.md, FN-Product.md ...
Feature clusters: 4
  → FEAT-Auth.md       (src/auth/, /api/auth/*)
  → FEAT-Checkout.md   (src/checkout/, /api/orders/*)
  → FEAT-Catalog.md    (src/catalog/, /api/products/*)
  → FEAT-Reviews.md    (src/reviews/, /api/reviews/*)

⚠️  ไม่แน่ใจ:
  - src/utils/ → ไม่ชัดว่า belong feature ไหน

สร้าง draft ทั้งหมด? [y/n]
```

## Workflow

ตัวอย่าง: brownfield ที่เพิ่ง install obsidian-workflow
```
1. /ow-init --brownfield           ← config + vault skeleton
2. /ow-reverse-engineer            ← คุณอยู่ที่นี่ — scan → draft docs
3. [ตรวจ FEAT-*.md — ลบ cluster ผิด เติม business rules]
4. /ow-clarify FEAT-Checkout       ← scan ambiguity ใน draft
5. /ow-plan <first task>           ← เริ่ม workflow ปกติ
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามเล่าการแก้ในเอกสาร vault** — "เดิม X → ใหม่ Y" / หัวข้อ `## Changelog` ให้ทับด้วยค่าปัจจุบันแทน · before/after อยู่ใน plan (`80-ImplementPlan`) หรือ fix-log (`85-FixLog`) · `/ow-secure` Phase 2.6 บล็อกให้
- 🚫 **ห้ามแก้ source code ใดๆ** — read-only ทั้งหมด
- 🚫 **ห้ามเดา business rules** ที่ไม่เห็นในโค้ด — เว้นว่างไว้ `<!-- TODO: fill in -->`
- 🚫 ห้ามเขียนไฟล์โดยไม่ผ่าน Phase 5 review checkpoint
- 🚫 ห้าม overwrite vault doc ที่มีอยู่แล้วโดยไม่ถาม
- 🚫 ห้าม mark status อื่นนอกจาก `draft` — user ต้อง promote เอง
- ⚠️ `--depth shallow` = เร็วแต่ API endpoints อาจไม่ครบ; `--depth deep` = ละเอียดกว่า ใช้เวลานาน
- 💡 Draft ที่ได้เป็น **จุดเริ่มต้น** — ต้องตรวจและเติม business logic ก่อนใช้ plan/implement

## Related

- ก่อน `/ow-reverse-engineer`: [/ow-init](./ow-init.md) (ต้องมี vault skeleton ก่อน)
- หลัง draft เสร็จ: [/ow-clarify](./ow-clarify.md), [/ow-plan](./ow-plan.md)
- ถ้ามี spec doc อยู่แล้ว: [/ow-new](./ow-new.md) `--import-prd` (merge เข้า vault)

## FAQ

**Q: ต่างจาก `/ow-init --brownfield` Phase 3 ยังไง?**
A: init Phase 3 scan surface-level (dependencies + README) เร็วแต่หยาบ; `/ow-reverse-engineer` อ่านโค้ดจริง (routes, models, controllers) ละเอียดกว่ามาก

**Q: ถ้า project ใหญ่มาก scan นานไหม?**
A: ใช้ `--depth shallow` ดูโครงสร้างก่อน แล้วเลือก `--area api` หรือ `--area models` แยกทีละส่วน

**Q: Draft ที่ได้ใช้กับ /ow-plan ได้เลยไหม?**
A: ได้ แต่ต้องเติม acceptance criteria + business rules ก่อน — `/ow-clarify` ช่วย scan จุดที่ยังคลุมเครือได้
