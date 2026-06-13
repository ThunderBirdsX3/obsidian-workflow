# Usage Guide — obsidian-workflow

คู่มือการใช้งานฉบับเต็ม: ทุก command (22 ตัว), workflow ที่พบบ่อย, กติกาที่บังคับใช้
และวิธีปรับแต่ง — สำหรับการเริ่มต้นครั้งแรกดู [GETTING-STARTED.md](GETTING-STARTED.md)

> ใน Claude Code พิมพ์ `/ow-help` ได้เสมอ — interactive help ที่แนะนำ command ตามสถานการณ์

---

## 1. ภาพรวม lifecycle

ทุกงานวิ่งผ่าน pipeline เดียวกัน: **spec → plan → implement → verify → ship**

```
                    ┌── /ow-reverse-engineer (มี code อยู่แล้ว ไม่มี spec)
                    ▼
   /ow-new ──► PRD + SRS + Tech spec          ← spec คือ contract
                    │
   /ow-clarify ◄────┤  (สแกน ambiguity)
   /ow-checklist ◄──┘  (spec-quality gate)
                    ▼
   /ow-plan ──► plan file ใน 80-ImplementPlan/   ← ไม่แตะโค้ด
                    │
          [user review → status: approved]        ← gate โดยมนุษย์
                    ▼
   /ow-implement ──► โค้ด + evidence              ← ตัวเดียวที่แก้โค้ด
                    ▼
   /ow-test → /ow-review → /ow-secure → /ow-verify
                    ▼
   /ow-git ──► commit + push    /ow-release ──► changelog + tag + bump
```

หลักที่บังคับทุกขั้น:

| หลัก | ความหมาย |
|---|---|
| **Vault-first** | อ่าน vault ก่อนถาม user หรือเขียนโค้ด เสมอ |
| **SRS คือ contract** | ทุก FR มี acceptance Given/When/Then — งานไม่มี spec รองรับ → เขียน spec ก่อน |
| **Plan ≠ Implement** | `/ow-plan` เขียนแผนอย่างเดียว; `/ow-implement` เท่านั้นที่แก้โค้ด; `/ow-fix` แค่ diagnose |
| **No fake evidence** | test count / commit hash / URL ต้องมาจากการรันจริง — ไม่มี = `pending evidence` |

---

## 2. Command reference

### 2.1 ช่วยเหลือ + ตั้งค่า

#### `/ow-help` — interactive help

```
/ow-help                          # interactive — ถามว่าอยากทำอะไร
/ow-help <command>                # อธิบาย command ตัวนั้นเชิงลึก
/ow-help workflow                 # แสดง workflows ที่พบบ่อย
/ow-help workflow <name>          # new-project | bug-fix | github-issue | design
/ow-help search <keyword>         # ค้น command/concept เช่น "evidence", "worktree"
/ow-help cheatsheet               # 1-page cheatsheet
/ow-help tree                     # decision tree "ถ้า X → ใช้ Y"
```

ใช้เมื่อ: ไม่รู้จะเริ่มตัวไหน หรืออยากรู้ option ของ command ใดๆ

#### `/ow-init` — bootstrap project

```
/ow-init
/ow-init <project-name>
/ow-init --greenfield        # บังคับ mode โปรเจกต์ใหม่
/ow-init --brownfield        # บังคับ mode โปรเจกต์ที่มี code แล้ว
/ow-init --reconfigure       # แก้ config ของ project ที่ init แล้ว
```

ทำอะไร: สร้าง/ปรับ `.ow.yml` + vault skeleton + เปิด/ปิด subagents
ใช้เมื่อ: ครั้งแรกหลัง `bash install.sh` หรืออยากเปลี่ยน config ภายหลัง

---

### 2.2 สร้าง spec

#### `/ow-new` — PRD → SRS → Tech spec

```
/ow-new                              # brainstorm จากศูนย์
/ow-new <one-line description>       # เริ่มจากไอเดียบรรทัดเดียว
/ow-new --import <path-to-existing-prd>   # มี PRD แล้ว ต่อ SRS/Tech
```

