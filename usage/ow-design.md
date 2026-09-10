# /ow-design

> **Design system** — tokens + components + patterns + preview.html (Storybook-lite single-file)

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-design.md`](../.ow/commands/ow-design.md)

## เมื่อไหร่ใช้

- เริ่ม project ที่มี UI — bootstrap design system ก่อน frontend dev
- ปรับ brand colors / typography / spacing (tokens)
- เพิ่ม component ใหม่ (ก่อน frontend/mobile implement)
- ตรวจ implementation vs DS (audit)

> **สำคัญ:** หลังมี DS แล้ว → งาน UI ทุกชิ้น **ถูกบังคับใช้ DS** ไม่ว่าทำ inline หรือ delegate ให้ subagent — ad-hoc styling ถูก refuse

## Quick start

```
/ow-design init
```

ตัวอย่าง output:
```
ถามทีเดียว 5 คำถาม:
  1. Brand colors (primary/secondary/accent hex)
  2. Typography (font family หลัก + code font)
  3. Style (minimalist/playful/corporate/dark-first)
  4. Framework (React/Vue/Svelte/Flutter/SwiftUI/Compose)
  5. Target users (consumer/professional/a11y-critical)

→ สร้าง 7 ไฟล์ใน docs/obsidian-vault/70-Reference/DesignSystem/
→ เปิด preview.html ด้วย browser ได้เลย
```

## รูปแบบเต็ม

```
/ow-design                     # interactive
/ow-design init                # bootstrap minimal DS
/ow-design tokens              # แก้/เพิ่ม tokens
/ow-design component <name>    # เพิ่ม/แก้ component
/ow-design pattern <name>      # เพิ่ม recurring pattern
/ow-design audit               # ตรวจ implementation vs DS
/ow-design preview             # regenerate preview.html
/ow-design import-figma <path> # import Figma export → DS-Tokens (ผ่าน contrast gate)
```

| Mode | ใช้สำหรับ |
|---|---|
| `init` | bootstrap 7 ไฟล์ + preview.html |
| `tokens` | colors, typography, spacing, radius, shadow, motion |
| `component <name>` | Button, Input, Card, Modal, Toast, … |
| `pattern <name>` | form layouts, list-detail, empty state |
| `audit` | self-audit DS docs (Score /100: token integrity, claim re-verify, preview sync) + scan source code → contrast/token/component violations |
| `preview` | regenerate `preview.html` ให้ตรง DS-Tokens.md / DS-Components.md |
| `import-figma <export-path>` | อ่านไฟล์ export จาก Figma (read-only) → flatten tokens → **ต้องผ่าน contrast gate** ก่อนเขียนลง DS-Tokens.md · ชนกับ token เดิม = STOP ให้ user ตัดสิน |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect state (มี folder?)
   - **Phase 0.1** — ตัดสินว่าทำ inline เองหรือ delegate ให้ `design` agent (ดุลพินิจ ไม่บังคับทางไหน; agent ตัวนี้ไม่ได้ ship มา — ไม่มีก็ inline) — process + gate ทั้งหมด (G2 contrast / G3-G4 DS compliance / WCAG 2.2 AA) อยู่ที่ `.ow/commands/_shared/design-process.md` เหมือนกันทั้งสองแบบ
2. **Phase 1 (init)** — สร้าง 7 ไฟล์ + ถาม batch 5 questions + generate tokens defaults
3. **Phase 2** — Extend mode (tokens / component / pattern / audit)
4. **Phase 3** — Force-use rule: gate DS บังคับที่ **ตัวงาน** ไม่ใช่ที่ผู้ทำ ⇒ ไม่ต้องมี agent ก็บังคับใช้ (อยากมี agent จริง → `/ow-agent create {frontend,mobile,design}`)
5. **Phase 4** — Link จาก docs + update preview.html ให้ตรง DS-Tokens.md (lint rule)
6. **Phase 5 (import-figma)** — import จาก export file เท่านั้น (ไม่เรียก Figma API) → contrast gate → เขียน token ที่ผ่าน · asset binary = แจ้ง path + size ให้ user ตัดสิน ไม่ auto-commit

## Output ที่ได้

```
docs/obsidian-vault/70-Reference/DesignSystem/
├── README.md
├── DS-Tokens.md            ← colors, typography, spacing, radius, shadow, motion
├── DS-Components.md        ← Button, Input, Card, Modal, Toast, …
├── DS-Patterns.md          ← form, list, detail, empty-state patterns
├── DS-Accessibility.md     ← WCAG AA, contrast, focus, ARIA
├── DS-Layout.md            ← grid, breakpoints, container, spacing scale
├── DS-Voice.md             ← tone, copy guidelines, microcopy
└── preview.html            ← Storybook-lite single-file (เปิด browser ได้เลย)
```

## preview.html — Storybook-lite

- Self-contained (vanilla HTML + inline CSS + JS) — เปิดด้วย browser ตรงๆ ไม่ต้อง build
- รวม tokens จาก DS-Tokens.md เป็น CSS variables ที่ `:root { }`
- แสดงทุก component (variant × size × state matrix)
- มี light/dark theme toggle + sidebar nav
- ใช้ source-of-truth จาก DS-*.md — ห้าม diverge

## Workflow ที่นิยม

ตัวอย่าง 1: bootstrap หลัง PRD
```
1. /ow-new                          ← PRD/SRS
2. /ow-design init                   ← คุณอยู่ที่นี่
3. เปิด preview.html ดู
4. /ow-plan FEAT-X                   ← งาน frontend ตอนนี้ผูกกับ DS แล้ว (inline หรือ agent ก็ตาม)
5. /ow-implement <plan>
```

ตัวอย่าง 2: เพิ่ม component ใหม่
```
1. /ow-plan FEAT-Y                          ← plan ระบุ Design Additions: Datepicker
2. (STOP — DS ยังไม่มี Datepicker)
3. /ow-design component Datepicker          ← สร้าง spec ก่อน
4. /ow-implement <plan>                     ← ใช้ Datepicker ได้
```

ตัวอย่าง 3: audit เก่า
```
/ow-design audit
  → self-audit DS docs: Score 54/100 (claim contrast เท็จ 1, token อ้างแต่ไม่มีนิยาม 8)
  → scan frontend/src/, mobile/lib/: 5 violations (3 inline color, 2 ad-hoc component)
  → docs/obsidian-vault/70-Reference/DesignSystem/audit-2026-05-21.md
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้ามเล่าการแก้ในเอกสาร vault** — "เดิม X → ใหม่ Y" / หัวข้อ `## Changelog` ให้ทับด้วยค่าปัจจุบันแทน · before/after อยู่ใน plan (`80-ImplementPlan`) หรือ fix-log (`85-FixLog`) · `/ow-secure` Phase 2.6 บล็อกให้
- 🚫 **ห้ามแก้ source code ของ frontend/mobile** — `/ow-design` = spec, code = `/ow-implement`
- 🚫 ห้าม commit DS โดยไม่มี accessibility section
- 🚫 ห้ามใช้ color/font ที่ไม่มี explicit reference (ห้าม "AI-suggested" unverified)
- ⚠️ DS-Tokens.md เปลี่ยน → ต้อง update preview.html ใน commit เดียว (lint rule จะตรวจ)
- ⚠️ Component ใหม่ใน plan → STOP, ต้อง `/ow-design component <name>` ก่อน `/ow-implement`
- 💡 หลัง DS active → งาน frontend/mobile ถูกบังคับอ่าน DS-Tokens + DS-Components ก่อนเขียน UI — ใช้ทั้ง inline และ delegate (`/ow-implement` Phase 4 · gate G2-G4 ใน `_shared/design-process.md`)

