<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/test-scenario-report.md` (lookup priority สูงกว่า)

  ใช้โดย /ow-test — test EXECUTION report (ผล run จริง, คนละไฟล์กับ test-plan.md)
  เขียนเป็น report.md ใต้ EVIDENCE_ROOT (gitignored) + text link-note ใน vault 90-TestPlan/
  หลักฐาน binary (screenshots/logs) อยู่ใต้ EVIDENCE_ROOT เท่านั้น — NEVER ใน vault
-->

---
tags: [type/test-report]
status: <pass | fail | blocked | partial>
date: <YYYY-MM-DD>
test_plan: "[[TP-<slug>]]"     # test plan ที่ execute (ถ้ามี); auto-mode = (none)
target: <web | mobile | api | cross>
evidence_root: <EVIDENCE_ROOT relative path>   # e.g. test-artifacts/<date>/<source>-<NN>-<slug>/
safe_to_share: false           # ตั้ง true เฉพาะเมื่อ PII masking ครบ
---

# Test Scenario Report — <Title>

## Summary

- **Target**: <web | mobile | api>
- **Scenarios**: <n>  (PASS: <n> · FAIL: <n> · BLOCKED: <n> · LIMITED/INFO: <n>)
- **Run by**: /ow-test → test-runner agent
- **Verdict**: <PASS | FAIL | PARTIAL | BLOCKED>

| Scenario | Status | Route source | Evidence |
|---|---|---|---|
| TC-001 — <title> | <PASS> | <VISIBLE_MENU> | <screenshots/TC-001-*.png> |

> Status taxonomy: `PASS` · `FAIL` · `INFO` · `LIMITED` · `BLOCKED_<reason>` · `NOT_RUN_RISK`
> Route source: `VISIBLE_MENU` (default) · `DIRECT_URL_USER` (ระบุเหตุผล) · `DIRECT_URL_TECHNICAL` (tech check)
> (รายการเต็มดู `.ow/templates/evidence-manifest.md`)

## Per-scenario detail

### TC-00X — <scenario title>  · <STATUS>

- **Page / URL**: <route>
- **Expected**: <result>
- **Actual**: <observed>
- **Console**: <error summary หรือ "clean">
- **Network**: <failed requests หรือ "ok">
- **Screenshot**: `screenshots/TC-00X-0Y-<state>.png`
- **PII / secret**: <none | masked — list fields>

<!-- ทำซ้ำต่อ scenario; FAIL ต้องมี console + screenshot จริง — ห้าม claim ผ่านโดยไม่ได้รัน -->

## Blocked / limitations

- <BLOCKED_<reason> + อะไรที่ยังไม่ได้ทดสอบ + ทำไม>

## Next

- <FAIL → /ow-fix "<symptom>"  ·  spec gap → /ow-clarify  ·  ผ่านครบ → /ow-verify หรือ /ow-handoff>
