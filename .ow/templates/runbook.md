<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/runbook.md` (lookup priority สูงกว่า)

  Runbook = คู่มือดับเพลิง — เขียนให้คนที่โดนปลุกตอนตีสามทำตามได้โดยไม่ต้องคิด:
  ทุก step เป็นคำสั่ง copy-paste ได้ + expected output, ไม่ใช่คำอธิบายเชิงทฤษฎี
  เก็บที่ $REF_DIR/Runbooks/RUNBOOK-<slug>.md — สร้างผ่าน /ow-doc Runbook
-->

---
tags: [type/runbook]
title: <สถานการณ์ที่ runbook นี้แก้>
service: <service/area>
severity_scope: SEV1-SEV3        # ระดับเหตุที่ใช้ runbook นี้ได้
owner: <ทีม/role ที่ดูแล runbook นี้>
last_verified: <YYYY-MM-DD>      # วันที่ "ซ้อมจริง" ล่าสุด — เกิน 6 เดือน = ต้อง verify ใหม่
---

# RUNBOOK — <สถานการณ์>

## 1. When to use

<!-- อาการที่มองเห็น — ให้คนหน้างาน match ได้ใน 10 วินาที -->

ใช้ runbook นี้เมื่อ:
- Alert: `<ชื่อ alert / metric ที่แดง>`
- อาการ: <user เจออะไร — error 500 หน้า X, queue ค้าง, login ไม่ได้>

**อย่าใช้เมื่อ**: <เคสหน้าตาคล้ายแต่คนละเรื่อง → ชี้ runbook ที่ถูก>

## 2. Impact if ignored

<ปล่อยไว้แล้วอะไรพัง — ช่วยตัดสินว่าปลุกคนเพิ่มไหม>

## 3. Pre-checks (ยืนยันก่อนว่าใช่เคสนี้)

```bash
# 1. <เช็คอะไร>
<command>
# expected: <output ที่บอกว่าใช่เคสนี้>
```

ผล pre-check ไม่ตรง → **หยุด** ไป § 7 Escalation — อย่าฝืนรัน step ต่อ

## 4. Steps

<!-- ทุก step: คำสั่ง copy-paste ได้ + expected output + ผลข้างเคียงถ้ามี
     step ที่ destructive (restart/delete) ต้องบอกชัด + วิธีถอย -->

1. <step แรก — ปลอดภัยสุด/ได้ข้อมูลมากสุดก่อน>
   ```bash
   <command>
   ```
   expected: `<output>`
2. <step ถัดไป>
   ```bash
   <command>
   ```
   ⚠️ **destructive**: <ผลข้างเคียง> — ถอยด้วย § 6

## 5. Verification (รู้ได้ไงว่าหาย)

```bash
<command เช็ค metric/health กลับปกติ>
# expected: <ค่า normal>
```

- [ ] Alert เคลียร์
- [ ] <user-facing check — เปิดหน้า X ได้>

## 6. Rollback

<ถ้า step ใน § 4 ทำให้แย่ลง — ถอยยังไง ทีละข้อ>

## 7. Escalation

| เมื่อไหร่ | ติดต่อใคร | ช่องทาง |
|---|---|---|
| pre-check ไม่ตรง / step ไม่ work ใน <N> นาที | <role/ทีม> | <ช่องทาง> |
| SEV1 / data loss | <role> | <ช่องทาง> |

## 8. Related

- Postmortem ที่เคยเกิด: [[PM-<date>-<slug>]]
- Spec/architecture: [[FN-<slug>]] · [[REF-Architecture]]

---
> หลังใช้ runbook จริง: อัปเดต `last_verified` + แก้ step ที่ไม่ตรงความจริง —
> runbook ที่ล้าหลังอันตรายกว่าไม่มี runbook
