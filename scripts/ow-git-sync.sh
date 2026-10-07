#!/usr/bin/env bash
# obsidian-workflow — git sync helper for multi-person (shared-branch) work
# ─────────────────────────────────────────────────────────────────────────────
# WHY THIS IS A SCRIPT AND NOT PROSE: the conflict classifier below decides whether
# a file is auto-resolved or handed to a human. A rule that lives only in a command
# spec runs a little differently every session; here it is deterministic and covered
# by scripts/test.sh. Never move this logic back into prose.
#
# Consumers: /ow-git (Phase 2.5 sync, Phase 6/7 push) and _shared/git-sync.md.
#
# API
#   ow-git-sync.sh status   <repo>                → "<ahead>\t<behind>\t<upstream>"
#   ow-git-sync.sh sync     <repo>                → fetch + rebase|merge onto upstream
#   ow-git-sync.sh classify <repo>                → "<class>\t<file>" per conflicted file (no writes)
#   ow-git-sync.sh resolve  <repo>                → auto-resolve safe classes in the current conflict
#   ow-git-sync.sh continue <repo>                → after files were resolved by hand/AI: resolve safe
#                                                   classes + rebase --continue (or merge commit) until done
#   ow-git-sync.sh sides    <repo> <file>         → evidence for a conflicted file: commits per side
#                                                   + the plan / fix-log files those commits touched
#   ow-git-sync.sh push     <repo> <branch>       → push, sync+retry on non-fast-forward
#   ow-git-sync.sh push-tag <repo> <tag>          → push one tag; collision NEVER retried/forced
#   ow-git-sync.sh config                         → print effective knobs (debug/test)
#
# EXIT CODES (shared by every subcommand — callers branch on these)
#   0  ok / already in sync / nothing to do
#   1  hard error (bad args, not a repo, unexpected git failure)
#   3  CONFLICT LEFT FOR A HUMAN — stop the calling command: no commit, no push, no bump
#   4  SKIPPED (no remote / no upstream / fetch failed = offline) — not an error
#   5  TAG COLLISION — remote already owns this tag; never moved, never forced
#
# INVARIANTS (mirrored in _shared/git-sync.md — keep both in step)
#   - never `push --force` / `--force-with-lease`, in any path
#   - never `rebase --abort` on the user's behalf: a stopped rebase is left in place
#     so the human can finish it
#   - never resolve silently: every auto-resolved file is printed on stdout as
#     "resolved\t<class>\t<file>"
#   - never trust a rebase exit 0 on its own: an autostash that pops with conflicts still
#     exits 0, so the success path re-checks for unmerged files and returns 3 instead
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '%s\n' "$*" >&2; }
emit() { printf '%s\n' "$*"; }

# ── config ───────────────────────────────────────────────────────────────────
# Knobs come from the `git:` block in .ow.yml via the resolver. Env vars
# override (tests + one-off runs). Resolver absent ⇒ built-in defaults, because a
# sync helper must never be the reason a command cannot run.
GIT_SYNC_JSON="${OW_GIT_SYNC_JSON:-}"
if [ -z "$GIT_SYNC_JSON" ] && [ -x "$SCRIPT_DIR/ow-paths.sh" ]; then
  GIT_SYNC_JSON=$(bash "$SCRIPT_DIR/ow-paths.sh" --check GIT_SYNC_JSON 2>/dev/null || echo '')
fi
[ -n "$GIT_SYNC_JSON" ] && [ "$GIT_SYNC_JSON" != "null" ] || GIT_SYNC_JSON='{}'

_cfg() {  # _cfg <jq-path> <default>
  local v
  v=$(printf '%s' "$GIT_SYNC_JSON" | jq -r "$1 // empty" 2>/dev/null || echo '')
  [ -n "$v" ] && [ "$v" != "null" ] || v="$2"
  printf '%s' "$v"
}

AUTO_SYNC="${OW_GIT_AUTO_SYNC:-$(_cfg '.auto_sync' 'true')}"
STRATEGY="${OW_GIT_STRATEGY:-$(_cfg '.strategy' 'rebase')}"
PUSH_RETRY="${OW_GIT_PUSH_RETRY:-$(_cfg '.push_retry' '1')}"
AUTO_RESOLVE="${OW_GIT_AUTO_RESOLVE:-$(printf '%s' "$GIT_SYNC_JSON" | jq -r '(.auto_resolve // ["version","lock","changelog","vault","vault-ai"]) | join(",")' 2>/dev/null)}"
[ -n "$AUTO_RESOLVE" ] && [ "$AUTO_RESOLVE" != "null" ] || AUTO_RESOLVE="version,lock,changelog,vault,vault-ai"

