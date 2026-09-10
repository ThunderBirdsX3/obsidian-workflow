#!/usr/bin/env bash
# obsidian-workflow — canonical version-file reader / writer / validator (#34)
# ─────────────────────────────────────────────────────────────────────────────
# The single writer for every version file `/ow-git --bump` touches. It exists
# because a version string that is merely *different* is not necessarily *valid*:
# a leading `v` leaking into pubspec.yaml or package.json produces a tagged,
# pushed release that cannot build at all (`flutter pub get` refuses to parse it),
# and the canonical file is re-read on the next bump, so one bad write poisons
# every future bump.
#
# CONVENTION (the whole point — the tag and the file are NOT the same string):
#   git tag       → `v<X.Y.Z>`      the `v` belongs on the tag
#   version file  → `<X.Y.Z>`       bare semver; pubspec/package.json reject a `v`
# `read` therefore strips a leading `v` defensively, and `validate` REJECTS one.
#
# API (paths are explicit — no resolver dependency, runs inside any submodule):
#   ow-version.sh normalize <version>            → bare X.Y.Z on stdout
#   ow-version.sh read      <file>               → the file's semver core (v stripped)
#   ow-version.sh write     <file> <version>     → write + read-back verify
#   ow-version.sh validate  <file> [expected]    → format gate (strict, no `v`)
#   ow-version.sh kind      <file>               → detected stack writer
#
# Options (write):
#   --build increment|preserve|drop   build-number policy for a `X.Y.Z+<digits>`
#                                     file (pubspec). Default: increment — an iOS
#                                     build number must strictly increase, so
#                                     carrying the old one forward breaks the store submission.
#                                     Zero-padding width is preserved.
#
# EXIT CODES ARE THE CONTRACT — the caller (Phase 6/7 of /ow-git) must STOP on
# any non-zero BEFORE it commits, tags or pushes:
#   0  ok
#   1  usage error
#   2  malformed version argument / malformed version in file
#   3  unsupported file type (never a silent skip — an unwritten version file
#      drifts behind the tag, which the spec forbids)
#   4  file missing, or no version field found in it
#   5  read-back mismatch after write / validate mismatch vs expected
#   6  malformed build number (non-numeric under --build increment)
#
# Supported: VERSION-like plain file · package.json · pubspec.yaml ·
#            pyproject.toml · Cargo.toml · *.csproj/*.props/*.vbproj/*.fsproj

set -uo pipefail

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
BUILD_POLICY="increment"

die() { local c="$1"; shift; printf '%s\n' "$*" >&2; exit "$c"; }

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -40
  exit "${1:-1}"
}

# ── version-string helpers ───────────────────────────────────────────────────
# strip ONE leading v/V + surrounding whitespace. `vv1.0.0` stays invalid on
# purpose — a second prefix means someone hand-edited it and must be told.
_strip_v() {
  local v="$1"
  v="$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  v="${v#v}"; v="${v#V}"
  printf '%s' "$v"
}

_core()  { printf '%s' "${1%%+*}"; }                                  # X.Y.Z from X.Y.Z+B
_build() { case "$1" in *+*) printf '%s' "${1#*+}" ;; *) : ;; esac; } # B from X.Y.Z+B

_normalize() {
  local v; v="$(_strip_v "${1:-}")"
  printf '%s' "$v" | grep -Eq "$SEMVER_RE" || return 1
  printf '%s' "$v"
}

# ── stack detection ──────────────────────────────────────────────────────────
_kind() {
  local f="$1" b; b="$(basename "$f")"
  case "$b" in
    package.json)                        printf 'json' ;;
    pubspec.yaml|pubspec.yml)            printf 'pubspec' ;;
    pyproject.toml)                      printf 'toml' ;;
    Cargo.toml)                          printf 'cargo' ;;
    *.csproj|*.props|*.vbproj|*.fsproj)  printf 'msbuild' ;;
    VERSION|VERSION.txt|version|version.txt|*.version) printf 'plain' ;;
    *)
      # heuristic: a file whose entire content is one version token is plain
      if [ -f "$f" ] \
         && [ "$(grep -cv '^[[:space:]]*$' "$f" 2>/dev/null || echo 0)" = "1" ] \
         && grep -Eq '^[[:space:]]*v?[0-9]+\.[0-9]+\.[0-9]+' "$f" 2>/dev/null; then
        printf 'plain'
      fi ;;
  esac
}