ทำอะไร: สร้าง chain PRD (intent — ทำไม) → SRS (contract — ระบบทำอะไร แค่ไหน ตรวจยังไง)
→ Tech spec ลง `10-PRD/`
ใช้เมื่อ: เริ่ม project/feature ใหญ่ที่ยังไม่มี spec

#### `/ow-clarify` — สแกน ambiguity

```
/ow-clarify                          # scan SRS ล่าสุด (ไม่มี SRS → plan ล่าสุด)
/ow-clarify <path-to-doc>            # scan doc เฉพาะ (PRD/SRS/FEAT/plan)
/ow-clarify --feature <slug>         # scan ทุก doc ของ feature
/ow-clarify --max 3                  # จำกัดจำนวนคำถาม (default 5)
/ow-clarify --resume                 # ต่อ session ที่ค้าง
```

ทำอะไร: taxonomy scan หาจุดกำกวม → ถามทีละข้อพร้อมคำตอบแนะนำ → เขียน Clarifications log
กลับเข้า spec
ใช้เมื่อ: spec เขียนเสร็จใหม่ๆ หรือก่อน `/ow-plan` งานที่ spec ดูคลุมเครือ

#### `/ow-checklist` — spec-quality gate

```
/ow-checklist                        # interactive — ถาม domain
/ow-checklist <domain>               # generate checklist ใหม่
/ow-checklist <domain> --append      # เพิ่ม items ลง checklist เดิม
/ow-checklist review <path>          # ตรวจ checklist ที่ user ตอบแล้ว
/ow-checklist list                   # แสดง checklists ทั้งหมด
```

ทำอะไร: สร้าง "unit tests for English" — คำถามตรวจคุณภาพ spec ต่อ domain ก่อนลงมือ
ใช้เมื่อ: spec สำคัญ/เสี่ยงสูง อยากตรวจความครบก่อน implement

#### `/ow-doc` — เขียน/แก้ vault doc

```
/ow-doc                              # interactive — ถาม type
/ow-doc <type> <name>                # เช่น /ow-doc SRS CheckoutFlow
/ow-doc --edit <path>                # แก้ไฟล์ที่มีอยู่
/ow-doc --review <path>              # review only ไม่แก้
```

ทำอะไร: สร้าง/แก้เอกสารตาม template — PRD, SRS, Tech, ADR, Feature (FEAT), Function (FN),
Role, Postmortem (PM), Runbook
ใช้เมื่อ: ต้องการ doc เดี่ยวๆ นอก flow ของ `/ow-new`

#### `/ow-reverse-engineer` — extract spec จาก code

```
/ow-reverse-engineer                        # scan ทั้ง project
/ow-reverse-engineer --area api             # เฉพาะ API/routes
/ow-reverse-engineer --area ui              # เฉพาะ UI components/screens
/ow-reverse-engineer --area models          # เฉพาะ domain models/schemas
/ow-reverse-engineer --area all             # ครบทุกมิติ (default)
/ow-reverse-engineer --depth shallow        # โครงสร้างอย่างเดียว (เร็ว)
/ow-reverse-engineer --depth deep           # อ่านเนื้อหาไฟล์จริง (ละเอียด)
```

ทำอะไร: อ่านโค้ดที่มีอยู่ → สร้าง TechStack, API doc, FEAT/FN docs + SRS skeleton (draft)
ใช้เมื่อ: brownfield — มี code อยู่แล้วแต่ไม่มี spec; รันหลัง `/ow-init --brownfield`

---

### 2.3 วางแผน + ลงมือ

#### `/ow-plan` — สร้าง implementation plan (ไม่แตะโค้ด)

```
/ow-plan <task description>
/ow-plan <task> --worktree           # opt-in: implement+test ใน git worktree แยก + auto-merge ตอน test PASS
/ow-plan fix:<slug>                  # plan ที่ escalate จาก fix-log — ผูก link สองทาง
/ow-plan --from-fix <path>           # เหมือน fix: แต่ระบุ path เต็มของ fix-log
/ow-plan <task> --revise <plan-path> # แก้ plan เดิม
```

