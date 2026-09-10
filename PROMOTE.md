# 📣 ชวนมาลองใช้ obsidian-workflow

> **TL;DR** — เอา *วินัยการทำงานกับ AI* มาผูกกับ *command ที่สั่งงานได้จริง*
> แล้วทำงานทุกอย่างผ่าน **docs (Obsidian)** ตามแนวคิด **docs-driven development** —
> วางแผน เขียนโค้ด แก้บั๊ก ตรวจของจริง ไปจนถึงส่งมอบให้ผู้บริหาร อยู่ใน workflow เดียว

---

## ทำไมถึงทำตัวนี้ขึ้นมา

"วินัยการทำงานกับ AI" ส่วนใหญ่จบที่ **เอกสารแนวปฏิบัติ** — อ่านแล้วเห็นด้วย แต่เวลาทำงานจริง
ไม่มีอะไรบังคับ ต้องอาศัยวินัยคนล้วน ๆ พอเร่งงานก็หลุดทุกที

`obsidian-workflow` เลยเกิดมาเพื่อ **แปลงวินัยพวกนั้นเป็น command ที่สั่งได้จริง** โดยยืมของดีจาก:

- **[spec-kit](https://github.com/github/spec-kit)** — ปรัชญา plan-driven (`/plan` → `/clarify` → `/implement` แยกขั้นชัด)
- **Obsidian vault patterns** — vault-first ที่ใช้จริงในโปรเจกต์ production

ผลลัพธ์คือชุดคำสั่ง `/ow-*` ที่อ่าน docs ก่อนทำงานเสมอ และทุกอย่างตรวจสอบย้อนได้

---

## ได้อะไรบ้าง

- 🗂️ **Docs-driven ผ่าน Obsidian** — vault (`docs/obsidian-vault/`) เป็น single source of truth; AI อ่าน PRD/SRS/FN/Flow
  ก่อนตอบหรือเขียนโค้ดเสมอ ตอบโจทย์คนที่อยากเก็บงานเป็นระบบใน Obsidian อยู่แล้ว
- 🧭 **Plan / Implement แยกกันชัด** — `/ow-plan` วางแผน (ไม่แตะโค้ด), `/ow-implement` เท่านั้นที่แก้โค้ด,
  `/ow-fix` แค่ diagnose — กัน AI ทำเกินสั่ง
- 🔍 **ผลตรวจสอบย้อนได้** — ทุกผลลัพธ์ใน doc quote output จริงจากคำสั่งที่รัน (mask PII ก่อน) — vault เก็บ text ล้วน
- 🧱 **กฎบังคับทุก output** — ทำอะไร / หลักฐานที่ตรวจจริง / เสี่ยง-ค้าง-ต่อไป — ห้ามอ้างว่า test ผ่านโดยไม่รันจริง

---

## ลองเริ่มยังไง (แนะนำ: ให้ AI ช่วย pre-check ก่อน)

ก่อนติดตั้ง ลองเปิด AI (Claude แนะนำ) ในโปรเจกต์เดิมของคุณแล้วถามประมาณว่า:

> *"อยากลง **obsidian-workflow** มาใช้ในโปรเจกต์นี้ — ช่วยดูให้หน่อยว่าจะติดอะไรบ้าง
> ทำงานร่วมกับโครงสร้างเดิมได้ไหม ต้องเตรียมอะไรก่อน?"*

ให้ AI สำรวจ stack / โครงสร้าง / docs เดิมแล้วประเมินเบื้องต้นว่าจะ adopt ได้ราบรื่นแค่ไหน
(`obsidian-workflow` รองรับทั้ง **greenfield** และ **brownfield** — โหมด brownfield จะ **ไม่แตะโค้ดเดิม** เพิ่มแค่ machinery ของตัวเอง)

**Prerequisite:** ต้องมี [`yq`](https://github.com/mikefarah/yq) (`brew install yq` / `apt install yq`)

**ติดตั้ง (one-line):**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
```


แล้วรัน `/ow-init` เพื่อ config + `/ow-help` ถ้าไม่รู้จะเริ่มตรงไหน

---

## เรื่อง AI ที่รองรับ (ขอพูดตรงๆ)

`obsidian-workflow` ออกแบบให้ใช้ได้หลาย AI — มี adapter สำหรับ **Claude Code · Codex · Gemini · GPT · GLM · Cline · Kimi Code**
(command spec เดียวกัน อ่านผ่าน `.ow/commands/<verb>.md`)

แต่ **ทดสอบใช้งานจริงจังแค่ Claude Code** เท่านั้น — ตัวอื่น ๆ ยังเป็น best-effort
ถ้าคุณไม่ได้ใช้ Claude **ก็ลองดูก่อนได้เลย** เผื่อใช้ได้ดี ถ้าเจอจุดที่ยังไม่เวิร์กก็บอกกันได้

---

## เจอปัญหา / อยากให้ดีขึ้น → เปิด issue ได้

ถ้าสนใจแต่ติดตรงไหน หรืออยากให้รองรับ workflow / AI / stack ของคุณมากขึ้น —
**เปิด issue ได้เลยที่ GitHub** เราเอามาปรับปรุงให้ใช้งานได้จริงขึ้นเรื่อย ๆ

👉 **[github.com/ThunderBirdsX3/obsidian-workflow](https://github.com/ThunderBirdsX3/obsidian-workflow)** — เปิด issue / ส่ง PR / ร่วมพัฒนากันได้

ลองกันดูครับ 🙌
