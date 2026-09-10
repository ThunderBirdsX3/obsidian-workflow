# /ow-git

> **Submodule-aware git ops** — commit/push/branch/merge ทั้ง main repo + submodules ตาม plan/fix scope

[← กลับ usage/README](./README.md) · [Full spec: `.ow/commands/ow-git.md`](../.ow/commands/ow-git.md)

## เมื่อไหร่ใช้

- Commit + push หลัง `/ow-implement` (plan-scoped — auto-stage จาก plan file)
- Commit fix (prefix `fix:` อัตโนมัติ จาก fix-log)
- Switch branch ทั้ง main + submodules พร้อมกัน
- Merge feature branch → default ของแต่ละ repo

## Quick start

```
/ow-git --plan docs/obsidian-vault/80-ImplementPlan/2026-05-21-add-search.md
```

ตัวอย่าง output:
```
git-sync summary
================
api    [develop]    1 commit pushed   ✅
web    [develop]    2 commits pushed  ✅
app    [master]     0 commits         skip (no changes)
main   [main]       1 commit pushed   ✅
figma  [read-only]  skipped
```

## รูปแบบเต็ม

```
/ow-git --plan <path>             # auto-stage + auto-message จาก plan
/ow-git --fix <path>              # commit prefix `fix:`
/ow-git --message "<msg>"         # explicit message
/ow-git --branch <name>           # switch branch + submodules
/ow-git --branch default          # switch กลับ tracked branch
/ow-git --create-branch           # สร้าง branch ใหม่ถ้าไม่มี
/ow-git --no-push                 # commit only
/ow-git --switch-only             # switch ไม่ commit
/ow-git --status                  # แสดง branch + dirty state + ahead/behind vs origin
/ow-git --pull                    # sync อย่างเดียว — fetch+rebase ทุก repo แล้วจบ (ไม่ commit ไม่ push)
/ow-git --no-sync                 # ข้าม auto-sync รอบนี้
/ow-git --rebase                  # sync ด้วย rebase (default)
/ow-git --merge                   # sync ด้วย merge
/ow-git --bump patch|minor|major  # bump version + append [vX.Y.Z]
/ow-git --merge-to default        # merge เข้า tracked branch
/ow-git --no-ff                   # force --no-ff merge commit
/ow-git --delete-source           # หลัง merge → delete source local + remote
```

| Flag group | Default | ใช้สำหรับ |
|---|---|---|
| `--plan` / `--fix` | n/a | scope จาก plan/fix + auto message |
| `--branch <name>` | current | switch all repos to branch |
| `--merge-to <br>` | n/a | merge หลัง push |
| `--no-push` | off | commit only (review ก่อน push) |
| `--bump` | **off (default = no bump)** | **opt-in** — bump version (**unified — เลขเดียวทุก submodule**) + tag + append in message; ไม่สั่ง = ไม่ bump |
| `--no-ready-for-test` | off | ปิด auto issue-handoff (ไม่ comment version / ไม่ flip label) |

## ขั้นตอนภายใน (Phase summary)

