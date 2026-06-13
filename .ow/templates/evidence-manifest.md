<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/evidence-manifest.md` (lookup priority สูงกว่า)
-->

# Evidence — Test Taxonomy Reference

> Per-folder evidence index คือ **`EVIDENCE.md` manifest** (markdown) — ดู
> `.ow/templates/evidence/EVIDENCE.md`. Evidence ไม่อยู่ใน vault:
> binaries + manifest อยู่ใต้ gitignored `test-artifacts/<date>/<source>-<NN>-<slug>/`
> และ manifest ชี้กลับ vault doc ผ่าน `doc:`.
>
> ไฟล์นี้คือ **taxonomy reference** ที่ `/ow-test`, `/ow-verify`, และ `test-runner`
> agent ใช้สำหรับค่า **Status** / **Route source** / **Drift** ที่บันทึกต่อ test case
> (ใน `## Notes` ของ manifest หรือตาราง Test Cases ของ test-plan)

## Status taxonomy

- `PASS` — รันผ่าน ตาม expected
- `FAIL` — รันผ่าน แต่ผลไม่ตรง expected
- `INFO` — รันแล้ว ไม่มี expected ที่ test
- `LIMITED` — รันบาง step ได้
- `PASS_NO_MUTATION` — pass แต่ skip mutation step (เช่น write to DB)
- `BLOCKED_NO_CREDENTIALS` — ไม่มี credential ทำต่อไม่ได้
- `BLOCKED_NO_ROLE` — ไม่มี role/permission
- `BLOCKED_PRODUCTION_WRITE_RISK` — block เพราะ prod-write risk
- `BLOCKED_PII_MASKING_REQUIRED` — เจอ PII ต้อง mask ก่อน
- `BLOCKED_ROUTE_DRIFT` — route ไม่ตรงกับ doc/menu
- `NOT_RUN_RISK` — ไม่ได้รัน + มี risk (ห้าม claim pass)
- `NOT_RUN` — ไม่ได้รัน (ไม่ใช่ risk-flag)

## Route source taxonomy

- `VISIBLE_MENU` — ใช้ menu/navigation ปกติ (default)
- `DIRECT_URL_USER` — direct URL user-facing (ต้อง justify)
- `DIRECT_URL_TECHNICAL` — direct URL technical only
- `SOURCE_CODE_ROUTE` — อ่านจาก code
- `OLD_DOCS_ROUTE` — จาก outdated docs (flag drift)
- `BROWSER_REDIRECT` — landed via redirect
- `DEPLOYED_BUNDLE_OBSERVED` — observe from deployed bundle

## Drift taxonomy

- `ROUTE_OK` — route ตรงกับ doc
- `ROUTE_MISSING` — route ใน doc แต่ไม่มีจริง
- `MENU_DRIFT` — menu ไม่ตรง doc
- `DOC_DRIFT` — doc ไม่ตรงกับ deploy
- `DEPLOY_DRIFT` — deploy ไม่ตรงกับ code
- `APP_LEVEL_404` — 404 ของ app routing
- `HTTP_404` — 404 จาก server
- `BLANK_OR_CRASH` — หน้าว่างหรือ crash
