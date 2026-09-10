#!/usr/bin/env bash
# obsidian-workflow — vault language gate (#33)
# ─────────────────────────────────────────────────────────────────────────────
# project.vault_language is advisory-only in command-spec prose: an agent can read
# the resolved $VAULT_LANG and still write chat-language prose into the vault, and
# nothing catches it until someone greps by hand. This is the mechanical gate:
# a script, not another instruction line, so it doesn't rely on the same agent
# remembering to self-police (root cause of #33).
#
# Scope: only NEW/MODIFIED vault files (working tree + staged + untracked, diffed
# against HEAD) — never touches pre-existing vault content (grandfathered per the
# v1.4.0 vault-language-split changelog).
#
# Skips (exit 0, no scan) when:
#   - VAULT_LANG == PROJECT_LANG (nothing to enforce — same language throughout)
#   - PROJECT_LANG's script isn't in the SCRIPT_RANGE map below (heuristic has no
#     pattern for it yet — extend the map rather than false-passing silently forever)
#
# Usage: bash scripts/ow-verify-vault-lang.sh   (root = resolver's own root-walk;
#                                                   honors OW_ROOT like every
#                                                   other obsidian-workflow script)
# Exit: 0 = clean/skipped, 1 = violations found (BLOCK), 2 = resolver failed (FATAL)

set -uo pipefail   # not -e: grep exits 1 on no-match, which must not abort the scan

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(bash "$SCRIPT_DIR/ow-paths.sh" --shell 2>/dev/null)" || {
  echo "FATAL: obsidian-workflow resolver missing/failed — run /<prefix>-init"; exit 2; }
[ -n "${VAULT_ABS:-}" ] || { echo "FATAL: resolver did not emit VAULT_ABS"; exit 2; }
[ -n "${ROOT:-}" ] || { echo "FATAL: resolver did not emit ROOT"; exit 2; }

echo "vault-lang gate (#33) — VAULT_LANG=$VAULT_LANG PROJECT_LANG=$PROJECT_LANG"

if [ "$VAULT_LANG" = "$PROJECT_LANG" ]; then
  echo "  skip: vault_language == project.language — nothing to enforce"
  exit 0
fi

# ── script-range heuristic map (chat-language script that must NOT leak into
#    prose once VAULT_LANG diverges from PROJECT_LANG) — extend as new languages
#    show up; an unmapped language skips (fail-open) rather than false-blocking.
script_range_for() {
  case "$1" in
    th)       printf '%s' '[ก-๛]' ;;
    ja)       printf '%s' '[぀-ヿ一-龯]' ;;
    zh|zh-*)  printf '%s' '[一-龯]' ;;
    ko)       printf '%s' '[가-힣]' ;;
    ru)       printf '%s' '[а-яА-Я]' ;;
    ar)       printf '%s' '[ء-ي]' ;;
    *)        printf '%s' '' ;;
  esac
}

# The ranges below are CODEPOINT ranges: grep only reads them that way under a UTF-8 locale.
# Under the C locale (how a script run from CI or a hook usually starts) grep compares BYTES, and
# `[ก-๛]` then spans byte values that also cover "—", "→" and "✓" — every English vault doc in this
# repo uses those, so the gate would BLOCK clean English prose. Pick a UTF-8 locale before scanning;
# if the machine has none, skip loudly rather than false-block.
if [ -z "${OW_LANG_LOCALE_OK:-}" ]; then
  _utf8_locale=""
  for _cand in "${LC_ALL:-}" "${LC_CTYPE:-}" "${LANG:-}" en_US.UTF-8 C.UTF-8; do
    case "$_cand" in *UTF-8|*utf8|*UTF8) _utf8_locale="$_cand"; break ;; esac
  done
  [ -n "$_utf8_locale" ] || _utf8_locale="$(locale -a 2>/dev/null | grep -iE '\.(utf-?8)$' | head -1)"
  if [ -z "$_utf8_locale" ]; then
    echo "  skip: no UTF-8 locale on this machine — a byte-range scan would flag any em dash as $PROJECT_LANG"
    exit 0
  fi
  export LC_ALL="$_utf8_locale" LC_CTYPE="$_utf8_locale"
fi

RANGE="$(script_range_for "$PROJECT_LANG")"
if [ -z "$RANGE" ]; then
  echo "  skip: no script heuristic mapped for project.language='$PROJECT_LANG' (extend script_range_for in $0)"
  exit 0
fi

# new/modified vault files: working tree + staged changes vs HEAD, plus untracked —
# never the whole vault, so pre-existing content is never re-flagged (scope note in #33).
# NUL-delimited (-z) and read whole-line: an Obsidian note is very often "My Note.md" or
# a title in the vault language, and word-splitting or git's default path-quoting would
# drop exactly those files — this gate would then report "clean" over unscanned prose.
LIST_TMP="$(mktemp)"
trap 'rm -f "$LIST_TMP"' EXIT
{ git -C "$ROOT" diff --name-only -z --diff-filter=ACMR HEAD 2>/dev/null
  git -C "$ROOT" ls-files --others --exclude-standard -z 2>/dev/null
} | tr '\0' '\n' | sort -u > "$LIST_TMP"

FAIL=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    *.md) ;;
    *) continue ;;
  esac
  abspath="$ROOT/$f"
  [ -f "$abspath" ] || continue
  case "$abspath" in
    "$VAULT_ABS"/*) ;;
    *) continue ;;
  esac

  # strip frontmatter + code fences + headings — scan prose body only
  hits=$(awk '
    NR==1 && /^---[[:space:]]*$/ { infm=1; next }
    infm && /^---[[:space:]]*$/  { infm=0; next }
    infm { next }
    /^[[:space:]]*```/ { incode = !incode; next }
    incode { next }
    /^[[:space:]]*#/ { next }
    { print NR": "$0 }
  ' "$abspath" | grep -E "$RANGE" 2>/dev/null)

  if [ -n "$hits" ]; then
    FAIL=1
    echo "  ✗ $f — prose in project.language script, expected vault_language=$VAULT_LANG:"
    printf '%s\n' "$hits" | sed 's/^/      /'
  fi
done < "$LIST_TMP"

if [ "$FAIL" -eq 0 ]; then
  echo "  ✓ clean — no $PROJECT_LANG-script prose in new/modified vault files"
  exit 0
else
  echo "  BLOCK: vault_language=$VAULT_LANG configured but new/modified vault prose above is in $PROJECT_LANG — rewrite in $VAULT_LANG"
  exit 1
fi
