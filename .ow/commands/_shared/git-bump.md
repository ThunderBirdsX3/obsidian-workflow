# `_shared/git-bump.md` — `/ow-git --bump`: unified version, version files, tags

Read this **only when the user passed `--bump patch|minor|major`**. A plain commit never opens it.

Three steps, each hooked from `/ow-git`: §1 runs as Phase 5.5 (before any commit) · §2 runs in
every repo that commits, right before its `git commit` · §3 runs right after that commit.

🔴 **One number everywhere** — every repo that commits this round, **including main**, gets the
same `$TARGET_VERSION` (config `version_bump.unified`, default true). Never bump repos one by one
until web=v0.2.76 / app=v0.2.77
🔴 **Tag vs file are not the same string** (#34) — `$TARGET_VERSION` is always **bare**; the `v`
is added only at `git tag` / tag push:

| what | value | why |
|---|---|---|
| git tag | `v$TARGET_VERSION` — e.g. `v0.3.36` | the `v` belongs on a git tag |
| version file | bare `$TARGET_VERSION` — e.g. `0.3.36` | `pubspec.yaml` / `package.json` / `Cargo.toml` **reject** a `v` and the release will not build |

## §1 Resolve unified bump version (Phase 5.5)

```bash
RESOLVER="$(git rev-parse --show-toplevel)/scripts/ow-paths.sh"
VERW="$(git rev-parse --show-toplevel)/scripts/ow-version.sh"
KIND="<patch|minor|major from --bump>"
[ -f "$VERW" ] || { echo "🛑 scripts/ow-version.sh missing — run: bash scripts/upgrade.sh (a commands-only /ow-sync does not ship scripts/)"; exit 1; }

# 0) no staged change anywhere → no commit, no bump, no tag
CHANGED=0
for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
  [ -n "$(git -C "$repo" diff --cached --name-only 2>/dev/null)" ] && CHANGED=1
done
if [ "$CHANGED" = "0" ]; then
  echo "ℹ️ No staged change — skipping commit + bump entirely (no tag, no push)"; TARGET_VERSION=""
else
  # 1) current version per repo = latest vX.Y.Z tag (none = 0.0.0) + every version file.
  #    fetch tags FIRST — a teammate's tag that exists only on origin would otherwise make this
  #    round compute the SAME number (tag push collides, exit 5). Offline ⇒ local tags only.
  vers=()
  for repo in . $(bash "$RESOLVER" --submodules | cut -f1); do
    git -C "$repo" fetch --tags --quiet origin 2>/dev/null || true
    v=$(git -C "$repo" tag --list 'v*.*.*' | sed 's/^v//' | sort -V | tail -1)
    vers+=("${v:-0.0.0}")
    for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
      [ -f "$repo/$vf" ] || continue
      fv=$(bash "$VERW" read "$repo/$vf" 2>/dev/null) && [ -n "$fv" ] && vers+=("$fv")
    done
  done
  # 2) BASE = max(current across every repo) — never walk back a repo that is ahead
  BASE=$(printf '%s\n' "${vers[@]:-0.0.0}" | sort -V | tail -1)
  # 3) TARGET_VERSION = bump(BASE, KIND) — computed once
  IFS=. read -r MA MI PA <<<"$BASE"
  case "$KIND" in
    major) MA=$((MA+1)); MI=0; PA=0 ;;
    minor) MI=$((MI+1)); PA=0 ;;
    *)     PA=$((PA+1)) ;;
  esac
  TARGET_VERSION="$MA.$MI.$PA"
  VERSION_TAG=$(echo "$VERSION_BUMP_JSON" | jq -r '.append_tag // "[v{version}]"' | sed "s/{version}/$TARGET_VERSION/")
  echo "🔢 Unified bump: BASE=$BASE → TARGET=v$TARGET_VERSION (every repo that commits, including main)"
fi
```

Phase 6/7 run in fresh shells — carry `TARGET_VERSION` and `VERSION_TAG` into them by value.
`unified: false` (legacy, not recommended) → bump each repo from its own current version.

## §2 Write version files (inside each committing repo, right before `git commit`)

```bash
VERW="$(git rev-parse --show-toplevel)/scripts/ow-version.sh"
BUILD_POLICY=$(echo "$VERSION_BUMP_JSON" | jq -r '.build_number // "increment"' 2>/dev/null); BUILD_POLICY="${BUILD_POLICY:-increment}"
for vf in $(echo "$VERSION_BUMP_JSON" | jq -r '.files[]? // empty'); do
  [ -f "$vf" ] || continue
  bash "$VERW" write "$vf" "$TARGET_VERSION" --build "$BUILD_POLICY" >/dev/null \
    || { echo "🛑 $repo: version write failed for $vf — nothing committed, nothing tagged"; exit 1; }
  bash "$VERW" validate "$vf" "$TARGET_VERSION" >/dev/null \
    || { echo "🛑 $repo: $vf failed the version format gate — nothing committed, nothing tagged"; exit 1; }
done
echo "$VERSION_BUMP_JSON" | jq -r '.verify_cmd[]? // empty' | while IFS= read -r vcmd; do
  [ -n "$vcmd" ] || continue
  sh -c "$vcmd" >/dev/null 2>&1 || { echo "🛑 $repo: version verify_cmd failed: $vcmd"; exit 1; }
done || exit 1
git add -A
```

🔴 **Version files go through `scripts/ow-version.sh`, never by hand** (#34) — it forces bare
semver, keeps a `+build` suffix numeric and increasing, and **reads the file back**. "The number
changed" is not a check: a malformed value changes too. Any non-zero exit STOPs before commit/tag/
push: `2` malformed · `3` unsupported file type · `4` file missing / no version field · `5` read-back
mismatch · `6` non-numeric build number. This helper's absence is fatal (unlike `ow-git-sync.sh`):
degrading means an ad-hoc write — the defect itself
🔴 **Never revert a version file** — the only skip is an empty staged diff. A repo with any real
change (even docs-only) gets the bump. Main's root `VERSION` is canonical and moves on every `--bump`

## §3 Tag + push the tag (right after `git commit`; push part only without `--no-push`)

```bash
SYNC="$(git rev-parse --show-toplevel)/scripts/ow-git-sync.sh"
git rev-parse "v$TARGET_VERSION" >/dev/null 2>&1 || git tag "v$TARGET_VERSION"
if [ "$no_push" != "1" ]; then
  if [ ! -x "$SYNC" ]; then git push origin "v$TARGET_VERSION"; rc=$?; else bash "$SYNC" push-tag "$repo" "v$TARGET_VERSION"; rc=$?; fi
  [ $rc -eq 5 ] && { echo "🛑 $repo: v$TARGET_VERSION already exists on origin — a teammate took this number. Commits are pushed; re-run with --bump to claim the next one. The remote tag is NOT moved."; exit 1; }
  [ $rc -eq 0 ] || { echo "🛑 $repo: tag push failed"; exit 1; }
fi
```

The pushed tag is how `/ow-fix-issue --ready-for-test` (Phase 8.5) detects the version.
