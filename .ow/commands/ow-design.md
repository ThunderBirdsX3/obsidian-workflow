---
description: Design system architect — tokens, components, patterns, accessibility, preview.html, Figma export import
---

# /ow-design — Design System

สร้าง + ดูแล design system: tokens, components, patterns, accessibility, preview, Figma export import

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules frontend)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-design init                          # bootstrap DS ครั้งแรก (tokens + components + preview)
/ow-design tokens [add|edit]             # จัดการ design tokens
/ow-design component <name>              # เพิ่ม/แก้ component spec
/ow-design pattern <name>                # เพิ่ม pattern (composition)
/ow-design audit [path]                  # scan code หา DS drift
/ow-design preview                       # regenerate preview.html
/ow-design import-figma <export-path>    # import Figma export → DS-Tokens (contrast-gated)
```

ว่าง → ถาม "จะทำ action ไหน?" + list DS state ปัจจุบัน

## Phase 0.5 — Resolve DS state

`/ow-design` เป็นเจ้าของ `$DS_DIR` (= `$VAULT_ABS/70-Reference/DesignSystem`)

```bash
[ -n "$DS_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
ls "$DS_DIR"/ 2>/dev/null || echo "DS not initialized"
```

| สถานการณ์ | action |
|---|---|
| `$DS_DIR` ไม่มี + user สั่ง tokens/component/audit | STOP → แนะนำ `/ow-design init` ก่อน |
| `$DS_DIR` มีแต่ไฟล์ DS หาย/ว่าง | flag corrupt → ถาม re-init หรือซ่อมเฉพาะไฟล์ |
| import-figma แต่ export-path ไม่มี | STOP (Phase 5) |

## Phase 1 — `init` mode

สร้าง DS skeleton:
1. `DS-Tokens.md` — primitive + semantic tokens
2. `DS-Components.md` — component catalog
3. `DS-Patterns.md` — composition patterns
4. `DS-Accessibility.md` — a11y rules
5. `DS-Voice.md` — microcopy guide
6. `preview.html` — visual reference

เรียก `design` subagent (§6 Process) ทำจริง

## Phase 2 — `tokens` / `component` / `pattern` modes

เรียก `design` subagent พร้อม action:
```
Action: tokens-add | tokens-edit | component-add | component-edit | pattern-add
Target: <name>
Context: อ่าน DS-Tokens.md + DS-Components.md ก่อน
```

## Phase 3 — `audit` mode

เรียก `design` subagent — audit 2 ชั้นเสมอ (agent Phase 5A + 5B):
```
Action: audit
Scope: self (DS docs — รันเสมอ) + <source path or detect จาก config — ไม่ hardcode stack>
Output: $DS_DIR/audit-<date>.md
        ต้องมี: Score /100 (สูตร deterministic ของ agent Phase 5A) + self-audit 6 มิติ
        (token-reference integrity / claim re-verify / preview sync / naming /
         completeness per component / required files) + code drift findings (เมื่อมี source)
```

design subagent enforce §5.2-5.4 (DS compliance) + WCAG 2.2 AA — **audit = read-only ต่อ source** (ให้ frontend/mobile agent apply fix). contrast claim ใน DS docs ที่ recompute แล้วไม่ตรง = HIGH finding (no-fake-evidence ใช้กับ design docs ด้วย — ห้ามเชื่อ ratio ที่จดไว้โดยไม่คำนวณซ้ำ)

## Phase 4 — `preview` mode

เรียก `design` subagent regenerate `preview.html`

### 4.1 Preview ↔ token drift check
หลัง regenerate → ตรวจว่า CSS var ใน preview.html ครบกับ DS-Tokens.md:
```bash
comm -23 <(grep -oE '`[a-z][a-z0-9-]+`' "$DS_DIR/DS-Tokens.md" | tr -d '`' | sort -u) \
         <(grep -oE -- '--[a-z][a-z0-9-]+' "$DS_DIR/preview.html" | sed 's/--//' | sort -u)
```
ผลลัพธ์ไม่ว่าง = token ใน DS ที่ยังไม่โผล่ใน preview → preview stale → flag + regenerate ให้ครบ

## Phase 5 — `import-figma` mode

`/ow-design import-figma <export-path>` — import Figma export เป็น DS tokens (design เป็นเจ้าของงานนี้ ไม่มี figma agent แยก)

```bash
[ -e "$EXPORT_PATH" ] || { echo "Figma export ไม่พบ: $EXPORT_PATH — ระบุ path ที่ถูกต้อง"; exit 1; }
```

เรียก `design` subagent action `figma-import` (§6 Phase 3.5):
```
Action: figma-import
Export: <export-path>   (tokens.json / variables.json / Style Dictionary)
Rules:
  - parse export → diff vs DS-Tokens.md
  - color ทุกตัวผ่าน contrast §5.2 ก่อน save (FAIL = ไม่ save + report)
  - token เดิมค่าขัดกัน = STOP report conflict (ห้าม overwrite เงียบ)
  - DS gap: Figma component ที่ไม่มีใน DS → flag + เสนอ component-add
  - save เฉพาะที่ผ่าน → bump tokens_version → regenerate preview.html
```

🔴 **design แสดง diff (add N / conflict M / orphan K) ให้ user เห็นก่อน save เสมอ**

(ถ้า user มี brand guideline แทน Figma → ใช้ `init` หรือ `tokens add` แล้ว extract palette เอง)

## Output (3 หัวข้อบังคับ)

1. **Result** — action ที่ทำ + DS files ที่สร้าง/แก้ + tokens_version bump (ถ้ามี)
2. **Verification / Evidence** — contrast check results + preview↔token drift check + (import-figma) diff add/conflict/orphan; ไม่ได้รัน = เขียน `not run — <เหตุผล>`
3. **Limitations / Next steps** — components ที่ยังขาด + conflict ที่ user ต้องตัดสิน + audit findings ให้ frontend/mobile agent แก้

## ห้าม

- ห้ามแก้ source code ใน /ow-design — spec อย่างเดียว (audit ใช้ frontend/mobile agent apply)
- ห้ามเพิ่ม/import color token โดยไม่ check contrast (subagent §5.2)
- ห้าม skip accessibility section ใน component
- ห้าม overwrite DS ที่มีอยู่โดยไม่ confirm
- ห้าม import Figma token ที่ค่าขัด token เดิมโดยไม่ confirm — §5.10 STOP report
- ห้ามแก้ Figma source / เรียก Figma API — import จาก export file เท่านั้น (read-only on Figma)