ทำอะไร: research vault → สร้าง plan file `80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md`
ผูก FR-### + ผ่าน policy check gate — **ไม่แก้โค้ดเด็ดขาด**
ผลลัพธ์: plan ที่ `status: draft` → **user ต้อง review แล้ว set `status: approved` เอง**
ก่อน `/ow-implement` จะยอมรัน

#### `/ow-implement` — ลงมือตาม plan (ตัวเดียวที่แก้โค้ด)

```
/ow-implement <plan-path>            # 80-ImplementPlan/YYYY-MM-DD-HHmm-<slug>.md
/ow-implement <slug>                 # auto-locate by slug
/ow-implement <plan> --worktree      # บังคับ build ใน git worktree แยก
/ow-implement <plan> --no-worktree   # บังคับ build ใน main tree
/ow-implement --from-fix <fix-log-path>   # P3 polish เท่านั้น — ข้าม plan, ปิด fix-log เองตอน done
```

ทำอะไร: execute plan ที่ approved ผ่าน specialized subagent (backend/frontend/mobile/docs)
→ เก็บ evidence → sync vault status
Gate: plan ต้อง `status: approved`; เรียกเปล่า → list 5 plans ล่าสุดที่ approved ให้เลือก
หมายเหตุ: `--from-fix` เป็น escape hatch สำหรับงานจิ๋ว (P3 polish) เท่านั้น —
บั๊กใหญ่กว่านั้นต้องผ่าน `/ow-plan fix:<slug>` เสมอ

---

### 2.4 แก้บั๊ก

#### `/ow-fix` — diagnose (ไม่แก้โค้ด)

```
/ow-fix <bug description>
/ow-fix <bug> --update <fix-log-path>   # เติมข้อมูลลง fix-log เดิม
```

ทำอะไร: diagnose root cause → capture **before evidence** (พิสูจน์ RED) →
สร้าง fix-log `85-FixLog/YYYY-MM-DD-HHMM-<slug>.md` พร้อม Reproduction, Root Cause,
Fix Approach, Test Cases — **ไม่แตะโค้ด**
งานต่อ: บั๊กเล็ก → `/ow-implement --from-fix <log>`; บั๊กใหญ่ → `/ow-plan fix:<slug>` ก่อน

#### `/ow-triage-issues` — batch-triage GitHub bugs

```
/ow-triage-issues                    # triage ทุก bug ที่ยังไม่มี triage/fix label
/ow-triage-issues #62 #63 #64        # เฉพาะ issue ที่ระบุ
/ow-triage-issues --dry-run          # classify + รายงาน ไม่ label/comment จริง
/ow-triage-issues --no-cluster       # ข้าม cluster detection
```

ทำอะไร: classify + label + comment + เสนอ cluster ของ issue ที่น่าจะแก้ด้วยกัน —
**read-only ต่อโค้ด, มี confirmation gate ก่อนแตะ GitHub**
ต้องมี: `gh` CLI + อยู่ใน git repo ที่มี remote

#### `/ow-fix-issue` — แก้ GitHub bug end-to-end

```
/ow-fix-issue                        # 🌟 DEFAULT — auto-discover real-bugs + per-group approval + parallel execute
/ow-fix-issue --dry-run              # แสดง plan แล้วจบ
/ow-fix-issue #62                    # 1 issue → 1 worktree, 1 agent
/ow-fix-issue #62 #63 #64            # 1 group — 1 worktree, agent เดียวปิดทั้งชุด
/ow-fix-issue #62 --diagnose-only    # หยุดที่ fix-log + before evidence
/ow-fix-issue #62 --submodule web    # บังคับ submodule ถ้า detect ไม่ออก
```

