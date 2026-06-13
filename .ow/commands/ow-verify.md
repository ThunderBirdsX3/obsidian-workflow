---
description: Full verify (tests + evidence + vault + security + DS) — ไม่สร้าง handoff note (ใช้ /ow-handoff แยก)
---

# /ow-verify — Full Verify

ตรวจครบทุกมิติก่อนปิดงาน — tests, evidence, vault, security, design system

> ต้องการสรุปงานส่งต่อ session ถัดไป (ตัวเองหรือ AI ตัวใหม่)? → `/ow-handoff <plan-or-fix-path>`

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules testing)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-verify <plan-or-fix-path>      # ตรวจ specific work
/ow-verify --since <ref>           # ตรวจทุกอย่างใน diff range
/ow-verify --feature <name>        # ตรวจ feature scope
```

## Phase 1 — Scope identification

อ่าน:
- Plan/fix file ที่ user ระบุ
- Files changed (`git diff`)
- Vault docs ที่ link (Feature, Function, PRD)

## Phase 2 — Test verification

รัน (หรือดูว่ารันแล้ว):
- Unit tests (relevant scope)
- Integration tests
- Lint
- Build
- Type check

**ห้าม fake** — ถ้ารันไม่ได้ ระบุ blocker + reason

## Phase 3 — Evidence audit

🔴 **HARD GATE: the vault must hold TEXT only — no evidence binaries.** Fail non-zero
on any hit (base64 `data:image/` is also banned; `preview.html` / `audit-<date>.md` are the
only allowed markup):

```bash
if find "$VAULT_ABS" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \
  -o -name '*.har' -o -name '*.zip' -o -name '*.trace' -o -name '*.log' -o -name '*.txt' \
  -o -name 'manifest.json' \) | grep -q .; then
  echo "FAIL: evidence binaries found in the vault — relocate to EVIDENCE_ROOT"; exit 1
fi
grep -rIl 'data:image/' "$VAULT_ABS" 2>/dev/null | grep -qv -e 'preview.html' && { echo "FAIL: base64 raster in vault"; exit 1; } || true
echo "OK: vault is text-only"
```

Then audit the staged evidence under `EVIDENCE_ROOT` (test-artifacts/, gitignored) via each
folder's **`EVIDENCE.md` manifest** (the vault holds TEXT only — the manifest is the index, not the vault):
- [ ] `EVIDENCE.md` manifest present per folder (front-matter source/slug/issue/doc/build/test + index table
  `| ID | File | TC | State | Type |`) — `find "$(dirname "$(dirname "$EVIDENCE_ROOT")")" -name EVIDENCE.md`
- [ ] every table row's `File` exists on disk; no file in the folder is missing from the table (untracked → /ow-evidence archives)
- [ ] Screenshots/logs ครบตาม test plan (under `test-artifacts/`, not the vault)
- [ ] PII masked ในไฟล์ evidence ที่ติด PII (ดู `/ow-evidence audit`)
- [ ] Console logs + network logs เก็บแล้ว
- [ ] Route source trace ระบุ
- [ ] Status taxonomy ถูก (PASS/FAIL/BLOCKED_*/NOT_RUN_RISK)

## Phase 4 — Vault consistency + Spec audit

```bash
# ตรวจ link ทุก [[...]] ใน docs ของ scope
# ตรวจ IMPLEMENTATION-STATUS update ($IMPL_STATUS)
# ตรวจ docs ใหม่ที่ควรเพิ่ม (function spec ของ feature ใหม่)
```

ถ้าเจอ inconsistency → list ให้ user → เสนอ `/ow-doc` แก้

**Spec audit (ถ้า scope มี FR):**
- FR ทุกข้อที่ implement ใน scope นี้มี task ID มัดอยู่ไหม?
- คำศัพท์ consistent กับ PRD ไหม? (เช่น "member" vs "patron")
- เจอ orphan FR → flag warn; ไม่ block แต่ระบุใน output

## Phase 5 — Security pre-flight

เรียก /ow-secure logic — ตรวจ secrets, PII, masking, public-repo, prod guardrails

ถ้าผลเป็น BLOCKED → STOP verify, user ต้องแก้ก่อน

## Phase 6 — Design system audit (ถ้ามี frontend/mobile)

ถ้า `$DS_DIR` มีอยู่ + scope กระทบ UI:
- เรียก /ow-design audit logic
- ตรวจ component compliance, contrast, focus state
- Report violations

## Phase 7 — สรุปผลและขั้นตอนต่อไป

แสดงผลรวม (verify report ใน chat):
- ✅ / ❌ แต่ละ Phase (test, evidence, vault, security, DS)
- รายการที่ยังไม่ผ่าน (ถ้ามี) + วิธีแก้
- ขั้นตอนต่อไป: `→ /ow-handoff <path>` เพื่อสร้าง session handoff note (สรุปงานส่งต่อ session ถัดไป)

## Output (3 หัวข้อบังคับ)

1. **Result** — verify report: ✅/❌ ต่อ Phase (test, evidence, vault, security, DS) + scope ที่ตรวจ
2. **Verification / Evidence** — ทุก test/lint/build command ที่รันจริง พร้อมผล + paths ของ evidence/manifest ที่ audit; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — รายการที่ยังไม่ผ่าน + วิธีแก้ + `→ /ow-handoff` สำหรับ session note

## ห้าม

- ห้าม verify ที่ test ไม่ผ่าน — STOP, แจ้ง user
- ห้าม fake evidence
- ห้ามสร้าง handoff note ใน command นี้ — ใช้ `/ow-handoff` แยก