# first `version = "..."` inside the named TOML sections (never a dependency's)
_toml_read() {
  awk -v want="$2" '
    BEGIN { n = split(want, w, ","); insec = 0 }
    /^[[:space:]]*\[/ {
      insec = 0
      for (i = 1; i <= n; i++) if ($0 ~ "^[[:space:]]*\\[" w[i] "\\][[:space:]]*$") insec = 1
      next
    }
    insec && /^[[:space:]]*version[[:space:]]*=/ {
      line = $0
      sub(/^[^=]*=[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/["'"'"']/, "", line)
      sub(/[[:space:]]+$/, "", line)
      print line; exit
    }
  ' "$1"
}

_toml_write() {
  local f="$1" sections="$2" val="$3" tmp; tmp="$f.ow-tmp.$$"
  awk -v want="$sections" -v val="$val" '
    BEGIN { n = split(want, w, ","); insec = 0; done = 0 }
    /^[[:space:]]*\[/ {
      insec = 0
      for (i = 1; i <= n; i++) if ($0 ~ "^[[:space:]]*\\[" w[i] "\\][[:space:]]*$") insec = 1
      print; next
    }
    insec && !done && /^[[:space:]]*version[[:space:]]*=/ {
      match($0, /^[[:space:]]*/)
      printf "%sversion = \"%s\"\n", substr($0, 1, RLENGTH), val
      done = 1; next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# ── raw read (the version exactly as stored, `v` and +build included) ────────
_raw_read() {
  local f="$1" k="$2" out=""
  case "$k" in
    plain)   out="$(grep -v '^[[:space:]]*$' "$f" | head -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" ;;
    json)
      if command -v jq >/dev/null 2>&1; then out="$(jq -r '.version // empty' "$f" 2>/dev/null)"
      else out="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)"; fi ;;
    pubspec) out="$(sed -n 's/^version:[[:space:]]*//p' "$f" | head -1 | sed -e 's/[[:space:]]*#.*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//' -e 's/[[:space:]]*$//')" ;;
    toml)    out="$(_toml_read "$f" 'project,tool.poetry')" ;;
    cargo)   out="$(_toml_read "$f" 'package')" ;;
    msbuild) out="$(sed -n 's/.*<Version>\([^<]*\)<\/Version>.*/\1/p' "$f" | head -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" ;;
  esac
  printf '%s' "$out"
}

# ── subcommand: kind ─────────────────────────────────────────────────────────
cmd_kind() {
  local f="${1:-}"; [ -n "$f" ] || usage 1
  local k; k="$(_kind "$f")"
  [ -n "$k" ] || die 3 "ow-version: unsupported version file: $f (no writer for this stack — add one or drop it from version_bump.files)"
  printf '%s\n' "$k"
}

# ── subcommand: normalize ────────────────────────────────────────────────────
cmd_normalize() {
  local v; v="$(_normalize "${1:-}")" \
    || die 2 "ow-version: malformed version '${1:-}' — expected bare X.Y.Z (the 'v' belongs on the git tag, not in the file)"
  printf '%s\n' "$v"
}

# ── subcommand: read (lenient — strips a leaked `v` so it cannot poison a bump) ──
cmd_read() {
  local f="${1:-}"; [ -n "$f" ] || usage 1
  [ -f "$f" ] || die 4 "ow-version: no such file: $f"
  local k; k="$(_kind "$f")"
  [ -n "$k" ] || die 3 "ow-version: unsupported version file: $f"
  local raw; raw="$(_raw_read "$f" "$k")"
  [ -n "$raw" ] || die 4 "ow-version: no version field found in $f"
  local core; core="$(_core "$(_strip_v "$raw")")"
  printf '%s' "$core" | grep -Eq "$SEMVER_RE" \
    || die 2 "ow-version: $f holds a malformed version '$raw' — expected X.Y.Z[+build]; fix it by hand before bumping"
  printf '%s\n' "$core"
}

# ── subcommand: validate (STRICT — this is the gate that runs before tag/push) ──
cmd_validate() {
  local f="${1:-}" expected="${2:-}"
  [ -n "$f" ] || usage 1
  [ -f "$f" ] || die 4 "ow-version: no such file: $f"
  local k; k="$(_kind "$f")"
  [ -n "$k" ] || die 3 "ow-version: unsupported version file: $f"
  local raw; raw="$(_raw_read "$f" "$k")"
  [ -n "$raw" ] || die 4 "ow-version: no version field found in $f"

  case "$raw" in
    v*|V*) die 5 "ow-version: $f holds '$raw' — a version FILE must be bare semver; the 'v' belongs on the git tag only" ;;
  esac

  local core build; core="$(_core "$raw")"; build="$(_build "$raw")"
  printf '%s' "$core" | grep -Eq "$SEMVER_RE" \
    || die 2 "ow-version: $f holds a malformed version '$raw' — expected X.Y.Z[+build]"
  if [ -n "$build" ]; then
    printf '%s' "$build" | grep -Eq '^[0-9]+$' \
      || die 6 "ow-version: $f build number '+$build' is not numeric — an iOS/Android build number must be digits only"
  fi

  if [ -n "$expected" ]; then
    local want; want="$(_normalize "$expected")" || die 2 "ow-version: malformed expected version '$expected'"
    [ "$core" = "$want" ] || die 5 "ow-version: $f holds $core but the bump targeted $want"
  fi
  printf '%s\n' "$raw"
}

