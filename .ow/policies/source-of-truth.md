# Policy — Source of Truth

## หลัก

ทุก fact ต้องมาจาก source-of-truth ที่ระบุ; ห้ามอ้าง memory ของ AI หรือ "ความรู้ทั่วไป"

## Hierarchy

1. **Vault** (`docs/vault/`) — product/feature/function decisions
2. **Code** (source files) — current implementation
3. **`.ow.yml`** — config
4. **`.ow/`** — process standard
5. **External docs** ที่อ้าง URL ชัดเจน — third-party

## ห้าม

- อ้าง requirement ที่ไม่อยู่ใน vault — ต้องสร้าง PRD/SRS/FN spec ก่อน
- อ้าง code behavior ที่ไม่ได้อ่าน source จริง
- อ้าง 3rd-party API ที่ไม่มี link/version

## ถ้า source-of-truth ขัดแย้ง

- Vault vs Code = drift → `/ow-doc --review` แล้วเลือก resolve direction
  (update doc หรือ update code)
- ต้อง deviate จาก standard → บันทึกเป็น ADR

## วิธีอ้าง

- `[[<wikilink>]]` สำหรับ vault doc
- `path/to/file.ts:42` สำหรับ code
- URL + access-date สำหรับ external
