---
description: Batch-triage GitHub bug issues — classify + label + comment + propose clusters (read-only on code, confirmation gate before touching GitHub)
---

# /ow-triage-issues — GitHub Bug Triage Bot

Batch-triage GitHub issues ที่ติด label `bug` → classify + label + comment + propose cluster (ไม่แก้โค้ด, ไม่เปิด fix-log)

> **กฎหลัก:** `/ow-triage-issues` = **read + label + comment เท่านั้น** ห้ามแก้โค้ด ห้ามเปิด fix-log ห้ามปิด issue เอง (เว้นแต่ class ที่ระบุไว้ว่าให้ปิด)
>
> Triage เป็นขั้น **ก่อน** `/ow-fix-issue` — แยก real-bug ที่พร้อมแก้ออกจาก question/need-info/wontfix/not-implement-yet เพื่อให้ `/ow-fix-issue` หยิบเฉพาะตัวที่ confirm แล้วไปทำ

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

## Prerequisite

- `gh` CLI authenticated (`gh auth status`)
- อยู่ใน git repo ที่ผูกกับ GitHub remote
- subagent `gh-issue` enabled ใน `.ow.yml` `subagents:` (default on — ดู `/ow-init` Phase 5)

## Trigger

```
/ow-triage-issues                    # triage ทุก bug ที่ยังไม่มี triage/fix label
/ow-triage-issues #62 #63 #64        # triage เฉพาะ issue ที่ระบุ
/ow-triage-issues --dry-run          # classify + รายงาน แต่ไม่ label/comment ของจริง
/ow-triage-issues --no-cluster       # ข้าม cluster detection (pass 1 เท่านั้น)
```

Default repo จาก `gh repo view --json nameWithOwner -q .nameWithOwner` (ต้องอยู่ใน git repo)

---

## Phase 0 — Pre-flight

### 0.1 Check gh CLI + repo
```bash
gh auth status || { echo "Run 'gh auth login' first"; exit 1; }
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repo: $REPO"
```

### 0.2 Resolve label set (config-aware)

Triage ใช้ label เพื่อ classify การจัดการ ค่า default (เปลี่ยนได้ใน `.ow.yml` `triage.labels.*`):

| Purpose | Default label |
|---|---|
| bug (real, pending fix) | `bug` |
| not-a-bug / how-to | `question` |
| needs more info | `need info` |
| feature / spec pending | `not implement yet` |
| by-design / out-of-scope / dup | `wontfix` |
| in progress (set by fix-issue) | `in progress` |
| ready for tester | `ready for test` |
| cluster marker | `cluster` |

ต้องการ label ใหม่ตัวเดียว = `cluster` ถ้ายังไม่มี → สร้าง:
```bash
gh label list --search cluster --json name -q '.[].name' | grep -qx cluster || \
  gh label create cluster --color "fbca04" --description "Issue grouped with related issues (see comment)"
```

ถ้า project ใช้ label ชื่ออื่น (เช่นภาษาอื่น / scheme ต่าง) → อ่านจาก `.ow.yml`:
```yaml
# optional override
triage:
  labels:
    bug: "bug"
    question: "question"
    need_info: "need info"
    not_implement: "not implement yet"
    wontfix: "wontfix"
    in_progress: "in progress"
    ready_for_test: "ready for test"
    cluster: "cluster"
```

---

## Phase 1 — Fetch Pool

### 1.1 Default pool (no args) — **ของเก่าก่อน (oldest first)**
```bash
# capture เข้าตัวแปรครั้งเดียว — นี่คือ snapshot ดิบที่จะ freeze ใน 1.3
POOL_JSON=$(gh issue list \
  --label bug \
  --search "is:open sort:created-asc \
            -label:question -label:\"need info\" \
            -label:\"not implement yet\" -label:wontfix \
            -label:\"in progress\" -label:\"ready for test\"" \
  --limit 50 \
  --json number,title,labels,author,body,url,createdAt)
```