# vault-ai is NOT resolved here — the calling command (an AI) merges vault prose with the
# plan/fix-log evidence from `sides`, then calls `continue`. This script only carries the knob.
_class_enabled() {  # vault-append / vault-meta both ride the "vault" knob
  local c="$1"; case "$c" in vault-append|vault-meta) c=vault ;; esac
  case ",$AUTO_RESOLVE," in *",$c,"*) return 0 ;; *) return 1 ;; esac
}

# Vault root — used by the vault-* classes to refuse anything outside the vault.
VAULT_ABS="${OW_VAULT_ABS:-}"
if [ -z "$VAULT_ABS" ] && [ -x "$SCRIPT_DIR/ow-paths.sh" ]; then
  VAULT_ABS=$(bash "$SCRIPT_DIR/ow-paths.sh" --check VAULT_ABS 2>/dev/null || echo '')
fi
# Physical path on both sides of the prefix test below. A configured vault reached through a
# symlink (macOS /var → /private/var, a linked external vault) would otherwise never match and
# every vault conflict would silently fall through to "human", with no visible cause.
[ -n "$VAULT_ABS" ] && [ -d "$VAULT_ABS" ] && VAULT_ABS=$(cd "$VAULT_ABS" && pwd -P)

# ── helpers ──────────────────────────────────────────────────────────────────
_in_repo() { git -C "$1" rev-parse --git-dir >/dev/null 2>&1; }

_branch() { git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null; }

# Upstream ref for the current branch: @{upstream} if tracking, else origin/<branch>
# if that exists, else empty (⇒ caller skips with exit 4).
_upstream() {
  local repo="$1" br up
  up=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)
  if [ -z "$up" ]; then
    br=$(_branch "$repo")
    [ -n "$br" ] && [ "$br" != HEAD ] && \
      git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null 2>&1 && up="origin/$br"
  fi
  printf '%s' "$up"
}

_has_remote() { [ -n "$(git -C "$1" remote 2>/dev/null)" ]; }

_conflicted() { git -C "$1" diff --name-only --diff-filter=U 2>/dev/null; }

_merge_in_progress() { git -C "$1" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; }

# diff3 markers carry the common-ancestor region — the frontmatter version rule needs the
# base to tell "both sides bumped" from "one side bumped".
GIT_DIFF3="-c merge.conflictStyle=diff3"

_rebase_in_progress() {
  local d; d=$(git -C "$1" rev-parse --git-path rebase-merge 2>/dev/null)
  [ -d "$1/$d" ] || [ -d "$d" ] && return 0
  d=$(git -C "$1" rev-parse --git-path rebase-apply 2>/dev/null)
  [ -d "$1/$d" ] || [ -d "$d" ]
}

