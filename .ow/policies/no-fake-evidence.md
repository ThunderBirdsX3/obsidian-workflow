# Policy — No Fake Evidence

## หลัก

ห้ามแต่ง evidence ทุกประเภท — ทุก claim ของผลลัพธ์ต้องมี evidence ที่ verify ได้

## ขอบเขต

- Commit hash, branch name, PR number → ต้องมีจริงเท่านั้น
- Test count (pass/fail/skip) → ต้องมาจาก output ของการรันจริง
- File content → ห้าม paraphrase แล้วอ้างเป็น quote
- URLs → ต้องเปิดได้จริง
- Screenshots → ห้ามสร้าง/แต่งภาพ
- Console/network logs → ต้องเป็น output จริง

## ประเภท Evidence ที่ยอมรับ

| Claim | Evidence |
|---|---|
| Code change | git diff + commit hash |
| Test passed | test runner output + log file |
| Build success | build log |
| Lint clean | lint output |
| Manual check | screenshot + date |
| Performance | benchmark output + environment |
| Security | scan tool output |

## ที่ไม่ยอมรับ

- "Trust me" / "Looks good" — ไม่มี concrete check
- Screenshot ที่ไม่บอกว่าถ่ายเมื่อไหร่/จาก flow ไหน
- Test count ที่ไม่ match กับ output

## Capture (ทุก test run)

- รัน test แล้ว**ต้องเก็บ evidence** — มิฉะนั้นถือว่า "not verified":
  - **UI / e2e** → screenshot อย่างน้อย 1
  - **non-UI (unit / API)** → captured output log
- ลงทะเบียนทุก artifact ใน `EVIDENCE.md` manifest ของ run นั้น (1 แถวต่อไฟล์)

## Storage

- Evidence binaries เก็บ**นอก vault** ใต้ gitignored root:
  `test-artifacts/<date>/<source>-<NN>-<slug>/` — `<source>` ∈ fix|plan|test|verify
  (**1 folder ต่อ task** — `/ow-test` ใช้ folder ของ plan/fix เดิม)
- Index = `EVIDENCE.md` manifest ในแต่ละ folder; manifest ชี้กลับ vault doc ผ่าน `doc:` —
  **vault doc ไม่ฝัง evidence index**
- 🔴 ห้ามเก็บ binary ใน vault · ห้าม commit raw evidence
- ไฟล์ใน folder ที่ไม่อยู่ใน manifest → `/ow-evidence` **ย้าย**ไป `_archive/` (ไม่ลบ)
- ห้าม delete evidence ของ failed test

## ถ้าทำไม่ได้

- เขียน `pending evidence` หรือ `not run — <reason>`
- ระบุ blocker ที่ตรวจสอบได้ + เสนอทางเลือก verify

## บังคับตรวจ

`/ow-secure` + `/ow-verify` ตรวจ pattern เหล่านี้ และ block ถ้าเจอ —
fake evidence ที่ถูกตรวจพบ = งานนั้น invalid ต้อง verify ใหม่