## Related

- ก่อน `/ow-design`: [/ow-new](./ow-new.md) (มี PRD ระบุ style/target users)
- หลัง `/ow-design init`: [/ow-plan](./ow-plan.md) (plan ต้องระบุ Design System Compliance section)
- Audit: [/ow-verify](./ow-verify.md) (ทำ design audit ใน Phase 6)
- Process + gates: [`.ow/commands/_shared/design-process.md`](../.ow/commands/_shared/design-process.md) — บังคับใช้เหมือนกันทั้ง inline และ agent
- Subagent `design` / `frontend` / `mobile`: ไม่ได้ ship มา สร้างด้วย [`/ow-agent create <name>`](./ow-agent.md)
- Vault path: `docs/obsidian-vault/70-Reference/DesignSystem/`

## FAQ

**Q: ถ้าทีมยังไม่มี brand guideline?**
A: ใช้ "defaults" — tokens generic จาก template ปรับทีหลังด้วย `/ow-design tokens`

**Q: ทำไมไม่ใช้ Storybook จริง?**
A: obsidian-workflow philosophy = single-file + source-driven จาก markdown — preview.html อ่านจาก DS-*.md เปิด browser ได้เลย ไม่ต้อง npm install

**Q: ถ้า frontend แก้ inline style จะเป็นยังไง?**
A: gate §5.3 ของงาน frontend/mobile refuse ถ้าไม่ใช้ token (บังคับทั้ง inline และ delegate) — `/ow-design audit` จะ flag

**Q: ใช้ DS กับ Flutter ได้ไหม?**
A: ได้ — Phase 1 ถาม framework → component examples generate ตาม (Flutter, SwiftUI, Compose, React, Vue)
