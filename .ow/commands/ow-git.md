---
description: Submodule-aware git ops — commit, push, branch, merge across main repo + submodules from plan/fix scope
---

# /ow-git — Submodule-aware git ops

Commit + push ทั้ง submodules + main repo ตาม plan/fix scope หรือ free text

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
/ow-git --plan <plan-path>
/ow-git --plan <plan-path> --bump patch   # ถ้า plan มี source_fix: → auto stamp fixed_in_version + fixed_commit ลง fix-log (Phase 8.6)
/ow-git --fix <fix-log-path>
/ow-git --fix <fix-log-path> --bump patch   # push+bump → auto comment version + flip label ทุก issue ที่ Closes (Phase 8.5)
/ow-git --message "feat: add search"
/ow-git --branch <name>
/ow-git --status
/ow-git --pull
/ow-git --merge-to default
/ow-git --no-push
/ow-git --fix <...> --bump patch --no-ready-for-test    # push+bump แต่ไม่แตะ issue (ปิด auto-handoff)
```

## Rules

- **ห้ามรันอัตโนมัติ** — รันเฉพาะตอน user เรียก (Phase 8.5 issue-handoff เป็น sub-step ของการ push ที่ user สั่ง ไม่ใช่การรัน command เอง)
- **Auto issue-handoff (Phase 8.5)** — push ที่มี `Closes #NN` → comment "fixed in vX.Y.Z" + flip label `ready for test` ให้อัตโนมัติ (default-on; ปิดด้วย `--no-ready-for-test`); ยังคงกฎ **ห้าม close** issue
- **Auto fix-log stamp (Phase 8.6)** — `--bump` push ของ plan ที่มี `source_fix:` → stamp `fixed_in_version` + `fixed_commit` (sha จริง) ลง fix-log ต้นทาง (mirror 8.5 สำหรับ fix-log local: ไม่ comment/ไม่ flip label)
- **Unified bump version (Phase 5.5)** — `--bump` คำนวณ `TARGET_VERSION` ครั้งเดียว (= bump จาก max ของ current version ทุก repo) แล้วใช้ tag + commit-tag เลขเดียวกันทุก submodule; ห้าม bump แยกจน version ไม่ตรงกัน (config `version_bump.unified`, default true)
- **Default = no bump (opt-in)** — ไม่ระบุ `--bump` = `--no-bump`: ไม่ tag, ไม่เขียน version file, ไม่ append `[vX.Y.Z]`. 🔴 ห้าม auto-เติม `--bump` เอง — แม้ phase/command อื่น (`/ow-test`, `/ow-implement`) จะ suggest "Next: `/ow-git --bump`"; version bump เป็น decision ของ user เท่านั้น (ต้องเรียก `--bump patch|minor|major` ชัดเจน)
- ตาม `.ow.yml` `submodules:` list
- Submodule branches ใช้ค่าจาก `.gitmodules` หรือ config
- **Read-only submodules** (เช่น design-assets) → skip silently
- Main repo commit หลัง submodules push หมด
- Submodule ไม่มี staged → skip silently
- Commit message ใช้ convention กลาง (`feat:`/`fix:`/`chore:` …) — ไม่มี tag เฉพาะองค์กร

## Phase 1 — Parse args

| Flag | Purpose |
|---|---|
| `--plan <path>` | Plan file → scope staged files + auto-generate commit message |
| `--fix <path>` | Fix log → scope + commit prefix `fix:` |
| `--branch <name>` | Switch main + submodules ก่อน commit (ยกเว้น read-only) |
| `--branch default` | Switch กลับ branch ตาม `.gitmodules` |
| `--create-branch` | สร้าง branch ใหม่ถ้าไม่มี |
| `--message "<msg>"` | Explicit message |
| `--no-push` | Commit only |
| `--switch-only` | แค่ switch ไม่ commit |
| `--status` | แสดง branch + dirty state ของแต่ละ repo |
| `--pull` | Fetch + ff pull ก่อน stage |
| `--rebase` | Pull --rebase |
| `--bump patch\|minor\|major` | **opt-in** — bump version (**unified — เลขเดียวทุก submodule**, Phase 5.5) + tag + append `[vX.Y.Z]` |
| `--no-bump` | **(default)** — ไม่ระบุ `--bump` ก็ตกค่านี้: ข้าม bump ทั้งหมด |
| `--merge-to <branch>` | หลัง push → merge เข้า branch |
| `--merge-to default` | merge เข้า tracked branch ของแต่ละ repo |
| `--no-ff` | force `--no-ff` merge commit |
| `--delete-source` | หลัง merge สำเร็จ → delete source branch local + remote |
| `--no-ready-for-test` | ปิด auto issue-handoff (Phase 8.5) — ไม่ comment version / ไม่ flip label แม้ push มี `Closes #NN` |

