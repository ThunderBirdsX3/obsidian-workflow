---
description: อ่านโค้ดที่มีอยู่แล้วสร้าง vault docs ย้อนกลับ — TechStack, API, Features, Functions + SRS skeleton (draft)
---

# /ow-reverse-engineer — Code → Vault Docs

อ่านโค้ดจริงแล้วสร้าง Obsidian vault docs เป็น draft สำหรับ brownfield project ที่ไม่มี spec —
รวมถึง **SRS skeleton** (FR stub จาก endpoint/screen ที่เจอ, acceptance เป็น `<TODO>` ให้ user ยืนยัน)

> **Read-only บนโค้ด** — ไม่แตะ source files เลย สร้างเฉพาะ docs ใน vault

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
RULES=$(bash "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" --rules coding)
for _rf in $RULES; do echo "Read rule: $_rf"; done
```

Use ONLY resolved vars in every later phase — never a `<vault>/...` literal or a hardcoded
build/test command: `$VAULT_ABS $IMPL_STATUS $PRD_DIR $FEAT_DIR $ROLE_DIR $FN_DIR $PHASE_DIR
$FLOW_DIR $REF_DIR $DS_DIR $PLAN_DIR $FIX_DIR $TEST_DIR $HANDOFF_DIR $EVIDENCE_ROOT
$TEMPLATE_CHAIN $GUARDRAILS_JSON`. Every later phase that consumes one asserts it first:
`[ -n "$PLAN_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }`.

## Trigger

```
/ow-reverse-engineer                        # scan ทั้ง project
/ow-reverse-engineer --area api             # เฉพาะ API/routes
/ow-reverse-engineer --area ui              # เฉพาะ UI components/screens
/ow-reverse-engineer --area models          # เฉพาะ domain models/schemas
/ow-reverse-engineer --area all             # ครบทุกมิติ (default)
/ow-reverse-engineer --depth shallow        # โครงสร้างอย่างเดียว (เร็ว)
/ow-reverse-engineer --depth deep           # อ่านเนื้อหาไฟล์จริง (ละเอียด)
```

ว่าง → ถาม area + depth แล้วเริ่ม scan

## Phase 0.5 — Project structure detection

```bash
# Manifests
ls package.json requirements.txt pyproject.toml go.mod Cargo.toml \
   pubspec.yaml pom.xml build.gradle composer.json Gemfile *.csproj 2>/dev/null

# Source roots
find . -maxdepth 3 -type d \( \
  -name src -o -name lib -o -name app -o -name api \
  -o -name server -o -name client -o -name backend -o -name frontend \
  -o -name mobile -o -name packages -o -name services \
\) 2>/dev/null | grep -v node_modules | grep -v .git

# Entry points
ls main.* index.* app.* server.* 2>/dev/null | grep -v node_modules
```

แสดง structure ที่เจอ + ถามว่าจะ scan ส่วนไหนก่อน (ถ้าไม่ได้ระบุ `--area`)

## Phase 1 — Tech stack scan

อ่าน manifest files แล้ว draft `REF-TechStack.md`:

```bash
# Node/JS
[ -f package.json ] && cat package.json | grep -A 50 '"dependencies"'

# Python
[ -f requirements.txt ] && cat requirements.txt
[ -f pyproject.toml ] && grep -A 30 '\[tool.poetry.dependencies\]' pyproject.toml

# Go
[ -f go.mod ] && cat go.mod

# Dart/Flutter
[ -f pubspec.yaml ] && grep -A 20 'dependencies:' pubspec.yaml

# Java/Kotlin
[ -f build.gradle ] && grep -E 'implementation|api' build.gradle | head -20
```

**Output draft:**
```
$REF_DIR/REF-TechStack.md
```

ระบุเฉพาะสิ่งที่เห็นจริงในไฟล์ — ห้ามเดา version หรือ dependency ที่ไม่เจอ

## Phase 2 — API / Routes scan

```bash
# Express / Fastify / Hapi (JS)
find . -type f \( -name "routes.*" -o -name "*.routes.*" -o -name "router.*" \) \
  2>/dev/null | grep -v node_modules | head -20

# NestJS controllers
find . -type f -name "*.controller.*" 2>/dev/null | grep -v node_modules | head -20

# FastAPI / Flask (Python)
grep -r "@app\.\(get\|post\|put\|delete\|patch\)" --include="*.py" -l 2>/dev/null | head -10
grep -r "@router\." --include="*.py" -l 2>/dev/null | head -10

# Go (gin/echo/chi)
grep -r "\.\(GET\|POST\|PUT\|DELETE\|PATCH\)(" --include="*.go" -l 2>/dev/null | head -10

# Laravel (PHP)
[ -f routes/api.php ] && cat routes/api.php | head -50
[ -f routes/web.php ] && cat routes/web.php | head -50

# Rails
[ -f config/routes.rb ] && cat config/routes.rb | head -50
```

ถ้า `--depth deep` → อ่านไฟล์ route จริง extract:
- method + path (`GET /api/users/:id`)
- parameters ที่เห็น
- response shape (ถ้าเห็น)

**Output draft:**
```
$REF_DIR/REF-APIIntegration.md
```

## Phase 3 — Domain model scan

```bash
# TypeScript interfaces / types
find . -type f \( -name "*.types.*" -o -name "*.interface.*" -o -name "*.model.*" -o -name "*.entity.*" -o -name "*.schema.*" \) \
  2>/dev/null | grep -v node_modules | head -20

# Prisma schema
find . -name "schema.prisma" 2>/dev/null

# SQLAlchemy / Django models (Python)
grep -r "class.*Model\|class.*Base" --include="*.py" -l 2>/dev/null | head -10

# Go structs (domain layer)
find . -path "*/domain/*.go" -o -path "*/model/*.go" -o -path "*/entity/*.go" 2>/dev/null | head -10

# Dart/Flutter models
find . -name "*.dart" -path "*/models/*" 2>/dev/null | head -10
```

ถ้า `--depth deep` → อ่าน fields จาก model/schema จริง

**Output draft (1 ไฟล์ต่อ domain entity ที่เจอ):**
```
$FN_DIR/FN-<EntityName>.md   ← status: draft
```

ใส่เฉพาะ fields ที่เห็นจริง — ห้ามเดา business logic

## Phase 4 — Feature area detection

จัดกลุ่ม files ที่เจอจาก Phase 2-3 เป็น feature clusters โดยดูจาก:
- folder structure (`/checkout/`, `/auth/`, `/users/`, `/products/`)
- naming patterns (`checkout*.`, `auth*.`, `user*.`)
- route prefix (`/api/checkout/`, `/api/auth/`)

แต่ละ cluster → draft `FEAT-*.md` หนึ่งไฟล์

**Output draft:**
```
$FEAT_DIR/FEAT-<Area>.md   ← status: draft
```

ข้อมูลที่ใส่:
- Feature name + slug (จาก folder/prefix ที่เจอ)
- Files ที่อยู่ใน cluster นี้
- API endpoints ที่ map มา (จาก Phase 2)
- Domain models ที่เกี่ยวข้อง (จาก Phase 3)
- ส่วนที่ **ไม่รู้** (เว้นว่างไว้ให้คนกรอก): business rules, acceptance criteria, non-goals

## Phase 4.5 — SRS skeleton (FR stub จาก endpoints/screens)

แตก endpoint ที่เจอ (Phase 2) + screen/flow จาก UI scan (`--area ui`/`all`) เป็น **FR stub**
แล้ว draft SRS 1 ไฟล์ตามโครง `.ow/templates/srs.md`:

**Output draft:**
```
$PRD_DIR/SRS-<project-slug>.md   ← status: draft, source: reverse-engineered
```

แต่ละ FR stub ใส่**เฉพาะสิ่งที่เห็นในโค้ด**:
- **Description** — พฤติกรรมที่ endpoint/screen ทำจริง (จาก handler/validation ที่อ่าน)
- **Inputs/Outputs** — จาก request/response schema, validation rules, model fields ที่เห็น
- **Acceptance** — `<TODO: user ยืนยัน Given/When/Then>` **เสมอ** — โค้ดบอก "ทำอะไร" แต่ไม่บอก "ถูกต้องคืออะไร"
- **Error handling** — เฉพาะ error code/message ที่เห็นในโค้ด
- **Dependencies** — FR อื่น / external service ที่เห็น import/call จริง

Section อื่นของ SRS skeleton:
- **State & Lifecycle** — เฉพาะ entity ที่มี status/enum field ในโค้ด; transition ใส่เท่าที่เห็น ที่เหลือ `<TODO>`
- **Error Catalog** — รวม error ที่ scan เจอจากทุก FR stub
- **NFR** — `<TODO>` ทั้งหมด (โค้ดไม่บอก threshold — ห้าม invent)
- **Traceability** — มัด FR stub ↔ FN draft (Phase 3); Test plan column = `<TODO>`
- unknown ทุกจุด → `<TODO>` + รวมรายการไว้ใน **Open Questions** ท้าย SRS skeleton (ให้ `/ow-clarify` ไล่ปิด)

🔴 business rule ที่มองไม่เห็นในโค้ด = **ไม่เขียน** — ใส่ `<TODO>` เท่านั้น

## Phase 5 — Review checkpoint (บังคับ)

แสดง mapping ทั้งหมดก่อนเขียนจริง:

```
📋 Reverse Engineer Summary — <project>

Tech Stack:
  → REF-TechStack.md (Node.js 20, Express 4, PostgreSQL, Prisma)

API Endpoints found: 23
  → REF-APIIntegration.md

Domain Models found: 6 (User, Order, Product, Cart, Payment, Review)
  → FN-User.md, FN-Order.md, FN-Product.md ... (6 files)

Feature clusters detected: 4
  → FEAT-Auth.md       (src/auth/, /api/auth/*, User model)
  → FEAT-Checkout.md   (src/checkout/, /api/orders/*, Order+Cart+Payment)
  → FEAT-Catalog.md    (src/catalog/, /api/products/*, Product model)
  → FEAT-Reviews.md    (src/reviews/, /api/reviews/*, Review model)

SRS skeleton: 23 FR stubs (จาก 23 endpoints — acceptance ทั้งหมด = <TODO>)
  → SRS-<project-slug>.md

⚠️  ไม่แน่ใจ (ต้องการ input จาก user):
  - src/utils/ → ไม่ชัดว่า belong feature ไหน
  - /api/admin/* → พบ endpoints แต่ไม่มี source folder ตรงกัน

สร้าง draft ทั้งหมด? [y/n] หรือ ระบุ cluster ที่ต้องการ (เช่น "Auth, Checkout"):
```

รอ user confirm ก่อนเขียนไฟล์จริง

## Phase 6 — Write vault docs

เขียนเฉพาะที่ user confirm:

- Frontmatter ทุกไฟล์ต้องมี `status: draft` และ `source: reverse-engineered`
- เนื้อหาที่ยังไม่รู้ใส่ `<!-- TODO: fill in -->` (ใน SRS = `<TODO>` ตาม template)
- ไม่ overwrite ไฟล์ที่มีอยู่แล้ว — ถามก่อน

```yaml
---
tags: [type/feature]
status: draft
source: reverse-engineered
date: YYYY-MM-DD
reverse_engineered_from:
  - src/checkout/checkout.controller.ts
  - src/checkout/checkout.service.ts
---
```

## Phase 7 — สรุปและ next steps

```
✅ Reverse Engineer เสร็จ

สร้างแล้ว:
  1 × REF-TechStack.md
  1 × REF-APIIntegration.md
  6 × FN-*.md (domain models)
  4 × FEAT-*.md (feature clusters)
  1 × SRS-<slug>.md (FR stubs — acceptance ทั้งหมดเป็น <TODO>)

⚠️  Draft ทั้งหมด — ต้องตรวจและเติมก่อนใช้ plan/implement

ขั้นต่อไป (แนะนำตามลำดับ):
  1. ตรวจ FEAT-*.md + SRS skeleton — ลบ cluster ที่ผิด, ยืนยัน FR ที่ extract มา
  2. /ow-clarify <SRS-path> — ไล่ปิด <TODO> acceptance + Open Questions ทีละข้อ
  3. /ow-doc SRS <slug> — เติม FR ให้ครบ depth bar (NFR threshold, State & Lifecycle)
  4. /ow-new --import <path> — ถ้ามี PRD/spec เดิมอยู่ → merge เข้า vault
  5. /ow-plan <task> — เริ่มวางแผน feature แรก
```

## Output (3 หัวข้อบังคับ)

1. **Result** — list ไฟล์ draft ที่สร้าง (REF/FN/FEAT + SRS skeleton) + จำนวน FR stub
2. **Verification / Evidence** — `find`/`grep` ที่รันจริงพร้อมผลสรุป + mapping source files → doc ที่ generate แต่ละไฟล์
3. **Limitations / Next steps** — ทุก doc เป็น draft; business rules + acceptance เป็น `<TODO>` ต้องให้ user ยืนยันผ่าน /ow-clarify ก่อน plan/implement

## ห้าม

- ห้ามแก้ source code ใดๆ — read-only ทั้งหมด
- ห้าม overwrite vault doc ที่มีอยู่แล้วโดยไม่ถาม
- ห้ามเดา business rules, acceptance criteria, NFR threshold หรือ behavior ที่ไม่เห็นในโค้ด — unknown = `<TODO>` + Open Questions เท่านั้น
- ห้ามเขียนไฟล์โดยไม่ผ่าน Phase 5 review checkpoint
- ห้าม mark status อื่นนอกจาก `draft` — user ต้อง promote เอง
