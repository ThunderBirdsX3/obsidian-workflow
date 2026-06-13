<!-- Checklist ของคุณเอง — แก้/เพิ่มข้อได้ตามต้องการ -->

# Checklist — Before Handoff

ก่อนปิด plan / จบ work session (`/ow-verify` → `/ow-handoff`):

- [ ] Plan/fix file status: done
- [ ] ทุก test scenario PASS หรือ acknowledged BLOCKED
- [ ] Evidence อยู่ใน `test-artifacts/<date>/<source>-<NN>-<slug>/` (gitignored, นอก vault)
- [ ] `EVIDENCE.md` manifest มีครบ (fields + index table) + safe_to_share validated
- [ ] PII masking confirmed
- [ ] Vault link graph ครบ ([[…]] ทุกอันชี้ไปไฟล์จริง)
- [ ] `00-Index/IMPLEMENTATION-STATUS.md` updated
- [ ] Design system compliance: 0 violations (ถ้า UI)
- [ ] Security pre-flight: ALL GREEN หรือ justified
- [ ] `/ow-verify` ผ่าน
- [ ] Session handoff note ใน `docs/vault/95-Handoff/HANDOFF-<YYYY-MM-DD>-<slug>.md`
      (สรุปงาน + remaining work + context ให้ session หน้า — สร้างโดย `/ow-handoff`)
- [ ] Rollback / mitigation plan (ถ้า production-facing)