ทำอะไร: spin worktree แยกต่อ group → agent diagnose + fix + test + commit →
auto-merge เข้า base branch **เฉพาะ local — ไม่ push, ไม่ comment**
ลำดับเต็ม: `/ow-fix-issue #NN` → `/ow-test` → `/ow-git --bump patch`
(push + bump แล้ว `/ow-git` จะ comment version + flip label `ready for test` ให้เอง)

---

### 2.5 ทดสอบ + evidence + design

#### `/ow-test` — smoke test changed surface

```
/ow-test                    # auto-detect จาก git diff
/ow-test web                # บังคับ web
/ow-test app                # บังคับ mobile
/ow-test api                # บังคับ backend (unit + integration)
/ow-test <plan-file>        # ใช้ scope ของ plan
/ow-test <test-plan-file>   # systematic role-by-role test plan (TP-*.md)
/ow-test --since <ref>      # diff ตั้งแต่ ref (default HEAD)
/ow-test <plan> --no-merge      # worktree mode: test แต่ห้าม auto-merge
/ow-test <plan> --no-worktree   # บังคับ test ที่ main tree
```

ทำอะไร: detect scope จาก diff → spin servers เท่าที่จำเป็น → dispatch test-runner →
append evidence ลง EVIDENCE.md ของ task เดิม (1 folder ต่อ task — ไม่สร้าง folder ใหม่)
Worktree mode: test PASS → auto-merge กลับ base (non-destructive `--no-ff`, local)

#### `/ow-evidence` — finalize evidence

```
/ow-evidence                       # 🌟 DEFAULT — finalize ทุก manifest ของวันนี้
/ow-evidence --since <date>        # ตั้งแต่ <date>
/ow-evidence --slug <slug>         # เฉพาะ folder เดียว เช่น fix-94-login-dropdown
/ow-evidence --dry-run             # แสดงว่าจะ archive อะไร ไม่ทำจริง
/ow-evidence list                  # list manifest + สถานะ complete/incomplete
/ow-evidence verify                # ตรวจ manifest table vs filesystem
/ow-evidence audit                 # PII/secret scan ใน evidence
```

ทำอะไร: cleanup (archive ไฟล์นอก manifest) + verify ความครบ + PII audit —
evidence ทั้งหมดเป็น local-only ใต้ `test-artifacts/` (gitignored)

#### `/ow-design` — design system

```
/ow-design init                          # bootstrap DS ครั้งแรก (tokens + components + preview)
/ow-design tokens [add|edit]             # จัดการ design tokens
/ow-design component <name>              # เพิ่ม/แก้ component spec
/ow-design pattern <name>                # เพิ่ม pattern (composition)
/ow-design audit [path]                  # scan code หา DS drift
/ow-design preview                       # regenerate preview.html
/ow-design import-figma <export-path>    # import Figma export → DS-Tokens (contrast-gated)
```

ทำอะไร: ดูแล Design System ใน `70-Reference/DesignSystem/` — tokens, components, patterns,
WCAG 2.2 AA validation, preview.html

---

### 2.6 ส่งมอบ

#### `/ow-trace` — traceability matrix

```
/ow-trace                     # ทุก SRS ใน vault
/ow-trace <srs-slug>          # เฉพาะ SRS เดียว
/ow-trace --gaps              # เฉพาะ FR ที่ยังขาดอะไรสักอย่าง
/ow-trace --update            # เขียนผลกลับตาราง §10 Traceability ของ SRS
```

ทำอะไร: derive ว่า FR → FN → Plan → Test → Evidence ตัวไหนครบ ตัวไหนขาด
Default = report ใน chat อย่างเดียว ไม่แตะไฟล์
ใช้เมื่อ: อยากรู้สถานะจริงของ project ("FR ไหนทำแล้ว ขาดอะไร")

#### `/ow-review` — review diff เทียบ SRS

```
/ow-review <plan-path>            # review งานของ plan — FR scope จาก ## FR Coverage
/ow-review --since <ref>          # review ทุกอย่างใน diff range
/ow-review --staged               # เฉพาะ staged changes
/ow-review --fr FR-012 FR-013     # จำกัดเฉพาะ FR ที่ระบุ
/ow-review --quality-only         # ข้าม spec check — quality checklist อย่างเดียว
```

