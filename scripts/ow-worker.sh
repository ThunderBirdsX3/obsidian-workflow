#!/usr/bin/env bash
# obsidian-workflow — external CLI worker runner (spec: .ow/commands/_shared/worker-cli.md)
# ─────────────────────────────────────────────────────────────────────────────
# Dispatches ONE chunk prompt to an external coding CLI (codex | claude) in a given
# working tree and returns ONLY the RETURN PROTOCOL tail (STATUS: + 7 HANDOFF lines)
# on stdout. Everything else (events, stdout, stderr) lands in RUN_DIR files so the
# orchestrator's context never holds raw worker output.
#
#   ow-worker.sh <codex|claude> --preflight
#   ow-worker.sh <codex|claude> <WORK_ROOT> <RUN_DIR> <TAG> <PROMPT_FILE> [--resume <session-id>]
#
# Exit codes: 0 = a STATUS block was produced (DONE/CONTINUE/BLOCKED — the DECISION is the
# orchestrator's, which must still run EXIT_STATE itself) · 2 = preflight failed (CLI missing /
# not authenticated) · 3 = usage · 4 = prompt contains a secret-like token (never dispatched).
#
# A process exit 0 with no STATUS line is reported as STATUS: BLOCKED REASON: no-status-line —
# it is never promoted to DONE. Timeout / non-zero exit / unparsable JSON likewise → BLOCKED.
# Credit / usage-limit exhaustion → BLOCKED with REASON: quota-exhausted (the caller falls back, see worker-cli.md §3.1).
#
# Knobs (env, or .ow/local/paths.env from Phase 0): AUTO_TIMEOUT_MIN (default 30; 0 = no timeout),
# AUTO_CODEX_MODEL, AUTO_CLAUDE_MODEL. OW_WORKER_TIMEOUT_SEC overrides minutes (tests).
# Portable: bash 3.2 + BSD userland. No `timeout(1)` on macOS → own watchdog.

set -u

usage() { echo "usage: $0 <codex|claude> --preflight | <codex|claude> <WORK_ROOT> <RUN_DIR> <TAG> <PROMPT_FILE> [--resume <id>]" >&2; exit 3; }
[ $# -ge 2 ] || usage
BACKEND="$1"; shift
case "$BACKEND" in codex|claude) ;; *) usage ;; esac

# ── knobs: paths.env (if Phase 0 ran) < env ──────────────────────────────────
_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "$_root/.ow/local/paths.env" ]; then
  _e_min="${AUTO_TIMEOUT_MIN-}"; _e_cm="${AUTO_CODEX_MODEL-}"; _e_am="${AUTO_CLAUDE_MODEL-}"
  . "$_root/.ow/local/paths.env" 2>/dev/null || true
  [ -n "$_e_min" ] && AUTO_TIMEOUT_MIN="$_e_min"
  [ -n "$_e_cm" ]  && AUTO_CODEX_MODEL="$_e_cm"
  [ -n "$_e_am" ]  && AUTO_CLAUDE_MODEL="$_e_am"
fi
AUTO_TIMEOUT_MIN="${AUTO_TIMEOUT_MIN:-30}"
AUTO_CODEX_MODEL="${AUTO_CODEX_MODEL:-}"
AUTO_CLAUDE_MODEL="${AUTO_CLAUDE_MODEL:-}"
TIMEOUT_SEC="${OW_WORKER_TIMEOUT_SEC:-$(( AUTO_TIMEOUT_MIN * 60 ))}"

