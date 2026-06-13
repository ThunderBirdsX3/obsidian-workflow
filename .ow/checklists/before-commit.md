<!-- Checklist ของคุณเอง — แก้/เพิ่มข้อได้ตามต้องการ -->

# Checklist — Before Commit

ก่อน `git commit` หรือ `/ow-git`:

- [ ] รัน `/ow-secure` — pass ALL GREEN หรือ justified
- [ ] รัน test ของ scope: pass
- [ ] รัน lint: pass
- [ ] รัน build: pass (ถ้า project มี)
- [ ] Diff scope ตรงกับ plan/fix file (ไม่มีไฟล์ off-scope)
- [ ] Success criteria ครบและตรวจกลับได้
- [ ] Change เป็น minimum correct change
- [ ] ทุก changed line trace กลับไปยัง request, bug, success criteria, หรือ verification ได้
- [ ] ไม่มี speculative abstraction/config/dependency/feature
- [ ] ไม่มี unrelated refactor หรือ format churn
- [ ] No secrets / credentials ใน diff
- [ ] No PII ใน diff
- [ ] Commit message ตาม convention: `<type>(<scope>): <subject>` (เช่น `feat(api): add search endpoint`)
- [ ] Reference plan/fix file ใน commit body
- [ ] Vault docs updated ตาม plan
