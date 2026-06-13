---
description: Bootstrap obsidian-workflow — config + Obsidian vault + subagents (greenfield หรือ brownfield)
---

# /ow-init — Bootstrap project

ตั้งค่า project — รองรับทั้ง **greenfield** (folder ว่าง) และ **brownfield** (มี code อยู่แล้ว)

> ถ้าไฟล์ toolkit (`.ow/`, `.claude/`, `scripts/ow-paths.sh`) ยังไม่อยู่ใน project นี้
> → copy จาก toolkit repo ก่อน (ดู `install.sh` ของ obsidian-workflow) แล้วค่อยรัน `/ow-init`

## Phase 0 — Load Context (best-effort)
<!-- OW-PHASE0: /ow-init เป็น command เดียวที่รันได้ก่อน config จะมี — resolver fail = fresh install, ไม่ STOP -->

```bash
# resolver สำเร็จ = มี config แล้ว (reconfigure mode); fail = fresh install (สร้างใหม่ Phase 6)
eval "$(bash "$(git rev-parse --show-toplevel 2>/dev/null || pwd)/scripts/ow-paths.sh" --shell)" 2>/dev/null \
  && export OW_CTX_LOADED=1 || echo "No .ow.yml yet — fresh init"
```

## Trigger

```
/ow-init
/ow-init <project-name>
/ow-init --greenfield        # บังคับ mode
/ow-init --brownfield        # บังคับ mode
/ow-init --reconfigure       # แก้ config ของ project ที่ init แล้ว
```

## Phase 1 — ตรวจสถานะ + Detect mode

```bash
test -f .ow.yml && echo "EXISTS" || echo "FRESH"
test -d docs && ls docs | head -5
test -d .claude/commands && ls .claude/commands | grep -c '^ow-' || echo 0

# Detect brownfield indicators (code already in repo)
ls package.json requirements.txt pyproject.toml go.mod Cargo.toml \
   pubspec.yaml pom.xml build.gradle composer.json *.csproj *.sln \
   2>/dev/null | head -3

# Detect submodules
test -f .gitmodules && cat .gitmodules
```

| สภาพ | การตัดสินใจ |
|---|---|
| **ไม่มี indicator เลย** (folder ว่าง) | **Greenfield auto** — ไม่ถาม |
| **มี indicator อย่างน้อย 1 อย่าง** | **ถาม user** 3 ตัวเลือก: greenfield / brownfield / adopt-vault |
| มี `.ow.yml` แล้ว | **Reconfigure** — ถามว่า reset ส่วนไหน |

### Indicators ที่ตรวจ (มีอย่างน้อย 1 → ถาม user แทน assume)

- **Manifests:** `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `Cargo.toml`,
  `pubspec.yaml`, `pom.xml`, `build.gradle`, `composer.json`, `Gemfile`, `*.csproj`
- **Source folders:** `src/`, `lib/`, `app/`, `frontend/`, `backend/`, `api/`, `packages/`, `services/`
- **VCS state:** `.git` + ≥ 1 commit (empty init ไม่นับ)
- **Multi-repo:** `.gitmodules`
- **Existing docs:** `docs/` ที่มี markdown content (อาจเป็น Obsidian vault อยู่แล้ว)

### 3 ตัวเลือก

```
  1) greenfield   — project setup ไว้แล้ว แต่ยังไม่มี content จริง (เริ่ม fresh ได้)
  2) brownfield   — มี code/docs ใช้งานอยู่จริง (adopt + ห้ามแตะของเดิม)
  3) adopt-vault  — มี Obsidian vault อยู่แล้ว (ใช้ vault เดิม + ชี้ vault_path ไปที่นั่น)
```

## Phase 2 — ถามข้อมูลขั้นต่ำ (1 message รวมทุกคำถาม)

1. **ชื่อ project** + slug (ถ้ายังไม่ระบุใน arguments)
2. **Stack/scope** (multi-select): Backend/API · Web frontend · Mobile app · Design system · Multi-repo
3. **Language** สำหรับเอกสาร: `th` (default) / `en`
4. **Vault อยู่ที่ไหน?**

   | ตัวเลือก | เก็บที่ | ใช้เมื่อ |
   |---|---|---|
   | **A) สร้างใหม่ใน `docs/vault/`** | in-repo (default) | greenfield หรือ project ใหม่ |
   | **B) ใช้ vault ที่มีอยู่ใน repo นี้** | path ที่ user ระบุ | brownfield + มี vault อยู่แล้ว |
   | **C) external vault (นอก repo)** | absolute path เช่น `/Users/.../MyVault/projects/<slug>` | vault กลางหลาย project / iCloud sync |

   ทุกตัวเลือกเขียนลง `.ow.yml` `vault_path:` (relative สำหรับ A/B, absolute สำหรับ C)

5. (brownfield) **มี README/docs อยู่แล้ว** อยาก import เข้า PRD ไหม? → yes = Phase 4.2
6. (multi-repo) **Submodules** — auto-detect จาก `.gitmodules` + confirm + branch ต่อ submodule

## Phase 3 — สร้าง vault skeleton

ตาม `vault_path` ที่เลือก:

```
<vault_path>/
├── 00-Index/
│   ├── IMPLEMENTATION-STATUS.md   single source of truth
│   ├── MOC-PRD.md
│   ├── MOC-Features.md
│   ├── MOC-Functions.md
│   └── README.md
├── 10-PRD/            PRD-*.md + SRS-*.md
├── 20-Features/
├── 30-Roles/
├── 40-Functions/
├── 50-Phases/
├── 60-Flows/
├── 70-Reference/
│   ├── REF-TechStack.md
│   ├── REF-AuthorizationMatrix.md
│   ├── REF-APIIntegration.md
│   └── DesignSystem/ (ถ้าเลือก design system)
├── 80-ImplementPlan/
├── 85-FixLog/
├── 90-TestPlan/
└── 95-Handoff/
```

ในแต่ละ folder ใส่ `_README.md` อธิบายหน้าที่ + naming convention
(adopt-vault mode: สร้างเฉพาะ folder ที่ขาด — ห้ามแตะของเดิม)

## Phase 4 — Brownfield adoption (skip ถ้า greenfield)

### 4.1 Stack scan (read-only — ไม่แก้โค้ด)

```bash
[ -f package.json ] && head -30 package.json
[ -f requirements.txt ] && head -20 requirements.txt
[ -f pyproject.toml ] && grep -A 20 'dependencies' pyproject.toml
[ -f go.mod ] && head -10 go.mod
[ -f pubspec.yaml ] && head -30 pubspec.yaml