# ── preflight ────────────────────────────────────────────────────────────────
preflight() {
  command -v "$BACKEND" >/dev/null 2>&1 || { echo "preflight: $BACKEND CLI not found on PATH" >&2; return 2; }
  local ver; ver=$("$BACKEND" --version 2>/dev/null | head -1) || true
  [ -n "$ver" ] || { echo "preflight: $BACKEND --version failed" >&2; return 2; }
  case "$BACKEND" in
    codex)  "$BACKEND" login status >/dev/null 2>&1 || { echo "preflight: codex not logged in — run: codex login" >&2; return 2; } ;;
    claude) printf 'reply OK' | "$BACKEND" -p --output-format json >/dev/null 2>&1 || { echo "preflight: claude -p failed — run: claude (interactive) and sign in" >&2; return 2; } ;;
  esac
  echo "$BACKEND $ver"
  return 0
}
if [ "${1:-}" = "--preflight" ]; then preflight; exit $?; fi

# ── dispatch args ────────────────────────────────────────────────────────────
[ $# -ge 4 ] || usage
WORK_ROOT="$1"; RUN_DIR="$2"; TAG="$3"; PROMPT="$4"; shift 4
RESUME=""
while [ $# -gt 0 ]; do
  case "$1" in --resume) RESUME="${2:-}"; [ -n "$RESUME" ] || usage; shift 2 ;; *) usage ;; esac
done
[ -d "$WORK_ROOT" ] || { echo "WORK_ROOT not a directory: $WORK_ROOT" >&2; exit 3; }
[ -f "$PROMPT" ]    || { echo "PROMPT_FILE missing: $PROMPT" >&2; exit 3; }

# ── refuse to ship a secret-looking prompt (rule files / env dumps) ──────────
if grep -qE '(ANTHROPIC|OPENAI)_API_KEY=|sk-ant-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY' "$PROMPT"; then
  echo "refusing to dispatch: prompt contains a secret-like token" >&2; exit 4
fi

mkdir -p "$RUN_DIR"
# absolute paths: the CLI runs with cwd = WORK_ROOT
RUN_DIR="$(cd "$RUN_DIR" && pwd)"
PROMPT="$(cd "$(dirname "$PROMPT")" && pwd)/$(basename "$PROMPT")"
LAST="$RUN_DIR/$TAG.last.md"; SESS="$RUN_DIR/$TAG.session"; ERR="$RUN_DIR/$TAG.stderr"
: > "$LAST"; : > "$ERR"

case "$BACKEND" in codex) OUT="$RUN_DIR/$TAG.events.jsonl" ;; claude) OUT="$RUN_DIR/$TAG.json" ;; esac
FIELDS="DONE FILES DIGEST DECISIONS DEVIATIONS OPEN CONTEXT_GAPS"
emit_blocked() {   # $1 = reason
  echo "STATUS: BLOCKED"
  echo "REASON: $1 · log: $OUT · stderr: $ERR"
  for f in $FIELDS; do echo "$f: (none)"; done
}

# ── codex model: a full slug (has a digit, e.g. gpt-6-sol) passes through untouched; a bare family alias
# (e.g. "sol") resolves — like `sonnet` does for claude — to the listed models of that family in
# $CODEX_HOME/models_cache.json, newest first. The newest is not always usable on every account, so a
# "model is not supported" rejection falls through to the next one (3 candidates max). A full slug is
# never retried: the user named exactly that model.
resolve_codex_alias() {
  local cache="${CODEX_HOME:-$HOME/.codex}/models_cache.json"
  [ -f "$cache" ] && command -v python3 >/dev/null 2>&1 || return 0
  python3 -I - "$cache" "$1" 2>/dev/null <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
suf = "-" + sys.argv[2]
ms = [m for m in (d.get("models") or []) if isinstance(m, dict)]
hits = [m["slug"] for m in ms if isinstance(m.get("slug"), str) and m["slug"].endswith(suf)
        and m.get("visibility", "list") == "list"]
ver = lambda s: tuple(int(x) for x in re.findall(r"\d+", s[: -len(suf)]))
for s in sorted(hits, key=ver, reverse=True)[:3]: print(s)
PY
}
MODELS="${AUTO_CODEX_MODEL:-}"; ALIAS=0
if [ "$BACKEND" = codex ] && [ -n "$MODELS" ]; then
  case "$MODELS" in
    *[0-9]*) ;;
    *) ALIAS=1; MODELS=$(resolve_codex_alias "$AUTO_CODEX_MODEL" | tr '\n' ' ')
       [ -n "${MODELS// /}" ] || { emit_blocked "model-alias '$AUTO_CODEX_MODEL' unresolved — no listed *-$AUTO_CODEX_MODEL in ${CODEX_HOME:-$HOME/.codex}/models_cache.json (set a full slug in auto.codex_model)"; exit 0; } ;;
  esac
