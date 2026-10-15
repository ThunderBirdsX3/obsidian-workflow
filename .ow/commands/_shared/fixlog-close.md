# `_shared/fixlog-close.md` — close the source fix-log (#30)

Read this **only when the work is fix-escalated**: the plan carries `source_fix:`, or the run was invoked as
`/ow-implement --from-fix <fix-log-path>`. Neither ⇒ skip silently, there is nothing to close.

🔴 **bi-directional close:** plan `done` (or `--from-fix` finished) ⇒ fix-log `fixed`, always:
no fix-log left at `in-progress` once the work that owns it is done.

## 0. `--from-fix` entry gate (`/ow-implement` Phase 1.1)

`--from-fix` accepts only a fix-log with `severity: P2` or `P3`. In this mode the **fix-log is the unit of
work** (there is no separate plan): Phase 1 skips the `status: approved` gate (invoking it = approval); the
build-test/coverage/discipline gates (5.0/5.2/5.3) + the open-checkbox gate (6.0) run against the fix-log;
Phase 6 closes the fix-log as `status: fixed` via §1–§2 below.

```bash
SEV=$(grep -m1 '^severity:' "$PLAN_PATH" | sed -E 's/^severity:[[:space:]]*//; s/[[:space:]]*—.*$//' | tr -d '"')
case "$SEV" in
  P2|P3) ;;
  *) echo "🛑 STOP: --from-fix accepts only P2/P3 (this fix-log = ${SEV:-unset}) → /ow-plan fix:<slug>"; exit 1 ;;
esac
```

🔴 Empty/unreadable severity = **refuse** (fail-closed) — never assume it is P3

## 1. Resolve the fix-log

```bash
. "$(git rev-parse --show-toplevel)/.ow/local/paths.env"
[ -n "$FIX_DIR" ] || { echo 'FATAL: Phase 0 not loaded'; exit 1; }
TGT=$(echo "$PLAN_PATH" | sed -E 's/^--from-fix[[:space:]]+//')   # resolved target file: plan (normal) | fix-log (--from-fix); $PLAN_PATH = flag-stripped (Phase 2.7.1)
FIXLOG=""
if grep -q 'type/fix-log' "$TGT" 2>/dev/null; then
  FIXLOG="$TGT"                                  # --from-fix: the target IS the fix-log itself
else
  # plan with source_fix: (wikilink/path) → resolve the fix-log slug under $FIX_DIR
  SRC=$(grep -m1 '^source_fix:' "$TGT" | sed -E 's/^source_fix:[[:space:]]*//; s/^"?\[\[//; s/\]\]"?$//; s/\.md$//')
  { [ -z "$SRC" ] || [ "$SRC" = "none" ]; } && SRC=""
  [ -n "$SRC" ] && FIXLOG=$(find "$FIX_DIR" -maxdepth 1 -name "${SRC##*/}.md" 2>/dev/null | head -1)
  # 🔴 SRC is set but the fix-log is not found (e.g. it was renamed after the plan) → STOP, do not flip the plan done silently
  [ -n "$SRC" ] && [ -z "$FIXLOG" ] && { echo "🛑 STOP: source_fix points at a fix-log that cannot be found: $SRC (broken link)"; exit 1; }
fi
# (neither a --from-fix fix-log target nor a plan source_fix → not fix-escalated → skip silently)
```

## 2. Close it

`$FIXLOG` found and its `status` is not yet `fixed`/`wont-fix`:

1. Frontmatter (surgical **Edit**): `status: fixed` · `fixed_commit: pending`
   (🔴 the real sha is filled by `/ow-git --bump` Phase 8.6 — `/ow-implement` does not commit to the main tree
   itself; **never** write a HEAD sha that is not yet this work's commit = no fake results) ·
   leave `fixed_in_version` for `/ow-git` to stamp
2. Tick only the checkboxes **actually proven** in the fix-log's `## Test Cases` (+ `## Success Criteria` if
   present) — map them to the build/test run (5.0) + the red→green run in this implement; an unproven item stays
   `[ ]` + a note (🔴 never tick blindly)
