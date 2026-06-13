<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/evidence/EVIDENCE.md` (lookup priority สูงกว่า)

  EVIDENCE.md — canonical evidence manifest (local-only)

  • ONE manifest per evidence folder: test-artifacts/<date>/<source>-<NN>-<slug>/EVIDENCE.md
  • Written at **capture time** (ตอนเริ่ม test/fix/implement) — ไม่ใช่ตอนจบ. command/agent ที่
    capture ต้องสร้างไฟล์นี้ทันทีที่มี artifact แรก
  • ONE manifest per TASK, not per command: /ow-test APPEND smoke rows ลง EVIDENCE.md
    ของ folder plan/fix เดิม (ไม่สร้าง smoke-* folder แยก) — build evidence (จาก /ow-implement)
    และ smoke evidence (จาก /ow-test) ของ task เดียวอยู่ใน manifest เดียว
  • `/ow-evidence` finalizes: cleanup (ไฟล์ใน folder ที่ไม่อยู่ในตาราง → ย้ายไป _archive/)
    + verify + PII audit
  • Manifest ชี้กลับ vault doc ผ่าน `doc:` — vault doc ไม่ embed evidence index.
    Binaries อยู่ที่นี่ใต้ gitignored EVIDENCE_ROOT — never in the vault, never base64-embedded.

  Copy ทุกอย่างใต้ comment นี้ไปเป็น EVIDENCE.md ของ folder แล้วเติม placeholders
-->
<!-- OW-EVIDENCE-MANIFEST v1 · written at test/fix start -->
# Evidence — <one-line title>

- source: <fix | plan | test | verify>      # = prefix ของ task folder; /ow-test reuse plan|fix
- slug: <NN>-<short-slug>            # = folder name ใต้ test-artifacts/<date>/<source>-<slug>
- issue: <#NN | ->                   # issue number ถ้างาน map กับ issue, ไม่มี = -
- doc: "[[<vault-doc-slug>]]"        # back-ref → fix-log / plan / test-plan ใน vault
- captured: <YYYY-MM-DD HH:MM>
- build: -                           # pass | fail | -      (เติมเมื่อ build รัน)
- test: -                            # "X/Y pass" | fail | - (เติมเมื่อ test รัน)

| ID | File | TC | State | Type |
|----|------|----|-------|------|
| E001 | before-<NN>-<slug>.png | TC-01 | before | screenshot |
| E002 | after-<NN>-<slug>.png  | TC-01 | after  | screenshot |
| E003 | before-test-output.txt | TC-01 | repro  | log        |
| E004 | after-test-output.txt  | TC-01 | result | log        |

<!--
  File   = filename RELATIVE to this folder = the keep-list. ไฟล์ใน folder ที่ไม่อยู่ในตารางนี้
           จะถูก /ow-evidence ย้ายไป _archive/ (moved, never deleted).
  TC     = test-case id ที่ artifact นี้พิสูจน์ (TC-01, …) — หรือ '-' สำหรับ build/setup artifacts.
  State  = before | after | result | smoke | regression | reference | repro
  Type   = screenshot | log | trace | har | report | recording | file
  🔴 Mandatory capture: ทุก test run บันทึก evidence ที่นี่. UI/e2e → ต้องมี screenshot row
     (ไม่มี = incomplete). Non-UI (unit/API) → ต้องมี captured output-log row.
-->

## Quality

| Layer | Result | Notes |
|-------|--------|-------|
| Build | <✅ EXIT=0 / ❌ / -> | <build-output.txt> |
| Unit  | <X/Y pass / -> | <file> |
| Integration | <X/Y pass / -> | <file> |
| E2E / UI | <X/Y pass / -> | <screenshot rows above> |

## Before

<RED proof — อะไรพัง + path ไป before evidence (หรือ "pending evidence" / "N/A non-UI")>

## After

<GREEN proof — สถานะหลังแก้ capture จาก build ที่ fix แล้ว (ห้าม reuse จาก issue)>

## Regression check

<role/area ที่ test + เหตุผลที่ skip area ข้างเคียง (scoped — ไม่ใช่ทุก role)>

## Success Criteria → Evidence

- [ ] <criterion 1> → <E001 / TC-01 / build-output.txt>
- [ ] <criterion 2> → <E00x>

## Notes

<free prose — parser ข้ามทุกอย่างหลังตาราง; ใส่ anomalies / context ที่นี่>