# Detect API surface
find . -type f \( -name "*.controller.*" -o -name "routes.*" -o -path "*/api/*" \) 2>/dev/null | grep -v node_modules | head -20

# Detect UI components
find . -type d \( -name "components" -o -name "screens" -o -name "pages" \) 2>/dev/null | grep -v node_modules | head -10
```

จาก scan → สร้าง draft:
- `$REF_DIR/REF-TechStack.md` (auto-fill จาก dependencies ที่เห็นจริง)
- `$REF_DIR/REF-APIIntegration.md` (auto-fill endpoints ที่เจอ)
- `$IMPL_STATUS` (mark: `adopted from existing codebase`)

### 4.2 Import README (ถ้า user เลือก yes)

อ่าน `README.md` ของ project แล้วเสนอ mapping:
- product description → `$PRD_DIR/PRD-<slug>.md`
- install/usage → reference ใน `REF-TechStack.md`
- features list → `$FEAT_DIR/FEAT-*.md` drafts

แสดง mapping → ถาม confirm ก่อนสร้างจริง → เสร็จแล้วแนะนำ `/ow-new --import` หรือ
`/ow-reverse-engineer` เพื่อต่อ SRS จาก code จริง

### 4.3 กฎเหล็ก — ไม่แตะโค้ดเดิม

- ห้าม /ow-init แก้/ย้าย/rename ไฟล์โค้ดที่มีอยู่
- เพิ่มเฉพาะ: vault, `.claude/`, `.ow/`, `scripts/ow-paths.sh`, `.ow.yml`, `CLAUDE.md`
- ถ้า `CLAUDE.md` มีอยู่แล้ว → ถามว่า append section หรือเก็บเก่าเป็น `CLAUDE.legacy.md`

## Phase 5 — เลือก subagents

จาก stack ที่เลือกใน Phase 2, set ใน `.ow.yml`:

| Stack | Subagents ที่ enable |
|---|---|
| (always-on) | `docs`, `verifier`, `security`, `gh-issue` |
| Backend/API | + `backend` |
| Web frontend | + `frontend` |
| Mobile app | + `mobile` |
| Design system | + `design` |
| E2E testing | + `test-runner` |

Subagents ที่ disable ยังอยู่ใน `.claude/agents/` แค่ `.ow.yml` set false → `/ow-implement` จะ skip

## Phase 6 — เขียน config + gitignore

### 6.1 `.ow.yml`

ใช้ค่าที่ user ตอบ: `project.*`, `vault_path`, `subagents.*`, `submodules` (จาก `.gitmodules` ถ้ามี)
— โครงตาม `.ow.yml` ของ toolkit (ดู template ใน toolkit repo)

### 6.2 `.gitignore`

```bash
grep -q "^test-artifacts/" .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

# obsidian-workflow — local artifacts
test-artifacts/
worktrees/
.obsidian/workspace*
EOF
```

## Phase 7 — Verification

```bash
bash scripts/ow-paths.sh --selftest
ls "$VAULT_ABS" | wc -l                 # expect ≥ 12 folders
test -f .ow.yml && echo OK
ls .claude/commands | grep -c '^ow-'  # expect 19
ls .claude/agents | wc -l               # expect 9
```

แสดง summary:

```
✅ obsidian-workflow init complete

Mode: <greenfield|brownfield|adopt-vault>
Project: <name> (<slug>)
Vault: <vault_path>/
Subagents enabled: docs, verifier, security, gh-issue <+optionals>
Submodules: <list or none>

ขั้นต่อไป:
  • Greenfield → /ow-new (brainstorm ไอเดียใหม่)
  • Brownfield (มี README) → ตรวจ PRD draft + /ow-new --import เพื่อต่อ SRS
  • Brownfield (อยาก spec จาก code จริง) → /ow-reverse-engineer
  • อยากสร้าง design system ก่อน → /ow-design init
```

## Output (3 หัวข้อบังคับ)

1. **Result** — mode + ไฟล์/folder ที่สร้าง + config ที่เขียน
2. **Verification / Evidence** — output ของ Phase 7 (selftest + counts)
3. **Limitations / Next steps** — เช่น "PRD draft จาก README ต้อง review", ขั้นต่อไปตาม summary

## ห้าม

- ห้ามแก้โค้ดเดิม
- ห้ามแต่ง dependencies, framework, version ที่ไม่ได้เห็นจริงในไฟล์
- ห้าม assume project type ถ้า detect ไม่ชัด — ถาม user
- ห้าม overwrite `.ow.yml` เดิมโดยไม่ confirm (reconfigure ต้องแสดง diff)