# ── conflict classification ──────────────────────────────────────────────────
# Class is decided by PATH ONLY. Whether the file is actually resolvable is decided
# per conflict region by the awk resolver — a path in a "safe" class whose regions
# do not match the class shape still falls through to a human stop.
_classify_file() {  # _classify_file <repo> <path> → class name on stdout
  local repo="$1" f="$2" base abs
  base=$(basename "$f")
  case "$base" in
    package-lock.json|pnpm-lock.yaml|yarn.lock|poetry.lock|Cargo.lock|composer.lock|Gemfile.lock|Podfile.lock)
      emit lock; return ;;
    CHANGELOG.md|CHANGELOG.MD|Changelog.md) emit changelog; return ;;
    VERSION|version) emit version; return ;;
    package.json|pubspec.yaml) emit version; return ;;
  esac
  # vault-* — only under the resolved vault.
  if [ -n "$VAULT_ABS" ]; then
    abs="$(cd "$repo" 2>/dev/null && pwd -P)/$f"
    case "$abs" in
      "$VAULT_ABS"/*) case "$base" in *.md) emit vault-append; return ;; esac ;;
    esac
  fi
  emit none
}

# The region resolver. One awk program, CLASS-driven, reading a conflicted working
# file and writing the resolved content. Exit 3 = at least one region this class
# cannot resolve ⇒ the caller leaves the file conflicted for the human.
_resolve_regions() {  # _resolve_regions <class> <file> <out>
  awk -v CLASS="$1" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }

    # highest semver found in a block of lines (a[1..n]); "" when none
    function maxver(a, n,   i, m, v) {
      m = ""
      for (i = 1; i <= n; i++) {
        v = a[i]
        if (match(v, /[0-9]+\.[0-9]+\.[0-9]+/)) {
          v = substr(v, RSTART, RLENGTH)
          if (m == "" || vgt(v, m)) m = v
        }
      }
      return m
    }
    function vgt(x, y,   xa, ya, i) {
      split(x, xa, "."); split(y, ya, ".")
      for (i = 1; i <= 3; i++) {
        if ((xa[i]+0) > (ya[i]+0)) return 1
        if ((xa[i]+0) < (ya[i]+0)) return 0
      }
      return 0
    }
    # every non-blank line carries a semver → the region is a pure version bump
    function allver(a, n,   i) {
      for (i = 1; i <= n; i++) {
        if (trim(a[i]) == "") continue
        if (a[i] !~ /[0-9]+\.[0-9]+\.[0-9]+/) return 0
      }
      return 1
    }
    # table row | list item | blank — the vault-append shape gate
    function appendable(a, n,   i, t) {
      for (i = 1; i <= n; i++) {
        t = trim(a[i])
        if (t == "") continue
        if (t ~ /^\|/) continue
        if (t ~ /^[-*+] /) continue
        if (t ~ /^[0-9]+\. /) continue
        return 0      # prose (or anything else) → not appendable
      }
      return 1
    }
    # primary key of a row/list item; "" = keyless (separator rows, plain bullets)
    function rowkey(line,   t, c, n) {
      t = trim(line)
      if (t ~ /^\|/) {
        n = split(t, c, "|")
        # c[1] is empty (leading pipe); first real cell is c[2]
        t = trim(c[2])
        if (t ~ /^-+$/ || t ~ /^:?-+:?$/) return ""     # separator row
        return t
      }
      sub(/^[-*+] /, "", t); sub(/^[0-9]+\. /, "", t)
      if (match(t, /\[\[[^]]+\]\]/)) return substr(t, RSTART, RLENGTH)
      if (match(t, /^[A-Za-z0-9_.\/-]+/))  return substr(t, RSTART, RLENGTH)
      return ""
    }
    # ── frontmatter (vault-meta): `version:` + date fields, merged key by key ──
    function metakey(line,   t) {
      t = trim(line)
      if (t ~ /^version:[^0-9]*[0-9]+\.[0-9]+\.[0-9]+/) return "version"
      if (match(t, /^(updated|last_synced|date_modified|synced_at):[^0-9]*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
        sub(/:.*/, "", t); return t
      }
      return ""
    }
    function metashape(a, n,   i) {
      for (i = 1; i <= n; i++) {
        if (trim(a[i]) == "") continue
        if (metakey(a[i]) == "") return 0
      }
      return 1
    }
    function semver(line) { return match(line, /[0-9]+\.[0-9]+\.[0-9]+/) ? substr(line, RSTART, RLENGTH) : "" }
    function dateof(line) { return match(line, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]([T ][0-9:]+)?/) ? substr(line, RSTART, RLENGTH) : "" }
    # both sides bumped the same base to the same number = two edits → add the deltas:
    # base 0.1.0, both 0.1.1 → 0.1.2 · base 0.1.3, both 0.2.0 → 0.3.0. "" = not a bump.
    function vsum(v, o,   va, oa, i, k) {
      split(v, va, "."); split(o, oa, ".")
      for (i = 1; i <= 3; i++) if ((va[i]+0) != (oa[i]+0)) break
      if (i > 3 || (va[i]+0) < (oa[i]+0)) return ""
      va[i] = (va[i]+0) * 2 - (oa[i]+0)
      return va[1] "." va[2] "." va[3]
    }
    function meta_merge(   i, k, n, la, lb, v, out, MA, MB, MO, nka, nkb) {
      nka = 0; nkb = 0
      for (i = 1; i <= na; i++) { k = metakey(A[i]); if (k == "") continue; if (k in MA) return 0; MA[k] = A[i]; nka++ }
      for (i = 1; i <= nb; i++) { k = metakey(B[i]); if (k == "") continue; if (k in MB) return 0; MB[k] = B[i]; nkb++ }
      for (i = 1; i <= no; i++) { k = metakey(O[i]); if (k != "") MO[k] = O[i] }
      # different key sets = one side added/removed a field → not a value collision
      if (nka != nkb) return 0
      for (k in MA) if (!(k in MB)) return 0
      n = 0
      for (i = 1; i <= na; i++) {
        k = metakey(A[i])
        if (k == "") { out[++n] = A[i]; continue }
        la = MA[k]; lb = MB[k]
        if (k == "version") {
          if (semver(la) == semver(lb)) {
            if ((k in MO) && semver(MO[k]) != semver(la)) {
              v = vsum(semver(la), semver(MO[k])); if (v == "") return 0
              sub(/[0-9]+\.[0-9]+\.[0-9]+/, v, la)
            }
            out[++n] = la
          } else out[++n] = vgt(semver(lb), semver(la)) ? lb : la
        } else out[++n] = (dateof(lb) > dateof(la)) ? lb : la
      }
      for (i = 1; i <= n; i++) print out[i]
      return 1
    }

    function flush_region(   i, j, va, vb, seen, ka, kb, out, n, t) {
      if (CLASS == "version") {
        if (!allver(A, na) || !allver(B, nb)) { bad = 1; return }
        va = maxver(A, na); vb = maxver(B, nb)
        if (va == "" || vb == "") { bad = 1; return }
        if (vgt(vb, va)) { for (i = 1; i <= nb; i++) print B[i] }
        else            { for (i = 1; i <= na; i++) print A[i] }
        resolved++
        return
      }
      if (CLASS == "changelog") {
        va = maxver(A, na); vb = maxver(B, nb)
        n = 0
        if (va != "" && vb != "" && vgt(vb, va)) {
          for (i = 1; i <= nb; i++) out[++n] = B[i]
          for (i = 1; i <= na; i++) out[++n] = A[i]
        } else {
          for (i = 1; i <= na; i++) out[++n] = A[i]
          for (i = 1; i <= nb; i++) out[++n] = B[i]
        }
        for (i = 1; i <= n; i++) {
          t = trim(out[i])
          if (t != "" && (t in seen)) continue
          if (t != "") seen[t] = 1
          print out[i]
        }
        resolved++
        return
      }
      if (CLASS == "vault-append") {
        # a vault file carries two safe shapes: table/list rows (append) and the
        # frontmatter version/date block (meta). Decided per region, prose ⇒ human.
        if (metashape(A, na) && metashape(B, nb)) {
          if (!meta_merge()) { bad = 1; return }
          usedmeta = 1; resolved++; return
        }
        if (!appendable(A, na) || !appendable(B, nb)) { bad = 1; return }
        usedappend = 1
        # same primary key on both sides with different content = two people edited
        # the same record → no deterministic answer, hand it to the human
        for (i = 1; i <= na; i++) { t = rowkey(A[i]); if (t != "") ka[t] = trim(A[i]) }
        for (i = 1; i <= nb; i++) {
          t = rowkey(B[i]); if (t == "") continue
          if ((t in ka) && ka[t] != trim(B[i])) { bad = 1; return }
        }
        n = 0
        for (i = 1; i <= na; i++) out[++n] = A[i]
        for (i = 1; i <= nb; i++) out[++n] = B[i]
        for (i = 1; i <= n; i++) {
          t = trim(out[i])
          if (t != "" && (t in seen)) continue
          if (t != "") seen[t] = 1
          print out[i]
        }
        resolved++
        return
      }
      bad = 1
    }

    /^<<<<<<< /  { inA = 1; inBase = 0; inB = 0; na = 0; nb = 0; no = 0; next }
    /^\|\|\|\|\|\|\| / { if (inA) { inA = 0; inBase = 1; next } }
    /^=======$/  { if (inA || inBase) { inA = 0; inBase = 0; inB = 1; next } }
    /^>>>>>>> /  { if (inB) { inB = 0; flush_region(); next } }
    {
      if (inA)         { A[++na] = $0 }
      else if (inBase) { O[++no] = $0 }
      else if (inB)    { B[++nb] = $0 }
      else             { print }
    }
    # 11 = resolved, but only frontmatter regions → reported as vault-meta
    END { if (bad || resolved == 0) exit 3; if (usedmeta && !usedappend) exit 11 }
  ' "$2" > "$3"
}