Precedence ของ message: `--message` > free text > auto-from-plan/fix > prompt user

## Phase 2 — Status / Switch-only modes

ถ้า `--status` หรือ `--switch-only`: ทำเฉพาะ branch ops ไม่ stage/commit/push

```bash
# Status example — main repo (.) + every submodule. Submodules come from the
# resolver TSV (path<TAB>read_only), NOT jq: the config is YAML, so `jq` silently
# no-ops and the loop would iterate nothing.
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  echo "=== $repo ==="
  git -C "$repo" branch --show-current
  git -C "$repo" status --short
done
```

## Phase 3 — Pull / Sync (ถ้า `--pull` หรือ `--update-submodules`)

```bash
git fetch --all
git pull --ff-only        # หรือ --rebase ถ้า --rebase
# submodules (resolver TSV — no jq-on-YAML)
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
for sub in $(bash "$RESOLVER" --submodules | cut -f1); do
  git -C "$sub" pull --ff-only
done
```

Abort ถ้า non-ff โดยไม่ใช่ --rebase

## Phase 4 — Scope staged files (ถ้า --plan / --fix)

อ่าน plan/fix file → list `Affected Files` → stage เฉพาะที่อยู่ใน list

```bash
files=$(grep -oP '`[^`]+`' "$plan" | head -50 | tr -d '`')
for f in $files; do git add "$f"; done
```

ถ้า file ไม่อยู่ใน plan → ไม่ stage; แจ้ง user ว่า file ใดถูก skip

## Phase 5 — Generate commit message

ลำดับ precedence:
1. `--message`
2. Free text จาก `$ARGUMENTS`
3. Auto จาก plan/fix:
   - Plan: `feat(<area>): <plan title>` หรือ `feat: <title>`
   - Fix: `fix(<area>): <fix title>`
4. Prompt user

Append version tag (`$VERSION_TAG` จาก Phase 5.5) ถ้า `--bump` — **เลขเดียวกันทุก repo**

## Phase 5.5 — Resolve unified bump version (ถ้า `--bump`)

🔴 **ทุก repo ที่มี change ในรอบเดียว ต้องได้ version เดียวกัน** — ห้าม bump แยกจน web=v0.2.76 / app=v0.2.77 (เลขไม่ตรงกัน) คำนวณ `TARGET_VERSION` **ครั้งเดียว** แล้วใช้กับทุก repo ที่ commit
🔴 **version ที่ bump คือของจริง** (git tag + version file ที่เขียน) ต้องตรงกัน — ไม่ใช่แค่เลขใน summary table ที่ show

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
UNIFIED=$(echo "$VERSION_BUMP_JSON" | jq -r '.unified // true')      # default = unified
KIND="<patch|minor|major จาก --bump>"

# 0) 🔴 No-change guard — มี repo ไหน "มี staged change" จริงบ้าง? ถ้าไม่มีเลย → ไม่ commit + ไม่ bump
CHANGED=0
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  [ -n "$repo" ] || continue
  [ -n "$(git -C "$repo" diff --cached --name-only 2>/dev/null)" ] && CHANGED=1
done
if [ "$CHANGED" = "0" ]; then
  echo "ℹ️ ไม่มี staged change — ข้าม commit + bump ทั้งหมด (ไม่ tag, ไม่ push)"; TARGET_VERSION=""; 
  # → ข้าม Phase 5.5 ที่เหลือ + Phase 6 จะ skip ทุก repo เอง
else

# 1) current version ของแต่ละ repo (semver tag ล่าสุด vX.Y.Z; ไม่มี = 0.0.0)
#    (ถ้า version_bump.files ตั้งไว้ → อ่านจาก version file ของ repo นั้นแทน)
vers=()
for repo in $(bash "$RESOLVER" --submodules | cut -f1); do
  v=$(git -C "$repo" tag --list 'v*.*.*' | sed 's/^v//' | sort -V | tail -1)
  vers+=("${v:-0.0.0}")
done

# 2) BASE = max(current ทุก repo) — กัน version ถอยหลังของ repo ที่ล้ำหน้า
BASE=$(printf '%s\n' "${vers[@]:-0.0.0}" | sort -V | tail -1)

# 3) TARGET_VERSION = bump(BASE, KIND) — คำนวณครั้งเดียว
IFS=. read -r MA MI PA <<<"$BASE"
case "$KIND" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  *)     PA=$((PA+1)) ;;                # patch (default)
esac
TARGET_VERSION="$MA.$MI.$PA"
# append_tag จาก config (default "[v{version}]") → token ที่ต่อท้าย commit msg
VERSION_TAG=$(echo "$VERSION_BUMP_JSON" | jq -r '.append_tag // "[v{version}]"' | sed "s/{version}/$TARGET_VERSION/")
echo "🔢 Unified bump: BASE=$BASE → TARGET=v$TARGET_VERSION (ใช้กับทุก submodule ที่ commit)"
fi   # end no-change guard
```

🔴 **No change → no bump:** ถ้าไม่มี repo ไหนมี staged change → `TARGET_VERSION` ว่าง → Phase 6 ไม่ commit/ไม่ tag เลย (ไม่ปล่อย empty commit + ไม่เด้ง version ฟรี)
🔴 **`max()` บังคับ** — repo ที่อยู่ v0.2.77 จะไม่ถูกดึงกลับเป็น v0.2.76; ทั้ง web+app → **v0.2.78 พร้อมกัน**
🔴 `unified: false` (ไม่แนะนำ) → bump แต่ละ repo จาก current ของตัวเอง (legacy — version อาจไม่ตรงกัน)
🔴 **Default = `--no-bump`** (ไม่ระบุ `--bump` ก็ตกที่นี่) → ข้าม Phase 5.5 ทั้งหมด (ไม่ tag/ไม่ append/ไม่เขียน version file); Phase 5.5 รันเฉพาะเมื่อ user สั่ง `--bump` ชัดเจน

## Phase 6 — Commit + push per submodule (version เดียวกันทุก repo)

```bash
# Read path<TAB>read_only rows from the resolver. The read-only skip is driven by
# the TSV's second column in the SAME pass — no jq re-query against YAML.
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
bash "$RESOLVER" --submodules | while IFS="$(printf '\t')" read -r sub ro; do
  [ "$ro" = "true" ] && continue          # read-only submodule → skip
  [ -n "$sub" ] || continue

  cd "$sub"
  staged=$(git diff --cached --name-only)
  test -z "$staged" && { cd -; continue; }

  # --bump: ใช้ TARGET_VERSION เดียวกันทุก repo (Phase 5.5) — เขียน version file (ถ้าตั้ง) + append tag ใน msg
  if [ -n "${TARGET_VERSION:-}" ]; then
    for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
      [ -f "$vf" ] && bump_version_file "$vf" "$TARGET_VERSION"   # per-stack writer (package.json/pubspec/VERSION)
    done
    git add -A
    MSG="$msg $VERSION_TAG"               # เลขเดียวกันทุก repo
  else
    MSG="$msg"
  fi

  git commit -m "$MSG"
  # tag เดียวกันทุก repo (idempotent — ข้ามถ้ามีแล้ว)
  [ -n "${TARGET_VERSION:-}" ] && { git rev-parse "v$TARGET_VERSION" >/dev/null 2>&1 || git tag "v$TARGET_VERSION"; }
  test "$no_push" = "1" || { git push origin "$current_branch"; [ -n "${TARGET_VERSION:-}" ] && git push origin "v$TARGET_VERSION"; }
  cd -