ทำอะไร: ตรวจ diff ว่า FR ครบตาม Given/When/Then ไหม + quality checklist —
**read-only ไม่แก้โค้ด**
ใช้เมื่อ: ก่อนปิดงาน/ก่อน commit งานใหญ่

#### `/ow-secure` — security pre-flight

```
/ow-secure                    # full scan
/ow-secure secrets            # scan secrets only
/ow-secure pii                # scan PII only
/ow-secure evidence           # check evidence masking
/ow-secure --since <ref>      # scan diff since ref
```

ทำอะไร: scan secrets (API keys, tokens), PII (เลขบัตร ปชช. ไทย + checksum, เบอร์โทร, อีเมล),
screenshot masking, public-repo + prod guardrails
ใช้เมื่อ: ก่อน commit/push/handoff เสมอ — โดยเฉพาะ repo public

#### `/ow-verify` — full verify

```
/ow-verify <plan-or-fix-path>      # ตรวจ specific work
/ow-verify --since <ref>           # ตรวจทุกอย่างใน diff range
/ow-verify --feature <name>        # ตรวจ feature scope
```

ทำอะไร: รวบยอด tests + evidence + vault sync + security + DS ใน pass เดียว —
ไม่สร้าง handoff note (นั่นงานของ `/ow-handoff`)
ใช้เมื่อ: ก่อนปิดงานใหญ่/ก่อน release

#### `/ow-git` — submodule-aware git ops

```
/ow-git --plan <plan-path>                # commit + push ตาม scope ของ plan
/ow-git --plan <plan-path> --bump patch   # + stamp fixed_in_version ลง fix-log ที่เกี่ยว
/ow-git --fix <fix-log-path>              # commit ตาม fix-log (prefix: fix:)
/ow-git --fix <fix-log-path> --bump patch # push+bump → auto comment version + flip label issue
/ow-git --message "feat: add search"      # commit ตรงๆ
/ow-git --branch <name>
/ow-git --status
/ow-git --pull
/ow-git --merge-to default
/ow-git --no-push                         # commit อย่างเดียว
/ow-git --fix <...> --bump patch --no-ready-for-test   # ไม่แตะ issue
```

ทำอะไร: commit/push/branch/merge ข้าม main repo + submodules ตาม scope จาก plan/fix —
`--bump` stamp version + แจ้ง issue ที่ `Closes #NN` อัตโนมัติ

#### `/ow-release` — ปล่อย version

```
/ow-release patch|minor|major        # full release: gate → changelog → /ow-git --bump
/ow-release --dry-run patch          # แสดง draft changelog + version — ไม่เขียน/ไม่ bump
/ow-release --notes-only             # เขียน CHANGELOG.md ของ tag เดิม — ไม่ bump
```

ทำอะไร: gate ด้วย before-release checklist → generate changelog จาก vault →
delegate bump/tag ให้ `/ow-git`
ไม่ระบุ kind → ถาม (SemVer hint: fix-only = patch, feature = minor, breaking = major)

#### `/ow-handoff` — session handoff

```
/ow-handoff                        # handoff งานของ session ปัจจุบัน
/ow-handoff <plan-or-fix-path>     # handoff งานจาก plan/fix ที่ระบุ
/ow-handoff --feature <name>       # handoff ทั้ง feature
/ow-handoff --since <ref>          # handoff ทุกอย่างใน diff range
```

ทำอะไร: สร้าง `95-Handoff/HANDOFF-*.md` — สรุปสิ่งที่ทำ/ค้าง/next step + อัปเดต status
ใช้เมื่อ: พักงานกลางคัน หรือจะต่อ session หน้า

---

## 3. Workflows ที่พบบ่อย

### 3.1 Project ใหม่ตั้งแต่ศูนย์ (greenfield)