แปล: **open bugs ที่ยังไม่มี triage/fix label ใด ๆ — เรียงจากเก่าสุดไปใหม่สุด**

🔴 **`sort:created-asc` บังคับ** — เพราะ:
1. Issue เก่ารอนานกว่า → priority สูงกว่า (ไม่ปล่อยค้าง)
2. Issue เก่าอาจเป็น root cause ของ issue ใหม่ → triage ก่อนช่วย dedupe issue ใหม่ได้
3. Cluster detection (Phase 3) ทำได้ดีขึ้น — เก่ากว่ามักเป็น "ตัวแม่" ของ cluster

### 1.2 Explicit pool (args เป็นเลข issue)
ถ้า `$ARGUMENTS` มีเลข issue → ดึงเฉพาะตัวเหล่านั้นด้วย `gh issue view <N> --json ...` รวมเป็น `POOL_JSON` (array) + เรียงตาม `createdAt` asc ก่อน process — explicit pool คือ snapshot อยู่แล้ว (ผู้ใช้ระบุชัด ไม่ขยายเอง)

### 1.3 🧊 Freeze snapshot — **ดึง pool ครั้งเดียว แล้ว lock**

🔴 **Pool ถูก snapshot ที่นี่ครั้งเดียวเท่านั้น** — เก็บรายการ issue number ที่ได้จาก 1.1/1.2 ลงเป็น **frozen ordered list** (เช่น `POOL=[55, 56, 67, 71, 74]`) แล้วใช้ลิสต์นี้ตลอด run

```bash
# capture ครั้งเดียว — ทุก phase ถัดไปอ้างจากตัวแปรนี้ ห้าม re-query
POOL=$(echo "$POOL_JSON" | jq -r 'sort_by(.createdAt) | .[].number')
echo "🧊 Frozen pool ($(echo "$POOL" | wc -w | tr -d ' ') issues): $POOL"
```

🔴 **หลัง 1.3 ห้ามรัน `gh issue list` อีกในทั้ง run** — ทั้ง batching (Phase 2) และ apply (Phase 5) ต้อง **slice จาก `POOL` ที่ freeze ไว้** เท่านั้น

🔴 **Issue ที่เข้ามา / ถูกแก้ label หลัง snapshot = OUT OF SCOPE ของ run นี้** — แม้จะ match filter `bug` ก็ห้ามดึงเข้ามากลางทาง ผู้ใช้รัน `/ow-triage-issues` รอบใหม่เพื่อเก็บตัวที่เพิ่งเข้ามา (snapshot ใหม่)

> **เหตุผล:** triage เป็นงาน batch ที่ต้อง deterministic — preview (Phase 4) ต้องตรงกับสิ่งที่ apply (Phase 5) เป๊ะ ถ้า pool ขยายกลางทาง preview จะ stale + user อนุมัติ set หนึ่งแต่ apply อีก set หนึ่ง (ผิด confirmation-gate contract)

### 1.4 รายงาน pool ก่อนเริ่ม
แสดง user (เรียงเก่า → ใหม่, จาก frozen `POOL`):
```
🔍 Pool ที่จะ triage: N issues (เก่าสุดก่อน, snapshot @ <เวลา>)
  #55 — [BUG] <title> (2026-05-27)
  #56 — [BUG] <title> (2026-05-27)
  ...
  #74 — [BUG] <title> (2026-05-28, ใหม่สุด)

แบ่งเป็น batch ละ ≤ 7 (ลด rate limit + readable output)
รวม ⌈N / 7⌉ batches — process ตามลำดับ (เก่าก่อน) จาก frozen pool
```

ถ้า pool > 20 → confirm กับ user ก่อนเริ่ม

---

## Phase 2 — Parallel Triage (batch ละ ≤ 7)