done
```

🔴 **commit message + git tag ของทุก submodule ใช้ `v$TARGET_VERSION` ตัวเดียวกัน** — ไม่ bump แยกราย repo
🔴 push tag ด้วย (`git push origin v$TARGET_VERSION`) เพื่อ `/ow-fix-issue --ready-for-test` (Phase 8.5/8.3) detect version จาก tag ได้

## Phase 7 — Main repo commit

หลัง submodules push:
1. Stage submodule pointer updates ถ้ามี
2. Stage main repo files ตาม scope
3. Commit + push (เว้นแต่ `--no-push`)

## Phase 8 — Merge-to (optional)

ถ้า `--merge-to <branch>`:
- per repo: checkout target → merge --no-ff source → push
- ถ้า `--delete-source`: delete source local + remote

## Phase 8.5 — Auto issue-handoff (ready-for-test) — **หลัง push สำเร็จ**

จุดประสงค์: เมื่อ push นี้ปิด GitHub issue (`Closes #NN`) → comment "fixed in vX.Y.Z" + flip label ให้ tester อัตโนมัติ **ใน session เดียว** (ไม่ต้องสั่ง `/ow-fix-issue --ready-for-test` แยกเอง) เพราะ `/ow-git --bump` รู้เลข version เป๊ะอยู่แล้ว

