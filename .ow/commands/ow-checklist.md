---
description: Generate domain checklist — "unit tests for English" to validate spec quality before implementation
---

# /ow-checklist — Spec Quality Checklist Generator

สร้าง checklist ที่เป็น **"unit tests for English"** — ทดสอบคุณภาพ spec ไม่ใช่ behavior ของ code
แต่ละ CHK item เป็นคำถามที่ author ตอบเอง: ✅ Yes / ❌ No → ✅ ทุกข้อก่อน implement

> **inspired by:** spec-kit `/checklist`

## Phase 0 — Load Context (MANDATORY — before every other phase)
<!-- OW-PHASE0: canonical Load-Context preamble — identical across all commands. Do NOT edit per-command. -->

Runs FIRST, before any other phase. Loads resolved project paths + config so this spec
never hardcodes a vault/build path. If the resolver is absent or exits non-zero, **STOP**
and tell the user to run `/ow-init` — never proceed on defaults.

```bash
# 1) resolve config — never a bare relative path
eval "$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --shell)" || {
  echo "FATAL: resolver missing/failed — run /ow-init"; exit 1; }
[ -n "$VAULT_ABS" ] || { echo "FATAL: Phase 0 not loaded"; exit 1; }
export OW_CTX_LOADED=1
# 2) load this command's project rules — they OVERRIDE the generic guidance in this spec
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules docs)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-checklist                        # interactive — ถาม domain
/ow-checklist <domain>               # generate ใหม่
/ow-checklist <domain> --append      # เพิ่ม items ลง checklist เดิม
/ow-checklist review <path>          # ตรวจ checklist ที่ user ตอบแล้ว
/ow-checklist list                   # แสดง checklists ทั้งหมดของ project
```

## Phase 0.5 — Detect domain

Domains ที่ default มี:

| Domain | ตรวจอะไร |
|---|---|
| **srs** | FR completeness ตาม depth bar ของ `.ow/templates/srs.md` (ดู examples Phase 2) |
| **ux** | clarity, accessibility, error handling, copy, loading states |
| **api** | versioning, auth, errors, idempotency, rate limit, schema |
| **security** | secrets, PII, threat model, audit log, OWASP top 10 |
| **performance** | latency, throughput, payload size, cache, query N+1 |
| **data** | schema migration, retention, backup, GDPR, integrity |
| **a11y** | WCAG AA, keyboard, screen reader, contrast, focus |
| **observability** | logs, metrics, traces, alerts, dashboards |
| **rollout** | feature flag, rollback, monitoring, canary, comms |
| **<custom>** | user-defined — สร้างเองได้ |

ถ้า `$ARGUMENTS` ว่าง → ถาม "domain ไหน?" (multi-select ได้)
**Target เป็น SRS → include domain `srs` เสมอ** — SRS คือ working contract; checklist นี้คือ quality gate หลักก่อน plan/implement

## Phase 1 — Determine scope

ถาม:
1. **Target**: feature ไหน / PRD/SRS ไหน / project-wide?
2. **Phase**: pre-design / pre-implementation / pre-release?
3. **Append หรือ new file**?

## Phase 2 — Generate items (CHK### format)

แต่ละ item เป็น **คำถามที่ทดสอบ spec ไม่ใช่ implementation**

Examples สำหรับ `srs` (มัดกับ section ที่มีจริงใน `.ow/templates/srs.md`):
```markdown
- [ ] CHK001 ทุก US ใน PRD มี FR-### รองรับอย่างน้อย 1 ตัว (ไม่มี story ลอย)?
- [ ] CHK002 ทุก FR มี acceptance Given/When/Then ≥ 2 scenario และมี sad path?
- [ ] CHK003 ทุก FR ระบุ inputs/outputs พร้อม type + constraint (ไม่ใช่แค่ชื่อ field)?
- [ ] CHK004 ทุก FR ระบุ pre/post-conditions รวม business rule + side effect (audit log ฯลฯ)?
- [ ] CHK005 ทุก FR ระบุ error handling (code + message ต่อ failure mode, race condition ถ้ามี)?
- [ ] CHK006 ทุก FR ระบุ dependencies (FR อื่น / external system / DB schema)?
- [ ] CHK007 ทุก NFR มี measurable threshold + วิธีวัด (ไม่มี "fast"/"secure" ลอยๆ)?
- [ ] CHK008 ทุก entity ที่มี status มีตาราง State & Lifecycle (transition / actor / side effect)?
- [ ] CHK009 ทุก error ที่ FR อ้าง อยู่ใน Error Catalog (code / when / message / FR)?
- [ ] CHK010 Traceability table ครบ — ทุก FR map ไป FN spec + Test plan (ไม่มี orphan)?
- [ ] CHK011 ไม่เหลือ `<TODO>` ใน FR ที่อยู่ใน scope ที่จะ implement?
```