fi

# kill_tree <sig> <pid> — the CLI's shell commands (dev servers, watchers) are grandchildren;
# `pkill -P` reaches one level only, so collect the whole tree first, then signal it.
_tree() { local c; for c in $(pgrep -P "$1" 2>/dev/null); do _tree "$c"; done; echo "$1"; }
kill_tree() { local p; p=$(_tree "$2"); [ -n "$p" ] && kill -"$1" $p 2>/dev/null; return 0; }

# run_once <model|""> — build argv, run with watchdog (no timeout(1) on macOS); sets RC, TIMED_OUT.
# The CLI is started directly (no wrapping subshell) so the watchdog signals the real process tree.
# The watchdog's own stdout/stderr go to /dev/null: a sleeping child holding the caller's pipe open
# would otherwise stall `$(ow-worker.sh ...)`.
run_once() {
  local model="$1"
  : > "$LAST"; : > "$ERR"
  set -- "$BACKEND"
  case "$BACKEND" in
    codex)
      # exec-level flags go BEFORE `resume`: `codex exec resume` itself accepts no -C / -s (codex-cli 0.155.1)
      set -- "$@" exec -C "$WORK_ROOT" -s workspace-write --json -o "$LAST"
      [ -n "$model" ] && set -- "$@" -m "$model"
      [ -n "$RESUME" ] && set -- "$@" resume "$RESUME"
      set -- "$@" -
      ;;
    claude)
      set -- "$@" -p --permission-mode acceptEdits --add-dir "$WORK_ROOT" --output-format json
      [ -n "$RESUME" ] && set -- "$@" --resume "$RESUME"
      [ -n "$AUTO_CLAUDE_MODEL" ] && set -- "$@" --model "$AUTO_CLAUDE_MODEL"
      ;;
  esac
  "$@" < "$PROMPT" > "$OUT" 2> "$ERR" &
  PID=$!
  # The runner itself killed (host tool timeout, Ctrl-C, TERM) → take the CLI with it: an orphaned
  # worker would keep editing WORK_ROOT while the orchestrator moves on.
  trap 'kill_tree TERM "$PID"; sleep 1; kill_tree KILL "$PID"; exit 143' TERM INT HUP
  TFLAG="$RUN_DIR/$TAG.timeout"; rm -f "$TFLAG"
  # Watchdog polls once a second and exits by itself as soon as the CLI is gone, so it
  # never has to be killed (killing it mid-sleep would race the flag write / orphan sleep).
  ( [ "$TIMEOUT_SEC" -gt 0 ] || exit 0   # 0 = no timeout: nothing to watch
    i=0
    while [ "$i" -lt "$TIMEOUT_SEC" ]; do
      sleep 1; kill -0 "$PID" 2>/dev/null || exit 0; i=$((i + 1))
    done
    : > "$TFLAG"   # flag first: a child dying before its parent can turn RC into 0
    kill_tree TERM "$PID"
    sleep 2
    kill_tree KILL "$PID" ) >/dev/null 2>&1 &
  WD=$!
  wait "$PID" 2>/dev/null; RC=$?
  wait "$WD" 2>/dev/null
  trap - TERM INT HUP
  TIMED_OUT=0; [ -e "$TFLAG" ] && TIMED_OUT=1; rm -f "$TFLAG"
}