🔴 **Batch ทั้งหมด slice มาจาก frozen `POOL` (Phase 1.3) เท่านั้น** — `batches = chunk(POOL, 7)` ห้ามรัน `gh issue list` ใหม่เพื่อหา "batch ถัดไป" loop วนจนครบ `POOL` แล้วจบ ไม่ว่าจะมี issue ใหม่เข้ามากี่ตัวระหว่างทาง

### 2.1 Fan out per issue (parallel)

สำหรับแต่ละ issue ใน batch → ส่ง `gh-issue` agent **ใน 1 message** (max 7 parallel) ให้:
- Fetch full content + images
- Return structured analysis

Prompt ที่ส่ง gh-issue agent:
```
Read issue #<NN> from repo <owner>/<repo>.
Return summary + all image observations.
DO NOT modify the issue (you are read-only).
```

### 2.2 Classify (Claude อ่าน agent output แล้ว decide)

สำหรับแต่ละ issue → classify ด้วย rule sheet นี้:

| Class | เกณฑ์ | Label action | Comment? | Close? |
|---|---|---|---|---|
| **real-bug** | reproduce ได้ + system ทำงานผิดจาก spec | คง `bug` (no change) | optional summary | no |
| **not-a-bug (question)** | user เข้าใจผิด / asking how-to / spec ถูกแล้ว | + `question`, ลบ `bug` | ✅ อธิบายเหตุผล | ✅ |
| **needs-info** | repro ไม่พอ / ขาด screenshot / version ไม่ชัด | + `need info` | ✅ ถาม specific field ที่ขาด | no |
| **not-implement-yet** | ต้องการ feature ใหม่ / spec ยังไม่มา | + `not implement yet`, ลบ `bug` | ✅ ระบุว่ารอ spec อะไร | no |
| **duplicate** | ซ้ำกับ issue เก่า (open หรือ closed) | + `wontfix` | ✅ link issue ต้นฉบับ | ✅ |
| **wontfix** | by design / out of scope / cost > benefit | + `wontfix` | ✅ อธิบายเหตุผล | ✅ |

> **Conservative rule:** ถ้า class ไม่ชัด → default `needs-info` ปลอดภัยสุด ห้าม guess

### 2.3 Plan only — **ห้าม apply ที่นี่**

🔴 Phase 2 = classify + plan **เก็บใน memory เท่านั้น** ห้ามเรียก `gh issue edit/comment/close` ของจริง

ต่อแต่ละ issue เก็บ struct:
```yaml
- nn: 62
  title: "..."
  class: real-bug
  add_labels: []                  # real-bug = ไม่เพิ่ม label
  remove_labels: []
  close: false
  comment: null                   # real-bug = ไม่ comment (no-comment rule, Phase 4.2)
  reasoning: "เป็น UI bug แสดงปุ่มผิด, reproduce ชัด, มี screenshot"

- nn: 73
  title: "..."
  class: wontfix
  add_labels: [wontfix]
  remove_labels: []
  close: true
  comment: |
    **Triage:** wontfix
    <เหตุผลภาษาไทย 1-3 ประโยค>
    — Triaged by `/ow-triage-issues`
  reasoning: "ปัญหานี้เกิดจาก design intent ที่ตั้งใจ — ฯลฯ"
```

Plan แสดงครบใน Phase 4 ให้ user review **ก่อน apply**

---

## Phase 3 — Cluster Detection (plan only, skip ถ้า --no-cluster)

หลัง classify ครบทุก issue → **เฉพาะ class `real-bug`** → คิด cluster + เก็บใน plan struct (ห้าม comment GitHub ที่นี่)

### 3.1 Heuristic
- **Surface overlap:** issue body พูดถึงหน้า/component เดียวกัน (e.g., หน้าลงทะเบียน, dropdown, profile upload)
- **Root cause guess:** error pattern คล้ายกัน (e.g., "Dropdown ซ้ำ" หลาย issue = อาจมา master-data resolver ตัวเดียว)
- **Files touched:** จาก guess submodule + component → ถ้าทับซ้อน likely cluster

