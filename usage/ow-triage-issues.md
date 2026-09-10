# /ow-triage-issues — Batch-triage GitHub bug issues

> ใช้ตอน: มี bug issues ค้างใน GitHub เยอะ อยาก classify + ติด label + comment เป็นชุด ก่อนเริ่มแก้

## ใช้ยังไง

```
/ow-triage-issues                 # triage ทุก bug ที่ยังไม่มี triage/fix label (เก่าสุดก่อน)
/ow-triage-issues #62 #63 #64     # triage เฉพาะ issue ที่ระบุ
/ow-triage-issues --dry-run       # classify + รายงาน แต่ไม่แตะ GitHub
/ow-triage-issues --no-cluster    # ข้าม cluster detection
```

## Prerequisite

- `gh` CLI auth แล้ว (`gh auth status`) + อยู่ใน git repo ที่ผูก GitHub
- agent `gh-issue` enabled (`/ow-agent enable gh-issue`)

## ทำอะไรให้

1. ดึง open bug ที่ยังไม่ถูก triage (เรียงเก่า→ใหม่) — **snapshot ครั้งเดียว** แล้ว lock (issue ที่เข้ามาหลังเริ่ม = run ถัดไป)
2. อ่าน issue + ภาพ (ผ่าน gh-issue agent) แบบขนาน
3. Classify: real-bug / question / need-info / not-implement-yet / duplicate / wontfix
4. เสนอ cluster (รวม bug ที่น่าจะแก้ด้วยกัน)
5. **STOP + แสดง plan + ถามก่อน apply** (confirmation gate)
6. หลัง yes → ติด label + comment + close ตาม plan

## ต่อด้วย

- `/ow-fix-issue #NN ...` — หยิบ real-bug จาก section "🎯 Ready to fix" ไปแก้

## หมายเหตุ

- **read-only ต่อโค้ด** — ไม่แก้ไฟล์ใน repo เลย
- **frozen pool** — pool ถูก freeze ตอนเริ่ม loop วนเฉพาะ snapshot นั้น ไม่ดูด issue ใหม่เข้ามากลางทาง (preview = apply เป๊ะ)
- **confirmation gate บังคับ** — ไม่แตะ GitHub จนกว่า user ตอบ yes
- ติด `cluster` label ด้วยมือเท่านั้น (skill แค่เสนอ)
- comment ภาษาไทย (ตาม `project.language` ใน `.ow.yml`)
