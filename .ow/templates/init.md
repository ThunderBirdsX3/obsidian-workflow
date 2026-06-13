<!--
  Default template — แก้ per-project ได้โดย copy ไป `templates/init.md` (lookup priority สูงกว่า)
  ใช้โดย /ow-init — prompt ให้ AI สำรวจโครงสร้าง Obsidian/project ก่อนใช้ command อื่น
-->

# Command: Init

## ใช้เมื่อ

ต้องการให้ AI รู้จักโครงสร้าง Obsidian/project ก่อนใช้ command อื่น เช่น `/ow-plan`,
`/ow-fix`, `/ow-implement`, `/ow-doc`, `/ow-test`

## Copy this into AI

```text
ทำงาน: Init
Context:
- Vault path: <path ของ Obsidian vault หรือ project folder>
- Project folder/note: <ชื่อ folder/note หลัก ถ้ามี>
- Source repo path: <path repo ที่เกี่ยวข้อง ถ้ามี>
- Scope: <งาน/ระบบที่ต้องให้ AI รู้จัก>

โปรดทำตามขั้นตอนนี้:
1. ยืนยัน path ที่จะอ่าน/เขียน และห้ามแตะ vault/repo นอก scope
2. สำรวจโครงสร้าง Obsidian: folder หลัก, index/home note, architecture/docs,
   changelog, evidence/test reports, naming, tags, frontmatter, link pattern
3. สร้างหรืออัปเดต Obsidian context manifest ตาม `templates/obsidian-context.md`
4. สรุปวิธีที่ command อื่นต้องใช้ context นี้ และระบุ path canonical ของ manifest

Output ที่ต้องส่ง: init summary พร้อม Obsidian context path, files created/updated, และ evidence

Output ต้องมีหัวข้อ: Result, Verification / Evidence, Limitations / Next steps
```

## Default Obsidian artifacts

mapping ใน obsidian-workflow vault:

- Obsidian context manifest → `docs/vault/00-Index/IMPLEMENTATION-STATUS.md`
  (เพิ่ม section "Agent Context Manifest")
- Test/evidence index → `docs/vault/90-TestPlan/` (text link-notes);
  manifest + binaries ใต้ `test-artifacts/` (gitignored, นอก vault)
- Session handoff → `docs/vault/95-Handoff/HANDOFF-YYYY-MM-DD-<slug>.md`

ถ้ามี source repo ที่แยกจาก vault → สร้าง/อัปเดต `.ow/obsidian-context.md` ใน repo
เป้าหมายเฉพาะเมื่อ user อนุญาต