### 3.2 เก็บ cluster ลง plan struct (ห้าม apply)
สำหรับแต่ละ issue ใน cluster → เพิ่ม `cluster_comment` field ที่จะ post ตอน Phase 5:

```yaml
- nn: 62
  class: real-bug
  cluster_slug: register-form
  cluster_members: [62, 63, 64, 65, 66, 69]
  cluster_comment: |
    **Cluster proposal:** อาจรวมแก้กับ #63, #64, #65, #66, #69
    **เหตุผล:** หน้าลงทะเบียน form เดียวกัน
    **ถัดไป:** ถ้าเห็นด้วยติด label `cluster` ด้วยมือ → `/ow-fix-issue #62 #63 #64 #65 #66 #69`
    — Proposed by `/ow-triage-issues`
```

🔴 **ห้าม `gh issue comment` ใน Phase 3** — เก็บไว้ apply พร้อมกับ Phase 5 หลัง user yes

🔴 **ไม่ติด `cluster` label เอง** — user ตัดสิน (manual gate)

---

## Phase 4 — Preview + Confirmation Gate (🔴 บังคับก่อน apply)

แสดง plan ทั้งหมดต่อ user **ก่อนแตะ GitHub** ใน 3 sections — แล้ว **STOP + ถาม** ก่อน Phase 5

### 4.1 Full classification table (ทุก issue ที่ process)

```
✅ Triage Complete — N issues processed

