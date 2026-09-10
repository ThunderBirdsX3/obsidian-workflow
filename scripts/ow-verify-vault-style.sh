#!/usr/bin/env bash
# obsidian-workflow — vault present-tense gate
# ─────────────────────────────────────────────────────────────────────────────
# A vault doc must state the project AS IT IS NOW: no "เดิม X → ใหม่ Y", no
# "changed from … to …", no "## Changelog" section. The record of a change lives
# in the plan / fix-log / test-plan / handoff of the run that made it, and the
# previous wording lives in git — not inline in a spec doc, where the next reader
# cannot tell which half is still true.
#
# The contract itself (what to write instead, how an ADR names a rejected option,
# how to update a doc that is now wrong) is ONE file:
#     .ow/commands/_shared/vault-doc-style.md
# This script is only its mechanical half — prose in a spec is advisory until a
# gate reads it, which is exactly how the vault-language rule (#33) leaked before
# scripts/ow-verify-vault-lang.sh existed.
#
# Scope: only NEW/MODIFIED vault files (working tree + staged + untracked, diffed
# against HEAD) — pre-existing vault content is grandfathered and never re-flagged,
# the same rule the #33 gate follows.
#
# Exempt folders (a change record is their SUBJECT matter, not a defect) — taken
# from the resolver, never hardcoded, so a project that renamed a folder in
# .ow.yml keeps its exemption:
#     $PLAN_DIR (80-ImplementPlan) · $FIX_DIR (85-FixLog)
#     $TEST_DIR (90-TestPlan)      · $HANDOFF_DIR (95-Handoff)
#
# Frontmatter and fenced code blocks are skipped (a quoted diff or a sample log is
# not narration). Headings ARE scanned — "## What changed" is the exact section
# this gate exists to keep out of a spec doc.
#
# Usage: bash scripts/ow-verify-vault-style.sh   (root = resolver's own root-walk;
#                                                   honors OW_ROOT like every
#                                                   other obsidian-workflow script)
# Exit: 0 = clean, 1 = violations found (BLOCK), 2 = resolver failed (FATAL)

set -uo pipefail   # not -e: grep exits 1 on no-match, which must not abort the scan

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

eval "$(bash "$SCRIPT_DIR/ow-paths.sh" --shell 2>/dev/null)" || {
  echo "FATAL: obsidian-workflow resolver missing/failed — run /<prefix>-init"; exit 2; }
[ -n "${VAULT_ABS:-}" ] || { echo "FATAL: resolver did not emit VAULT_ABS"; exit 2; }
[ -n "${ROOT:-}" ] || { echo "FATAL: resolver did not emit ROOT"; exit 2; }

echo "vault present-tense gate — vault=$VAULT_PATH"

# ── the banned forms ─────────────────────────────────────────────────────────
# Kept deliberately tight: every alternative below narrates an EDIT. Wording that
# merely states a current fact ("X is no longer supported", "สถานะเปลี่ยนเป็น
# approved") is legitimate present tense and must not be listed here — a gate that
# cries wolf gets bypassed, and then the real ones ship too.
PROSE_RE='จากเดิม|เดิม(เป็น|คือ|ใช้|กำหนด|ตั้ง|ชื่อ|ระบุ)|เปลี่ยนจาก|เปลี่ยนมาจาก|แก้(ไข)?จาก|แทนที่(ของ)?เดิม|ของเดิม|เมื่อก่อน|แต่ก่อน|เคย(เป็น|ใช้|ชื่อ)|changed from .+ to |previously (was|used|named|called|set)|used to be|formerly|renamed from|replaced the (old|previous)|migrated from .+ to |instead of the (old|previous)'

# Section headings whose whole purpose is a change record. `##ประวัติการแก้ไข` /
# `## What changed` belong in the plan or fix-log, never in a spec doc.
HEAD_RE='^[0-9]+:[[:space:]]*#+[[:space:]]*.*(changelog|change log|change history|revision history|version history|what changed|ประวัติการแก้ไข|ประวัติการเปลี่ยนแปลง|สิ่งที่เปลี่ยน)'

# new/modified vault files: working tree + staged changes vs HEAD, plus untracked —
# never the whole vault, so pre-existing content is never re-flagged.
# NUL-delimited (-z) and read whole-line: an Obsidian note is very often "My Note.md"
# or a title in the vault language, and word-splitting or git's default path-quoting
# would drop exactly those files — a silent PASS is worse than no gate at all.
LIST_TMP="$(mktemp)"
trap 'rm -f "$LIST_TMP"' EXIT
{ git -C "$ROOT" diff --name-only -z --diff-filter=ACMR HEAD 2>/dev/null
  git -C "$ROOT" ls-files --others --exclude-standard -z 2>/dev/null
} | tr '\0' '\n' | sort -u > "$LIST_TMP"

SCANNED=0
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
  # exempt folders — a plan/fix-log/test-plan/handoff records one run, so "X → Y"
  # is what it is FOR
  skip=0
  for ex in "${PLAN_DIR:-}" "${FIX_DIR:-}" "${TEST_DIR:-}" "${HANDOFF_DIR:-}"; do
    [ -n "$ex" ] || continue
    case "$abspath" in "$ex"/*) skip=1 ;; esac
  done
  [ "$skip" = 1 ] && continue
  SCANNED=$((SCANNED + 1))

  # strip frontmatter + fenced code — scan prose and headings only
  body=$(awk '
    NR==1 && /^---[[:space:]]*$/ { infm=1; next }
    infm && /^---[[:space:]]*$/  { infm=0; next }
    infm { next }
    /^[[:space:]]*```/ { incode = !incode; next }
    incode { next }
    { print NR": "$0 }
  ' "$abspath")

  hits=$(printf '%s\n' "$body" | grep -iE "$PROSE_RE" 2>/dev/null)
  head_hits=$(printf '%s\n' "$body" | grep -iE "$HEAD_RE" 2>/dev/null)
  [ -n "$head_hits" ] && hits=$(printf '%s\n%s' "$hits" "$head_hits" | grep -v '^$' | sort -n -u)

  if [ -n "$hits" ]; then
    FAIL=1
    echo "  ✗ $f — narrates a change instead of stating the present:"
    printf '%s\n' "$hits" | sed 's/^/      /'
  fi
done < "$LIST_TMP"

if [ "$FAIL" -eq 0 ]; then
  echo "  ✓ clean — $SCANNED new/modified vault file(s) scanned, none narrate an edit"
  exit 0
else
  echo "  BLOCK: rewrite the lines above as current truth (the value that is true today, alone)."
  echo "         The before/after belongs in the plan (80-ImplementPlan) or fix-log (85-FixLog)"
  echo "         of the run that made the change — contract: .ow/commands/_shared/vault-doc-style.md"
  exit 1
fi
