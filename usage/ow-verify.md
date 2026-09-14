# /ow-verify

> **Full verify** — tests + vault + spec audit + security + DS audit → สรุปผลพร้อม next steps

> ต้องการสร้าง Handoff Report ส่งต่อ reviewer/exec? → `/ow-handoff <path>` (command แยก)

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-verify.md`](../.ow/commands/ow-verify.md)

## เมื่อไหร่ใช้

- หลัง `/ow-implement` + `/ow-test` + `/ow-secure` ผ่าน
- ตรวจให้ครบก่อนสร้าง Handoff Report
- ต้องการ verify แต่ยังไม่พร้อม handoff (ยังแก้อยู่)

## Quick start

```
/ow-verify docs/obsidian-vault/80-ImplementPlan/2026-05-21-1430-add-search.md
```

ผลลัพธ์:
```
✅ Phase 1 Scope      — plan + git diff + linked vault docs
✅ Phase 2 Tests      — 42/42 passed, lint clean, build OK
✅ Phase 3 Vault text — vault text-only OK, PII masked, ทุกผลอ้างคำสั่งจริง
✅ Phase 4 Vault      — links OK, IMPLEMENTATION-STATUS updated
   ⚠️  Spec audit     — FR-003 no task ID (orphan) — warn only
   ⚠️  SRS layout     — FR-105 outside SRS-<project>-checkout fr_range (split SRS only) — warn only
✅ Phase 5 Security   — no secrets, no PII
✅ Phase 6 DS Audit   — 0 violations

→ /ow-handoff <path>  เพื่อสร้าง Handoff Report ส่งต่อ reviewer
```

## รูปแบบเต็ม

```
/ow-verify <plan-or-fix-path>      # ตรวจ specific work
/ow-verify --since <ref>           # ตรวจทุกอย่างใน diff range
/ow-verify --feature <name>        # ตรวจ feature scope
```

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Scope identification (plan/fix + `git diff` + linked vault docs)
2. **Phase 2** — Test verification (unit, integration, lint, build, type check) — **ห้าม fake**
3. **Phase 3** — Vault-is-text audit (ไม่มี binary ใน vault, PII masked, ทุกผลมีคำสั่งรองรับ, route source trace, status taxonomy)
4. **Phase 4** — Vault consistency + Spec audit (wikilinks, IMPLEMENTATION-STATUS, orphan FR, terminology)
5. **Phase 5** — Security pre-flight (เรียก `/ow-secure` logic) — STOP ถ้า BLOCKED
6. **Phase 6** — Design system audit (เรียก `/ow-design audit` logic)
7. **Phase 7** — สรุปผล ✅/❌ แต่ละ Phase + hint `→ /ow-handoff`

## Output ที่ได้

- ผลรวม ✅/❌ แต่ละ Phase พร้อมรายการที่ยังไม่ผ่าน
- Spec audit: orphan FR warn (ไม่ block), terminology issues
- Hint: `→ /ow-handoff <path>` ถัดไป

## Workflow

ตัวอย่าง 1: feature
```
1. /ow-implement <plan>            ← code + tests + build/test result
2. /ow-test                        ← smoke pass
3. /ow-secure                      ← clean
4. /ow-verify <plan>               ← คุณอยู่ที่นี่
5. /ow-handoff <plan>              ← สร้าง HOR-*.md ส่ง reviewer
6. /ow-git --plan <plan>           ← commit + push
```

ตัวอย่าง 2: bug fix
```
1. /ow-fix → /ow-plan → /ow-implement
2. /ow-test --since HEAD~
3. /ow-verify --fix docs/obsidian-vault/85-FixLog/<slug>.md
4. /ow-handoff --fix <fix-log>
5. /ow-git --fix <fix-log>
```

ตัวอย่าง 3: diff-scoped
```
/ow-verify --since main
  → ตรวจทุก commit vs main
  → สรุปผล + hint /ow-handoff
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้าม verify ที่ test ไม่ผ่าน** — STOP, แจ้ง user แก้ก่อน
- 🚫 **ห้าม fake ผลลัพธ์** — no-fake-results policy
- ⚠️ Security pre-flight (Phase 5) BLOCKED → STOP, ต้อง `/ow-secure` clear ก่อน
- ⚠️ Vault inconsistency (Phase 4) → flag + เสนอ `/ow-doc` แก้ — ไม่ block
- ⚠️ Orphan FR (Phase 4 spec audit) → warn เท่านั้น ไม่ block
- 💡 `/ow-verify` ไม่สร้าง Handoff Report — ใช้ `/ow-handoff` แยกต่างหาก

## Related

- ก่อน `/ow-verify`: [/ow-implement](./ow-implement.md), [/ow-test](./ow-test.md), [/ow-secure](./ow-secure.md)
- หลัง `/ow-verify`: [/ow-handoff](./ow-handoff.md) (สร้าง HOR-*.md), [/ow-git](./ow-git.md)
- Embedded: `/ow-secure` (Phase 5), `/ow-design audit` (Phase 6)

## FAQ

**Q: ต่างจาก `/ow-handoff` ยังไง?**
A: `/ow-verify` = ตรวจงานตัวเอง; `/ow-handoff` = สร้างเอกสารส่งต่อคนอื่น ควรรัน verify ให้ผ่านก่อน

**Q: ถ้า verify fail ต้องเริ่มใหม่ไหม?**
A: ไม่ — แก้ blocker แล้วรัน `/ow-verify` ใหม่

**Q: Orphan FR ใน spec audit เป็น error ไหม?**
A: เป็นแค่ warning — ไม่ block verify แต่ควรแก้ก่อน handoff (สร้าง plan สำหรับ FR นั้น หรือลบถ้า descoped)