### 8.5.1 Trigger gate (ต้องครบทุกข้อ — ไม่งั้น skip เงียบ)
- ✅ push เกิดจริง (ไม่ใช่ `--no-push` / `--status` / `--switch-only`)
- ✅ **มี issue ref ใน commit ที่เพิ่ง push** — scan `Closes #NN` / `Fixes #NN` จาก commit range ที่ push (ทุก repo) **หรือ** `--fix <fix-log>` ที่มี `github_issue:` frontmatter
- ✅ **ไม่มี** `--no-ready-for-test`

> commit ทั่วไป (plan/feat ที่ไม่มี `Closes #NN`) → gate ไม่ผ่าน → ไม่แตะ issue ใด ๆ (ปลอดภัยสำหรับการใช้ `/ow-git` ทั่วไป)

### 8.5.2 เก็บ issue numbers ที่ push ปิด
```bash
# RESOLVER = "$(git rev-parse --show-toplevel)/scripts/ow-paths.sh" (Phase 2)
# range = commit ที่เพิ่ง push รอบนี้: capture origin ref ของแต่ละ repo ก่อน push (Phase 6/7)
#         แล้วใช้ "<pre-push remote sha>..HEAD" (หรือ git log @{push}..HEAD หลัง push)
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  git -C "$repo" log "${PREPUSH_REF[$repo]}"..HEAD --format=%B 2>/dev/null \
    | grep -ioE '(close[sd]?|fixe?[sd]?|resolve[sd]?) #[0-9]+' | grep -oE '#[0-9]+'
done | sort -u
```
(`--fix` mode: เพิ่มเลขจาก fix-log `github_issue:` ด้วย)

### 8.5.3 Resolve version (authoritative จาก bump นี้)
- ถ้า `--bump` ใช้ในรอบนี้ → ใช้ **`$TARGET_VERSION` จาก Phase 5.5** (unified — เลขเดียวทุก submodule) ตรง ๆ ไม่ต้อง detect
- ถ้าไม่ได้ bump → fallback ตาม `/ow-fix-issue` Phase 8.3 (commit `[vX.Y.Z]` token > `git describe --tags`); หาไม่เจอ → ส่งต่อโดยไม่มี version (ให้ Phase 8 ของ fix-issue เตือน + ไม่ flip)

### 8.5.4 Delegate ไป `/ow-fix-issue` Phase 8 (reuse logic เดียว — ห้าม duplicate)
```
/ow-fix-issue <#NN #MM ...> --ready-for-test --version <vX.Y.Z>
```
ทำงานต่อใน session ปัจจุบัน — Phase 8 ของ fix-issue จะ verify-pushed (8.2, ผ่านอยู่แล้วเพราะเพิ่ง push) → comment version + flip `in progress`→`ready for test` (8.4) → อัปเดต fix-log `fixed_in_version` (8.5)

