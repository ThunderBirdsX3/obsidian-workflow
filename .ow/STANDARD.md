# Working Standard — มาตรฐานการทำงาน

> หัวใจ: อ่านก่อนถาม · วางแผนก่อนแก้ · ตรวจจริงก่อน claim · ไม่มี evidence = ไม่ผ่าน

## 1. Understand

- อ่าน task, issue, docs ใน vault ที่เกี่ยวข้องก่อนเสมอ
- แยกเป้าหมาย, non-goals, constraints
- ระบุ assumption ถ้าข้อมูลไม่ครบ

## 2. Plan

- งานเล็ก: 3-5 bullet
- งานกลาง: แผนเป็น phase และไฟล์หลัก
- งานใหญ่: discovery, design, implementation, verification
- ระบุ success criteria ก่อนแก้ เพื่อให้ทุกขั้นตอนตรวจกลับได้
- **Minimum correct change**: ทำสิ่งที่จำเป็นให้ถูกต้องก่อน ไม่เพิ่ม abstraction/config/feature เผื่ออนาคต

## 3. Execute

- แก้เฉพาะ scope ที่เกี่ยวข้อง
- เก็บ backward compatibility ถ้าเป็นระบบใช้งานจริง
- อย่า format หรือ refactor ใหญ่โดยไม่จำเป็น
- ทำตาม pattern เดิมของ repo ก่อนสร้าง pattern ใหม่
- ทุกบรรทัดที่แก้ต้อง trace กลับไปยัง request, bug, หรือ success criteria ได้
- มี assumption/ambiguity → หยุดถามเฉพาะเมื่อกระทบ scope, data safety, security, correctness; ไม่กระทบ → ระบุ assumption แล้วทำต่อแบบเล็กที่สุด

## 4. Verify

- ใช้ test/lint/build/manual check จริง
- ถ้ารันไม่ได้ ให้บอก blocker และทางเลือกตรวจ
- เก็บ command และผลลัพธ์ไว้ใน output
- map verification กลับไปยัง success criteria ทีละข้อ และระบุส่วนที่ยังไม่มี evidence

## 5. Wrap up

- สรุปให้ตัวเอง (หรือ session ถัดไป) ทำต่อได้ทันที
- ระบุไฟล์, behavior ที่เปลี่ยน, verification, risk, next step
- งานที่ยังไม่จบ → `/ow-handoff` สร้าง session note ไว้ต่องาน

## Output ทุกงาน (3 หัวข้อบังคับ)

1. **Result** — สรุปสิ่งที่ทำ + ไฟล์ที่สร้าง/แก้
2. **Verification / Evidence** — command ที่รันจริง + ผลลัพธ์; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — ข้อจำกัด ความเสี่ยง งานต่อ

## Definition of Done

- Requirement หลักครบ + success criteria ทุกข้อมีผลลัพธ์หรือข้อจำกัดที่ระบุชัด
- เป็น minimum correct change — ไม่มี speculative abstraction/config/feature
- ไม่มี unrelated refactor, format churn, style-only change นอก scope
- ไม่มี fake evidence — verification map กลับ success criteria ได้
- ถ้าเป็น production-facing ต้องมี rollback หรือ mitigation

## Vault conventions

- Vault คือ source of truth ของ product/feature decisions — อ่านก่อนถาม user
- รักษา link graph: ทุก `[[wikilink]]` ต้องชี้ไฟล์จริง; rename → ทิ้ง alias ไว้
- Frontmatter ครบตาม template; tags ใช้ `type/<kind>` เสมอ
- ห้ามเก็บ binary ใน vault — evidence อยู่ใต้ `test-artifacts/` (gitignored)
- ภาษา: ตาม `project.language` ใน `.ow.yml` (default ไทย); code/frontmatter อังกฤษได้