```
1.  /ow-init                           ← config (vault location, subagents)
2.  /ow-new                            ← brainstorm → PRD + SRS + Tech spec
3.  /ow-clarify                        ← สแกน ambiguity ใน SRS (แนะนำ)
4.  /ow-design init                    ← (optional) bootstrap design system
5.  /ow-plan <feature>                 ← วางแผน feature แรก
6.  [user review plan → set status: approved]
7.  /ow-implement <plan-path>          ← ลงมือผ่าน subagent
8.  /ow-test                           ← smoke test
9.  /ow-secure                         ← pre-flight
10. /ow-verify                         ← ตรวจรวมก่อนปิด
11. /ow-git --plan <path>              ← commit + push
12. /ow-release minor                  ← (เมื่อพร้อมปล่อย)
```

### 3.2 มี code อยู่แล้ว ไม่มี spec (brownfield)

```
1. /ow-init --brownfield
2. /ow-reverse-engineer                ← extract TechStack/API/FEAT/FN + SRS draft
3. /ow-clarify                         ← เก็บจุดที่ AI เดาไม่ได้จาก code
4. [review SRS draft → ปรับให้ตรงความจริง]
5. ต่อด้วย flow ปกติ: /ow-plan → /ow-implement → ...
```

### 3.3 Feature ใหม่ใน project เดิม

```
1. /ow-plan <feature>                  ← (spec มีแล้ว; ถ้า FR ยังไม่มี → /ow-doc หรือ /ow-new ก่อน)
2. [review → status: approved]
3. /ow-implement <plan>
4. /ow-test
5. /ow-review <plan>                   ← ตรวจเทียบ SRS ก่อนปิด
6. /ow-git --plan <plan>
```

แยก branch ปลอดภัย: เพิ่ม `--worktree` ตอน `/ow-plan` —
implement+test จะทำใน git worktree แยก แล้ว auto-merge เมื่อ test PASS

### 3.4 แก้บั๊ก (พร้อม evidence red→green)

```
1. /ow-fix "search ค้างเมื่อใส่ขีดล่าง"   ← diagnose + fix-log + before evidence (no code)
2a. บั๊กเล็ก (P3): /ow-implement --from-fix <fix-log>
2b. บั๊กใหญ่:      /ow-plan fix:<slug> → [approve] → /ow-implement <plan>
3. /ow-test --since <sha>                ← verify fix (after evidence)
4. /ow-git --fix <fix-log-path>          ← commit (prefix: fix:)
```

### 3.5 GitHub issues (triage → fix → release)

```
1. /ow-triage-issues                   ← classify + label + เสนอ cluster (confirm ก่อนแตะ GitHub)
2. /ow-fix-issue                       ← auto-discover + parallel worktree agents (merge local, ไม่ push)
   หรือ /ow-fix-issue #62 #63          ← ระบุ group เอง
3. /ow-test --since <ref>              ← smoke เฉพาะ area ที่แตะ
4. /ow-git --bump patch                ← push + bump → auto comment "fixed in vX.Y.Z" + flip label
5. [verify บน version ใหม่] → close issue
```

### 3.6 พัก/ส่งต่องาน

```
/ow-handoff                            ← สร้าง HANDOFF note
# session หน้า: เปิด project → Claude อ่าน 95-Handoff/ ล่าสุด → ทำต่อ
```

---

## 4. กติกาที่บังคับใช้ (ทุก command)

### Output 3 หัวข้อบังคับ

ทุก command จบด้วย:

1. **Result** — สรุปสิ่งที่ทำ + ไฟล์ที่สร้าง/แก้
2. **Verification / Evidence** — command ที่รันจริง + ผลลัพธ์; ไม่ได้รัน = `pending evidence`
3. **Limitations / Next steps** — ข้อจำกัด ความเสี่ยง งานต่อ

### Gates สำคัญ