🔴 **ไม่ duplicate logic** — Phase 8.5 แค่ detect + เรียก; การ comment/flip/verify อยู่ที่ `/ow-fix-issue` Phase 8 ที่เดียว (single source)
🔴 **ยังคงกฎ ห้าม close** — handoff แค่ flip เป็น ready-for-test, tester verify ก่อน close

### 8.5.5 รวมผลเข้า Report (Phase 9)
แสดงใน summary ว่า issue ไหนถูก comment + flip (หรือ skipped พร้อมเหตุผล)

## Phase 8.6 — Fix-log version stamp — **หลัง push สำเร็จ**

จุดประสงค์: เมื่อ `--bump` push งานที่ปิด fix-log local (`/ow-implement` ตั้ง `fixed_commit: pending` ไว้ Phase 6.5 เพราะตอนนั้น commit/version ยังไม่เกิด) → เติม `fixed_in_version` + `fixed_commit` (sha จริง) ให้ fix-log — **mirror ของ 8.5** แต่ fix-log local ไม่มี GitHub issue → **ไม่ comment / ไม่ flip label** แค่ stamp frontmatter ให้ traceable. รองรับทั้ง option A (plan-driven) และ option B (`--from-fix`)

### 8.6.1 Trigger gate (ครบทุกข้อ ไม่งั้น skip เงียบ)
- ✅ `--bump` รันรอบนี้ (`$TARGET_VERSION` ไม่ว่าง = push + tag จริง, Phase 5.5)
- ✅ มี fix-log local ที่ push นี้ finalize — หาได้ 2 ทาง:
  - **option A** — `--plan <path>` ที่ plan มี `source_fix:` (escalate ผ่าน `/ow-plan fix:`)
  - **option B** — `--fix <fixlog>` ที่ fix-log มี `fixed_commit: pending` (P3 ผ่าน `/ow-implement --from-fix`, ไม่มี plan)

> ไม่ `--bump` / ไม่มี `--plan` ที่ `source_fix:` / ไม่มี `--fix` ที่ `pending` → gate ไม่ผ่าน → ไม่แตะ fix-log ใด (ปลอดภัยกับ `/ow-git` ทั่วไป — เหมือน 8.5). fix-log ที่มี `github_issue:` ไป Phase 8.5 (ไม่ใช่ที่นี่)

