# /ow-archive

> **ย้าย plan/fix-log ที่เสร็จแล้วเข้า `archive/`** — เก็บ `80-ImplementPlan` / `85-FixLog` ให้สั้น โดยไม่ลบประวัติ

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-archive.md`](../.ow/commands/ow-archive.md)

## เมื่อไหร่ใช้

- plan/fix-log เก่าเกลื่อน `80-ImplementPlan`/`85-FixLog` — อยากเก็บให้เรียบ
- ปิด phase/release แล้ว — อยากรวม plan ของ phase นั้นไว้ด้วยกัน (`--into phase1`)
- ทำความสะอาดก่อน handoff/release — ไม่ต้องการให้ list งานปนกับงานเก่า

## Quick start

```
/ow-archive
```

ย้าย**ทุกไฟล์**ใน `80-ImplementPlan/` และ `85-FixLog/` (ที่ยังไม่ใช่ archive) เข้า `archive/<วันนี้>/`:
```
docs/obsidian-vault/80-ImplementPlan/archive/2026-09-22/2026-05-21-1430-add-search.md
docs/obsidian-vault/85-FixLog/archive/2026-09-22/2026-05-21-1430-search-stuck.md
```

ตั้งชื่อ subfolder เอง:
```
/ow-archive phase1
→ ทุกไฟล์เข้า archive/phase1/ แทน archive/2026-09-22/
```

## รูปแบบเต็ม

```
/ow-archive                          # ย้ายทุกไฟล์ → subfolder = วันนี้
/ow-archive <name>                   # ย้ายทุกไฟล์ → subfolder ชื่อที่ตั้งเอง เช่น phase1, 2026-Q3
/ow-archive --into <name>            # เหมือนกัน เขียนแบบ flag
```

ไม่มีการเลือกไฟล์ — ย้ายทั้งหมดเสมอ argument เดียวที่รับคือชื่อ subfolder ปลายทาง

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — รวมไฟล์ทั้งหมดใน `$PLAN_DIR` + `$FIX_DIR` (ไม่นับที่อยู่ใน `archive/` แล้ว)
2. **Phase 2** — หา subfolder ปลายทาง (`<name>`/`--into <name>` หรือ default = วันที่วันนี้)
3. **Phase 3** — ถาม y/n ยืนยันครั้งเดียว แล้ว `git mv` เข้า `archive/<name>/`
4. **Phase 4** — ไล่แก้ลิงก์ที่ยังชี้ path เก่า (MOC, IMPLEMENTATION-STATUS, plan/fix-log อื่นที่ reference กัน)

## Gotchas / ข้อควรระวัง

- 🚫 **ไม่ลบไฟล์** — ย้ายที่อย่างเดียว เนื้อหา/frontmatter ไม่ถูกแก้
- 🚫 ไม่แตะไฟล์นอก `80-ImplementPlan` / `85-FixLog`
- 🚫 ปลายทางมีไฟล์ชื่อซ้ำอยู่แล้ว → หยุดถามก่อน ไม่ทับ
- 💡 archive ไม่เปลี่ยน `status` ให้ — ถ้าอยากปิดสถานะด้วยต้องบอกแยก

## Related

- ก่อน archive: `/ow-plan`, `/ow-fix` (สร้างไฟล์ที่จะ archive)
- Vault path: `docs/obsidian-vault/80-ImplementPlan/archive/`, `docs/obsidian-vault/85-FixLog/archive/`