| Gate | บังคับที่ไหน |
|---|---|
| Plan ต้อง `status: approved` โดย user | `/ow-implement` ปฏิเสธ plan ที่ยัง draft |
| Diagnose ก่อนแก้ | `/ow-fix` สร้าง fix-log + before evidence ก่อน ใครจะแก้ต้องผ่าน log นี้ |
| Confirmation ก่อนแตะ GitHub | `/ow-triage-issues` STOP รอ confirm ก่อน label/comment |
| ไม่ push อัตโนมัติ | `/ow-fix-issue` merge local เท่านั้น — push คือ `/ow-git` |
| Integrity gate | status flip เป็น `done`/`fixed` ต้องมี artifact ครบ (ดู `.ow.yml integrity_gate`) |
| No binaries in vault | evidence binaries อยู่ `test-artifacts/` เท่านั้น (gitignored) |

### Evidence layout

```
test-artifacts/<date>/<source>-<NN|TS>-<slug>/
├── EVIDENCE.md          ← manifest (ตาราง ID | File | TC | State | Type)
├── before-*.png         ← RED proof (สำหรับ fix)
├── after-*.png          ← GREEN proof
└── *.log / *.json       ← test output จริง
```

- 1 folder ต่อ **task** (plan/fix) ไม่ใช่ต่อ command — `/ow-test` append ลง manifest เดิม
- screenshot ที่มี PII ต้อง mask ก่อน (`/ow-secure evidence` ตรวจให้)

---

## 5. ปรับแต่ง

| อยากทำ | วิธี |
|---|---|
| เปลี่ยน template เอกสาร | แก้ `.ow/templates/<name>.md` ตรงๆ (ที่เดียว) |
| เพิ่มกติกาเฉพาะ area | เขียน `.ow/rules/<area>.md` (มี `applies_to` frontmatter) — override generic guidance |
| เปลี่ยน model ต่อ command | `.ow.yml` → `commands.model` / `commands.overrides.<verb>` แล้วรัน `bash scripts/ow-claude-manifest.sh --apply` |
| เปลี่ยน model ต่อ agent | `.ow.yml` → `subagents.<name>.model` แล้วรัน manifest script เหมือนกัน |
| เปิด subagent เพิ่ม | `.ow.yml` → `subagents.<name>.enabled: true` (backend/frontend/mobile/design/test-runner) |
| Vault อยู่นอก repo | `.ow.yml` → `vault_path:` เป็น absolute path |
| Multi-repo / submodules | `.ow.yml` → `submodules:` list (ใช้โดย `/ow-git`, `/ow-implement`) |
| กำหนด build/test command เอง | `.ow.yml` → `verification_matrix:` (ว่าง = auto-detect จาก repo) |

⚠️ ห้าม hand-edit `model:` ใน `.claude/commands/` หรือ `.claude/agents/` —
ไฟล์พวกนี้ GENERATED จาก `.ow.yml`; sync รอบถัดไปจะทับ

---

## 6. Troubleshooting

| อาการ | สาเหตุ/ทางแก้ |
|---|---|
| command บ่น `yq: command not found` | `brew install yq` — hard requirement ของ `scripts/ow-paths.sh` |
| `/ow-implement` ไม่ยอมรัน plan | plan ยัง `status: draft` — review แล้วแก้ frontmatter เป็น `status: approved` |
| `/ow-triage-issues` / `/ow-fix-issue` fail | ต้องมี `gh` CLI login แล้ว + อยู่ใน git repo ที่มี remote |
| model ใน shim ไม่ตรง `.ow.yml` | รัน `bash scripts/ow-claude-manifest.sh --apply` เพื่อ re-sync |
| vault ไม่เจอ | เช็ก `vault_path` ใน `.ow.yml` — relative ต่อ project root |
| upgrade toolkit แล้วของหาย | `bash scripts/ow-upgrade.sh <project> --rollback` คืน backup ล่าสุด |
| ไม่แน่ใจว่า toolkit สมบูรณ์ | รัน smoke test: `bash scripts/test.sh` (ใน toolkit repo) |

---

*เอกสารนี้สรุปจาก `.ow/commands/*.md` (source of truth ของแต่ละ command) —
รายละเอียด phase ต่อ phase อ่านที่ไฟล์ source หรือ `/ow-help <command>`*
