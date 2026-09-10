# /ow-help

> **Interactive help + cheatsheet + decision tree** — ใช้เมื่อไม่รู้ว่าจะใช้ command ไหน

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-help.md`](../.ow/commands/ow-help.md)

## เมื่อไหร่ใช้

- เพิ่งเริ่มใช้ obsidian-workflow — อยากดูรายการ command ทั้งหมด
- รู้ว่าอยากทำอะไรแต่ไม่รู้ command ตรงเป๊ะ
- อยาก cheatsheet 1 หน้า, decision tree, หรือ workflow card

## Quick start

```
/ow-help
```

จะถาม 1 คำถาม:
```
จะให้ผมช่วยอะไร?
  1) แนะนำ command ตามสถานการณ์
  2) อธิบาย command เฉพาะ
  3) แสดง workflow ที่พบบ่อย
  4) Cheatsheet 1 หน้า
  5) ค้นด้วย keyword
```

## รูปแบบเต็ม

```
/ow-help                          # interactive — ถาม 1 คำถาม
/ow-help <command>                # อธิบาย command ตัวนั้น (เช่น /ow-help plan)
/ow-help workflow                 # workflows ที่พบบ่อย
/ow-help workflow <name>          # workflow card เฉพาะ (new-project, bug-fix, daily, design, brownfield-adopt, submodule)
/ow-help search <keyword>         # ค้น keyword ใน commands/*.md + .claude/agents/*.md
/ow-help cheatsheet               # ตาราง 1 หน้า — command × ใช้เมื่อ × ผลลัพธ์
/ow-help tree                     # decision tree "ถ้า X → ใช้ Y"
```

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect intent (ถ้า args ว่าง → ถาม mode)
2. **Phase 1** — "แนะนำตามสถานการณ์" (batch 3-5 คำถาม)
3. **Phase 2** — "อธิบาย command เฉพาะ" (อ่าน `.ow/commands/<cmd>.md` แล้วสรุป)
4. **Phase 3** — "workflows" (แสดง workflow cards)
5. **Phase 4** — "cheatsheet" (ตาราง 1 หน้า)
6. **Phase 5** — "search" (grep ใน .ow/commands/ + .claude/agents/)

## Output ที่ได้

- ไม่สร้าง/แก้ไฟล์ใดๆ — `/ow-help` เป็น **read-only**
- แสดงข้อมูลในแชตเท่านั้น

## Workflow ที่นิยม

ตัวอย่าง: user ใหม่ ไม่รู้จะเริ่มอะไร
```
1. /ow-help tree           ← ดู decision tree
2. /ow-help workflow new-project  ← step-by-step
3. /ow-init                ← เริ่มจริง
```

ตัวอย่าง: user อยาก deep-dive command
```
1. /ow-help plan           ← สรุป + path ของ full spec
2. cat .ow/commands/ow-plan.md  ← อ่านเต็ม
```

## Gotchas / ข้อควรระวัง

- 🚫 ห้ามแก้ไฟล์ — help เป็น read-only (ไม่เขียนอะไรเลย)
- 💡 ถ้า command ที่ถามไม่มีจริง → help จะ refuse (ไม่ guess)
- 💡 `/ow-help cheatsheet` คือเร็วสุดถ้ามีประสบการณ์แล้ว — รายชื่อทุก command + ใช้เมื่อ + ผลลัพธ์ ในตาราง 1 หน้า

## Related

- ทุก command ที่ help อ้างถึง → ดู `.ow/commands/<name>.md` หรือ `usage/ow-<name>.md`
- README หลัก: [`../README.md`](../README.md)

## FAQ

**Q: ถามคำถามนอก scope ของ obsidian-workflow ได้ไหม?**
A: ไม่ — help ตอบเฉพาะ command + workflow ของ obsidian-workflow ถ้าถามทั่วไป (เช่น "Vue คืออะไร") ให้ใช้ general AI

**Q: ถ้า help แนะนำ command ไม่มีจริงล่ะ?**
A: ไม่ควรเกิด — help ผูกกับ verb ที่มีไฟล์จริงใน `.ow/commands/` เท่านั้น ถ้าเจอ bug แจ้งเลย