# Regenerate a lock file for the manager that owns it. Lockfile-only where the
# manager supports it — no node_modules, no network beyond metadata.
_lock_regen() {  # _lock_regen <repo> <lockfile> → 0 ok / 1 cannot
  local repo="$1" f="$2" dir base
  base=$(basename "$f"); dir="$repo/$(dirname "$f")"
  case "$base" in
    package-lock.json) command -v npm  >/dev/null 2>&1 && (cd "$dir" && npm  install --package-lock-only --silent >/dev/null 2>&1) ;;
    pnpm-lock.yaml)    command -v pnpm >/dev/null 2>&1 && (cd "$dir" && pnpm install --lockfile-only        >/dev/null 2>&1) ;;
    yarn.lock)         command -v yarn >/dev/null 2>&1 && (cd "$dir" && yarn install --mode=update-lockfile >/dev/null 2>&1) ;;
    poetry.lock)       command -v poetry >/dev/null 2>&1 && (cd "$dir" && poetry lock --no-update           >/dev/null 2>&1) ;;
    Cargo.lock)        command -v cargo  >/dev/null 2>&1 && (cd "$dir" && cargo generate-lockfile           >/dev/null 2>&1) ;;
    composer.lock)     command -v composer >/dev/null 2>&1 && (cd "$dir" && composer update --lock          >/dev/null 2>&1) ;;
    Gemfile.lock)      command -v bundle >/dev/null 2>&1 && (cd "$dir" && bundle lock                       >/dev/null 2>&1) ;;
    *) return 1 ;;   # Podfile.lock etc. — regeneration is heavy/interactive → human
  esac
}