cd "$WORK_ROOT" || exit 3
rm -f "$RUN_DIR/$TAG.model"
set -f   # MODELS is a word list; no globbing
[ -n "$MODELS" ] || MODELS="-"
for M in $MODELS; do
  [ "$M" = "-" ] && M=""
  run_once "$M"
  [ -n "$M" ] && printf '%s\n' "$M" > "$RUN_DIR/$TAG.model"
  # alias only: the account refused this model → try the next of the family
  if [ $ALIAS -eq 1 ] && [ $RC -ne 0 ] && [ $TIMED_OUT -eq 0 ] && grep -q 'model is not supported' "$OUT" "$ERR" 2>/dev/null; then
    continue
  fi
  break
done
set +f

# ── extract last message + session id ────────────────────────────────────────
case "$BACKEND" in
  codex)
    sid=$(grep -o '"thread_id":"[^"]*"' "$OUT" 2>/dev/null | head -1 | sed 's/.*:"//; s/"$//')
    [ -z "$sid" ] && sid=$(grep -o '"session_id":"[^"]*"' "$OUT" 2>/dev/null | head -1 | sed 's/.*:"//; s/"$//')
    ;;
  claude)
    sid=$(grep -o '"session_id":"[^"]*"' "$OUT" 2>/dev/null | tail -1 | sed 's/.*:"//; s/"$//')
    # .result is a JSON string with \n escapes → unescape into LAST (python3 is on every macOS/Linux dev box;
    # fall back to sed if absent)
    if command -v python3 >/dev/null 2>&1; then
      python3 -I - "$OUT" > "$LAST" 2>/dev/null <<'PY' || : > "$LAST"
import json,sys
last=""
for line in open(sys.argv[1],encoding="utf-8",errors="replace"):
    line=line.strip()
    if not line: continue
    try: o=json.loads(line)
    except Exception: continue
    if isinstance(o,dict) and o.get("type")=="result" and isinstance(o.get("result"),str): last=o["result"]
sys.stdout.write(last)
PY
    else
      grep -o '"result":"[^"]*"' "$OUT" 2>/dev/null | tail -1 | sed 's/^"result":"//; s/"$//; s/\\n/\
/g' > "$LAST"
    fi
    ;;
esac
[ -n "${sid:-}" ] && printf '%s\n' "$sid" > "$SESS"

# ── emit RETURN PROTOCOL only ────────────────────────────────────────────────
if [ $TIMED_OUT -eq 1 ]; then emit_blocked "timeout after ${TIMEOUT_SEC}s"; exit 0; fi
# credit / usage-limit exhaustion is its own reason: the orchestrator falls back to the host and tries this backend again next chunk.
# Only the CLI's error records are scanned — the model's own prose could mention "quota" without the account being out.
# Checked on a non-zero exit AND on a STATUS-less exit 0 (`claude -p` may report a limit as is_error with exit 0).
is_quota() {
  { cat "$ERR"; grep -E '"type":"(error|turn\.failed)"|"is_error":true' "$OUT"; } 2>/dev/null \
    | grep -qiE 'usage.limit|insufficient.quota|out of credits|credit balance|exceeded your (current )?quota|quota (exceeded|exhausted)|purchase more credits|rate.limit'
}
if [ $RC -ne 0 ]; then
  is_quota && { emit_blocked "quota-exhausted"; exit 0; }
  emit_blocked "exit-code $RC"; exit 0
fi
if ! grep -q '^STATUS:' "$LAST" 2>/dev/null; then
  is_quota && { emit_blocked "quota-exhausted"; exit 0; }
  emit_blocked "no-status-line"; exit 0
fi

# from the LAST `STATUS:` line to EOF; then normalise to STATUS + exactly 7 fields
tail_block=$(awk '/^STATUS:/{buf=""; on=1} on{buf=buf $0 "\n"} END{printf "%s", buf}' "$LAST")
printf '%s\n' "$tail_block" | head -1
for f in $FIELDS; do
  line=$(printf '%s\n' "$tail_block" | grep -m1 "^$f:" || true)
  [ -n "$line" ] && echo "$line" || echo "$f: (none)"
done
exit 0
