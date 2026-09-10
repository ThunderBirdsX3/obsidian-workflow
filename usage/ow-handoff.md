# /ow-handoff

> **สร้าง Handoff Report ส่งงานต่อ reviewer/exec/QA** — เอกสารทางการสรุปผลงานพร้อมผลตรวจจริงและ approval section

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-handoff.md`](../.ow/commands/ow-handoff.md)

## เมื่อไหร่ใช้

- หลัง `/ow-verify` ผ่านครบแล้ว — พร้อมส่งงาน
- เมื่อต้องการเอกสารทางการให้ reviewer/executive อ่านและ approve
- ก่อน deploy production — Approval gate

> ควรรัน `/ow-verify` ให้ผ่านก่อน แล้วค่อย `/ow-handoff`

## Quick start

```
/ow-handoff docs/obsidian-vault/80-ImplementPlan/2026-05-21-1430-add-search.md
```

ผลลัพธ์:
```
docs/obsidian-vault/95-Handoff/HOR-2026-05-21-add-search.md

# Add Search Feature — Handoff Report
## Summary · What Changed · Verification Results · DS Compliance
## Security · Project rules · Pipeline trace · Commands run
## Sources · Limitations · Rollback · Approval [ ]
```

## รูปแบบเต็ม

```
/ow-handoff <plan-or-fix-path>     # handoff งานจาก plan/fix
/ow-handoff --feature <name>       # handoff ทั้ง feature
/ow-handoff --since <ref>          # handoff ทุกอย่างใน diff range
```

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Pre-flight check: ตรวจ plan status + warn ถ้ายังไม่ `/ow-verify`
2. **Phase 2** — สร้าง Handoff Report `HOR-<YYYY-MM-DD>-<slug>.md` (12 sections)
3. **Phase 3** — อัปเดต status: plan → `handed-off`, IMPLEMENTATION-STATUS → `ready-for-review`

## Handoff Report sections

```
Frontmatter:
  status: ready-for-review | approved | deployed
  audience: [executive, reviewer, qa]

Body:
  ## Summary                    ← 1 ย่อหน้า exec-friendly
  ## What Changed               ← files, features, bugs, docs
  ## Verification Results       ← tests, build, lint + คำสั่งที่รันจริง
  ## Design System Compliance   ← components, violations
  ## Security Pre-flight        ← secrets, PII, masking, prod
  ## Project rules applied
  ## Pipeline trace             ← Understand → Plan → Execute → Verify → Handoff
  ## Commands run
  ## Sources                    ← plan link, fix-log link, commit hashes
  ## Limitations / Risks / Next steps
  ## Rollback / Mitigation      ← ถ้า production-facing
  ## Approval                   ← reviewer signs ทีหลัง
```

## Workflow

```
1. /ow-implement <plan>        ← code + tests + build/test result
2. /ow-test                    ← smoke pass
3. /ow-secure                  ← clean
4. /ow-verify <plan>           ← ตรวจครบ (tests, vault, security, DS)
5. /ow-handoff <plan>          ← คุณอยู่ที่นี่ — สร้าง HOR-*.md
6. /ow-git --plan <plan>       ← commit + push
7. [reviewer เปิด HOR-*.md + sign Approval section]
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้าม fake ผลลัพธ์** ในรายงาน
- 🚫 **ห้าม approve ตัวเอง** — Approval section ให้ reviewer กรอก
- 🚫 ห้าม push handoff to public ถ้ามี customer PII
- ⚠️ ถ้า plan ยัง `status != done` → warn ให้ implement ก่อน (ไม่ block แต่ recommend)
- ⚠️ ถ้าไม่ได้รัน `/ow-verify` → warn ให้รันก่อน (ไม่ block แต่ recommend)
- 💡 Handoff Report = 5 mandatory output sections ครบในเอกสารเดียว

## Related

- ก่อน `/ow-handoff`: [/ow-verify](./ow-verify.md), [/ow-secure](./ow-secure.md)
- หลัง `/ow-handoff`: [/ow-git](./ow-git.md), reviewer review + approve
- Vault path: `docs/obsidian-vault/95-Handoff/HOR-*.md`

## FAQ

**Q: ต่างจาก `/ow-verify` ยังไง?**
A: `/ow-verify` = ตรวจงานตัวเอง (tests/vault/security/DS); `/ow-handoff` = สร้างเอกสารส่งต่อคนอื่น พร้อม Approval section

**Q: Reviewer ดูที่ไหน?**
A: `docs/obsidian-vault/95-Handoff/HOR-*.md` — Approval section รอ reviewer sign

**Q: ต้อง verify ก่อนทุกครั้งไหม?**
A: แนะนำ — ถ้าไม่ verify มาก่อน `/ow-handoff` จะ warn แต่ไม่ block; handoff report จะมีหมายเหตุว่า verification pending