1. **Phase 1** — Parse args (message precedence: `--message` > free text > auto > prompt)
2. **Phase 2** — Status / Switch-only modes (ไม่ commit)
2.5. **Phase 2.5** — Sync กับ origin ก่อน stage (fetch + rebase ทุก repo) — **default-on** สำหรับทีมหลายคน; conflict ที่ auto ไม่ได้ → หยุดทั้ง command
3. **Phase 3** — `--pull` เดี่ยวๆ (ไม่มี `--plan`/`--fix`/`--message`/free text) = **sync แล้วจบ** ไม่ commit ไม่ push; พ่วงกับ flag อื่น = sync แล้วไหลต่อ
4. **Phase 4** — Scope staged files (จาก plan `Affected Files` — file นอก list ไม่ stage + แจ้ง)
5. **Phase 5** — Generate commit message (plan → `feat(<area>): <title>`, fix → `fix(<area>): <title>`)
5.5. **Phase 5.5** — Unified bump version (`--bump`): คำนวณ `TARGET_VERSION` ครั้งเดียว = bump(max(current ของทุก repo **รวม version file**)) → ใช้ tag + commit-tag **เลขเดียวกันทุก submodule** (กัน web/app version ไม่ตรงกัน)
6. **Phase 6** — Commit + push per submodule (skip read-only + no-stage) — tag `v$TARGET_VERSION` เดียวกันทุก repo
7. **Phase 7** — Main repo commit (stage submodule pointer updates + main files)
8. **Phase 8** — Merge-to (optional)
8.5. **Phase 8.5** — Auto issue-handoff: push มี `Closes #NN` → comment "fixed in vX.Y.Z" + flip label `ready for test` (default-on; `--no-ready-for-test` ปิด; ห้าม close — tester verify เอง)
8.6. **Phase 8.6** — Fix-log version stamp: `--bump` push ของ plan ที่มี `source_fix:` → stamp `fixed_in_version` + `fixed_commit` (sha จริง) ลง fix-log ต้นทาง (mirror 8.5 สำหรับ fix-log local — ไม่ comment/ไม่ flip label) (#30)
9. **Phase 9** — Report summary table (+ handoff result)

## `--bump` เขียน version file ยังไง (#34)

**tag กับ file ไม่ใช่ string เดียวกัน** — จำแค่นี้พอ:

| อะไร | ค่า | ทำไม |
|---|---|---|
| git tag | `v0.3.36` | `v` เป็นของ tag |
| version file | `0.3.36` (bare) | `pubspec.yaml` / `package.json` / `Cargo.toml` **ไม่รับ** `v` → `flutter pub get` พังทั้ง release |

`v` ที่หลุดเข้าไฟล์ไม่ได้พังแค่รอบเดียว — bump รอบถัดไปอ่านไฟล์เดิมต่อ เลยติดยาว

ทุกการเขียนผ่าน `scripts/ow-version.sh` ตัวเดียว:
- เขียน bare semver เสมอ — เจอ `v` มาก็ตัดให้ **แต่บอกด้วย** (ไม่เงียบ)
- ไฟล์ที่มี build number (`0.3.36+0009` แบบ pubspec) → `+1` และคงจำนวนหลัก (`+0010`); build ที่ไม่ใช่ตัวเลขล้วน = หยุด (iOS/Android รับแต่ตัวเลข)
- เขียนเสร็จ **อ่านกลับมา parse ใหม่** — เช็คแค่ "เลขเปลี่ยนแล้ว" ไม่พอ ค่าพังๆ ก็เปลี่ยนเหมือนกัน
- **gate รันก่อน commit/tag/push** — พังเมื่อไหร่หยุดทั้ง run ไม่มี tag ไม่มี push (ไม่ใช่มารู้ตอน release ขึ้นไปแล้ว)
- ไฟล์ type ที่ไม่รู้จัก = error ดังๆ ไม่ skip เงียบ (skip เงียบ = version file ตามหลัง tag)

รองรับ: `VERSION` · `package.json` · `pubspec.yaml` · `pyproject.toml` · `Cargo.toml` · `*.csproj`

ปรับได้ที่ `version_bump:` ใน `.ow.yml`:

```yaml
version_bump:
  files: [VERSION, app/pubspec.yaml]
  build_number: increment        # increment (default) | preserve | drop
  verify_cmd: ["cd app && flutter pub get"]   # ตัวตัดสินจริงของ stack — fail = STOP ก่อน tag
```

> `ow-version.sh` เป็น helper **ตัวเดียว** ที่หายแล้ว `--bump` หยุด (ตัวอื่นหาย = degrade ต่อได้) — เพราะ degrade ตรงนี้ = กลับไปเขียนมั่วเอง ซึ่งคือบั๊กเดิม. ไม่มีให้รัน `bash scripts/upgrade.sh` (ไม่ใช่ `/ow-sync` — ตัวนั้นลง `commands/` ไม่แตะ `scripts/`)

## Rules ที่บังคับ

- **ห้ามรันอัตโนมัติ** — รันเฉพาะ user เรียก
- ใช้ submodules list จาก `.ow.yml`
- **Read-only submodules** (เช่น `figma`) → skip silently
- Main repo commit **หลัง** submodules push หมด
- Submodule ไม่มี staged → skip silently

## Output ที่ได้

- Git history (commits + tags ถ้า `--bump`)
- Push to remote (เว้นแต่ `--no-push`)
- Console: summary table (branch × commits × status per repo)

## Workflow ที่นิยม

ตัวอย่าง 1: feature commit
```
1. /ow-implement <plan>
2. /ow-secure
3. /ow-verify <plan>
4. /ow-git --plan <plan>
   → stage เฉพาะไฟล์ใน Affected Files
   → message: feat(web): add search feature
   → push api/, web/, main/
```

ตัวอย่าง 2: bug fix
```
1. /ow-fix → /ow-plan fix:<slug> → /ow-implement
2. /ow-git --plan <plan> --bump patch
   → message: fix(web): search returns empty [v1.2.4]
   → Phase 8.6: stamp fixed_in_version: v1.2.4 + fixed_commit ลง fix-log ต้นทาง (plan มี source_fix:)
```

ตัวอย่าง 3: switch branch
```
/ow-git --switch-only --branch feature/checkout
  → main + submodules ทั้งหมด switch ไป feature/checkout
  → ไม่ commit
```

ตัวอย่าง 4: bump version + merge
```
/ow-git --plan <plan> --bump minor --merge-to default
  → commit message: feat: ... [v1.3.0]
  → push → merge เข้า main/develop ของแต่ละ repo
```

## Gotchas / ข้อควรระวัง

- 🚫 **ห้าม `git push --force` โดยไม่ explicit user confirm**
- 🚫 **ห้าม commit ก่อนรัน `/ow-secure`** — workflow บังคับ pre-flight
- 🚫 ห้าม delete branch โดยไม่ verify ว่า merged
- 🚫 **ห้าม commit ที่ figma (หรือ read-only) submodule** — skip silently
- 🚫 ห้าม `git reset --hard` โดยไม่ confirm
- ⚠️ File ที่ไม่อยู่ใน plan `Affected Files` → ไม่ถูก stage + แจ้ง user
- ⚠️ Non-ff push (teammate push ก่อน) → sync ใหม่แล้ว push ซ้ำอัตโนมัติ (`git.push_retry`, default 1); ครบแล้วยังเด้ง = หยุด **ไม่เคย force**
- ⚠️ Conflict ที่ auto-resolve ไม่ได้ → rebase **ค้างไว้ให้แก้ต่อ** (ไม่ abort ให้) + ไม่ commit/push/bump; แก้เสร็จ `git rebase --continue` แล้วรัน `/ow-git` เดิมซ้ำ
- ⚠️ `--bump` ชนกับ teammate (tag มีบน origin แล้ว) → หยุด ไม่ย้าย tag; รัน `--bump` ใหม่เพื่อเอาเลขถัดไป
- 💡 Commit message precedence: `--message` > free text > plan auto > prompt user
- 💡 **Default = ไม่ bump** — ต้องสั่ง `--bump patch|minor|major` เอง; `/ow-git` ไม่เคย auto-bump (แม้ command อื่นจะ suggest "Next: `/ow-git --bump`")

## Related

- ก่อน `/ow-git`: [/ow-secure](./ow-secure.md) (บังคับ), [/ow-verify](./ow-verify.md) (recommended)
- หลัง `/ow-git`: reviewer review
- Config: `.ow.yml` `submodules:` (path + branch + read_only)
- Rules: `.ow/rules/<area>.md` (resolver `ow-paths.sh --rules <area>`)

## FAQ

**Q: ผมมี submodule แต่ `.ow.yml` ไม่มี — `/ow-git` จะรู้ไหม?**
A: ใช้ `.gitmodules` fallback แต่แนะนำ list ใน `.ow.yml` เพื่อ explicit branch + read_only flag

**Q: ถ้า submodule บางตัวมี conflict?**
A: `/ow-git` หยุดทั้ง command + แจ้งว่าไฟล์ไหน — resolve ใน submodule นั้น (`git rebase --continue`) แล้วรันคำสั่งเดิมซ้ำ

**Q: อยาก update ให้ทัน teammate เฉยๆ ไม่ commit — สั่งยังไง?**
A: `/ow-git --pull` — fetch + rebase ทุก repo (main + submodules) แล้วจบ ไม่ stage ไม่ commit ไม่ push. อยากดูก่อนว่าตามหลังเท่าไหร่ → `/ow-git --status`

**Q: ทีมหลายคน commit branch เดียวกัน — ต้อง pull เองก่อนไหม?**
A: ไม่ต้อง — Phase 2.5 fetch + rebase ให้ทุกครั้งก่อน stage. ปิดเฉพาะรอบนี้ด้วย `--no-sync`, ปิดถาวรที่ `.ow.yml` → `git.auto_sync: false`

**Q: อะไรที่ AI แก้ conflict ให้เองได้บ้าง?**
A: เฉพาะที่มีกฎตายตัว — version file (เอาเลขสูงกว่า), lock file (regenerate), `CHANGELOG.md` (union), และ vault `.md` **เฉพาะตอนที่ conflict เป็น table row / list item ล้วนและไม่มี key ซ้ำ** (เช่น `IMPLEMENTATION-STATUS.md`, MOC). โค้ดและ prose ในเอกสาร = คนแก้เสมอ. ทุกไฟล์ที่แก้ให้จะขึ้นในรายงาน — ไม่มีการแก้เงียบ. ปรับได้ที่ `git.auto_resolve` (`[]` = ปิดหมด)

**Q: ผมแก้ค้างไว้ยังไม่ commit แล้ว teammate push มาก่อน — งานผมหายไหม?**
A: ไม่หาย — rebase ใช้ `--autostash` (stash ให้อัตโนมัติแล้วคืนให้ตอนจบ). ถ้าคืนแล้วชนบรรทัดเดียวกัน `/ow-git` **หยุดทันที** ไม่ stage ไม่ commit ไม่ push, และงานคุณอยู่ **2 ที่**: marker ในไฟล์ + `git stash list`. เคสนี้ rebase จบไปแล้ว → แก้เสร็จใช้ `git add <file> && git stash drop` (**ไม่ใช่** `git rebase --continue`) แล้วรันคำสั่งเดิมซ้ำ. ตั้ง `git.strategy: merge` แทนได้ถ้าไม่อยากให้ stash เลย — git จะปฏิเสธตั้งแต่ต้นเมื่อ tree ยังไม่สะอาด

**Q: repo ผมไม่มี remote / ทำงาน offline — พังไหม?**
A: ไม่ — sync จะ skip เงียบๆ แล้วทำงานเหมือนเดิมทุกอย่าง

**Q: ใช้ `/ow-git` กับ monorepo (ไม่มี submodule) ได้ไหม?**
A: ได้ — `.ow.yml` `submodules: []` ว่าง → ทำงาน main repo อย่างเดียว

**Q: ทำไม `--plan` auto-message — ผมเปลี่ยน message ได้ไหม?**
A: ได้ — ใช้ `--message "<msg>"` (precedence สูงสุด) หรือ ตอบ prompt ตอน commit
