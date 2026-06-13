---
description: Taxonomy-driven ambiguity scan + 1-at-a-time question with recommended answer → write Clarifications log back into spec
---

# /ow-clarify — Ambiguity Scan (1-at-a-time)

Scan PRD/SRS/plan แล้วถามคำถามทีละข้อ (max 5) พร้อม **Recommended answer** เพื่อลด decision fatigue
เขียน answers กลับเข้า doc ใน `## Clarifications` เป็น `### Session YYYY-MM-DD` block

> **inspired by:** spec-kit `/clarify`

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
/ow-clarify                          # scan SRS ล่าสุด (ไม่มี SRS → plan ล่าสุด)
/ow-clarify <path-to-doc>            # scan specific doc (PRD/SRS/FEAT/plan/etc.)
/ow-clarify --feature <slug>         # scan all docs of a feature
/ow-clarify --max 3                  # override max questions (default: 5)
/ow-clarify --resume                 # continue session ที่ค้าง
```

## Phase 0.5 — Resolve target

```bash
[ -n "$PRD_DIR" ] && [ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }

if [ -z "$ARGUMENTS" ]; then
  # default: SRS ล่าสุด (working contract — เป้าหมายหลักของ clarify) → fallback: plan ล่าสุด
  TARGET=$(ls -t "$PRD_DIR"/SRS-*.md 2>/dev/null | head -1)
  [ -n "$TARGET" ] || TARGET=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
fi
test -f "$TARGET" || echo "target not found"
```

แสดง user:
> จะ scan: `<TARGET>`
> ประเภท: PRD / SRS / Feature / Plan / Function / Fix-log
> Existing clarifications: <N> session(s)
> ดำเนินการต่อ?

## Phase 1 — Taxonomy scan (read-only)

ตรวจ ambiguity ตาม 9 หมวด (จาก spec-kit):

| Category | ตัวอย่าง ambiguity ที่หา |
|---|---|
| **1. Functional Scope** | "support multiple X" — กี่ตัว? ทุกประเภท? |
| **2. Domain & Data** | "user" — role ไหน? "order" — schema มีอะไร? |
| **3. UX / Behavior** | "show notification" — modal/toast/banner? auto-dismiss? |
| **4. Non-functional Requirements** | "fast" — กี่ ms? "secure" — threat model ไหน? |
| **5. Integration** | "send to API" — endpoint? auth? retry? |
| **6. Edge Cases** | empty state, network fail, concurrent edit, permission denied |
| **7. Constraints** | budget, deadline, team size, must-reuse |
| **8. Terminology** | "member" vs "user" vs "account" ใช้ตัวไหน |
| **9. Completion / DoD** | "done" หมายถึง? — code merged? deployed? approved? |

สำหรับแต่ละหมวด:
1. Grep target doc + linked docs (frontmatter `related:` + wikilinks)
2. หา weasel words: "should", "could", "may", "fast", "many", "appropriate", "TBD", "?"
3. หา `[NEEDS CLARIFICATION]` + `<TODO>` markers
4. รวม candidate questions

### Underspecified FR = เป้าหมายอันดับแรก (target เป็น SRS หรือ doc ที่อ้าง FR)

ตรวจทุก FR block เทียบ depth bar ของ `.ow/templates/srs.md` — ขาดข้อใดข้อหนึ่ง = underspecification:
- ไม่มี acceptance **Given/When/Then** หรือมี < 2 scenario / ไม่มี sad path
- ไม่มี inputs/outputs, pre/post-conditions, error handling, dependencies
- NFR ไม่มี measurable threshold + วิธีวัด ("fast"/"secure" ลอยๆ)
- entity มี status แต่ไม่มี row ใน State & Lifecycle / error ที่ FR อ้างไม่อยู่ใน Error Catalog
- Traceability row ของ FR ว่าง

คำถามจากกลุ่มนี้**ขึ้นคิวก่อนหมวดอื่นเสมอ** — FR ที่ไม่มี acceptance คือ ambiguity ที่แพงที่สุด
(`/ow-plan` จะ flag FR พวกนี้แล้วส่งกลับมาที่ command นี้)

ลด list → **max 5 คำถาม** เลือกตาม:
- Severity (Critical > High > Medium)
- Block downstream (เช่น affect data model หรือ API contract)
- Cheap to answer (1 sentence)

## Phase 2 — Ask 1 question at a time

**ห้าม batch** — ถามทีละข้อ (ต่างจาก /ow-new และ /ow-plan ที่ batch)

Format ของแต่ละคำถาม:

```markdown
🔍 Clarification 2/5 — Category: UX / Behavior

**Question:**
เมื่อ checkout สำเร็จ ระบบควรแสดงผลแบบไหน?

