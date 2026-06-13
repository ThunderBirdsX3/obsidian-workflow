---
description: Interactive help — แนะนำ command ตามสถานการณ์ + อธิบายวิธีใช้ + workflow ที่พบบ่อย
---

# /ow-help — Interactive Help

ตัวช่วยถาม-ตอบ: "อยากทำอะไร → ใช้ command ไหน → ทำงานยังไง"

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
/ow-help                          # interactive — ถามว่าอยากทำอะไร
/ow-help <command>                # อธิบาย command ตัวนั้นเชิงลึก
/ow-help workflow                 # แสดง workflows ที่พบบ่อย
/ow-help workflow <name>          # อธิบาย workflow เฉพาะ (new-project, bug-fix, github-issue, design)
/ow-help search <keyword>         # ค้น command/concept ที่เกี่ยวข้อง
/ow-help cheatsheet               # 1-page cheatsheet สั้นๆ
/ow-help tree                     # decision tree "ถ้า X → ใช้ Y"
```

## Phase 1 — Detect intent

ถ้า arguments ว่าง → ถาม user 1 คำถามเดียว:

```
จะให้ช่วยอะไร?

  1) แนะนำ command ตามสถานการณ์    (ถ้าไม่รู้ว่าจะใช้ตัวไหน)
  2) อธิบาย command เฉพาะ           (ถ้ารู้แล้วแต่อยากรู้ option/phase)
  3) แสดง workflow ที่พบบ่อย         (เช่น "เริ่ม project ใหม่ทั้งหมดยังไง")
  4) Cheatsheet 1 หน้า               (รายชื่อ command + ใช้เมื่อไหร่)
  5) ค้นด้วย keyword                  (เช่น "evidence", "worktree", "SRS")
```

### Decision tree (ใช้ใน `tree` mode)

```
ถาม: project มี .ow.yml อยู่แล้วไหม?
├─ ไม่มี → /ow-init
└─ มี → ถามต่อ: จะทำอะไร?
    ├─ "มีไอเดียใหม่"              → /ow-new
    ├─ "มี PRD แล้ว อยากต่อ SRS"    → /ow-new --import
    ├─ "spec กำกวม/ไม่ครบ"          → /ow-clarify
    ├─ "ตรวจคุณภาพ spec"           → /ow-checklist
    ├─ "วางแผน feature"            → /ow-plan <task>
    ├─ "ลงมือทำตาม plan"            → /ow-implement <plan-file>
    ├─ "แก้บั๊ก"                    → /ow-fix <bug>
    ├─ "แก้ GitHub issue เป็นชุด"    → /ow-triage-issues → /ow-fix-issue #NN
    ├─ "เขียน/แก้ doc"              → /ow-doc <type>
    ├─ "มี code แล้วไม่มี spec"      → /ow-reverse-engineer
    ├─ "test smoke"                 → /ow-test
    ├─ "ออกแบบ UI / design system"  → /ow-design [init|tokens|component]
    ├─ "จัดระเบียบ evidence"         → /ow-evidence
    ├─ "ตรวจ security"              → /ow-secure
    ├─ "FR ไหนทำแล้ว/ขาดอะไร"       → /ow-trace
    ├─ "review โค้ดเทียบ SRS"        → /ow-review
    ├─ "verify ก่อนปิดงาน"           → /ow-verify
    ├─ "commit/push"                → /ow-git [--plan|--fix|--bump]
    ├─ "ปล่อย version + changelog"   → /ow-release
    └─ "พักงาน/ต่อ session หน้า"     → /ow-handoff
```

## Phase 2 — Mode "อธิบาย command เฉพาะ"

อ่าน `.ow/commands/<cmd>.md` แล้วสรุปให้ user:

```
## /ow-<name>

ใช้เมื่อ: <one-line>

Trigger:
  <list trigger forms>

ทำอะไร: (Phase summary — ไม่ลงรายละเอียดยาว)
  1. <Phase 1 ในประโยคเดียว>

ผลลัพธ์ใน vault:
  - <ไฟล์ที่จะสร้าง/แก้>

ห้าม: (top 2-3)

ต่อด้วย: → /ow-<next>

อ่าน full spec: .ow/commands/ow-<name>.md
```

## Phase 3 — Mode "workflows"

### `workflow new-project` — เริ่มโปรเจกต์ใหม่ตั้งแต่ศูนย์

```
1. /ow-init                           ← config (vault location, subagents)
2. /ow-new                            ← brainstorm → PRD + SRS + Tech-spec
3. /ow-clarify                        ← สแกน ambiguity ใน SRS (แนะนำ)
4. /ow-design init                    ← (optional) bootstrap design system
5. /ow-plan <feature>                 ← วางแผน feature แรก
6. [user review plan, set status: approved]
7. /ow-implement <plan-path>          ← ลงมือ ผ่าน subagent
8. /ow-test                           ← smoke test
9. /ow-secure                         ← pre-flight
10. /ow-verify                        ← verify ทุกอย่างก่อนปิด
11. /ow-git --plan <path>             ← commit + push
12. /ow-release minor                 ← (เมื่อพร้อมปล่อย) changelog + tag + bump
```

### `workflow bug-fix` — แก้บั๊กพร้อม evidence

```
1. /ow-fix "search ค้างเมื่อใส่ขีดล่าง"  ← diagnose + fix-log (no code)
2. /ow-plan fix:<slug>                   ← small plan referencing fix-log
3. /ow-implement <plan>                  ← ลงมือ
4. /ow-test --since <sha>                ← verify fix
5. /ow-verify                            ← ตรวจรวม
6. /ow-git --fix <fix-log-path>          ← commit (prefix: fix:)
```

### `workflow github-issue` — triage + แก้ GitHub bug

```
1. /ow-triage-issues                     ← ดึง bug pool → classify + label + เสนอ cluster
   → STOP + ยืนยันก่อนแตะ GitHub
