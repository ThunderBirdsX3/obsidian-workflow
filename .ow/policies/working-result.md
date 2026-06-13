# Policy — Working Result

## หลัก

ส่งงานเมื่อ**ทำงานได้จริง** — ไม่ใช่แค่ compile ผ่าน

## ระดับ Working

| ระดับ | นิยาม | ใช้เมื่อ |
|---|---|---|
| **Compiles** | build ไม่ error | minimum bar (ไม่พอสำหรับปิดงาน) |
| **Lint clean** | lint ไม่มี error | ก่อน commit |
| **Tests pass** | unit + integration pass | ก่อน PR / ปิด plan |
| **Local smoke** | รัน flow หลักผ่านจริง local | ก่อน /ow-verify ผ่าน |
| **Staging smoke** | รันใน staging ผ่าน | ก่อน production deploy |
| **Production verified** | ใช้งานจริงไม่มี regression | post-deploy |

## บังคับ

- `/ow-implement` ต้องถึง "Tests pass" minimum
- `/ow-verify` ต้องถึง "Local smoke" minimum
- Production deploy ต้องถึง "Staging smoke" minimum
- Output ทุกงานระบุระดับที่ achieved

## ห้าม

- Claim "working" ถ้าแค่ compiles
- Skip level โดยไม่ระบุเหตุผล
- Mark "done" ถ้า test ที่เพิ่งเขียนยังไม่ได้ run

## Exception

Block ที่ระดับใด (เช่น staging ไม่พร้อม) → ระบุชัดเจน + เสนอ alternative verification
