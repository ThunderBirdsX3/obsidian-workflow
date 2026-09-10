---
tags: [type/design-system, ds/voice]
version: 1.0.0
date: 2026-05-15
---

# DS-Voice — Tone + Microcopy

## Principle

- **เป็นกันเอง** แต่ **ให้ข้อมูลครบ** — ห้าม cold technical jargon
- ใช้คำว่า **คุณ** (formal-friendly) ห้าม "ท่าน" (เป็นทางการเกิน) ห้าม "เธอ/นาย" (สนิทเกิน)
- ภาษาไทยเป็นหลัก; English fallback สำหรับ librarian UI ที่ technical

## Action buttons

- ใช้ verb-first: "บันทึก", "ยกเลิก", "ลบ", "ดูรายละเอียด"
- ห้าม "OK" — ใช้ "ตกลง" หรือ verb เฉพาะ
- Confirm dialog: ใช้ verb ที่ตรงกับ action ("ลบ", "ยืนยันยืม") ไม่ใช่ "ใช่"

## Errors

- บอกปัญหา + บอก action ที่แก้ได้
- Example:
  - ❌ "Error 500"
  - ❌ "Something went wrong"
  - ✅ "บันทึกไม่สำเร็จ — ลองอีกครั้ง หรือติดต่อ admin"
- ห้ามใช้คำที่กล่าวโทษ user ("คุณทำผิด") — ใช้ neutral

## Empty states

- เริ่มด้วยสิ่งที่ user ทำได้ ไม่ใช่สิ่งที่ขาด
- Example:
  - ❌ "ไม่มีข้อมูล"
  - ✅ "ยังไม่มีรายการ — กดเพิ่มสมาชิกใหม่"

## Success messages

- สั้น + ระบุสิ่งที่เกิด
- Example: "ยืมเรียบร้อย — กำหนดคืน 3 มิ.ย. 2026"

## Warning / Confirm

- บอก consequence ชัดเจน
- Example:
  - "หนังสือนี้ถูกยืมอยู่โดย คุณสมชาย — ยังต้องการยืมต่อ?"
  - "เกินจำนวนสูงสุด (5 เล่ม) — ยืนยันยืมเพิ่มไหม?"

## Loading

- เกิน 2 วินาที — แสดง message
- Example: "ค้นหานานกว่าปกติ..."

## Date/Time

- Thai Buddhist year? — **NO**, ใช้ Gregorian (2026) — agreed with stakeholder
- Format: "20 พ.ค. 2026 14:30" (เดือนย่อ + ปี ค.ศ.)
- Relative: "เมื่อสักครู่", "5 นาทีที่แล้ว", "เมื่อวาน"

## Numbers

- Thousand separator: comma `1,234`
- Decimal: dot `1,234.50`
- Currency: ใช้ `฿` หรือ `บาท` (consistent ใน screen เดียว)

## Form labels

- คำสั้น + เป็นนาม
- Example: "ชื่อ-นามสกุล", "เบอร์โทร", "อีเมล", "วันคืน"
- ห้าม sentence ใน label

## Helper text

- ใช้สำหรับ format guide หรือ optional info
- Example: "เบอร์โทร 10 หลัก ขึ้นต้น 0"
