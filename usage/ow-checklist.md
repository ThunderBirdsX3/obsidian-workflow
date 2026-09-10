# /ow-checklist

> **"Unit tests for English"** — สร้าง checklist ที่ทดสอบคุณภาพ spec ไม่ใช่ behavior ของ code

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-checklist.md`](../.ow/commands/ow-checklist.md)

## เมื่อไหร่ใช้

- ก่อน implement → ตรวจว่า spec ครบไหม (UI states, error messages, edge cases)
- ก่อน release → security checklist, accessibility, performance
- รับ PRD จากลูกค้า → checklist ux/api ดู gaps
- หลัง `/ow-verify` เจอ underspec → checklist แบบ structured

> **อิงจาก spec-kit `/checklist`**

## Quick start

```
/ow-checklist ux
```

ตัวอย่าง items:
```markdown
- [ ] CHK001 ทุก action button ใน spec ระบุ "ทำอะไรเมื่อ user คลิก" ชัดเจน?
- [ ] CHK002 ทุก form field ระบุ validation rule + error message?
- [ ] CHK003 ทุก state (idle/loading/success/error/empty) มี wireframe?
- [ ] CHK004 Copy เป็นภาษาที่กำหนด (th/en) + ผ่าน tone guideline?
- [ ] CHK005 Loading > 1s มี loading indicator + estimated time?
...
```

## รูปแบบเต็ม

```
/ow-checklist                        # interactive — ถาม domain
/ow-checklist <domain>               # generate ใหม่
/ow-checklist <domain> --append      # เพิ่ม items ลง checklist เดิม
/ow-checklist review <path>          # สรุป checklist ที่ user mark แล้ว
/ow-checklist list                   # checklists ทั้งหมดใน project
```

| Flag | Default | ใช้สำหรับ |
|---|---|---|
| `--append` | new file | เพิ่ม items ลง checklist เดิมแทน |

## Domains ที่มี default

| Domain | ตรวจอะไร |
|---|---|
| `ux` | clarity, a11y, error handling, copy, loading |
| `api` | versioning, auth, errors, idempotency, rate limit |
| `security` | secrets, PII, threat model, audit log, OWASP |
| `performance` | latency, throughput, payload, cache, N+1 |
| `data` | migration, retention, backup, GDPR, integrity |
| `a11y` | WCAG AA, keyboard, screen reader, contrast |
| `observability` | logs, metrics, traces, alerts |
| `rollout` | feature flag, rollback, canary, comms |
| `<custom>` | user-defined |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 0** — Detect domain
2. **Phase 1** — Determine scope (target feature / phase / append-vs-new)
3. **Phase 2** — Generate items (CHK###) — 10-30 ต่อ domain
4. **Phase 3** — Write file `docs/obsidian-vault/95-Handoff/checklists/<domain>-<scope>-<date>.md`
5. **Phase 4** — Review mode (สรุป `[X]` ที่ user mark)
6. **Phase 5** — Integration: `/ow-verify` ตรวจ checklist; `/ow-implement` warn ถ้า in-review

## Output ที่ได้

- `docs/obsidian-vault/95-Handoff/checklists/<domain>-<scope>-<YYYY-MM-DD>.md`
- Frontmatter: `items_total`, `items_passed`, `items_failed`, `items_pending`, `status: in-review | passed | blocked`

## Workflow ที่นิยม

ตัวอย่าง 1: pre-implementation
```
1. /ow-new                                  ← PRD
2. /ow-checklist ux --append                ← scan PRD → generate UX items
3. (user mark `[X]` หลัง spec ครบ)
4. /ow-checklist review <path>              ← สรุป
5. /ow-plan FEAT-X
```

ตัวอย่าง 2: pre-release
```
1. /ow-checklist security
2. /ow-checklist performance
3. /ow-checklist rollout
4. (user resolve all `[ ]`)
5. /ow-verify                               ← will check all checklists
```

ตัวอย่าง 3: review หลัง user mark
```
/ow-checklist review docs/obsidian-vault/95-Handoff/checklists/ux-FEAT-Checkout-2026-05-21.md

→ Total: 10
  Passed [X]: 7
  Failed [N]: 1 — CHK004 "Copy ทั้งหมดเป็นภาษาที่กำหนด"
  Pending [ ]: 2
  Blocking: CHK004 → /ow-doc copy-guide หรือแก้ PRD
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้าม generate item ที่ทดสอบ implementation** — เช่น "POST /api/checkouts returns 201" (= integration test, ไม่ใช่ spec quality)
- 🚫 ห้าม > 30 items ใน domain เดียว — แตกเป็น sub-checklist
- 🚫 ห้าม mark `[X]` แทน user — user ต้องตอบเอง
- 🚫 ห้ามแก้ source spec ใน checklist process — ใช้ `/ow-doc` หรือ `/ow-clarify`
- 🚫 ห้าม block `/ow-implement` automatically — แค่ WARN ถ้า in-review
- 💡 ทุก item เป็นคำถามที่ author ตอบได้: ✅ Yes / ❌ No
- 💡 ผ่าน → `[X]`, ไม่ผ่าน → `[N]`, รอ → `[ ]`

## Related

- ก่อน `/ow-checklist`: [/ow-new](./ow-new.md), [/ow-clarify](./ow-clarify.md)
- หลัง `/ow-checklist`: [/ow-verify](./ow-verify.md) (verify will block ถ้า fail)
- Pair กับ: [/ow-verify](./ow-verify.md)
- Vault path: `docs/obsidian-vault/95-Handoff/checklists/`

## FAQ

**Q: ต่างจาก test file ยังไง?**
A: Test file ทดสอบ code behavior; checklist ทดสอบ spec ภาษาอังกฤษ (เช่น "spec บอกชัดไหมว่าทำอะไรเมื่อ network fail?")

**Q: ถ้า user ตอบ `[N]` แล้วต้องทำไง?**
A: Review mode จะ flag เป็น blocking — แก้ spec/PRD ก่อน mark `[X]` ใหม่

**Q: custom domain ใช้ยังไง?**
A: `/ow-checklist my-domain` → ถามจำนวน items + auto-generate ตาม context vault (ลด heuristic, ต้องการ user oversight มากกว่า default domain)