# ── subcommand: write ────────────────────────────────────────────────────────
cmd_write() {
  local f="${1:-}" v="${2:-}"
  [ -n "$f" ] && [ -n "$v" ] || usage 1
  [ -f "$f" ] || die 4 "ow-version: no such file: $f"

  local ver; ver="$(_normalize "$v")" \
    || die 2 "ow-version: refusing to write malformed version '$v' into $f — expected bare X.Y.Z (the 'v' belongs on the git tag)"
  # defensive strip, never silent: a `v` reaching the writer means the caller is
  # wrong, and the file it would poison is re-read on the next bump.
  [ "$ver" = "$v" ] || printf 'ow-version: stripped the tag prefix from "%s" → %s before writing %s (a version FILE is bare semver)\n' "$v" "$ver" "$f" >&2

  local k; k="$(_kind "$f")"
  [ -n "$k" ] || die 3 "ow-version: unsupported version file: $f (no writer for this stack — add one or drop it from version_bump.files)"

  # build number: only a file that already carries one keeps one
  local old build new_build=""
  old="$(_raw_read "$f" "$k")"
  build="$(_build "$(_strip_v "$old")")"
  if [ -n "$build" ] && [ "$BUILD_POLICY" != "drop" ]; then
    if [ "$BUILD_POLICY" = "preserve" ]; then
      new_build="$build"
    else
      printf '%s' "$build" | grep -Eq '^[0-9]+$' \
        || die 6 "ow-version: $f build number '+$build' is not numeric — cannot increment. Fix it by hand, or set version_bump.build_number: preserve"
      new_build="$(printf "%0${#build}d" "$((10#$build + 1))")"
    fi
  fi

  local target="$ver"; [ -n "$new_build" ] && target="$ver+$new_build"
  local tmp="$f.ow-tmp.$$"

  case "$k" in
    plain)
      printf '%s\n' "$target" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; die 1 "ow-version: write failed: $f"; } ;;
    json)
      command -v jq >/dev/null 2>&1 || die 1 "ow-version: jq is required to write $f"
      jq --arg v "$target" --indent 2 '.version = $v' "$f" > "$tmp" && mv "$tmp" "$f" \
        || { rm -f "$tmp"; die 1 "ow-version: write failed: $f"; } ;;
    pubspec)
      awk -v val="$target" '
        !done && /^version:/ { print "version: " val; done = 1; next }
        { print }
      ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; die 1 "ow-version: write failed: $f"; } ;;
    toml)    _toml_write "$f" 'project,tool.poetry' "$target" || die 1 "ow-version: write failed: $f" ;;
    cargo)   _toml_write "$f" 'package' "$target" || die 1 "ow-version: write failed: $f" ;;
    msbuild)
      awk -v val="$target" '
        !done && /<Version>[^<]*<\/Version>/ {
          sub(/<Version>[^<]*<\/Version>/, "<Version>" val "</Version>"); done = 1
        }
        { print }
      ' "$f" > "$tmp" && mv "$tmp" "$f" || { rm -f "$tmp"; die 1 "ow-version: write failed: $f"; } ;;
  esac

  # read-back: the write is only real if the file parses back to what we meant.
  # A diff-only check ("the number changed") passes on a malformed value too.
  local back; back="$(_raw_read "$f" "$k")"
  [ "$back" = "$target" ] \
    || die 5 "ow-version: read-back mismatch in $f — wrote '$target', file now reads '$back'"
  cmd_validate "$f" "$ver" >/dev/null
  printf '%s\n' "$target"
}

# ── dispatch ─────────────────────────────────────────────────────────────────
SUB="${1:-}"; [ -n "$SUB" ] || usage 1
shift || true

ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --build) BUILD_POLICY="${2:-increment}"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
case "$BUILD_POLICY" in
  increment|preserve|drop) ;;
  *) die 1 "ow-version: --build must be increment|preserve|drop (got '$BUILD_POLICY')" ;;
esac

case "$SUB" in
  normalize) cmd_normalize "${ARGS[@]:-}" ;;
  read)      cmd_read      "${ARGS[@]:-}" ;;
  write)     cmd_write     "${ARGS[@]:-}" ;;
  validate)  cmd_validate  "${ARGS[@]:-}" ;;
  kind)      cmd_kind      "${ARGS[@]:-}" ;;
  -h|--help) usage 0 ;;
  *)         die 1 "ow-version: unknown subcommand '$SUB' (normalize|read|write|validate|kind)" ;;
esac