Examples สำหรับ `ux`:
```markdown
- [ ] CHK001 ทุก action button ใน spec ระบุ "ทำอะไรเมื่อ user คลิก" ชัดเจน (ไม่ใช่แค่ชื่อ)?
- [ ] CHK002 ทุก form field ระบุ validation rule + error message ที่ user จะเห็น?
- [ ] CHK003 ทุก state (idle/loading/success/error/empty) มี wireframe หรือคำอธิบาย?
- [ ] CHK004 Copy ทั้งหมดเป็นภาษาที่กำหนด (th/en) + ผ่าน tone guideline?
- [ ] CHK005 Loading > 1 วินาที มี loading indicator + estimated time?
- [ ] CHK006 Error message บอก user ว่า "ทำอะไรต่อ" ไม่ใช่แค่ "เกิดข้อผิดพลาด"?
- [ ] CHK007 ทุก destructive action (delete/cancel) มี confirmation dialog?
- [ ] CHK008 ทุก dialog ระบุ keyboard behavior (Escape, Enter, Tab focus trap)?
- [ ] CHK009 Mobile layout ระบุ ตั้งแต่ width < 640px?
- [ ] CHK010 Empty state มี call-to-action ที่ user รู้ว่าทำอะไรต่อ?
```

Examples สำหรับ `api`:
```markdown
- [ ] CHK001 ทุก endpoint ระบุ HTTP method + path pattern + auth requirement?
- [ ] CHK002 Request schema ระบุ field type + required/optional + max length?
- [ ] CHK003 Response schema ระบุ success format + ทุก error code + message structure?
- [ ] CHK004 Idempotency — POST/PUT ระบุ idempotency-key behavior?
- [ ] CHK005 Rate limit ระบุ (per-user / per-IP) + response เมื่อเกิน?
- [ ] CHK006 Pagination ระบุ format (offset/cursor) + max page size?
- [ ] CHK007 Backward compatibility — breaking change ระบุ versioning?
- [ ] CHK008 ทุก timestamp ระบุ timezone (UTC vs local)?
- [ ] CHK009 PII fields ใน response ระบุ masking rule?
- [ ] CHK010 Webhook retry policy + signature verification ระบุ?
```

Examples สำหรับ `security`:
```markdown
- [ ] CHK001 ทุก secret/credential ระบุ source (env var / secret manager) + ไม่อยู่ใน vault?
- [ ] CHK002 PII fields ระบุ + masking rule + retention?
- [ ] CHK003 ทุก endpoint ที่อ่าน data ระบุ authorization rule (role × resource)?
- [ ] CHK004 Input validation ระบุ + sanitization สำหรับ SQL/XSS/SSRF?
- [ ] CHK005 Audit log ระบุ what/who/when/where ทุก mutation?
- [ ] CHK006 Rate limit + brute-force protection สำหรับ auth endpoint?
- [ ] CHK007 CSRF token / SameSite cookie ระบุ?
- [ ] CHK008 Dependency CVE scan ผ่าน?
- [ ] CHK009 Threat model อย่างน้อย 1 หน้า มี?
- [ ] CHK010 Backup + recovery procedure ระบุ?
```

จำนวน items: 10-30 ต่อ domain (custom domain → ถาม user ว่าต้องการกี่ข้อ)

## Phase 3 — Write file

Path: `$HANDOFF_DIR/checklists/<domain>-<scope>-<YYYY-MM-DD>.md`

หรือ append ถ้า `--append`

Frontmatter:
```yaml
---
tags: [type/checklist, domain/<domain>]
date: <YYYY-MM-DD>
scope: feature:<slug> | project
domain: <domain>
generated_by: /ow-checklist
items_total: 10
items_passed: 0
items_failed: 0
items_pending: 10
status: in-review                # in-review | passed | blocked
---
```

## Phase 4 — Review mode (`/ow-checklist review`)

อ่าน checklist ที่ user mark `[X]` แล้ว → สรุป:

```markdown
## Review Summary — ux-FEAT-Checkout-<YYYY-MM-DD>

- **Total:** 10
- **Passed [X]:** 7
- **Failed [N]:** 1 — CHK004 "Copy ทั้งหมดเป็นภาษาที่กำหนด" (user marked failed)
- **Pending [ ]:** 2 — CHK008, CHK010

**Blocking issues:**
- CHK004 → /ow-doc copy-guide หรือแก้ใน PRD copy section
- CHK008, CHK010 → ตอบใน PR review

**Next:** กลับมารัน /ow-checklist review หลังแก้
```

## Phase 5 — Integration กับ /ow-verify

`/ow-verify` ตรวจ checklist:
- ถ้ามี `domain` checklist ใน scope → required ทุกข้อ pass (`[X]`)
- ถ้ามี [ ] หรือ [N] → block handoff ออก WARNING

`/ow-implement` ตรวจ checklist:
- ถ้า status ของ plan == approved แต่ checklist `status: in-review` → ถาม "ดำเนินต่อโดย checklist ยังไม่ผ่านครบ?"

## Output (3 หัวข้อบังคับ)

1. **Result** — checklist file path + domain(s) + items count (review mode: summary pass/fail/pending)
2. **Verification / Evidence** — scope docs ที่อ่านจริง + ผล frontmatter counts ตรงกับ items ในไฟล์
3. **Limitations / Next steps** — items pending/failed = spec-quality risk ที่ยังไม่ปิด → แก้ผ่าน /ow-doc หรือ /ow-clarify

## ห้าม

- ห้าม generate item ที่ทดสอบ implementation (เช่น "POST /api/checkouts returns 201") — checklist เป็น spec-quality test เท่านั้น
- ห้ามทำให้ checklist > 30 items ใน domain เดียว — แตกเป็น sub-checklist
- ห้าม mark item เป็น `[X]` แทน user (user ต้องตอบเอง)
- ห้ามแก้ source spec ใน checklist process — ใช้ /ow-doc หรือ /ow-clarify
- ห้าม block /ow-implement automatically — แค่ WARN ถ้า checklist ไม่ผ่าน
