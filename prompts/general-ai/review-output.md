# Review output — Generic AI prompt for verifying obsidian-workflow response

ใช้ prompt นี้ตรวจ output ของ AI ตัวอื่น (หรือ self-review)

---

# Task

ตรวจ response ด้านล่างว่าทำตาม obsidian-workflow rules ครบ:

## Check 1 — Output เป็น bullet สรุปสั้น + ครบสาระ

ตรวจว่า output เป็น bullet สั้น (ภาษาตาม `project.language`) ไม่ยัด 5-header ยาว และมีสาระที่จำเป็น:
- [ ] ≤7 bullets · bullet ละ 1 บรรทัด ไม่มี bullet ซ้อนย่อย?
- [ ] ไม่มีเกริ่นนำ / ไม่ทวนคำถาม user / ไม่มีตาราง (เว้นแต่เทียบ ≥3 อย่าง)?
- [ ] คำถามที่ถาม user: 1 ข้อต่อครั้ง ≤2 บรรทัด ตัวเลือก ≤4 และมี "แนะนำ:" กำกับ?
- [ ] ทำอะไร/แก้อะไร — การเปลี่ยนหลัก + ไฟล์/พื้นที่ ชัด?
- [ ] หลักฐาน — test/lint/build/screenshot ที่ตรวจจริง (parse ไม่ได้ = บอกตรง)?
- [ ] เสี่ยง/ค้าง/ต่อไป — มีเมื่อควรมี?

## Check 2 — No fake results

ตรวจว่า:
- [ ] Commit hashes มี format ถูก (40-char SHA-1)? ดู realistic?
- [ ] URLs ที่อ้างมีจริงหรือไม่?
- [ ] Test counts (3/5 passed) match กับ commands run?
- [ ] Token counts มี source ที่ track ได้หรือ self-reported?
- [ ] File paths ที่อ้างมีอยู่จริงใน project?

## Check 3 — Plan/Implement separation

- [ ] ถ้า verb คือ `ow-plan` หรือ `ow-fix` → **ห้าม** มี code change
- [ ] ถ้า verb คือ `ow-implement` → ต้องมี plan file reference + plan status: approved
- [ ] Code change ใน wrong verb → BLOCK + flag

## Check 4 — Vault-first

- [ ] AI ได้อ่าน `docs/obsidian-vault/00-Index/IMPLEMENTATION-STATUS.md`?
- [ ] AI ได้อ่าน relevant docs (PRD/Feature/Function) ก่อนถามคำถาม?
- [ ] คำถามที่ vault ตอบอยู่แล้วถูกถามใหม่ไหม? (ถ้ามี = ผิด)

## Check 5 — Language

- [ ] รายงานเป็นภาษาที่ตรงกับ `.ow.yml` language config?
- [ ] Code/frontmatter/path เป็นอังกฤษ?

## Check 6 — Safety

- [ ] ไม่มี secret/credential leak ใน output?
- [ ] Production write ถ้ามี — มี explicit confirm?
- [ ] Shared repo modification ถ้ามี — มี explicit confirm?

---

# Verdict

| Status | Action |
|---|---|
| ✅ ALL PASS | output OK |
| 🟡 MINOR | output OK แต่แก้ที่ list ต่อไป |
| ❌ BLOCKED | output ใช้ไม่ได้ — list reasons + ขอ AI ทำใหม่ |

# Response format

```markdown
## Review verdict
<ALL PASS | MINOR | BLOCKED>

## Issues found
- [Section]: issue description

## Recommended fix
- <specific instruction to AI to re-do or adjust>
```

---

# Original response (paste below)

<AI response to review>
