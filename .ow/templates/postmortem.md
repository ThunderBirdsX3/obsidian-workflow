<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/postmortem.md` (lookup priority สูงกว่า)

  Postmortem = production incident (ระบบล่ม/เสียหายตอนคนใช้จริง) — คนละเรื่องกับ fix-log
  (bug ตอน dev). เก็บที่ $FIX_DIR/PM-<YYYY-MM-DD>-<slug>.md — สร้างผ่าน /ow-doc Postmortem
  กติกา: blameless — โฟกัสที่ระบบ/กระบวนการ ไม่ใช่ตัวบุคคล; เวลาใน timeline มาจาก
  log/alert จริง ห้ามเดา (no-fake-evidence)
-->

---
tags: [type/postmortem]
date: <YYYY-MM-DD>
title: <incident title>
severity: SEV2            # SEV1 = ล่มทั้งระบบ/data loss | SEV2 = feature หลักพัง | SEV3 = degraded
status: draft             # draft | reviewed | closed (closed = action items ครบ)
detected: <YYYY-MM-DD HH:mm>
resolved: <YYYY-MM-DD HH:mm>
duration_minutes: <number>
services: []              # service/area ที่กระทบ
related_fix: none         # "[[<fix-log-slug>]]" ถ้า hotfix ผ่าน /ow-fix
github_issue: none
---

# PM-<YYYY-MM-DD> — <Incident title>

## 1. Summary

<2-4 ประโยค: เกิดอะไร กระทบใคร นานแค่ไหน แก้ด้วยอะไร — ไม่มีชื่อคน ไม่มี blame>

## 2. Impact

- **Users affected**: <จำนวน/กลุ่ม — จากข้อมูลจริง (metric/log) ไม่ใช่ประมาณลอยๆ>
- **Duration**: <detected → resolved จาก frontmatter>
- **Data loss**: <yes/no + รายละเอียด>
- **Business impact**: <ออเดอร์หาย / SLA หลุด / etc.>

## 3. Timeline

<!-- เวลาทุกแถวมาจาก log / alert / chat จริง — ห้ามเดา; timezone ตาม project.timezone -->

| เวลา | เหตุการณ์ | ใคร/ระบบ |
|---|---|---|
| HH:mm | <deploy v1.2.3 ออก> | CI |
| HH:mm | <alert X แดง / user รายงาน> | <monitor/support> |
| HH:mm | <เริ่ม investigate> | on-call |
| HH:mm | <ระบุ root cause> | |
| HH:mm | <fix/rollback ออก> | |
| HH:mm | <ยืนยันหาย — metric กลับปกติ> | |

## 4. Detection

- รู้ได้จาก: <alert อะไร / user รายงานช่องทางไหน>
- **Time to detect**: <นาที — เกิดจริงถึงรู้>
- ควรรู้เร็วกว่านี้ได้ไหม: <alert/metric ที่ขาด → ลง Action Items>

## 5. Root Cause

<!-- 5 Whys หรือ causal chain — ลึกถึงสาเหตุเชิงระบบ ไม่หยุดที่ "คน X พลาด" -->

- **Trigger**: <อะไรจุดชนวน — deploy / config change / traffic spike / dependency down>
- **Why chain**:
  1. <ทำไมพัง> →
  2. <ทำไมถึงเป็นแบบนั้น> →
  3. <ทำไมไม่มีอะไรกัน> →
- **Contributing factors**: <สิ่งที่ทำให้แย่ลง/นานขึ้น — missing test, no alert, doc เก่า>

## 6. Resolution

<แก้ยังไง — rollback / hotfix / config — + commit/version จริงถ้ามี (`fixed_in_version`)>

## 7. Lessons

- **What went well**: <อะไร work — เช่น rollback เร็ว, runbook ใช้ได้จริง>
- **What went wrong**: <อะไรไม่ work — เช่น alert เงียบ, หาคน on-call ไม่เจอ>
- **Where we got lucky**: <จุดที่รอดเพราะโชค — นี่คือ risk ที่ยังอยู่>

## 8. Action Items

<!-- ทุก item ต้อง trackable: แตกเป็น /ow-plan หรือ GitHub issue — ห้ามจบที่ "จะระวังมากขึ้น" -->

| # | Action | Type | Tracked at | Due | Status |
|---|---|---|---|---|---|
| 1 | <เพิ่ม alert สำหรับ X> | detect | <plan/issue link> | <date> | open |
| 2 | <กัน root cause ด้วย Y> | prevent | | | open |
| 3 | <อัปเดต/สร้าง runbook Z> | mitigate | [[RUNBOOK-<slug>]] | | open |

Type: `prevent` (กันเกิดซ้ำ) / `detect` (รู้เร็วขึ้น) / `mitigate` (เจ็บน้อยลง)

## 9. Links

- Runbook ที่เกี่ยว: [[RUNBOOK-<slug>]] — <สร้างใหม่/อัปเดตจากเหตุการณ์นี้>
- Fix log: <"[[<slug>]]" ถ้ามี hotfix>
- Evidence: `test-artifacts/<date>/fix-<NN>-<slug>/` — <log/screenshot ตอน incident ถ้าเก็บไว้>