**Options:**
  A) Toast (auto-dismiss 3 วินาที) — discrete, ไม่ block flow
  B) Modal dialog (user ต้องคลิก close) — explicit confirmation
  C) Inline message ใน page เดิม — เหมาะ embedded flow
  D) Redirect ไป /checkout/success page — ครบสุด มี receipt

**Recommended:** B) Modal dialog
**Reasoning:** persona หลักต้องการ explicit confirmation ก่อน proceed; ตรง Modal pattern ใน DS-Components; สอดคล้อง state diagram ใน [[FLOW-checkout]]

**Your answer:** [A/B/C/D หรือ ข้อความอื่น]
```

User ตอบ → record + ไป question ถัดไป

ถ้า user ตอบ "skip" หรือ "TBD" → record เป็น `[DEFERRED]` ใน Clarifications log

## Phase 3 — Write back to source doc

หลังจบ session (5 คำถาม หรือ user หยุดก่อน) เขียนลง `## Clarifications` ของ target:

- Template ใหม่ (PRD/SRS) มี `## Clarifications` ท้าย doc อยู่แล้ว → แทน placeholder
  `_ยังไม่มี clarification session_` ด้วย session แรก
- มี session เก่าแล้ว → **append** `### Session <today>` ใหม่ (ไม่ทับเก่า)
- doc เก่าที่ไม่มี section → เพิ่ม `## Clarifications` ท้าย doc

```markdown
## Clarifications

### Session <YYYY-MM-DD>

- **Q1 (FR-completeness):** FR-003 ไม่มี acceptance — sad path ของ <action> คืออะไร? **A:** <answer> → flag: เติม GWT ใน FR-003
- **Q2 (UX):** <toast vs modal สำหรับ success state>? **A:** Modal (recommended). Reasoning: explicit confirmation
- **Q3 (NFR):** Acceptable latency ของ <endpoint>? **A:** p95 ≤ 800ms
- **Q4 (Terminology):** "<term A>" vs "<term B>" ใช้ตัวไหน? **A:** <term A> (consistent กับ PRD glossary)
- **Q5 (Edge):** Behavior เมื่อ network fail ระหว่าง submit? **A:** [DEFERRED]
```

## Phase 4 — Update affected docs

ถ้า answer มีผลต่อ:
- **FR/acceptance** → flag: "FR-### ต้องเติม acceptance / แก้นิยาม (Q1)" → ชี้ไป `/ow-doc SRS <slug>`
- **Data model** → flag ใน plan: "data-model needs update (Q#)"
- **API contract** → flag in REF-APIIntegration.md
- **DS component** → flag if new variant needed
- **FR list** → suggest FR-### addition/refinement

ไม่แก้ docs อื่นเอง — แค่ **flag** ให้ user รัน `/ow-doc` หรือ `/ow-plan <task> --revise <path>`

## Phase 5 — Update status

Update `$IMPL_STATUS` ถ้า status ของ target เปลี่ยน (เช่น planning → approved-pending-update)

## Phase 6 — Next-step suggestion

> ✅ Clarifications saved → `<target>`
>
> Next:
>   • เติม FR ที่ flag ไว้: `/ow-doc SRS <slug>`
>   • Revise plan: `/ow-plan <task> --revise <plan-path>`
>   • Re-verify consistency: `/ow-verify --feature <slug>`
>   • If data-model changed: `/ow-doc data-model <feature>`
>   • If unblocked: `/ow-implement <plan>` (only if status: approved)

## Output (3 หัวข้อบังคับ)

1. **Result** — target doc + จำนวน clarifications added (resolved/deferred) + session block ที่เขียน
2. **Verification / Evidence** — scan ที่รันจริง (grep weasel words / FR depth check) + affected-docs list ที่ flag
3. **Limitations / Next steps** — deferred questions + downstream docs ที่ต้อง revise (/ow-doc, /ow-plan --revise)

## ห้าม

- ห้าม batch คำถาม — **ทีละข้อเท่านั้น**
- ห้ามให้คำตอบ recommended ที่ไม่อิง vault content (ต้อง cite ทุก reasoning ด้วย link ไป doc/section)
- ห้ามแก้ source doc นอก `## Clarifications` section — ไม่แตะ FR, Goals, etc.
- ห้ามถามคำถามที่ vault ตอบอยู่แล้ว — Phase 1 ต้อง filter ออกก่อน
- ห้ามแก้ doc อื่นๆ — แค่ flag เท่านั้น
- ห้าม invent option ที่ unrealistic — ถ้าไม่รู้ → ใส่แค่ 2 options + "[OTHER]" ให้ user พิมพ์เอง