# ── converged doc-version bumps ──────────────────────────────────────────────
# Two people edit different sections of one vault doc and both bump `version:` 0.1.0 → 0.1.1.
# Git sees the same line change on both sides ⇒ no conflict ⇒ 0.1.1, one bump lost. After a
# sync, find those docs and add the deltas (0.1.2), as one commit of its own, reported.
# Same blob on both sides = the same change arrived twice (cherry-pick) ⇒ left alone.
_fm_version() {  # _fm_version <repo> <rev> <file> → semver of the frontmatter version: line
  git -C "$1" show "$2:$3" 2>/dev/null | awk '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    /^version:/ { if (match($0, /[0-9]+\.[0-9]+\.[0-9]+/)) print substr($0, RSTART, RLENGTH); exit }'
}
_vsum() {  # same rule as vsum() in the awk resolver; empty = not a forward bump
  awk -v v="$1" -v o="$2" 'BEGIN {
    split(v, a, "."); split(o, b, ".")
    for (i = 1; i <= 3; i++) if ((a[i]+0) != (b[i]+0)) break
    if (i > 3 || (a[i]+0) < (b[i]+0)) exit
    a[i] = (a[i]+0) * 2 - (b[i]+0); print a[1] "." a[2] "." a[3] }'
}
_converged_bumps() {  # _converged_bumps <repo> <pre-sync HEAD> <upstream>
  local repo="$1" pre="$2" up="$3" base root f vb vu vl vn list
  _class_enabled vault-meta && [ -n "$VAULT_ABS" ] || return 0
  base=$(git -C "$repo" merge-base "$pre" "$up" 2>/dev/null) || return 0
  root=$(cd "$repo" && pwd -P)
  list=$(mktemp)
  git -C "$repo" diff --name-only "$base" "$up" -- '*.md' 2>/dev/null | sort > "$list.u"
  git -C "$repo" diff --name-only "$base" "$pre" -- '*.md' 2>/dev/null | sort > "$list.l"
  comm -12 "$list.u" "$list.l" | while IFS= read -r f; do
    case "$root/$f" in "$VAULT_ABS"/*) ;; *) continue ;; esac
    [ "$(git -C "$repo" rev-parse "$up:$f" 2>/dev/null)" != "$(git -C "$repo" rev-parse "$pre:$f" 2>/dev/null)" ] || continue
    # the user's uncommitted edits to this file must never ride along in our commit
    git -C "$repo" diff --quiet -- "$f" && git -C "$repo" diff --cached --quiet -- "$f" || continue
    vb=$(_fm_version "$repo" "$base" "$f"); vu=$(_fm_version "$repo" "$up" "$f"); vl=$(_fm_version "$repo" "$pre" "$f")
    [ -n "$vb" ] && [ "$vu" = "$vl" ] && [ "$vu" != "$vb" ] || continue
    [ "$(_fm_version "$repo" HEAD "$f")" = "$vu" ] || continue     # a conflict pass already merged it
    vn=$(_vsum "$vu" "$vb"); [ -n "$vn" ] || continue
    awk -v vu="$vu" -v vn="$vn" '
      NR == 1 && $0 == "---" { fm = 1; print; next }
      fm && $0 == "---" { fm = 0 }
      fm && !done && /^version:/ { sub(vu, vn); done = 1 }
      { print }' "$repo/$f" > "$list.f" && cat "$list.f" > "$repo/$f"
    printf '%s\n' "$f" >> "$list"
    emit "resolved	vault-meta	$f	both sides bumped $vb→$vu ⇒ $vn"
  done
  if [ -s "$list" ]; then
    # pathspec commit: only these files, whatever else the user has staged stays staged
    ( cd "$repo" && tr '\n' '\0' < "$list" | xargs -0 git add -- && \
      tr '\n' '\0' < "$list" | xargs -0 git commit -q -m "docs: add up version bumps both sides made to the same vault docs" -- ) >/dev/null 2>&1 \
      || log "converged doc-version commit failed — files left modified"
  fi
  rm -f "$list" "$list.u" "$list.l" "$list.f"
  return 0
}

# ── subcommand: classify ─────────────────────────────────────────────────────
cmd_classify() {
  local repo="$1" f c rc=0
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    c=$(_classify_file "$repo" "$f")
    _class_enabled "$c" || c="none"
    emit "$c	$f"
    [ "$c" = none ] && rc=3
  done <<EOF
$(_conflicted "$repo")
EOF
  return $rc
}

# ── subcommand: resolve ──────────────────────────────────────────────────────
# Resolves every conflicted file whose class is enabled AND whose regions match the
# class shape. Any file left over ⇒ exit 3 (the human finishes the rebase/merge).
cmd_resolve() {
  local repo="$1" f c tmp rc left=0 did=0
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  [ -n "$(_conflicted "$repo")" ] || return 0

  while IFS= read -r f; do
    [ -n "$f" ] || continue
    c=$(_classify_file "$repo" "$f")
    if ! _class_enabled "$c"; then left=1; emit "unresolved	$c	$f"; continue; fi

    if [ "$c" = lock ]; then
      # take the checked-out side as a stable base, then regenerate from the
      # (already resolved or unconflicted) manifest. Regen unavailable/failing ⇒
      # leave it conflicted rather than commit a lock file we cannot vouch for.
      if git -C "$repo" checkout --ours -- "$f" 2>/dev/null && _lock_regen "$repo" "$f"; then
        git -C "$repo" add -- "$f" && { emit "resolved	lock	$f"; did=1; continue; }
      fi
      git -C "$repo" checkout -m -- "$f" 2>/dev/null
      left=1; emit "unresolved	lock	$f"; continue
    fi

    if [ "$c" = none ]; then left=1; emit "unresolved	none	$f"; continue; fi

    tmp=$(mktemp)
    _resolve_regions "$c" "$repo/$f" "$tmp"; rc=$?
    if [ $rc -eq 0 ] || [ $rc -eq 11 ]; then
      [ $rc -eq 11 ] && c=vault-meta
      cat "$tmp" > "$repo/$f"; rm -f "$tmp"
      git -C "$repo" add -- "$f" && { emit "resolved	$c	$f"; did=1; continue; }
    fi
    rm -f "$tmp"
    left=1; emit "unresolved	$c	$f"
  done <<EOF
$(_conflicted "$repo")
EOF

  [ "$left" = 1 ] && return 3
  [ "$did" = 1 ] && return 0
  return 0
}

# ── subcommand: status ───────────────────────────────────────────────────────
cmd_status() {
  local repo="$1" up counts
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  # fetch first — stale remote-tracking refs would report "0 behind" while a
  # teammate's commit is already on origin, which is the exact lie this exists to stop.
  # Offline ⇒ numbers are computed from whatever refs are on disk.
  _has_remote "$repo" && git -C "$repo" fetch --prune origin >/dev/null 2>&1
  up=$(_upstream "$repo")
  if [ -z "$up" ]; then emit "0	0	none"; return 4; fi
  counts=$(git -C "$repo" rev-list --left-right --count "$up...HEAD" 2>/dev/null) || { emit "0	0	none"; return 4; }
  # rev-list prints "<behind>\t<ahead>" for upstream...HEAD → swap into ahead,behind
  emit "$(printf '%s' "$counts" | awk '{print $2 "\t" $1}')	$up"
  return 0
}

# ── subcommand: sync ─────────────────────────────────────────────────────────
cmd_sync() {
  local repo="$1" up br rc out pre
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  [ "$AUTO_SYNC" = "true" ] || { emit "skipped	auto_sync=off"; return 4; }

  # A rebase/merge already in progress = the previous run stopped for a human.
  # Never touch it.
  if [ -n "$(_conflicted "$repo")" ] || _rebase_in_progress "$repo"; then
    emit "conflict	in-progress"; return 3
  fi
  _has_remote "$repo" || { emit "skipped	no-remote"; return 4; }

  br=$(_branch "$repo")
  [ -n "$br" ] && [ "$br" != HEAD ] || { emit "skipped	detached-head"; return 4; }

  git -C "$repo" fetch --prune origin >/dev/null 2>&1 || { emit "skipped	fetch-failed"; return 4; }
  up=$(_upstream "$repo")
  [ -n "$up" ] || { emit "skipped	no-upstream"; return 4; }

  # nothing upstream that we do not already have → no rewrite at all
  if [ "$(git -C "$repo" rev-list --count "HEAD..$up" 2>/dev/null || echo 0)" = "0" ]; then
    emit "in-sync	$up"; return 0
  fi

  # remember repeated resolutions so the next collision on the same hunk is free
  git -C "$repo" config --local rerere.enabled >/dev/null 2>&1 || \
    git -C "$repo" config --local rerere.enabled true >/dev/null 2>&1

  pre=$(git -C "$repo" rev-parse HEAD)
  if [ "$STRATEGY" = "merge" ]; then
    out=$(git -C "$repo" $GIT_DIFF3 merge --no-edit "$up" 2>&1); rc=$?
  else
    out=$(git -C "$repo" $GIT_DIFF3 rebase --autostash "$up" 2>&1); rc=$?
  fi

  # `rebase --autostash` exits 0 even when the autostash pops with conflicts: the rebase
  # itself succeeded, so git keeps the stash and leaves conflict markers in the worktree.
  # Unchecked, the caller stages those markers and pushes them. The work exists twice here
  # (markers + the kept stash), so nothing is lost — but a human decides which side wins.
  if [ $rc -eq 0 ]; then
    [ -n "$(_conflicted "$repo")" ] && { emit "conflict	autostash	$up"; return 3; }
    _converged_bumps "$repo" "$pre" "$up"
    emit "synced	$up	$STRATEGY"; return 0
  fi

  # conflicted → try the safe classes, then continue if everything got resolved
  if [ -n "$(_conflicted "$repo")" ]; then
    _finish "$repo" "$up" "$pre"; return $?
  fi
  log "$out"
  emit "error	$up"; return 1
}

# Resolve safe classes → continue → repeat for every replayed commit that stops again.
# Every pass prints its own resolved/unresolved lines — a later commit's auto-resolve is
# reported exactly like the first one. Leftovers ⇒ exit 3, the stop stays in place.
_finish() {  # _finish <repo> <upstream> <pre-sync HEAD>
  local repo="$1" label="$2" pre="$3" out rc
  while :; do
    if [ -n "$(_conflicted "$repo")" ]; then
      cmd_resolve "$repo"; rc=$?
      if [ $rc -ne 0 ] || [ -n "$(_conflicted "$repo")" ]; then
        emit "conflict	$label"   # left in place on purpose — the human (or AI step) finishes it
        return 3
      fi
    fi
    if _merge_in_progress "$repo"; then
      out=$(git -C "$repo" commit --no-edit 2>&1); rc=$?
    elif _rebase_in_progress "$repo"; then
      out=$(GIT_EDITOR=true git -C "$repo" $GIT_DIFF3 rebase --continue 2>&1); rc=$?
    else
      [ -n "$pre" ] && [ -n "$label" ] && _converged_bumps "$repo" "$pre" "$label"
      emit "synced	$label	$STRATEGY	auto-resolved"; return 0
    fi
    if [ $rc -ne 0 ] && [ -z "$(_conflicted "$repo")" ]; then
      log "$out"; emit "error	$label"; return 1   # e.g. the resolution left an empty commit
    fi
  done
}

# ── subcommand: continue ─────────────────────────────────────────────────────
# The calling command resolved (and `git add`-ed) files this script cannot judge —
# vault prose merged from plan/fix-log evidence. Finish the stopped rebase/merge.
cmd_continue() {
  local repo="$1"
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  _rebase_in_progress "$repo" || _merge_in_progress "$repo" || { emit "nothing-to-continue"; return 0; }
  _finish "$repo" "$(_upstream "$repo")" "$(git -C "$repo" rev-parse -q --verify ORIG_HEAD 2>/dev/null)"
}

# ── subcommand: sides ────────────────────────────────────────────────────────
# Evidence for merging one conflicted file by intent instead of by text:
#   head\tcommit\t<sha>\t<subject>    commits on the HEAD side (index stage :2)
#   other\tcommit\t<sha>\t<subject>   commits on the incoming side (stage :3)
#   <side>\tlog\t<path>               plan / fix-log files those commits touched
# During a rebase HEAD is the upstream being rebased onto and "other" is the local
# commit being replayed — git's own ours/theirs inversion, kept visible on purpose.
cmd_sides() {
  local repo="$1" f="$2" other base side ref sha subj p plan fix
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  if git -C "$repo" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1; then other=REBASE_HEAD
  elif _merge_in_progress "$repo"; then other=MERGE_HEAD
  else log "no rebase/merge in progress"; return 1; fi
  base=$(git -C "$repo" merge-base HEAD "$other" 2>/dev/null) || { log "no merge base"; return 1; }
  plan=$(basename "${OW_PLAN_DIR:-$(bash "$SCRIPT_DIR/ow-paths.sh" --check PLAN_DIR 2>/dev/null)}")
  fix=$(basename "${OW_FIX_DIR:-$(bash "$SCRIPT_DIR/ow-paths.sh" --check FIX_DIR 2>/dev/null)}")
  [ -n "$plan" ] && [ "$plan" != . ] || plan=80-ImplementPlan
  [ -n "$fix" ] && [ "$fix" != . ] || fix=85-FixLog
  for side in head other; do
    ref=HEAD; [ "$side" = other ] && ref="$other"
    git -C "$repo" log --format='%H	%s' "$base..$ref" -- "$f" 2>/dev/null | while IFS='	' read -r sha subj; do
      emit "$side	commit	$sha	$subj"
      git -C "$repo" show --name-only --format= "$sha" 2>/dev/null | while IFS= read -r p; do
        case "/$p" in */"$plan"/*|*/"$fix"/*) emit "$side	log	$p" ;; esac
      done
    done
  done
  return 0
}

# ── subcommand: push ─────────────────────────────────────────────────────────
# Plain push only. A non-fast-forward rejection means a teammate pushed first →
# sync and try again, up to push_retry times. Never force: remote history cannot
# be lost through this path by construction.
cmd_push() {
  local repo="$1" br="$2" tries out rc
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  _has_remote "$repo" || { emit "skipped	no-remote"; return 4; }
  tries=$(( PUSH_RETRY + 1 ))

  while [ "$tries" -gt 0 ]; do
    out=$(git -C "$repo" push origin "$br" 2>&1); rc=$?
    if [ $rc -eq 0 ]; then emit "pushed	$br"; return 0; fi
    case "$out" in
      *"non-fast-forward"*|*"fetch first"*|*"Updates were rejected"*|*"behind its remote"*)
        tries=$(( tries - 1 ))
        [ "$tries" -gt 0 ] || break
        emit "retry	$br	non-fast-forward"
        cmd_sync "$repo" >/dev/null; rc=$?
        [ $rc -eq 3 ] && { emit "conflict	$br"; return 3; }
        [ $rc -eq 4 ] && { emit "rejected	$br"; return 1; }
        ;;
      *) log "$out"; emit "error	$br"; return 1 ;;
    esac
  done
  emit "rejected	$br	non-fast-forward"
  return 1
}

# A tag is a claim on a version number. If the remote already owns it a teammate
# bumped to the same number — moving it would rewrite their release. Stop instead.
cmd_push_tag() {
  local repo="$1" tag="$2" out rc
  _in_repo "$repo" || { log "not a git repo: $repo"; return 1; }
  _has_remote "$repo" || { emit "skipped	no-remote"; return 4; }
  out=$(git -C "$repo" push origin "$tag" 2>&1); rc=$?
  [ $rc -eq 0 ] && { emit "pushed-tag	$tag"; return 0; }
  case "$out" in
    *"already exists"*|*"rejected"*|*"stale info"*) emit "tag-collision	$tag"; return 5 ;;
    *) log "$out"; emit "error	$tag"; return 1 ;;
  esac
}

cmd_config() {
  emit "auto_sync=$AUTO_SYNC"
  emit "strategy=$STRATEGY"
  emit "push_retry=$PUSH_RETRY"
  emit "auto_resolve=$AUTO_RESOLVE"
  emit "vault_abs=${VAULT_ABS:-}"
}

# ── dispatch ─────────────────────────────────────────────────────────────────
SUB="${1:-}"; shift || true
case "$SUB" in
  status)   cmd_status   "${1:-.}" ;;
  sync)     cmd_sync     "${1:-.}" ;;
  classify) cmd_classify "${1:-.}" ;;
  resolve)  cmd_resolve  "${1:-.}" ;;
  continue) cmd_continue "${1:-.}" ;;
  sides)    [ $# -ge 2 ] || { log "usage: sides <repo> <file>"; exit 1; }; cmd_sides "$1" "$2" ;;
  push)     [ $# -ge 2 ] || { log "usage: push <repo> <branch>"; exit 1; }; cmd_push "$1" "$2" ;;
  push-tag) [ $# -ge 2 ] || { log "usage: push-tag <repo> <tag>"; exit 1; }; cmd_push_tag "$1" "$2" ;;
  config)   cmd_config ;;
  *) log "usage: ow-git-sync.sh {status|sync|classify|resolve|continue|sides|push|push-tag|config} [args]"; exit 1 ;;
esac
