<!-- Checklist ของคุณเอง — แก้/เพิ่มข้อได้ตามต้องการ -->

# Checklist — Before Release

ก่อน `/ow-release` (gate ใน Phase 1):

- [ ] `/ow-verify` รอบล่าสุดของ scope ผ่าน — มี evidence จริง (ไม่ใช่ "น่าจะผ่าน")
- [ ] `/ow-secure` ผ่าน ALL GREEN หรือ justified
- [ ] ทุก plan ใน scope `status: done` — ไม่มี in-progress ค้างที่ตั้งใจจะรวมรอบนี้
- [ ] ทุก fix log ใน scope มี `fixed_commit` (ไม่เหลือ `pending`)
- [ ] SRS § 12 Acceptance for Release: FR P1+P2 ของ scope ครบ (ดู `/ow-trace --gaps`)
- [ ] Working tree clean ทุก repo (`/ow-git --status`) — หรือ dirty เฉพาะไฟล์ใน release scope
- [ ] ไม่มี migration ค้างที่ยังไม่ได้รัน/ทดสอบ (ถ้ามี DB)
- [ ] Breaking changes ระบุใน changelog ชัดเจน + bump kind ถูก (breaking = major)
- [ ] Rollback ได้: รู้ว่า version ก่อนหน้าคืออะไร + ถอยยังไง
- [ ] `IMPLEMENTATION-STATUS` ตรงกับความจริงก่อนประกาศ release
