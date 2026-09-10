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
AUTO_RESOLVE="${OW_GIT_AUTO_RESOLVE:-$(printf '%s' "$GIT_SYNC_JSON" | jq -r '(.auto_resolve // ["version","lock","changelog","vault"]) | join(",")' 2>/dev/null)}"
[ -n "$AUTO_RESOLVE" ] && [ "$AUTO_RESOLVE" != "null" ] || AUTO_RESOLVE="version,lock,changelog,vault"

_class_enabled() {  # vault-append / vault-meta both ride the "vault" knob
  local c="$1"; case "$c" in vault-*) c=vault ;; esac
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
    # frontmatter date field only (updated:, last_synced:, ...)
    function alldate(a, n,   i, t) {
      for (i = 1; i <= n; i++) {
        t = trim(a[i]); if (t == "") continue
        if (t !~ /^(updated|last_synced|date_modified|synced_at):[ \t]*[0-9]{4}-[0-9]{2}-[0-9]{2}/) return 0
      }
      return 1
    }
    function maxdate(a, n,   i, m, t) {
      m = ""
      for (i = 1; i <= n; i++) {
        t = a[i]
        if (match(t, /[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9:]+)?/)) {
          t = substr(t, RSTART, RLENGTH)
          if (m == "" || t > m) { m = t; mline = a[i] }
        }
      }
      return mline
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
        if (!appendable(A, na) || !appendable(B, nb)) { bad = 1; return }
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
      if (CLASS == "vault-meta") {
        if (!alldate(A, na) || !alldate(B, nb)) { bad = 1; return }
        mline = ""
        for (i = 1; i <= na; i++) C[i] = A[i]
        for (j = 1; j <= nb; j++) C[na + j] = B[j]
        print maxdate(C, na + nb)
        resolved++
        return
      }
      bad = 1
    }

    /^<<<<<<< /  { inA = 1; inBase = 0; inB = 0; na = 0; nb = 0; next }
    /^\|\|\|\|\|\|\| / { if (inA) { inA = 0; inBase = 1; next } }
    /^=======$/  { if (inA || inBase) { inA = 0; inBase = 0; inB = 1; next } }
    /^>>>>>>> /  { if (inB) { inB = 0; flush_region(); next } }
    {
      if (inA)         { A[++na] = $0 }
      else if (inBase) { }
      else if (inB)    { B[++nb] = $0 }
      else             { print }
    }
    END { if (bad || resolved == 0) exit 3 }
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
  local repo="$1" f c tmp left=0 did=0
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
    if _resolve_regions "$c" "$repo/$f" "$tmp"; then
      cat "$tmp" > "$repo/$f"; rm -f "$tmp"
      git -C "$repo" add -- "$f" && { emit "resolved	$c	$f"; did=1; continue; }
    fi
    rm -f "$tmp"
    # vault-append gate can fail on the .md body but still pass on frontmatter dates
    if [ "$c" = vault-append ] && _class_enabled vault-meta; then
      tmp=$(mktemp)
      if _resolve_regions vault-meta "$repo/$f" "$tmp"; then
        cat "$tmp" > "$repo/$f"; rm -f "$tmp"
        git -C "$repo" add -- "$f" && { emit "resolved	vault-meta	$f"; did=1; continue; }
      fi
      rm -f "$tmp"
    fi
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
  local repo="$1" up br rc out
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

  if [ "$STRATEGY" = "merge" ]; then
    out=$(git -C "$repo" merge --no-edit "$up" 2>&1); rc=$?
  else
    out=$(git -C "$repo" rebase --autostash "$up" 2>&1); rc=$?
  fi

  # `rebase --autostash` exits 0 even when the autostash pops with conflicts: the rebase
  # itself succeeded, so git keeps the stash and leaves conflict markers in the worktree.
  # Unchecked, the caller stages those markers and pushes them. The work exists twice here
  # (markers + the kept stash), so nothing is lost — but a human decides which side wins.
  if [ $rc -eq 0 ]; then
    [ -n "$(_conflicted "$repo")" ] && { emit "conflict	autostash	$up"; return 3; }
    emit "synced	$up	$STRATEGY"; return 0
  fi

  # conflicted → try the safe classes, then continue if everything got resolved
  if [ -n "$(_conflicted "$repo")" ]; then
    cmd_resolve "$repo"; rc=$?
    if [ $rc -eq 0 ] && [ -z "$(_conflicted "$repo")" ]; then
      if [ "$STRATEGY" = "merge" ]; then
        git -C "$repo" commit --no-edit >/dev/null 2>&1 && { emit "synced	$up	$STRATEGY	auto-resolved"; return 0; }
      else
        GIT_EDITOR=true git -C "$repo" rebase --continue >/dev/null 2>&1 && { emit "synced	$up	$STRATEGY	auto-resolved"; return 0; }
        # --continue can stop again on the NEXT replayed commit → recurse once per commit
        if [ -n "$(_conflicted "$repo")" ]; then cmd_resolve "$repo" >/dev/null 2>&1 && \
          GIT_EDITOR=true git -C "$repo" rebase --continue >/dev/null 2>&1 && { emit "synced	$up	$STRATEGY	auto-resolved"; return 0; }
        fi
      fi
    fi
    emit "conflict	$up"   # left in place on purpose — the human finishes it
    return 3
  fi
  log "$out"
  emit "error	$up"; return 1
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
  push)     [ $# -ge 2 ] || { log "usage: push <repo> <branch>"; exit 1; }; cmd_push "$1" "$2" ;;
  push-tag) [ $# -ge 2 ] || { log "usage: push-tag <repo> <tag>"; exit 1; }; cmd_push_tag "$1" "$2" ;;
  config)   cmd_config ;;
  *) log "usage: ow-git-sync.sh {status|sync|classify|resolve|push|push-tag|config} [args]"; exit 1 ;;
esac
