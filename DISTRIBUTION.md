# Distribution Guide — obsidian-workflow

วิธี distribute obsidian-workflow ให้ team หรือ external users ผ่าน git (รูปแบบเดียวกับ [spec-kit](https://github.com/github/spec-kit))

---

## 1. โมเดล distribution

**obsidian-workflow ใช้แนวทาง 3 ขั้น:**

1. **Source repo on GitHub** — `git@github.com:ThunderBirdsX3/obsidian-workflow.git` (ตอนนี้ตั้งไว้แล้ว)
2. **One-line install via curl** — `bash <(curl -fsSL .../scripts/install.sh)` (เหมือน spec-kit)
3. **Tagged releases** — version-pinned snapshots (`v0.1.0`, `v0.2.0`, ...)

**ต่างจาก spec-kit ตรงไหน:**
- spec-kit ใช้ Python (`uvx`) — ต้องมี Python + uv ติดตั้ง
- obsidian-workflow ใช้ **pure bash** — ใช้ได้ทุก Mac/Linux โดยไม่ต้องลงอะไรเพิ่ม นอกจาก `git` + `bash`

---

## 2. First commit + push (ครั้งแรก)

```bash
cd /Volumes/testspace/AI-workflow/obsidian-workflow

# ตรวจ remote (ตั้งไว้แล้ว)
git remote -v
# origin    git@github.com:ThunderBirdsX3/obsidian-workflow.git (fetch/push)

# Stage ทั้งหมด
git add -A

# ดู status (กันลืม)
git status

# Commit แรก
git commit -m "feat: initial obsidian-workflow release v0.2.0

- commands (spec-driven + vault-first patterns) — source-of-truth: `.ow/commands/`
- 4 always-on subagents (docs · verifier · security · gh-issue); ตัวเฉพาะทางสร้างต่อ project ด้วย /ow-agent create
- 7 AI front-ends (Claude/Codex/Gemini/GPT/GLM/Cline/Kimi)
- Vault holds text only — command output is quoted into the doc, never stored as a file
- Sample Library Book Tracker vault
- 301 smoke tests passing"

# Push
git branch -M main
git push -u origin main

# Tag release
git tag -a v0.2.0 -m "Release v0.2.0 — initial public release"
git push origin v0.2.0
```

---

## 3. Subsequent releases (สำหรับ maintainer)

```bash
# 1. Bump VERSION
echo "0.3.0" > VERSION

# 2. Update CHANGELOG.md เพิ่ม section ใหม่ที่ด้านบน:
#    ## [0.3.0] — YYYY-MM-DD
#    ### Added / Changed / Removed
#    ...

# 3. Verify ก่อน push
bash scripts/test.sh                     # ทุก test ต้อง pass
bash bin/ow doctor                 # check ครบไหม

# 4. Commit + tag
git add -A
git commit -m "release: v0.3.0 — <summary 1 บรรทัด>"
git push origin main

git tag -a v0.3.0 -m "Release v0.3.0 — <summary>"
git push origin v0.3.0

# 5. (Optional) สร้าง GitHub Release จาก tag
gh release create v0.3.0 --title "v0.3.0" --notes-from-tag
# หรือผ่าน web: GitHub → Releases → Draft new release → เลือก tag v0.3.0
```

---

## 4. User install/upgrade flow

### Greenfield (project ใหม่)

```bash
mkdir my-app && cd my-app
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
```

### Brownfield (มี code อยู่แล้ว)

```bash
cd existing-project
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
# installer จะตรวจ indicators แล้วถาม mode
```

### Pin version (production projects)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/v0.2.0/scripts/install.sh)
# ใช้ tag v0.2.0 แทน main — version-locked
```

### Local install (offline / dev mode)

```bash
git clone git@github.com:ThunderBirdsX3/obsidian-workflow.git ~/obsidian-workflow
cd target-project
bash ~/obsidian-workflow/scripts/install.sh --source ~/obsidian-workflow
```

### Upgrade ของ project ที่ติดตั้งไว้แล้ว

```bash
cd my-project

# Latest
ow upgrade

# Pin to specific version
ow upgrade --version v0.3.0

# Preview (ไม่จริง)
ow upgrade --dry-run

# Rollback ถ้าพัง
ow upgrade --rollback
```

`upgrade` **ห้ามแตะ**: `templates/`, `docs/`, `.ow.yml`, `.ow/local/`, `CLAUDE.md`, `AI-README.md`, `README.md`
**แทนที่ทั้ง dir**: `.ow/commands/`, `.ow/templates/`, `codex/`, `gemini/`, `gpt/`, `glm/`, `prompts/`
**merge ทีละไฟล์ (ไม่เคย `rm -rf` ทั้ง dir)**:
- `.claude/commands/` — regenerate shim + prune shim ของ command ที่ถูกลบ
- `.claude/agents/` — เขียนทับเฉพาะ **always-on 4 ตัว** และตัดสินจาก **signature ไม่ใช่ชื่อไฟล์** ⇒ agent ที่
  project เขียนเอง (`/ow-agent create`) และ agent ชื่อซ้ำที่ project เป็นเจ้าของ ไม่เคยถูกแตะ
- `.claude/settings.json` — merge เฉพาะ key ที่ obsidian-workflow เป็นเจ้าของ (`$schema` · `permissions.allow` ·
  `env.OW_*`) hooks/deny/ask/env ของ host อยู่ครบ · `settings.local.json` ไม่แตะเลย
**refresh ทีละไฟล์** (mixed-ownership — สคริปต์ที่ host เขียนเองไม่ถูกแตะ): `scripts/` + `bin/` เฉพาะไฟล์ที่อยู่ใน manifest `scripts/ow-owned.sh`

---

## 5. Repository visibility decisions

| ทางเลือก | ข้อดี | ข้อเสีย |
|---|---|---|
| **Public** (เหมือน spec-kit) | curl install ทำงานได้ทันที, ไม่ต้อง auth | content เห็นได้สาธารณะ |
| **Private** | controlled access | curl ต้อง GITHUB_TOKEN, ใช้ยากขึ้น |

**ปัจจุบัน**: repo เป็น **Public** — curl install ทำงานได้ทันที ไม่ต้อง auth

**ถ้า private** — auth มี **สองชั้น** ที่พังแยกกัน: (1) fetch ตัว `install.sh`
(`raw.githubusercontent.com` ตอบ **404** ไม่ใช่ 403 ถ้าไม่มี auth) และ (2) `git clone` source
ที่ installer ทำต่อ ทางที่จบทั้งสองชั้นในคำสั่งเดียวคือ fetch ผ่าน `gh` แล้วชี้ source ไป SSH:

```bash
OW_SOURCE=git@github.com:ThunderBirdsX3/obsidian-workflow.git \
  bash <(gh api "repos/ThunderBirdsX3/obsidian-workflow/contents/scripts/install.sh?ref=main" \
           -H "Accept: application/vnd.github.raw")
```

ผ่าน token (ต้องมี scope `repo`) — ต้องตั้ง `gh auth setup-git` ให้ clone ชั้นที่ (2) ผ่านด้วย:

```bash
export GITHUB_TOKEN=ghp_xxx
bash <(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
```

หรือ clone เองแล้ว install จาก local source:

```bash
git clone --depth 1 git@github.com:ThunderBirdsX3/obsidian-workflow.git /tmp/obsidian-workflow
bash /tmp/obsidian-workflow/scripts/install.sh --source /tmp/obsidian-workflow .
```

---

## 6. CI/CD checklist (suggested)

เพิ่ม GitHub Actions workflow ที่ `.github/workflows/test.yml`:

```yaml
name: obsidian-workflow smoke tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run smoke tests
        run: |
          bash scripts/test.sh
      - name: Run doctor
        run: |
          bash bin/ow doctor
      - name: Test install on empty folder (greenfield)
        run: |
          mkdir /tmp/test-greenfield
          bash scripts/install.sh /tmp/test-greenfield \
            --source . --ai claude --yes
          test -f /tmp/test-greenfield/.ow.yml
          test -d /tmp/test-greenfield/commands
```

หรือเพิ่ม release workflow ที่ `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
```

---

## 7. Versioning policy

obsidian-workflow ใช้ **Semantic Versioning** (`MAJOR.MINOR.PATCH`):

- **MAJOR** — breaking changes: command rename/remove, output format change, installer flag change
- **MINOR** — new command, new template, new AI shim, new helper script
- **PATCH** — clarifications, bug fix, doc update (ไม่ breaking)

## 8. รายชื่อ users / consumers

(ใส่ project ที่ใช้ obsidian-workflow — เพื่อ track adoption)

- (เพิ่ม project ที่ใช้ obsidian-workflow ที่นี่)

---

## 9. Comparison — spec-kit vs obsidian-workflow distribution

| Aspect | spec-kit | obsidian-workflow |
|---|---|---|
| Language | Python | Bash |
| Install command | `uvx specify init <name>` | `ow init <name>` หรือ curl-pipe |
| Dependencies | Python 3 + uv | Bash + git (most systems) |
| Version pinning | `--from git+...@tag` | `--version v0.2.0` |
| Greenfield/Brownfield | `init` vs `init --here` | auto-detect via indicators + ถาม user |
| AI selection | `--ai claude\|copilot\|gemini\|...` | `--ai claude,codex,google,gpt,glm,cline,kimi` |
| Template override | 4-tier override stack | 2-tier (project → .ow/templates) |
| Update | re-run installer | `ow upgrade` (preserves user content) |

---

## 10. ขั้นต่อไป (recommended)

1. ☐ commit + push (ดู section 2)
2. ☐ tag `v<version>` ให้ตรงกับ `ow.version` ใน `.ow.yml` (ดู section 2)
3. ☑ repo เป็น public แล้ว
4. ☐ เพิ่ม `.github/workflows/test.yml` (section 6)
5. ☐ เขียน GitHub Release notes ของ tag นั้น (tag อย่างเดียวไม่พอ — คนที่ติดตามได้จาก Releases เท่านั้น)
6. ☐ แชร์ install command กับ team:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/scripts/install.sh)
   ```
7. ☐ collect feedback ผ่าน issues + standard-feedback process