### 8.6.2 Resolve fix-log + stamp
```bash
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
[ -n "${TARGET_VERSION:-}" ] || exit 0          # ไม่ bump → ไม่ stamp
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
FIXLOG=""; AREA_HINT=""
if [ -n "${plan:-}" ]; then                      # option A — "$plan" = --plan <path> arg (Phase 4 scope)
  SRC=$(grep -m1 '^source_fix:' "$plan" | sed -E 's/^source_fix:[[:space:]]*//; s/^"?\[\[//; s/\]\]"?$//; s/\.md$//')
  if [ -n "$SRC" ] && [ "$SRC" != "none" ]; then
    FIXLOG=$(find "$FIX_DIR" -maxdepth 1 -name "${SRC##*/}.md" 2>/dev/null | head -1)
    [ -n "$FIXLOG" ] || echo "⚠ source_fix ชี้ fix-log ที่หาไม่เจอ: $SRC (ข้าม stamp)"
    # plan ไม่มี field repo — infer submodule จาก path ใน Affected Files เทียบ prefix กับ resolver --submodules
    PFILES=$(grep -oE '`[^`]+`' "$plan" | tr -d '`')
    for s in $(bash "$RESOLVER" --submodules | cut -f1); do
      printf '%s\n' "$PFILES" | grep -q "^$s/" && { AREA_HINT="$s"; break; }
    done
  fi
elif [ -n "${fix:-}" ] && grep -q '^fixed_commit:[[:space:]]*pending' "$fix" 2>/dev/null; then
  FIXLOG="$fix"                                  # option B — "$fix" = --fix <fixlog> ที่ยัง pending (จาก /ow-implement --from-fix)
  AREA_HINT=$(grep -m1 '^area:' "$fix" | sed -E 's/^area:[[:space:]]*//; s/[[:space:]].*$//')
fi
[ -n "$FIXLOG" ] || exit 0                        # ไม่มี fix-log ให้ stamp → safe-skip (ไม่แต่งอะไร)
# repo ที่ถือ commit งานนี้: monorepo/all/docs/cross → "."; multi-repo → submodule ที่ infer/area ชี้
case "$AREA_HINT" in
  ""|all|docs|main|cross) FIX_REPO="." ;;
  *) FIX_REPO=$(bash "$RESOLVER" --submodules | awk -v s="$AREA_HINT" '$1==s{print $1;exit}'); [ -n "$FIX_REPO" ] || FIX_REPO="." ;;
esac
FIX_SHA=$(git -C "$FIX_REPO" rev-parse --short HEAD)   # sha จริงจาก git — ไม่แต่ง
```

แก้ frontmatter ของ `$FIXLOG` (surgical **Edit**):
- `fixed_in_version: v$TARGET_VERSION`   (เลขเดียวกับ unified bump — Phase 5.5)
- `fixed_commit: $FIX_SHA`               (แทน `pending` ที่ `/ow-implement` ใส่ไว้ Phase 6.5)

🔴 **no-fake-evidence:** `fixed_in_version` = `$TARGET_VERSION` จาก Phase 5.5 (tag จริง); `fixed_commit` = sha จริงจาก git — ห้ามแต่ง/ห้ามเดา
🔴 fix-log local **ไม่มี** GitHub issue → ต่างจาก 8.5: **ไม่ยิง** `/ow-fix-issue --ready-for-test`, ไม่ comment, ไม่ flip label — แค่ stamp 2 field

### 8.6.3 รวมเข้า Report (Phase 9)
แสดงบรรทัด: `fix-log stamp (Phase 8.6) v$TARGET_VERSION: <fix-slug> ← plan <plan-slug>`

## Phase 9 — Report

แสดง (`--bump` → คอลัมน์ Version **ต้องเป็นเลขเดียวกันทุก submodule**):
```
git-sync summary
================
Repo   Branch     Pushed             Version
api    [develop]  8a77a02..2f7e850   v0.2.78
web    [develop]  b74346d..3b62477   v0.2.78
app    [master]   1357ace..9bd02f1   v0.2.78
main   [main]     99027c0..163b39e   —
assets [read-only] —                 skipped

ready-for-test handoff (Phase 8.5)  v0.2.78:  #62 #63 → ready for test ✅
fix-log stamp (Phase 8.6)           v0.2.78:  2026-06-08-1523-foo ← plan 2026-06-08-1533-bar
```
(บรรทัด Phase 8.6 แสดงเฉพาะเมื่อ plan ใน scope มี `source_fix:`; ไม่มี → ไม่แสดง)
🔴 **ไม่ต้องลงรายการ issue/fix ('Fixes' column) ใน table** — เป็นรายละเอียดของงาน ไม่ใช่สาระของ summary; เก็บไว้ใน commit message พอ
🔴 **Version column ของทุก submodule = เลขเดียวกัน** (จาก Phase 5.5 unified, สะท้อน tag จริง) — main repo (umbrella) ไม่มี version
(ถ้า gate ไม่ผ่าน — push ไม่มี `Closes #NN` หรือใช้ `--no-ready-for-test` — บรรทัด handoff ไม่แสดง)

## Output (3 หัวข้อบังคับ)

1. **Result** — git-sync summary table (repo / branch / pushed / version) + issue-handoff + fix-log stamp ที่เกิดขึ้น
2. **Verification / Evidence** — ทุก git command ที่รันจริง + exit codes + commit hashes / push results / branch per repo; ไม่ได้รัน = เขียน `pending evidence` หรือ `not run — <เหตุผล>`
3. **Limitations / Next steps** — files ที่ skip, conflicts ที่ต้อง resolve

## ห้าม

- ห้าม `git push --force` โดยไม่ explicit user confirm
- ห้าม commit ก่อนรัน /ow-secure
- ห้าม delete branch โดยไม่ verify ว่า merged
- ห้าม commit ที่ read-only submodule
- ห้าม `git reset --hard` โดยไม่ confirm
