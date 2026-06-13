<!-- Checklist ของคุณเอง — แก้/เพิ่มข้อได้ตามต้องการ -->

# Checklist — Code Review

- [ ] อ่าน plan/fix file ที่ link จาก PR/commit
- [ ] อ่าน vault docs ที่เกี่ยวข้อง
- [ ] Diff ตรง scope ของ plan?
- [ ] Test ครอบคลุม change?
- [ ] Lint clean?
- [ ] Build pass?
- [ ] Naming, file structure ตาม convention?
- [ ] No commented-out code (ที่ไม่มีเหตุผล)
- [ ] No magic numbers / hardcoded strings (ใช้ constants / DS tokens)
- [ ] No secrets / PII leaked
- [ ] Error handling ครบ
- [ ] Edge cases handled
- [ ] Logging structured + no PII
- [ ] Vault docs updated ตาม plan checklist
- [ ] Design system compliance (ถ้า UI): violations 0
- [ ] Security implications considered (auth, input validation, XSS, SQLi)
- [ ] Performance acceptable (no obvious N+1, no large allocations)
- [ ] Backward compatibility (ถ้า public API)
- [ ] Migration path (ถ้า DB schema)