| #                                          | Title (truncated)    | Class            | Action                  |
|--------------------------------------------|----------------------|------------------|-------------------------|
| [#74](https://github.com/<REPO>/issues/74) | <title>              | real-bug         | kept `bug` (no comment) |
| [#73](https://github.com/<REPO>/issues/73) | <title>              | wontfix          | + wontfix, closed       |
| [#72](https://github.com/<REPO>/issues/72) | <title>              | real-bug         | kept `bug` (no comment) |
| [#71](https://github.com/<REPO>/issues/71) | <title>              | real-bug         | kept `bug` (cluster ⇄ [#63](https://github.com/<REPO>/issues/63)) |
| [#67](https://github.com/<REPO>/issues/67) | <title>              | not-implement-yet| + not implement yet (comment) |
```

🔴 **column "Action" ต้องระบุ "(no comment)" สำหรับ real-bug ทุกตัว** — เพื่อ user เห็นชัดว่า command ตั้งใจไม่ comment (ไม่ใช่ skipped/lost)

### 4.2 🎯 Ready to fix (real-bugs) — **section นี้คือ pool สำหรับ `/ow-fix-issue`**

```
🎯 Ready to fix — N real-bugs (กดเลขเปิด issue / copy คำสั่งด้านล่างได้)

Standalone:
  [#74](https://github.com/<REPO>/issues/74) — <title> (mobile, P2)
  [#72](https://github.com/<REPO>/issues/72) — <title> (web, P0 data loss)

Cluster A — Register form (web):
  [#62](https://github.com/<REPO>/issues/62) [#63](https://github.com/<REPO>/issues/63) [#64](https://github.com/<REPO>/issues/64) [#65](https://github.com/<REPO>/issues/65) [#66](https://github.com/<REPO>/issues/66) [#69](https://github.com/<REPO>/issues/69)

Suggested commands:
  /ow-fix-issue #74                                  # standalone (mobile)
  /ow-fix-issue #72                                  # standalone (web, P0 first)
  /ow-fix-issue #62 #63 #64 #65 #66 #69              # Cluster A (web)
```

🔴 **section นี้รวม real-bug ทั้งหมด — ไม่ว่าจะ comment หรือไม่ comment** Real-bug "no comment" = "ไม่มีอะไรต้องเพิ่ม, ready to fix" = ต้องอยู่ใน list นี้เสมอ

### 4.3 Handled (closed by triage) — informational only

```
✅ Handled by triage — N closed/parked:
  [#73](https://github.com/<REPO>/issues/73) — wontfix (closed)
  [#67](https://github.com/<REPO>/issues/67) — not implement yet (waiting for spec)
```

🔴 **`<REPO>` ใน template = `$REPO` literal** จาก Phase 0.1 — replace ก่อน render ห้ามปล่อย placeholder

🔴 **ทุกเลข issue ใน output ของทุก section** → wrap markdown link เสมอ

🔴 **Real-bug selection rule:** การ "ไม่ comment" บน issue **ไม่ใช่** signal ว่า "skip / not actionable" — เป็น signal ว่า "real-bug, nothing to add, ready to fix" Section 4.2 ต้อง include ทุกตัวที่ class = `real-bug`

### 4.4 🛑 Confirmation Gate (บังคับ — STOP + ask user)

หลังแสดง 4.1-4.3 ครบ → **STOP** + ถาม:

```
─────────────────────────────────────────────
🔍 ด้านบนคือ plan ก่อน apply (ยังไม่แตะ GitHub)

จะให้ apply ทั้งหมดเลยมั้ย?
- "yes" / "y" / "ok"   → apply ทั้ง batch (label + comment + close ตาม plan + cluster comments)
- "no" / "n" / "cancel" → ยกเลิก ไม่แตะ GitHub
- "skip #NN #MM ..."    → apply ทุกตัวยกเว้นเลขที่ระบุ
- "เปลี่ยน #NN เป็น <class>" → reclassify แล้ว re-show preview + ถามใหม่
─────────────────────────────────────────────
```

🔴 **ห้าม apply จนกว่า user จะตอบ yes/skip explicit** — ถ้า user ตอบไม่ชัด ถามซ้ำ ห้ามเดา

🔴 **`--dry-run` flag = ข้าม Phase 5 ทั้งหมด** — แสดง preview แล้วจบ ไม่ถาม gate (ใช้เมื่อ user แค่อยาก inspect plan)

---

## Phase 5 — Apply Approved Changes (หลัง user yes)

วิ่งเฉพาะเมื่อ user ตอบ `yes` (หรือ `skip #...` ที่ exclude บางตัว)

### 5.1 Per-issue apply (parallel-safe, batch ≤ 7)

สำหรับแต่ละ issue ใน approved list:

```bash
NN=<from plan>
# 1. Apply labels (add ก่อน remove)
[ -n "<add_labels>" ]    && gh issue edit "$NN" --add-label "<add_labels>"
[ -n "<remove_labels>" ] && gh issue edit "$NN" --remove-label "<remove_labels>"

# 2. Post classification comment (ถ้า plan มี)
[ -n "<comment>" ]         && gh issue comment "$NN" --body "<comment>"

# 3. Post cluster proposal comment (ถ้า plan มี)
[ -n "<cluster_comment>" ] && gh issue comment "$NN" --body "<cluster_comment>"

# 4. Close if plan.close = true
[ "<close>" = "true" ]     && gh issue close "$NN"
```

🔴 **Order สำคัญ:** label ก่อน comment — เพื่อให้ comment ติดอยู่ใน issue หลัง class ใหม่แล้ว

### 5.2 Report apply result

แสดง user:
```
✅ Applied N/M issues
  ✅ #62 — labels updated, cluster comment posted
  ✅ #73 — wontfix label + comment + closed
  ✅ #67 — not implement yet label + comment
  ⚠️ #74 — failed: <gh error>  → user retry เอง
  ⏭️ #71 — skipped (per user request)
```

---

## Rules

- 🔴 **Read-only mode สำหรับ code** — ห้ามแก้ไฟล์ใน repo เลย แม้จะ "ตรวจ root cause"
- 🔴 **Triage ไม่เก็บ evidence** (read-only ต่อ filesystem) — evidence trail เริ่มที่ `/ow-fix` / `/ow-fix-issue`,
  **1 folder ต่อ task** (`fix-<NN>-<slug>/`) ที่ implement+test reuse ตลอด flow; triage แค่ส่ง real-bug ต่อให้ `/ow-fix-issue`
- 🔴 **Frozen pool** — `gh issue list` รันได้ครั้งเดียว (Phase 1.1) snapshot เข้า `POOL` (Phase 1.3) ทุก batch/apply วนจาก `POOL` เท่านั้น ห้าม re-query กลางทาง issue ที่เข้ามาหลัง snapshot = out-of-scope (เก็บใน run ถัดไป)
- 🔴 **Confirmation gate บังคับ** — Phase 2/3 = plan only (in-memory) — Phase 5 = apply หลัง user yes เท่านั้น
- 🔴 **ห้าม `gh issue edit/comment/close` ใน Phase 2/3** — ทุก write ไปอยู่ Phase 5
- 🔴 **`cluster` label ติดด้วย user เท่านั้น** — command แค่ post cluster proposal comment ใน Phase 5
- 🔴 **--dry-run บังคับเมื่อ user สั่ง** — preview จบ ไม่ถาม gate ไม่ apply
- **Batch ≤ 7 parallel agents** ใน Phase 2 (classify) — กัน rate limit + อ่าน output ทัน
- **Batch ≤ 7 parallel `gh` calls** ใน Phase 5 (apply) — เหตุผลเดียวกัน
- **Conservative classification:** ไม่ชัด = `need info` (ห้าม guess real/not-bug)
- **Comment ภาษาไทย** (ตาม `.ow.yml` `project.language` — default th; ถ้า `en` → comment อังกฤษ)
- **ลงท้าย comment ด้วย `— Triaged by /ow-triage-issues`** เพื่อ audit
- **ไม่แตะ issue ที่มี triage/fix label อยู่แล้ว** (filter ใน Phase 1 ทำให้แล้ว แต่ double-check)
- **ไม่แตะ issue ที่ไม่มี label `bug`** — เช่น `enhancement`, `documentation` ไม่ใช่ scope
- **ไม่ทำ implementation suggestion ใน comment** — แค่ classify + เหตุผล (`/ow-fix-issue` จะคิด how ทีหลัง)
- **ห้ามแต่ง issue content / label / comment ที่ไม่ได้ post จริง** — no-fake-evidence policy

## Output (3 หัวข้อบังคับ)

1. **Result** — classification table (4.1) + ready-to-fix list (4.2) + apply result `N/M` (5.2 — ถ้า user อนุมัติ)
2. **Verification / Evidence** — `gh issue list/view/edit/comment/close` ที่รันจริง (พร้อมผลลัพธ์) + issue URLs ที่แก้จริง + label state ก่อน/หลัง; `--dry-run`/ยังไม่ apply = `not run — preview only`
3. **Limitations / Next steps** — issue ที่ classify ไม่ชัด (default need-info), cluster ที่ user ยังไม่ confirm, "ต่อด้วย `/ow-fix-issue` กับ real-bug ใน section 4.2"

## ห้าม

- ห้ามแก้โค้ดหรือไฟล์ใด ๆ ใน repo — triage = read-only ต่อ code
- ห้าม re-run `gh issue list` หลัง Phase 1.3 — pool ถูก freeze แล้ว ห้ามดูด issue ใหม่เข้ามากลาง loop (preview ต้องตรงกับ apply เป๊ะ)
- ห้าม `gh issue edit/comment/close` ก่อนผ่าน confirmation gate (Phase 4.4) — Phase 2/3 = plan in-memory เท่านั้น
- ห้าม apply จนกว่า user ตอบ yes/skip explicit — ตอบไม่ชัด = ถามซ้ำ ห้ามเดา
- ห้ามติด `cluster` label เอง — เสนอผ่าน comment ให้ user ติดเอง
- ห้าม guess class ที่ไม่ชัด — default `need info` (conservative)
- ห้ามแต่ง issue content / label / comment ที่ไม่ได้ post จริง (no-fake-evidence)
- ห้ามเปิด fix-log หรือเริ่มแก้บั๊กใน triage — นั่นคืองานของ `/ow-fix-issue`