2. /ow-fix-issue #62 #63                  ← worktree แยกต่อ group → diagnose → test → evidence → fix → merge local
   → ไม่ push / ไม่ comment
3. /ow-test --since <ref>                 ← smoke เฉพาะ area ที่ fix แตะ
4. /ow-git --bump patch                   ← push + bump version
5. [verify บน version ใหม่] → close issue

🔴 triage = read-only ต่อโค้ด · fix-issue ไม่ push · close หลัง verify เท่านั้น
```

### `workflow design` — สร้าง/ใช้ design system

```
1. /ow-design init                       ← bootstrap minimal DS (DS-Tokens, DS-Components, preview.html)
2. เปิด preview.html ด้วย browser
3. /ow-design tokens                     ← ปรับ token (brand colors, type)
4. /ow-design component <name>           ← เพิ่ม component ใหม่
5. /ow-design audit                      ← ตรวจ implementation vs DS

หลัง init → frontend/mobile subagent ถูกบังคับใช้ DS
ห้าม ad-hoc styling — ต้อง component ใหม่ → STOP, /ow-design ก่อน
```

### `workflow brownfield-adopt` — รับ codebase เดิมเข้า workflow

```
1. copy toolkit เข้า project (ดู install.sh) → /ow-init (brownfield)
2. (มี README) → ตรวจ PRD draft ที่ generate
3. /ow-reverse-engineer                   ← extract FEAT/FN/REF จาก code จริง
4. /ow-doc SRS <slug>                     ← ยกระดับเป็น SRS (FR + acceptance)
5. /ow-plan <first task>                  ← เริ่ม workflow ปกติ
```

## Phase 4 — Mode "cheatsheet"

```
| Command              | ใช้เมื่อ                                | ผลลัพธ์หลัก                |
|----------------------|------------------------------------------|----------------------------|
| /ow-init           | ตั้งค่า project ครั้งแรก                    | .ow.yml + vault          |
| /ow-new            | เริ่ม project/feature ใหม่                 | PRD + SRS + Tech           |
| /ow-clarify        | scan ambiguity ใน spec                   | clarified spec             |
| /ow-plan           | วางแผนงาน (ก่อนแตะโค้ด)                 | plan file in 80-...        |
| /ow-checklist      | spec-quality gate per domain             | checklist file             |
| /ow-implement      | ลงมือทำตาม plan (เท่านั้นที่แก้โค้ด)      | code + evidence            |
| /ow-fix            | diagnose บั๊ก (ไม่แก้โค้ด)               | fix-log in 85-FixLog       |
| /ow-triage-issues  | triage GitHub bug เป็นชุด                | label+comment+cluster      |
| /ow-fix-issue      | แก้ GitHub bug ขนาน (worktree)           | fix branches (local)       |
| /ow-reverse-engineer | extract spec จาก code เดิม              | FEAT/FN/REF drafts         |
| /ow-doc            | เขียน/แก้ doc (เน้น SRS-depth)            | doc file in vault          |
| /ow-test           | smoke test diff                          | test report + evidence     |
| /ow-design         | สร้าง/อัพเดท design system                | DS-*.md + preview.html     |
| /ow-evidence       | finalize evidence (cleanup + verify)     | EVIDENCE.md manifests      |
| /ow-secure         | security pre-flight                      | secure report              |
| /ow-trace          | FR coverage (FR→FN→plan→test→evidence)   | trace report + SRS §10     |
| /ow-review         | review diff เทียบ SRS acceptance          | FR verdict + findings      |
| /ow-verify         | verify (tests/evidence/security/DS)      | verify report              |
| /ow-release        | changelog + delegate bump ให้ /ow-git     | CHANGELOG.md + tag         |
| /ow-handoff        | session handoff note                     | HANDOFF-*.md in 95-Handoff |
| /ow-git            | submodule-aware commit/push              | git history                |
| /ow-help           | this help                                |                            |
```

## Phase 5 — Mode "search"

```bash
grep -l "$KEYWORD" .ow/commands/*.md
grep -l "$KEYWORD" .claude/agents/*.md
grep -l "$KEYWORD" .ow/policies/*.md
```

แสดงผลเป็นกลุ่ม: Commands / Subagents / Policies ที่กล่าวถึง keyword + one-line ว่าเกี่ยวยังไง

## Output — read-only exception

`/ow-help` เป็น command **อ่านอย่างเดียว** — ไม่สร้าง/แก้ไฟล์ใดๆ
ใช้ minimal output: คำตอบที่ user ขอ + ปิดท้าย:

> 💡 ยังไม่แน่ใจ → ลอง `/ow-help tree` หรือ `/ow-help cheatsheet`
> 📖 อ่านเต็ม: `.ow/commands/<name>.md`

## ห้าม

- ห้ามแก้ไฟล์ใดๆ — help เป็น read-only
- ห้าม guess command ที่ไม่มีจริง — list 22 commands เท่านั้น
- ห้าม invent workflow นอก Phase 3 cards — ผู้ใช้ถามนอกขอบเขต → ใช้ Phase 1 ถามต่อ
