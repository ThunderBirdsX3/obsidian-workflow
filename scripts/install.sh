#!/usr/bin/env bash
# obsidian-workflow installer — bootstrap docs-driven AI dev workflow in any project
#
# Usage:
#   Greenfield (new empty folder):
#     mkdir my-project && cd my-project && bash <(curl -fsSL .../install.sh)
#
#   Brownfield (existing project):
#     cd existing-project && bash <(curl -fsSL .../install.sh)
#
#   Local (from cloned obsidian-workflow):
#     ./scripts/install.sh /path/to/target-project
#
# Flags:
#   --source <path|url>   เลือกแหล่ง obsidian-workflow template — local dir, https://, ssh://
#                         หรือ git@host:owner/repo.git (default: github)
#   --target <dir>        โฟลเดอร์ปลายทาง (เท่ากับ positional arg; default: cwd)
#   --version <tag>       เลือก version (default: latest)
#   --mode greenfield|brownfield|auto   (default: auto-detect)
#   --ai <list>           Comma-separated AI front-ends, or "all"
#                         (default: interactive picker; --yes uses "claude")
#   --yes                 ข้ามคำถามทั้งหมด ใช้ default (= overwrite ไฟล์ที่มีอยู่)
#   --force               re-run install ทับ project ที่ adopt แล้ว (implies --yes)
#   --no-sample           ไม่คัดลอก sample vault ตอน greenfield
#   --dry-run             แสดงสิ่งที่จะทำ แต่ไม่จริง
#
# AI front-ends supported: see scripts/ow-frontends.sh — the ONE registry the
# picker, the folder map, the upgrade refresh set and the rollback set all read.
# Do not re-list them here; a hardcoded copy is exactly how gpt/glm silently fell
# out of two other lists.

set -euo pipefail

# ---------- defaults ----------
SOURCE_URL="${OW_SOURCE:-https://github.com/ThunderBirdsX3/obsidian-workflow.git}"
VERSION="${OW_VERSION:-main}"
MODE="auto"
AI_AGENTS=""                       # "" = ask interactively; "all" = all 5
YES=0
DRY_RUN=0
LOCAL_ONLY=0                       # --local: materialize only the gitignored personal files (#23)
NO_SAMPLE=0                        # --no-sample: never copy the sample vault (greenfield only)
FORCE=0                            # --force: re-run install over an already-adopted project
TARGET=""

# ---------- helpers ----------
log() { printf '\033[1;36m[obsidian-workflow]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[obsidian-workflow]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[obsidian-workflow]\033[0m %s\n' "$*" >&2; }
ask() {
  local prompt="$1"; local default="$2"; local reply
  if [[ $YES -eq 1 ]]; then echo "$default"; return; fi
  read -r -p "$prompt [$default]: " reply
  echo "${reply:-$default}"
}
run() {
  if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: $*"; else eval "$@"; fi
}

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE_URL="$2"; shift 2 ;;
    # --target is an alias for the positional target. bin/ow and the README both
    # spell it this way; the parser used to accept only the positional, so every one of
    # those call sites died on `Unknown flag: --target`.
    --target) TARGET="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --ai) AI_AGENTS="$2"; shift 2 ;;
    --yes) YES=1; shift ;;
    # --force = "re-run install over a project that is already adopted" (what
    # `ow update` wants). Implies --yes: there is no one to answer the prompts.
    # .ow.yml is in the protected set either way, so config is never clobbered.
    --force) FORCE=1; YES=1; shift ;;
    --no-sample) NO_SAMPLE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --local) LOCAL_ONLY=1; shift ;;
    -h|--help)
      grep '^#' "$0" | head -35; exit 0 ;;
    --*)
      err "Unknown flag: $1"; exit 1 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# Default target: cwd (if no positional arg provided)
TARGET="${TARGET:-$(pwd)}"
# Normalize to an absolute path BEFORE the `cd "$TARGET"` further down. Every later
# reference is "$TARGET/..."; with a relative target those resolve against the NEW cwd
# and the installer silently lays the project down inside <target>/<target>/.
[[ -d "$TARGET" ]] && TARGET="$(cd "$TARGET" && pwd)"

# ---------- detect indicators (returns list of what was found) ----------
detect_indicators() {
  local found=()
  local manifests=(package.json requirements.txt pyproject.toml Pipfile pom.xml build.gradle build.gradle.kts go.mod Cargo.toml composer.json Gemfile pubspec.yaml mix.exs)
  for m in "${manifests[@]}"; do
    [[ -f "$TARGET/$m" ]] && found+=("$m")
  done
  if compgen -G "$TARGET/*.csproj" > /dev/null 2>&1; then found+=("*.csproj"); fi
  if compgen -G "$TARGET/*.sln" > /dev/null 2>&1; then found+=("*.sln"); fi

  # Source folders (any of these = likely brownfield)
  for d in src lib app frontend backend mobile server client api packages apps services; do
    [[ -d "$TARGET/$d" ]] && found+=("$d/")
  done

  # Git history (real commits, not just empty init)
  if [[ -d "$TARGET/.git" ]]; then
    local commits
    commits=$(git -C "$TARGET" rev-list --count HEAD 2>/dev/null || echo 0)
    if [[ "$commits" -gt 0 ]]; then
      found+=(".git ($commits commits)")
    fi
  fi

  # Submodules
  [[ -f "$TARGET/.gitmodules" ]] && found+=(".gitmodules")

  # Existing docs/ vault
  if [[ -d "$TARGET/docs" ]] && [[ -n "$(find "$TARGET/docs" -maxdepth 2 -name '*.md' 2>/dev/null | head -1)" ]]; then
    found+=("docs/ (existing content)")
  fi

  # Print one per line (guard against empty array under set -u)
  [[ ${#found[@]} -eq 0 ]] && return 0
  printf "%s\n" "${found[@]}"
}

# ---------- ask user when ambiguous ----------
ask_mode() {
  # If --mode was set explicitly, honor it
  if [[ "$MODE" != "auto" ]]; then
    echo "$MODE"; return
  fi

  local indicators
  indicators=$(detect_indicators)

  # Case 1: ไม่มี indicator เลย → greenfield แน่นอน (no question)
  if [[ -z "$indicators" ]]; then
    echo "greenfield"
    return
  fi

  # Case 2: มี indicators → ถาม user (เพราะอาจเป็น setup ไว้แล้วแต่ยังเป็น greenfield)
  if [[ $YES -eq 1 ]]; then
    # --yes mode → ถือว่า brownfield ถ้ามี indicator
    echo "brownfield"
    return
  fi

  cat >&2 <<EOF

🔍 ${c_bold:-}ตรวจพบ indicators ใน folder นี้:${c_reset:-}

$(echo "$indicators" | sed 's/^/   • /')

${c_bold:-}โหมดไหนตรงกับสถานการณ์ของคุณ?${c_reset:-}

  1) ${c_bold:-}greenfield${c_reset:-}  — ${c_dim:-}project setup ไว้แล้ว แต่ยังไม่มี content จริง (เริ่ม fresh ได้)${c_reset:-}
  2) ${c_bold:-}brownfield${c_reset:-}  — ${c_dim:-}มี code/docs ใช้งานอยู่จริง (adopt + ห้ามแตะของเดิม)${c_reset:-}
  3) ${c_bold:-}adopt-vault${c_reset:-} — ${c_dim:-}มี Obsidian vault อยู่แล้วใน docs/ (ใช้ vault เดิม + รวม commands ของ obsidian-workflow)${c_reset:-}

EOF
  local choice
  read -r -p "เลือก (1/2/3) [default: 2 brownfield]: " choice
  case "${choice:-2}" in
    1|green|greenfield)      echo "greenfield" ;;
    2|brown|brownfield)      echo "brownfield" ;;
    3|adopt|adopt-vault)     echo "adopt-vault" ;;
    *) err "ตัวเลือกไม่ถูกต้อง: $choice"; exit 1 ;;
  esac
}

# ---------- detect stack (brownfield) ----------
detect_stack() {
  local stacks=()
  [[ -f "$TARGET/package.json" ]] && stacks+=("frontend-or-node")
  [[ -f "$TARGET/requirements.txt" || -f "$TARGET/pyproject.toml" ]] && stacks+=("python")
  [[ -f "$TARGET/go.mod" ]] && stacks+=("go")
  [[ -f "$TARGET/Cargo.toml" ]] && stacks+=("rust")
  [[ -f "$TARGET/pubspec.yaml" ]] && stacks+=("flutter")
  [[ -f "$TARGET/pom.xml" || -f "$TARGET/build.gradle" ]] && stacks+=("jvm")
  [[ -f "$TARGET/composer.json" ]] && stacks+=("php")
  if compgen -G "$TARGET/*.csproj" > /dev/null 2>&1; then stacks+=("dotnet"); fi
  if [[ -f "$TARGET/.gitmodules" ]]; then stacks+=("multi-repo"); fi
  if [[ ${#stacks[@]} -eq 0 ]]; then echo "unknown"; else echo "${stacks[*]}"; fi
}

# ---------- main ----------
log "obsidian-workflow installer — version: $VERSION"
log "Target: $TARGET"

# yq is a HARD prerequisite in v0.7 — the runtime resolver (scripts/ow-paths.sh)
# parses YAML lists/nested keys and fails closed without it. Gate the install so a
# fresh project never lands in a yq-less state where commands silently mis-resolve.
# (Escape hatch for CI imaging: OW_SKIP_YQ_CHECK=1.)
if ! command -v yq >/dev/null 2>&1 && [[ "${OW_SKIP_YQ_CHECK:-0}" != "1" ]]; then
  err "yq not found — obsidian-workflow v0.7 requires yq (YAML parser)."
  err "  Install: brew install yq  |  apt install yq  |  https://github.com/mikefarah/yq"
  err "  Then re-run the installer. (Set OW_SKIP_YQ_CHECK=1 to bypass for CI imaging.)"
  exit 1
fi

[[ -d "$TARGET" ]] || { err "Target folder ไม่พบ: $TARGET"; exit 1; }
cd "$TARGET"

# ---------- --local: materialize ONLY the gitignored personal files (#23) ----------
# For a teammate who cloned an already-adopted project: their gitignored personal files
# (.ow.local.yml, .ow/local/, secrets env) are absent. This mode creates just
# the MISSING ones from their committed *.example templates — touching NO shared/tracked
# file (.ow.yml, .ow/rules/, core, .claude). Idempotent: re-running is a no-op.
materialize_local_only() {
  if [[ ! -f "$TARGET/.ow.yml" ]]; then
    err "--local needs an already-adopted project (no .ow.yml here)."
    err "  Run a full 'ow init' first, then '--local' for additional teammates."
    exit 1
  fi
  log "Local-only materialization (personal/gitignored files; no shared file touched)"
  local created=0

  # 1) .ow.local.yml ← committed example (only when absent)
  if [[ -f "$TARGET/.ow.local.yml" ]]; then
    log "  ok (exists): .ow.local.yml"
  elif [[ -f "$TARGET/.ow.local.yml.example" ]]; then
    run "cp '$TARGET/.ow.local.yml.example' '$TARGET/.ow.local.yml'"
    log "  created: .ow.local.yml (from .example — edit to override paths)"; created=$((created+1))
  else
    warn "  skip: .ow.local.yml.example not found (cannot materialize .ow.local.yml)"
  fi

  # 2) .ow/local/ personal dir (+ minimal README) — gitignored, absent on a fresh clone
  if [[ -d "$TARGET/.ow/local" ]]; then
    log "  ok (exists): .ow/local/"
  else
    run "mkdir -p '$TARGET/.ow/local'"
    if [[ $DRY_RUN -eq 0 ]]; then
      cat > "$TARGET/.ow/local/README.md" <<'LOCALREADME'
# `.ow/local/` — personal, gitignored

Per-machine overrides that never get committed. Highest precedence in the resolver.

- `rules/<area>.md` — personal rule overrides (win over `.ow/rules/<area>.md`)
- `adopt.marker` — records your install-time keep/remove choice (written by the installer)

Created by `ow init --local`. Safe to delete; re-run `init --local` to recreate.
LOCALREADME
    fi
    log "  created: .ow/local/ (+ README — personal overrides)"; created=$((created+1))
  fi

  # 3) secrets/test-credentials env files ← committed *.example (only when absent)
  local ex dest
  for ex in .env.example .ow/test-credentials.env.example test-credentials.env.example; do
    [[ -f "$TARGET/$ex" ]] || continue
    dest="${ex%.example}"
    if [[ -e "$TARGET/$dest" ]]; then
      log "  ok (exists): $dest"
    else
      run "cp '$TARGET/$ex' '$TARGET/$dest'"
      log "  created: $dest (from $ex — fill in your secrets; gitignored)"; created=$((created+1))
    fi
  done

  log ""
  if [[ $created -eq 0 ]]; then
    log "✅ Nothing to do — all personal files already present (no-op)."
  else
    log "✅ Materialized $created personal file(s). No shared/tracked file was modified."
  fi
}

if [[ $LOCAL_ONLY -eq 1 ]]; then
  materialize_local_only
  exit 0
fi

# Detect mode (interactive if indicators present + not --yes)
MODE=$(ask_mode)
log "Mode: $MODE"

# Handle adopt-vault mode (new third option)
ADOPT_VAULT=0
if [[ "$MODE" == "adopt-vault" ]]; then
  ADOPT_VAULT=1
  MODE="brownfield"   # internally treat as brownfield
  log "(adopt-vault: vault path จะใช้ docs/ ที่มีอยู่แล้ว)"
fi

# Detect existing obsidian-workflow
if [[ -f .ow.yml ]]; then
  warn ".ow.yml already exists — this project looks already adopted."
  warn "  Just need YOUR personal files (new teammate on a cloned repo)? → re-run with --local"
  warn "  (materializes only the missing gitignored files; touches no shared/tracked file)"
  if [[ $FORCE -eq 1 ]]; then
    log "  --force: re-running install over it (.ow.yml is protected — kept as is)."
  else
    reply=$(ask "Continue and re-run install over it? (y/N)" "n")
    [[ "$reply" =~ ^[Yy] ]] || { log "Aborted."; exit 0; }
  fi
fi

# Detect stack (brownfield only)
STACK=""
if [[ "$MODE" == "brownfield" ]]; then
  STACK=$(detect_stack)
  log "Detected stack: $STACK"
fi

# NOTE: the AI front-end picker used to live here. It now runs AFTER the template
# fetch (see "AI front-end picker" below) because its list comes from the registry
# scripts/ow-frontends.sh, which only exists once the template has been fetched.

# ---------- fetch template ----------
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

log "Fetching obsidian-workflow template..."

if [[ -d "$SOURCE_URL" ]]; then
  # Local source — use `/.` to include hidden files (.ow.yml, .gitignore, .claude, ...)
  # WITHOUT this, glob `/*` skips dotfiles and installer silently produces an incomplete project
  run "cp -r '$SOURCE_URL/.' '$TMP_DIR/' 2>/dev/null || true"
# git can clone https://, ssh:// and the scp-like git@host:owner/repo form. A private
# repo is usually only reachable over SSH, so rejecting the scp-like form here made
# OW_SOURCE useless for exactly the case that needs it.
elif [[ "$SOURCE_URL" =~ ^(https?|ssh|git):// || "$SOURCE_URL" =~ ^[^/[:space:]]+@[^/[:space:]]+: ]]; then
  if command -v git > /dev/null; then
    # Don't suppress stderr — user needs to see clone failures (auth, missing repo, network)
    if ! run "git clone --depth 1 --branch '$VERSION' '$SOURCE_URL' '$TMP_DIR' 2>&1"; then
      err ""
      err "❌ git clone ล้มเหลว"
      err "   source: $SOURCE_URL"
      err "   branch: $VERSION"
      err "   ตรวจ: repo ถูกต้อง? branch/tag มีอยู่จริง? network/credential ok?"
      exit 1
    fi
  else
    err "git ไม่พบ ติดตั้ง git ก่อน หรือใช้ --source ชี้ไป local folder"
    exit 1
  fi
else
  err "Source ไม่ valid: $SOURCE_URL"
  exit 1
fi

# Sanity check — verify template actually landed (catches silent partial clones)
if [[ $DRY_RUN -eq 0 ]] && [[ ! -f "$TMP_DIR/.ow.yml" ]] && [[ ! -d "$TMP_DIR/.ow/commands" ]]; then
  err "❌ Template ที่ clone มาว่างเปล่า หรือไม่ใช่ obsidian-workflow repo"
  err "   TMP_DIR: $TMP_DIR"
  err "   source: $SOURCE_URL ($VERSION)"
  exit 1
fi

# Canonical protected/SAFE_PATHS set — shared with upgrade.sh (single source of
# truth). Sourced from the freshly fetched template ($TMP_DIR) because install.sh
# is often run via `bash <(curl ...)` and has no reliable own-script dir.
PROTECTED=()
if [[ -f "$TMP_DIR/scripts/ow-safe-paths.sh" ]]; then
  . "$TMP_DIR/scripts/ow-safe-paths.sh"
  while IFS= read -r _sp; do [[ -n "$_sp" ]] && PROTECTED+=("$_sp"); done < <(ow_safe_paths "")
fi
# .claude/ ownership manifest + shim generator — shared with upgrade.sh (#3/#8)
[[ -f "$TMP_DIR/scripts/ow-claude-manifest.sh" ]] && . "$TMP_DIR/scripts/ow-claude-manifest.sh"
# Fail closed: with no manifest nothing can be PROVEN obsidian-workflow-owned, so every agent already
# on disk counts as the project's and is kept rather than overwritten.
if ! command -v ow_is_owned_agent >/dev/null 2>&1; then
  ow_is_owned_agent() { return 1; }
fi
# .claude/settings.json owned-key merge — shared with upgrade.sh (same single source)
[[ -f "$TMP_DIR/scripts/ow-settings-merge.sh" ]] && . "$TMP_DIR/scripts/ow-settings-merge.sh"
# Guard: a protected path that already exists in the target is NEVER overwritten,
# even with --yes. Fresh installs (path absent) proceed normally.
is_protected_existing() {
  local rel="$1"
  [[ -e "$TARGET/$rel" ]] || return 1
  [[ ${#PROTECTED[@]} -gt 0 ]] || return 1
  ow_path_is_safe "$rel" "${PROTECTED[@]}"
}

# Every pre-existing file this run is about to overwrite is copied here FIRST, under its own
# repo-relative path, so the previous content is always recoverable:
#   cp -R .ow/backups/install-<ts>/. .
# The dir is created lazily — a run that overwrites nothing leaves nothing behind. A backup
# that cannot be written ABORTS before the write it guards: obsidian-workflow never overwrites a file
# it failed to preserve.
INSTALL_BAKDIR="$TARGET/.ow/backups/install-$(date +%Y%m%d-%H%M%S)"
INSTALL_BAKED=0
backup_before_overwrite() {
  local rel="$1"
  [[ -e "$TARGET/$rel" ]] || return 0
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY-RUN: backup '$rel' → ${INSTALL_BAKDIR#$TARGET/}/$rel"
    return 0
  fi
  mkdir -p "$INSTALL_BAKDIR/$(dirname "$rel")" \
    && cp -R "$TARGET/$rel" "$INSTALL_BAKDIR/$rel" \
    || { err "backup failed for $rel — refusing to overwrite it"; exit 1; }
  INSTALL_BAKED=$((INSTALL_BAKED + 1))
}

# ---------- AI front-end picker ----------
# The list of front-ends, their labels, their asset folders and their emitter kinds
# all come from ONE registry so the picker, the folder map, the upgrade refresh set
# and the rollback set can never drift (they did: gpt/glm silently fell out of two
# of them). Sourced from $TMP_DIR for the same reason as ow-safe-paths.sh above —
# `bash <(curl ...)` leaves install.sh with no reliable own-script dir, which is why
# this block runs after the fetch rather than before it.
if [[ ! -f "$TMP_DIR/scripts/ow-frontends.sh" ]]; then
  err "❌ Template incomplete — scripts/ow-frontends.sh missing (AI front-end registry)"; exit 1
fi
. "$TMP_DIR/scripts/ow-frontends.sh"

AI_AVAILABLE=()
while IFS= read -r _fe; do [[ -n "$_fe" ]] && AI_AVAILABLE+=("$_fe"); done < <(ow_frontends)

ai_label()  { ow_frontend_label "$1"; }
ai_folder() { ow_frontend_folder "$1"; }

ai_validate() {
  # Validate comma list against the registry; print canonical comma list
  local input="$1" out=() r
  IFS=',' read -ra reqs <<< "$input"
  for r in "${reqs[@]}"; do
    r="$(echo "$r" | tr '[:upper:]' '[:lower:]' | xargs)"
    [ -z "$r" ] && continue
    if [ "$r" = "all" ]; then echo "${AI_AVAILABLE[*]}" | tr ' ' ','; return 0; fi
    if ow_frontend_valid "$r"; then
      out+=("$r")
    else
      err "Unknown AI agent: $r (available: ${AI_AVAILABLE[*]}, all)"; return 1
    fi
  done
  (IFS=,; echo "${out[*]:-}")
}

if [[ -z "$AI_AGENTS" ]]; then
  if [[ $YES -eq 1 ]]; then
    AI_AGENTS="claude"
    log "AI agent (auto-default): $AI_AGENTS"
  else
    ai_menu=""
    ai_idx=0
    for _fe in "${AI_AVAILABLE[@]}"; do
      ai_idx=$((ai_idx + 1))
      ai_menu+="$(printf '   %d) %-9s — %s' "$ai_idx" "$_fe" "$(ai_label "$_fe")")"$'\n'
    done
    cat <<EOF

🤖 ${c_bold:-}เลือก AI frontend ที่จะใช้${c_reset:-} (พิมพ์เลขคั่นด้วย comma เลือกได้หลายตัว):

${ai_menu}   a) all       — เลือกทั้ง ${#AI_AVAILABLE[@]}

Default: 1 (claude)

หมายเหตุ: นี่คือ AI frontend (CLI/web ที่จะคุยด้วย) — ไม่ใช่ subagent
         Subagent (backend/frontend/mobile/...) เริ่มต้นจะมีแค่ docs/verifier/security
         enable เพิ่มภายหลังด้วย /ow-agent enable <name> หรือ /ow-agent suggest
EOF
    # Read from /dev/tty, not stdin: the documented `bash <(curl ...)` invocation
    # leaves stdin pointing at the process-substitution FD, so a plain `read -p`
    # consumed script bytes instead of the answer and the picker misbehaved.
    # Falls back to stdin when there is no controlling tty (CI, piped input).
    if [[ -r /dev/tty ]]; then
      read -r -p "เลือก: " ai_input </dev/tty
    else
      read -r -p "เลือก: " ai_input
    fi
    ai_input="${ai_input:-1}"
    # Map numbers → names via the registry (position = table order)
    selected=()
    if [[ "$ai_input" =~ ^[Aa]$ ]] || [[ "$ai_input" == "all" ]]; then
      selected=("${AI_AVAILABLE[@]}")
    else
      IFS=',' read -ra picks <<< "$ai_input"
      for p in "${picks[@]}"; do
        p="$(echo "$p" | xargs)"
        resolved=""
        if [[ "$p" =~ ^[0-9]+$ ]]; then
          resolved="$(ow_frontend_by_index "$p")"
        elif ow_frontend_valid "$p"; then
          resolved="$p"
        fi
        if [[ -n "$resolved" ]]; then selected+=("$resolved"); else warn "ข้าม invalid: $p"; fi
      done
    fi
    [[ ${#selected[@]} -eq 0 ]] && { err "ต้องเลือก AI agent อย่างน้อย 1 ตัว"; exit 1; }
    AI_AGENTS=$(IFS=,; echo "${selected[*]}")
  fi
else
  AI_AGENTS=$(ai_validate "$AI_AGENTS") || exit 1
fi

log "AI agents to install: ${c_bold:-}$AI_AGENTS${c_reset:-}"

# ---------- copy template into target ----------
log "Installing obsidian-workflow scaffolding..."

# Always-installed items (core — regardless of AI selection)
# v0.4.1+ layout (commands/ moved under .ow/ — all obsidian-workflow machinery in one place):
#   - .ow/{commands/, templates/, rules/}
#   - .ow/commands/ = the verb specs (source of truth for every AI front-end)
#   - obsidian-workflow own version lives in .ow.yml `ow.version` key (no separate file)
#   - root templates/ — OPTIONAL project overrides (lookup chain: root → .ow/templates/)
#   - root commands/ — OPTIONAL project overrides (lookup chain: root → .ow/commands/)
SAFE_ITEMS=(
  ".ow/commands"
  ".ow/templates"
  ".ow/rules"        # project-rules layer (#17) — dir + README so scaffolds (#22) have a home
  ".ow.yml"
  ".ow.local.yml.example"
  # NOTE: .gitignore is intentionally NOT here. It is MERGED (managed-block only)
  # further down via ow_gitignore_merge — never wholesale-copied, so a brownfield
  # install can no longer clobber the host project's existing .gitignore.
  #
  # NOTE: README.md and AI-README.md are intentionally NOT installed. README.md is
  # obsidian-workflow's OWN repo readme (would land as the host project's README), and the
  # AI usage guidance the host needs already ships via CLAUDE.md (+ the per-AI
  # codex/gemini/gpt/glm prompt dirs). Both remain in ow-safe-paths PROTECTED so a
  # host's own same-named file is never overwritten.
)

# Scripts: install only runtime helpers — exclude obsidian-workflow source-only scripts.
# The owned-file manifest is the SINGLE SOURCE OF TRUTH (shared with upgrade.sh) so
# install vs. upgrade can never drift. install.sh / test.sh are source-only (excluded).
if [[ ! -f "$TMP_DIR/scripts/ow-owned.sh" ]]; then
  err "❌ Template incomplete — scripts/ow-owned.sh missing (owned-file manifest)"; exit 1
fi
. "$TMP_DIR/scripts/ow-owned.sh"
SCRIPTS_TO_INSTALL=()
while IFS= read -r _s; do [[ -n "$_s" ]] && SCRIPTS_TO_INSTALL+=("$_s"); done < <(ow_owned_scripts)

for item in "${SAFE_ITEMS[@]}"; do
  if [[ -e "$TMP_DIR/$item" ]]; then
    # Compute target path — preserve nested paths like ".ow/standards"
    target_path="$TARGET/$item"
    parent_dir="$(dirname "$target_path")"
    if is_protected_existing "$item"; then
      # User-owned config/override layer already present — never overwrite (even --yes)
      log "  preserved (user-owned, never overwritten): $item"
    elif [[ -e "$target_path" && "$MODE" == "brownfield" ]]; then
      warn "  skip existing: $item (ใช้ --yes เพื่อ overwrite)"
      [[ $YES -eq 1 ]] && { backup_before_overwrite "$item"; run "rm -rf '$target_path' && mkdir -p '$parent_dir' && cp -r '$TMP_DIR/$item' '$target_path'"; }
    else
      run "mkdir -p '$parent_dir' && cp -r '$TMP_DIR/$item' '$target_path'"
      log "  installed: $item"
    fi
  fi
done

# Install scripts whitelist (not whole scripts/ folder)
mkdir -p "$TARGET/scripts"
for s in "${SCRIPTS_TO_INSTALL[@]}"; do
  if [[ -f "$TMP_DIR/scripts/$s" ]]; then
    if [[ -f "$TARGET/scripts/$s" && "$MODE" == "brownfield" && $YES -ne 1 ]]; then
      warn "  skip existing: scripts/$s (use --yes to overwrite)"
    else
      backup_before_overwrite "scripts/$s"
      run "cp '$TMP_DIR/scripts/$s' '$TARGET/scripts/$s'"
      log "  installed: scripts/$s"
    fi
  fi
done

# Install bin/ owned files (same manifest — keeps install/upgrade symmetric so the
# documented `ow doctor|lint` CLI is available right after install, not only
# after the first upgrade). bin/ is mixed-ownership too — only owned files copied.
mkdir -p "$TARGET/bin"
while IFS= read -r b; do
  [[ -n "$b" && -f "$TMP_DIR/bin/$b" ]] || continue
  if [[ -f "$TARGET/bin/$b" && "$MODE" == "brownfield" && $YES -ne 1 ]]; then
    warn "  skip existing: bin/$b (use --yes to overwrite)"
  else
    backup_before_overwrite "bin/$b"
    run "cp '$TMP_DIR/bin/$b' '$TARGET/bin/$b' && chmod +x '$TARGET/bin/$b'"
    log "  installed: bin/$b"
  fi
done < <(ow_owned_bin)

# v0.4 migration: remove a legacy obsidian-workflow install.sh/test.sh from scripts/ — but ONLY
# if it carries obsidian-workflow's header signature (`# obsidian-workflow ` on line ≤3). A host project
# may legitimately own scripts/test.sh (its CI runner) or scripts/install.sh; those have
# no obsidian-workflow signature and MUST survive (matches upgrade.sh — single behavior, no
# divergent hardcoded list, no silent data loss on brownfield adoption).
while IFS= read -r old; do
  [[ -n "$old" && -f "$TARGET/scripts/$old" ]] || continue
  if ! head -3 "$TARGET/scripts/$old" | grep -q '^# obsidian-workflow '; then
    warn "  kept scripts/$old — no obsidian-workflow signature (host-owned, not removed)"
    continue
  fi
  log "  migration: removing scripts/$old (obsidian-workflow source-only — not for consumers)"
  [[ $DRY_RUN -eq 0 ]] && rm -f "$TARGET/scripts/$old"
done < <(ow_source_only_scripts)

# ---------- tombstones: files obsidian-workflow USED to own (scripts/ow-owned.sh) ----------
# upgrade applies these version-gated, so they run once. install cannot: it writes the SHIPPED
# version into .ow.yml, which is already past every `since`, so a brownfield install over
# a tree still carrying a retired file would strand it forever — the row can never fire again.
# So install sweeps ALL rows. Safe to do unconditionally because the guard is ownership, not
# version: only a path under scripts/ or bin/ still carrying obsidian-workflow's `# obsidian-workflow ` header
# signature is removed, and it is backed up first like every other overwrite this run makes.
if command -v ow_tombstones >/dev/null 2>&1; then
  while IFS="$(printf '\t')" read -r _tpath _tver _treason; do
    [[ -n "$_tpath" ]] || continue
    case "$_tpath" in scripts/*|bin/*) ;; *) continue ;; esac
    [[ -f "$TARGET/$_tpath" ]] || continue
    if ! head -3 "$TARGET/$_tpath" | grep -q '^# obsidian-workflow '; then
      warn "  kept $_tpath — no obsidian-workflow signature (host-owned, not removed)"
      continue
    fi
    backup_before_overwrite "$_tpath"
    log "  retired $_tpath (v$_tver — $_treason)"
    [[ $DRY_RUN -eq 0 ]] && rm -f "$TARGET/$_tpath"
  done < <(ow_tombstones)
fi

# ---------- v0.4 migrations (run AFTER copy, so new files exist for conflict detection) ----------
# Goal: bring any prior layout to the current FLAT layout: .ow/{commands,templates,…}
# Sources of legacy state:
#   pre-v0.4:           root standards/  +  root VERSION
#   v0.4-intermediate:  .ow/standards/  +  .ow/VERSION (obsidian-workflow own)
#
# Order matters: drop the obsidian-workflow-own VERSION BEFORE flattening
#
# Note: by this point, SAFE_ITEMS loop has already copied the new flat files in.

# (1) Migrate pre-v0.4 root standards/ → .ow/ (flat)
LEGACY_ROOT_STD="$TARGET/standards"
if [[ -d "$LEGACY_ROOT_STD" ]]; then
  bak="$TARGET/standards.bak-$(date +%Y%m%d-%H%M%S)"
  log "  migration (v0.4): moving legacy root standards/ → $bak (template already provided fresh copies in .ow/)"
  [[ $DRY_RUN -eq 0 ]] && mv "$LEGACY_ROOT_STD" "$bak"
fi

# (2) Migrate v0.4-intermediate .ow/standards/ → flatten into .ow/
if [[ -d "$TARGET/.ow/standards" ]]; then
  bak="$TARGET/.ow/standards.bak-$(date +%Y%m%d-%H%M%S)"
  log "  migration (v0.4): moving .ow/standards/ → $bak (now flat under .ow/)"
  [[ $DRY_RUN -eq 0 ]] && mv "$TARGET/.ow/standards" "$bak"
fi

# (3) Root VERSION handling (#2 — data-loss fix; mirrors scripts/upgrade.sh).
# A host project's own root VERSION must never be silently deleted. Preserve by
# default; migrate only a genuinely legacy obsidian-workflow marker (no ow: block AND a
# release-shaped value), and only after back up → persist → verify → then delete.
if [[ -f "$TARGET/VERSION" ]]; then
  root_ver=$(cat "$TARGET/VERSION" 2>/dev/null | tr -d '[:space:]')
  if [[ $DRY_RUN -eq 0 ]]; then
    # No backup in the preserve paths — the file is left untouched, so a backup is
    # pure litter (this was the cause of stray VERSION.ow-backup-* files). A
    # backup is created ONLY in the migration branch, immediately before deletion.
    if [[ -f "$TARGET/.ow.yml" ]] && grep -q "^ow:" "$TARGET/.ow.yml"; then
      log "  note: root VERSION ($root_ver) preserved — .ow.yml already has ow.version (host-owned)"
    elif printf '%s' "$root_ver" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+'; then
      # Genuinely legacy obsidian-workflow marker → migrate: back up → persist → verify → delete.
      bak="$TARGET/VERSION.ow-backup-$(date +%Y%m%d-%H%M%S)"
      cp "$TARGET/VERSION" "$bak" 2>/dev/null || true
      if [[ -n "$root_ver" && -f "$TARGET/.ow.yml" ]]; then
        printf '\now:\n  version: "%s"\n' "$root_ver" >> "$TARGET/.ow.yml"
      fi
      if grep -q "^ow:" "$TARGET/.ow.yml" 2>/dev/null \
         && grep -q "version: \"$root_ver\"" "$TARGET/.ow.yml" 2>/dev/null \
         && [[ -f "$bak" ]]; then
        rm -f "$TARGET/VERSION"
        log "  migration: legacy root VERSION ($root_ver) migrated to .ow.yml + backed up ($bak), then removed"
      else
        # Migration aborted — file left intact, so the backup is also useless: clean it up.
        rm -f "$bak" 2>/dev/null || true
        warn "  root VERSION ($root_ver) NOT removed — persist/verify incomplete (file left intact, no backup needed)"
      fi
    else
      log "  note: root VERSION ($root_ver) preserved — not a obsidian-workflow release (host-owned)"
    fi
  fi
fi

# (4) v0.4.1 migration: legacy root commands/ → archive (commands moved to .ow/commands/)
# In v0.4 and earlier, commands/ sat at project root. Now it lives under .ow/ together
# with the rest of the obsidian-workflow machinery. Archive the legacy folder if user has not customized
# beyond what we now ship — otherwise warn and keep both as override layer.
if [[ -d "$TARGET/commands" ]]; then
  # Detect customization: any file in root commands/ that differs from the new .ow/commands/ ?
  has_custom=0
  if [[ -d "$TARGET/.ow/commands" ]]; then
    while IFS= read -r f; do
      rel="${f#$TARGET/commands/}"
      if [[ ! -f "$TARGET/.ow/commands/$rel" ]] || ! diff -q "$f" "$TARGET/.ow/commands/$rel" >/dev/null 2>&1; then
        has_custom=1
        break
      fi
    done < <(find "$TARGET/commands" -type f -name '*.md' 2>/dev/null)
  fi
  if [[ $has_custom -eq 1 ]]; then
    log "  note: root commands/ พบ + มี customization — เก็บไว้เป็น override layer (lookup: root commands/ → .ow/commands/)"
  else
    bak="$TARGET/commands.bak-$(date +%Y%m%d-%H%M%S)"
    log "  migration (v0.4.1): moving legacy root commands/ → $bak (now under .ow/commands/)"
    [[ $DRY_RUN -eq 0 ]] && mv "$TARGET/commands" "$bak"
  fi
fi

# (5) v0.4.1 schema migration: standard.* block → ow.* block ใน .ow.yml
# Uses python3 (more available than yq); preserves comments + ordering best-effort
if [[ -f "$TARGET/.ow.yml" ]] && command -v python3 >/dev/null 2>&1 && [[ $DRY_RUN -eq 0 ]]; then
  migrated=$(python3 - "$TARGET/.ow.yml" <<'PYEOF'
import re, sys
p = sys.argv[1]
with open(p) as f: txt = f.read()
m = re.search(r'(?ms)^standard:\s*\n((?:[ \t]+.+\n?)+)', txt)
if not m:
    sys.exit(0)  # nothing to migrate
block = m.group(1)
src_m   = re.search(r'^\s+source:\s*"?([^"\n]+)"?', block, re.M)
sync_m  = re.search(r'^\s+last_synced:\s*"?([^"\n]+)"?', block, re.M)
src     = src_m.group(1).strip() if src_m else ''
sync    = sync_m.group(1).strip() if sync_m else ''
# Drop the whole standard: block
new = re.sub(r'(?ms)^standard:\s*\n(?:[ \t]+.+\n?)+', '', txt)
# Ensure ow: block has source + last_synced if not already
bs_m = re.search(r'(?ms)^ow:\s*\n((?:[ \t]+.+\n?)+)', new)
if bs_m:
    bs_block = bs_m.group(1)
    additions = ''
    if src and 'source:' not in bs_block:
        additions += f'  source: "{src}"\n'
    if sync and 'last_synced:' not in bs_block:
        additions += f'  last_synced: "{sync}"\n'
    if additions:
        # Append to ow: block
        new = new[:bs_m.end()] + additions + new[bs_m.end():]
else:
    # No ow: block at all — create one
    block_yaml = 'ow:\n'
    if src:  block_yaml += f'  source: "{src}"\n'
    if sync: block_yaml += f'  last_synced: "{sync}"\n'
    new = new.rstrip() + '\n\n' + block_yaml
with open(p, 'w') as f: f.write(new)
print('OK')
PYEOF
)
  if [[ "$migrated" == "OK" ]]; then
    log "  migration (v0.4.1): consolidated .ow.yml standard.* → ow.*"
  fi
fi

# Legacy root templates/: leave alone if user has customizations; only note its presence
if [[ -d "$TARGET/templates" ]]; then
  log "  note: root templates/ พบ — เก็บไว้เป็น override layer (v0.4 ไม่ติดตั้งให้แล้ว แต่ใช้ได้ถ้ามี)"
fi

# ---------- AI agent folders (only selected ones) ----------
# Always-on subagents (vault/quality/security keepers — every project needs these).
# - docs/verifier/security: core keepers
# - gh-issue: read-only GitHub issue+image reader — dependency ของ /ow-triage-issues + /ow-fix-issue
#   (always-installed เพราะ 2 commands นั้นเป็น core; haiku read-only = harmless ถ้าไม่ใช้)
# Specialized subagents (backend/frontend/mobile/design/test-runner และชื่อที่ project
# ตั้งเอง) ไม่ได้ ship มา — สร้างทีหลังด้วย /ow-agent suggest → /ow-agent create <name>
# หลัง /ow-init detect stack แล้ว body จึงตรงกับ stack จริงของ project ไม่ใช่ของกลาง
ALWAYS_ON_AGENTS=(docs verifier security gh-issue)

# Helper: per-file SELECTIVE MERGE of .claude/ (issues #3/#8).
# Overwrites ONLY the files obsidian-workflow owns (generated shims + always-on agents +
# settings.json). NEVER rm -rf's the tree, NEVER touches settings.local.json, user
# hooks, MCP permission files, or project-enabled (specialized) agent docs.
install_claude_selective() {
  local src="$TMP_DIR/.claude"
  local dst="$TARGET/.claude"

  # Shims are regenerated wholesale below; back the dir up before the first write so a
  # project's own file under a ow-* name is recoverable. BEFORE the mkdir, or a greenfield
  # run "backs up" the empty dir it just made and reports overwriting a file that never was.
  backup_before_overwrite ".claude/commands"

  run "mkdir -p '$dst/agents' '$dst/commands'"

  # commands — GENERATE shims override-first from the verb specs (was: cp -r whole
  # folder verbatim, which ignored the project commands/ override layer). #8
  if [[ -d "$TMP_DIR/.ow/commands" ]] && command -v generate_shims >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "DRY-RUN: generate_shims from .ow/commands → .claude/commands (override-first)"
    else
      generate_shims "$TMP_DIR/.ow/commands" "$TARGET" "ow"
    fi
  elif [[ -d "$src/commands" ]]; then
    warn "  shim generator unavailable — falling back to verbatim shim copy"
    run "cp -r '$src/commands/.' '$dst/commands/'"
  fi

  # settings.json — team-shared, but only SOME KEYS are obsidian-workflow's ($schema,
  # permissions.allow, env.OW_*). Merge those; a brownfield project's hooks,
  # permissions.deny/ask and env additions survive. settings.local.json is per-machine
  # and is NEVER copied or removed.
  if [[ -f "$src/settings.json" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "DRY-RUN: merge '$src/settings.json' → '$dst/settings.json' (your hooks/deny/ask/env kept)"
    elif command -v ow_settings_merge >/dev/null 2>&1; then
      backup_before_overwrite ".claude/settings.json"
      ow_settings_merge "$src/settings.json" "$dst/settings.json"
    elif [[ ! -f "$dst/settings.json" ]]; then
      run "cp '$src/settings.json' '$dst/'"
    else
      warn "  settings merge helper unavailable — .claude/settings.json left unchanged"
    fi
  fi

  # agents — write only where the destination is obsidian-workflow's, decided by SIGNATURE and never
  # by filename: a project may own an agent called backend.md and it is kept, not replaced.
  # adopt_existing_claude already offered keep/remove for it before this ran.
  local copied=() kept=()
  for a in ${OW_ALWAYS_ON_AGENTS:-${ALWAYS_ON_AGENTS[*]}}; do
    if [[ -f "$src/agents/$a.md" ]]; then
      if [[ -e "$dst/agents/$a.md" ]] && ! ow_is_owned_agent "$dst/agents/$a.md"; then
        kept+=("$a")
        continue
      fi
      backup_before_overwrite ".claude/agents/$a.md"
      run "cp '$src/agents/$a.md' '$dst/agents/'"
      copied+=("$a")
    fi
  done
  log "  merged: .claude/ (shims generated + always-on agents: ${copied[*]:-none}; user settings/hooks/agents preserved)"
  [[ ${#kept[@]} -gt 0 ]] && warn "  kept project-owned agents — obsidian-workflow's NOT installed: ${kept[*]} (rename or delete yours and re-run to take obsidian-workflow's)"

  # Enabled ⟺ present ⟺ spawnable. Only /ow-agent writes a specialized body, so install
  # cannot materialize one — but a brownfield .ow.yml that already enables
  # backend/frontend/... would otherwise carry a flag with nothing behind it in silence.
  # Name it instead, and name the one command that fixes it.
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY-RUN: verify every enabled subagent has a body under .claude/agents/"
  elif command -v verify_enabled_agents >/dev/null 2>&1; then
    verify_enabled_agents "$TARGET" \
      || warn "  an enabled subagent has no body — create it with /ow-agent create <name>"
  fi
  log "  note: /ow-triage-issues + /ow-fix-issue ใช้ gh CLI + agent gh-issue (ติดมาแล้ว)"
  log "  note: specialized agents (backend/frontend/mobile/...) — รัน /ow-agent suggest หลัง /ow-init แล้ว /ow-agent create <name>"
}

# Back up then remove one user-owned file (dry-run prints the intent).
_adopt_remove() {
  local f="$1" bakdir="$2"
  if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: backup+remove '$f' → '$bakdir/'"; return; fi
  mkdir -p "$bakdir"
  mv "$f" "$bakdir/" && log "    removed (backed up): $(basename "$f")"
}

# Ask keep/remove/select for a category. Writes the chosen mode to stdout; all human
# text goes to stderr (stdout is captured by the caller). Non-interactive → keep + warn.
_adopt_prompt() {
  local category="$1"; shift
  if [[ $YES -eq 1 || ! -t 0 ]]; then
    warn "  $category: keeping all (non-interactive default). New ow-* commands will NOT inject" >&2
    warn "    the §0 PROJECT CONTEXT block into non-conforming agents — the two layers may not interoperate." >&2
    echo "keep"; return
  fi
  local reply
  {
    echo ""
    echo "  How to handle the $# pre-existing $category (not owned by obsidian-workflow)?"
    echo "    [k] keep all (default) — leave them; obsidian-workflow adds its own beside them"
    echo "    [r] remove all — back up to .ow/backups/ then delete"
    echo "    [s] select per item — choose keep/remove for each"
  } >&2
  read -r -p "  choice [k/r/s] (k): " reply </dev/tty
  case "${reply:-k}" in
    r|R) echo "remove" ;;
    s|S) echo "select" ;;
    *)   echo "keep" ;;
  esac
}

# Apply a chosen mode to a category's files.
_adopt_apply() {
  local category="$1" bakdir="$2" choice="$3"; shift 3
  local f base r
  case "$choice" in
    keep)
      log "  $category: kept all ($# file(s)). Interop note: obsidian-workflow injects §0 only into obsidian-workflow-owned agents."
      ;;
    remove)
      for f in "$@"; do _adopt_remove "$f" "$bakdir"; done
      log "  $category: removed $# file(s) → backed up under ${bakdir#$TARGET/}"
      ;;
    select)
      for f in "$@"; do
        base="$(basename "$f")"
        if [[ $YES -eq 1 || ! -t 0 ]]; then r="k"; else read -r -p "    $category/$base — [k]eep / [r]emove (k): " r </dev/tty; fi
        case "${r:-k}" in r|R) _adopt_remove "$f" "$bakdir" ;; *) log "    kept: $base" ;; esac
      done
      ;;
  esac
}

# Adoption UX (#21): detect pre-existing USER-OWNED .claude agents/commands (not shipped
# by obsidian-workflow) and ask keep/remove/select — independently for agents and commands. The
# choice is recorded under .ow/local/adopt.marker so re-runs / upgrades don't re-prompt.
adopt_existing_claude() {
  [[ -d "$TARGET/.claude/agents" || -d "$TARGET/.claude/commands" ]] || return 0
  local marker="$TARGET/.ow/local/adopt.marker"
  local f base
  local user_agents=() user_cmds=()

  if [[ -d "$TARGET/.claude/agents" ]]; then
    for f in "$TARGET/.claude/agents"/*.md; do
      [[ -e "$f" ]] || continue
      # ownership by SIGNATURE, not filename — a project may legitimately own an agent
      # called backend.md, and it must be offered keep/remove like any other file of theirs.
      ow_is_owned_agent "$f" || user_agents+=("$f")
    done
  fi
  if [[ -d "$TARGET/.claude/commands" ]]; then
    for f in "$TARGET/.claude/commands"/*.md; do
      [[ -e "$f" ]] || continue
      base="$(basename "$f")"
      case "$base" in ow-*.md) ;; *) user_cmds+=("$f") ;; esac
    done
  fi

  [[ ${#user_agents[@]} -eq 0 && ${#user_cmds[@]} -eq 0 ]] && return 0

  if [[ -f "$marker" ]]; then
    log "  adopt: prior keep/remove choice recorded (.ow/local/adopt.marker) — not re-prompting"
    return 0
  fi

  log ""
  log "Pre-existing user-owned .claude files detected (not shipped by obsidian-workflow):"
  [[ ${#user_agents[@]} -gt 0 ]] && log "  agents:   ${user_agents[*]##*/}"
  [[ ${#user_cmds[@]} -gt 0 ]]   && log "  commands: ${user_cmds[*]##*/}"

  local ts bak choice_agents="keep" choice_cmds="keep"
  ts="$(date +%Y%m%d-%H%M%S)"
  bak="$TARGET/.ow/backups/adopt-$ts"

  if [[ ${#user_agents[@]} -gt 0 ]]; then
    choice_agents="$(_adopt_prompt agents "${user_agents[@]}")"
    _adopt_apply "agents" "$bak/agents" "$choice_agents" "${user_agents[@]}"
  fi
  if [[ ${#user_cmds[@]} -gt 0 ]]; then
    choice_cmds="$(_adopt_prompt commands "${user_cmds[@]}")"
    _adopt_apply "commands" "$bak/commands" "$choice_cmds" "${user_cmds[@]}"
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$TARGET/.ow/local"
    { echo "# obsidian-workflow adopt choice — $ts"; echo "agents=$choice_agents"; echo "commands=$choice_cmds"; } > "$marker"
    log "  adopt: choice recorded → .ow/local/adopt.marker (agents=$choice_agents, commands=$choice_cmds)"
  else
    echo "DRY-RUN: would record adopt choice → .ow/local/adopt.marker (agents=$choice_agents, commands=$choice_cmds)"
  fi
}

# Rule scaffolds (#22): create .ow/rules/<area>.md stubs for the ENABLED areas so a
# new adopter has a concrete, correctly-named file to fill in (not just an empty dir).
# Tracked (shared) by default; idempotent — never overwrites an existing rule file.
scaffold_rules() {
  local rdir="$TARGET/.ow/rules"
  [[ -d "$rdir" ]] || return 0
  local subs="" a area rf
  if [[ -f "$TARGET/scripts/ow-paths.sh" ]] && command -v yq >/dev/null 2>&1; then
    subs="$(OW_ROOT="$TARGET" bash "$TARGET/scripts/ow-paths.sh" --subagents 2>/dev/null | tr '\n' ' ')"
  fi
  if [[ -z "${subs// }" ]]; then   # fallback: grep enabled subagents straight from config
    subs="$(grep -E '^[[:space:]]+(docs|verifier|security|backend|frontend|mobile|design|test-runner):[[:space:]]*true' \
            "$TARGET/.ow.yml" 2>/dev/null | sed -E 's/^[[:space:]]*([a-z-]+):.*/\1/' | tr '\n' ' ')"
  fi
  local created=()
  for a in $subs; do
    case "$a" in
      backend) area=backend ;; frontend) area=frontend ;; mobile) area=mobile ;;
      design) area=design ;; security) area=security ;; docs) area=docs ;;
      test-runner) area=testing ;;
      *) continue ;;   # verifier, gh-issue → not a rule area
    esac
    rf="$rdir/$area.md"
    [[ -e "$rf" ]] && continue
    if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: scaffold rule .ow/rules/$area.md"; continue; fi
    cat > "$rf" <<RULESTUB
---
applies_to: [$area]
---
# $area conventions for THIS project

<!-- Put this project's $area conventions here. A rule resolved for this area
     OVERRIDES the generic guidance baked into the command/agent specs for $area.
     Keep concrete project facts here — never in core (they'd be lost on upgrade).
     Delete this file if this project has no special $area conventions. -->
RULESTUB
    created+=("$area.md")
  done
  [[ ${#created[@]} -gt 0 ]] && log "  scaffolded rules: ${created[*]} (.ow/rules/ — fill in or delete)"
  return 0
}

log "Installing AI agent shims: $AI_AGENTS"
IFS=',' read -ra AI_LIST <<< "$AI_AGENTS"
INSTALLED_AI=()
for ai in "${AI_LIST[@]}"; do
  folder=$(ai_folder "$ai")

  # Claude: selective copy (commands + always-on agents only)
  if [[ "$ai" == "claude" ]]; then
    if [[ -d "$TMP_DIR/.claude" ]]; then
      if [[ -d "$TARGET/.claude" && "$MODE" == "brownfield" && $YES -ne 1 ]]; then
        warn "  skip existing: .claude/ (use --yes to merge shipped files only)"
      else
        # Offer keep/remove for the project's own .claude files BEFORE the merge writes
        # anything — asking afterwards asks about a file that is already gone. Placed inside
        # this branch, not beside it, so a run that skips .claude never prompts about files
        # nothing is going to touch.
        adopt_existing_claude
        # per-file selective merge — NEVER rm -rf .claude (would destroy
        # settings.local.json, hooks, MCP perms, project-enabled agents). #3
        install_claude_selective
        INSTALLED_AI+=("$ai")
      fi
    else
      warn "  template missing: .claude/ (claude) — skipped"
    fi

    # Claude needs CLAUDE.md at root (AI-specific entry point). obsidian-workflow owns ONLY the
    # marked block inside it — same contract as the .gitignore managed block — so a host's
    # own instructions are never clobbered AND a brownfield project actually receives the
    # workflow contract instead of a "merge it yourself" note nobody acts on. A wholesale
    # copy is what shipped this repo's dev-only prose into consumer projects.
    if [[ -e "$TMP_DIR/CLAUDE.md" && -f "$TMP_DIR/scripts/ow-claude-md.sh" ]]; then
      . "$TMP_DIR/scripts/ow-claude-md.sh"
      if [[ $DRY_RUN -eq 1 ]]; then
        log "  would merge: CLAUDE.md (obsidian-workflow managed block — existing host prose preserved)"
      else
        # A refresh REWRITES the marked span in place, so the previous content must be
        # recoverable like every other overwrite this run makes. Span-conditional: a create
        # or an append overwrites nothing and must not be counted as an overwrite.
        if _ow_cm_has_span "$TARGET/CLAUDE.md"; then backup_before_overwrite "CLAUDE.md"; fi
        _cm_rc=0
        _cm_did="$(ow_claude_md_merge "$TARGET/CLAUDE.md" "$TMP_DIR/CLAUDE.md")" || _cm_rc=$?
        case "$_cm_did" in
          created)   log "  created: CLAUDE.md (obsidian-workflow managed block only)" ;;
          refreshed) log "  refreshed: CLAUDE.md (obsidian-workflow managed block; host prose preserved)" ;;
          appended)  log "  merged: CLAUDE.md (appended obsidian-workflow managed block; existing lines preserved)" ;;
          *)
            case "$_cm_rc" in
              3) warn "  CLAUDE.md WRITE FAILED (rc=3) — nothing was written; check permissions and free space" ;;
              2) warn "  CLAUDE.md has a OW START marker with no matching END — refusing to guess the span; fix the markers by hand, then re-run" ;;
              *) warn "  CLAUDE.md left untouched (merge rc=$_cm_rc) — the shipped CLAUDE.md carries no managed block" ;;
            esac ;;
        esac
      fi
    fi
    continue
  fi

  # Other AI frontends: copy the front-end's own asset folder (README / prompts).
  # NOTE the trailing '/.' on the source and the explicit mkdir: plain
  # `cp -r src dst/` NESTS as dst/<folder>/<folder> whenever dst/<folder> already
  # exists. The brownfield branch above guarded that case; a greenfield run into a
  # dir that happens to contain e.g. cline/ did not.
  if [[ -e "$TMP_DIR/$folder" ]]; then
    if [[ -e "$TARGET/$folder" && "$MODE" == "brownfield" ]]; then
      warn "  skip existing: $folder (use --yes to overwrite)"
      [[ $YES -eq 1 ]] && {
        run "rm -rf '$TARGET/$folder' && mkdir -p '$TARGET/$folder' && cp -r '$TMP_DIR/$folder/.' '$TARGET/$folder/'"
        INSTALLED_AI+=("$ai")
      }
    else
      run "mkdir -p '$TARGET/$folder' && cp -r '$TMP_DIR/$folder/.' '$TARGET/$folder/'"
      log "  installed: $folder ($ai)"
      INSTALLED_AI+=("$ai")
    fi
  else
    warn "  template missing: $folder ($ai) — skipped"
  fi
done


# ---------- shared per-KIND assets ----------
# Installed once when at least one front-end of that kind is enabled. Which paths
# belong to which kind comes from the registry (ow_kind_shared_paths), so this can
# never drift from the picker the way the old `gpt|glm|google` literal did.
ai_kind_enabled() {
  local want="$1" a
  for a in "${INSTALLED_AI[@]:-}"; do
    [[ -n "$a" ]] || continue
    [[ "$(ow_frontend_kind "$a")" == "$want" ]] && return 0
  done
  return 1
}

# router kind → shared prompts/ (general-AI paste material)
if ai_kind_enabled router; then
  if [[ -d "$TMP_DIR/prompts" && ! -d "$TARGET/prompts" ]]; then
    run "cp -r '$TMP_DIR/prompts' '$TARGET/'"
    log "  installed: prompts/ (general-AI shared)"
  elif [[ -d "$TARGET/prompts" ]]; then
    log "  kept existing: prompts/ (not overwritten)"
  fi
fi

# skills kind → root AGENTS.md, the shared entry point for Cline / Kimi / Codex.
# Same contract as CLAUDE.md: protected, so a host's own AGENTS.md is never clobbered.
if ai_kind_enabled skills; then
  if [[ -e "$TMP_DIR/AGENTS.md" ]]; then
    if is_protected_existing "AGENTS.md"; then
      log "  preserved (user-owned, never overwritten): AGENTS.md (merge the obsidian-workflow section manually)"
    elif [[ ! -e "$TARGET/AGENTS.md" || $YES -eq 1 ]]; then
      run "cp '$TMP_DIR/AGENTS.md' '$TARGET/AGENTS.md'"
      log "  installed: AGENTS.md (shared entry point)"
    fi
  else
    warn "  template missing: AGENTS.md — Cline/Kimi/Codex will have no entry point"
  fi
fi

# ---------- generate per-kind command shims ----------
# One verb spec → whatever file format each kind reads. All emitters resolve the
# project override layer (commands/<verb>.md) first, so no front-end is blind to it.
if [[ -d "$TMP_DIR/.ow/commands" ]]; then
  if ai_kind_enabled skills && command -v generate_skills >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "DRY-RUN: generate_skills from .ow/commands → .agents/skills (override-first)"
    else
      log "  generating .agents/skills/ (Cline · Kimi · Codex)"
      generate_skills "$TMP_DIR/.ow/commands" "$TARGET"
    fi
  fi
  if ai_kind_enabled router && command -v generate_router >/dev/null 2>&1; then
    for ai in "${INSTALLED_AI[@]:-}"; do
      [[ -n "$ai" ]] || continue
      [[ "$(ow_frontend_kind "$ai")" == "router" ]] || continue
      if [[ $DRY_RUN -eq 1 ]]; then
        echo "DRY-RUN: generate_router → $(ai_folder "$ai")/prompts/router.md (override-first)"
      else
        generate_router "$TMP_DIR/.ow/commands" "$TARGET" "$(ai_folder "$ai")" "$(ai_label "$ai")"
        log "  generated: $(ai_folder "$ai")/prompts/router.md"
      fi
    done
  fi
fi

# Persist ai_agents into .ow.yml
# Record what was ACTUALLY installed, not what was requested. A brownfield run that
# hit `skip existing: .claude/` used to still record claude, and upgrade would then
# merge .claude/ into a project that never received it.
AI_AGENTS_INSTALLED="$(IFS=,; echo "${INSTALLED_AI[*]:-}")"
if [[ -f "$TARGET/.ow.yml" && $DRY_RUN -eq 0 ]]; then
  if grep -q "^ai_agents:" "$TARGET/.ow.yml" 2>/dev/null; then
    sed -i.bak "s|^ai_agents:.*|ai_agents: [${AI_AGENTS_INSTALLED//,/, }]|" "$TARGET/.ow.yml" \
      && rm -f "$TARGET/.ow.yml.bak"
  else
    printf '\n# AI agents enabled in this project (set by installer)\nai_agents: [%s]\n' \
      "$(echo "$AI_AGENTS_INSTALLED" | sed 's/,/, /g')" >> "$TARGET/.ow.yml"
  fi
fi

# ---------- Vault location prompt (separate from green/brownfield detection) ----------
# `--here` ≠ brownfield: ผู้ใช้อาจรันใน folder ว่างที่เพิ่งสร้าง หรือใน repo ที่มี code อยู่แล้ว
# ดังนั้นถามตำแหน่ง vault เป็นคำถามแยก ไม่ผูกกับ mode

vault_default="docs/obsidian-vault"
# ถ้า brownfield + docs/ มีเนื้อหาอื่นๆอยู่ → ใช้ docs/obsidian-vault/ (default) — แยกชัด
[[ "$MODE" == "brownfield" && -d "$TARGET/docs" && ! -d "$TARGET/docs/obsidian-vault" ]] && vault_default="docs/obsidian-vault"

if [[ $YES -eq 0 ]]; then
  cat <<EOF

📁 Obsidian vault location
   A) สร้างใหม่ใน docs/obsidian-vault/     (default — แยกจาก docs/ ที่อาจมีเอกสารอื่น)
   B) สร้างใหม่ใน docs/                    (ใช้ docs/ เป็น vault โดยตรง — สำหรับ project เล็ก)
   C) ใช้ vault ที่มีอยู่แล้วใน repo นี้    (ใส่ relative path)
   D) ใช้ external vault (path นอก repo)   (เช่น Obsidian sync folder)

EOF
  vault_choice=$(ask "เลือก (A/B/C/D)" "A")
else
  vault_choice="A"
fi

VAULT_PATH=""
EXTERNAL_VAULT=""

case "$vault_choice" in
  [Aa])
    VAULT_PATH="docs/obsidian-vault"
    ;;
  [Bb])
    VAULT_PATH="docs"
    ;;
  [Cc])
    existing_path=$(ask "Path ของ vault ที่มีอยู่ (relative to repo root)" "docs")
    VAULT_PATH="$existing_path"
    ;;
  [Dd])
    ext_path=$(ask "Absolute path ของ external vault" "")
    [[ -z "$ext_path" ]] && { err "External vault path ห้ามว่าง"; exit 1; }
    EXTERNAL_VAULT="$ext_path"
    VAULT_PATH="external"
    log "External vault: $EXTERNAL_VAULT"
    log "(จะบันทึกใน .ow.local.yml — gitignored)"
    ;;
  *)
    err "ตัวเลือกไม่ถูกต้อง: $vault_choice"
    exit 1
    ;;
esac

# Create vault skeleton (skip if external — assumes user has it set up)
if [[ "$VAULT_PATH" != "external" ]]; then
  full_vault="$TARGET/$VAULT_PATH"
  if [[ ! -d "$full_vault" ]]; then
    log "สร้าง vault ที่ $VAULT_PATH/"
    run "mkdir -p '$full_vault'"
  fi

  # Copy sample only if greenfield + brand-new vault location + sample available.
  # Source is the sample VAULT itself (docs/obsidian-vault/), not its parent docs/ —
  # copying the parent lands the vault one level below $VAULT_PATH (docs/obsidian-vault/obsidian-vault/).
  sample_vault="$TMP_DIR/docs/obsidian-vault"
  if [[ $NO_SAMPLE -eq 0 && "$MODE" == "greenfield" && -d "$sample_vault" && -z "$(ls -A "$full_vault" 2>/dev/null)" ]]; then
    log "Greenfield: copy sample Library Book Tracker → $VAULT_PATH/"
    run "cp -r '$sample_vault/.' '$full_vault/'"
  else
    # Brownfield or non-empty vault — สร้างแค่ skeleton folders
    for sub in 00-Index 10-PRD 20-Features 30-Roles 40-Functions 50-Phases 60-Flows 70-Reference 80-ImplementPlan 85-FixLog 90-TestPlan 95-Handoff; do
      run "mkdir -p '$full_vault/$sub'"
    done
  fi
fi

# Save external_vault to .ow.local.yml if chosen
if [[ -n "$EXTERNAL_VAULT" ]]; then
  if [[ ! -f "$TARGET/.ow.local.yml" ]]; then
    if [[ -f "$TMP_DIR/.ow.local.yml.example" ]]; then
      run "cp '$TMP_DIR/.ow.local.yml.example' '$TARGET/.ow.local.yml'"
    else
      run "touch '$TARGET/.ow.local.yml'"
    fi
  fi
  # Set external_vault — use sed for cross-platform compatibility
  if grep -q "external_vault:" "$TARGET/.ow.local.yml" 2>/dev/null; then
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i.bak "s|external_vault:.*|external_vault: \"$EXTERNAL_VAULT\"|" "$TARGET/.ow.local.yml" && rm "$TARGET/.ow.local.yml.bak" 2>/dev/null || true
    fi
  else
    if [[ $DRY_RUN -eq 0 ]]; then
      printf '\npaths:\n  external_vault: "%s"\n' "$EXTERNAL_VAULT" >> "$TARGET/.ow.local.yml"
    fi
  fi
  log "  → .ow.local.yml saved (gitignored)"
fi

# Persist VAULT_PATH to .ow.yml (replace default vault_path: docs)
if [[ -f "$TARGET/.ow.yml" && "$VAULT_PATH" != "docs" && $DRY_RUN -eq 0 ]]; then
  sed -i.bak "s|^vault_path:.*|vault_path: $VAULT_PATH|" "$TARGET/.ow.yml" && rm "$TARGET/.ow.yml.bak" 2>/dev/null || true
fi

# ---------- Project identity (project.name / project.slug) ----------
# The shipped .ow.yml carries a sample identity. Left in place, the host project
# resolves project.name to the sample and names generated files after it. Rewrite it ONLY
# while the sample value is still there, so a re-install over a project that already set its
# own name (the file is in SAFE_PATHS and preserved) can never clobber it. Default = target
# folder basename, so a --yes / CI run still lands a real name.
# Surgical sed only — `yq -i` on this file strips its 110 comment lines.
if [[ -f "$TARGET/.ow.yml" && $DRY_RUN -eq 0 ]] \
   && grep -q '^  name: "Library Book Tracker"' "$TARGET/.ow.yml"; then
  project_name="$(basename "$(cd "$TARGET" && pwd)")"
  if [[ $YES -eq 0 ]]; then
    pn_input=""
    if [[ -r /dev/tty ]]; then
      read -r -p "📛 ชื่อ project [$project_name]: " pn_input </dev/tty || pn_input=""
    else
      read -r -p "📛 ชื่อ project [$project_name]: " pn_input || pn_input=""
    fi
    project_name="${pn_input:-$project_name}"
  fi
  # slug: lowercase; each run of non-alphanumerics becomes one dash; no leading/trailing dash.
  # BSD sed (macOS) has no `+` in a basic regex — \{1,\} is the portable spelling.
  project_slug="$(printf '%s' "$project_name" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"
  [[ -n "$project_slug" ]] || project_slug="project"
  # Two escapes, in this order. A YAML double-quoted scalar has exactly two hazards — `"`
  # ends it and `\` opens an escape — and both are legal in a directory name, so they reach
  # here through `basename "$TARGET"` alone. Escaping YAML first is what makes the sed stage
  # protect the backslashes the YAML stage just added; the reverse order leaves them bare.
  pn_yaml="$(printf '%s' "$project_name" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  pn_esc="$(printf '%s' "$pn_yaml" | sed 's/[\\&|]/\\&/g')"
  sed -i.bak \
    -e "s|^  name: .*|  name: \"$pn_esc\"|" \
    -e "s|^  slug: .*|  slug: \"$project_slug\"|" \
    "$TARGET/.ow.yml" && rm -f "$TARGET/.ow.yml.bak"
  log "  project: $project_name ($project_slug)"
fi

# ---------- .gitignore (MERGE managed block — never clobber the host's file) ----------
# obsidian-workflow owns ONLY a marked block (obsidian-workflow-internal paths). Everything else in
# the host's .gitignore is preserved. Greenfield → file created with just the block;
# brownfield → block injected/refreshed in place, all existing user lines untouched.
if [[ $DRY_RUN -eq 0 ]] && [[ -f "$TMP_DIR/scripts/ow-gitignore.sh" ]]; then
  . "$TMP_DIR/scripts/ow-gitignore.sh"
  if grep -qF "$OW_GI_START" "$TARGET/.gitignore" 2>/dev/null; then
    ow_gitignore_merge "$TARGET/.gitignore"
    log "  refreshed: .gitignore (obsidian-workflow managed block)"
  elif [[ -f "$TARGET/.gitignore" ]]; then
    ow_gitignore_merge "$TARGET/.gitignore"
    log "  merged: .gitignore (appended obsidian-workflow managed block; existing lines preserved)"
  else
    ow_gitignore_merge "$TARGET/.gitignore"
    log "  created: .gitignore (obsidian-workflow managed block only)"
  fi
elif [[ $DRY_RUN -eq 1 ]]; then
  log "  would merge: .gitignore (obsidian-workflow managed block — existing user lines preserved)"
fi

# ---------- copy .ow.local.yml.example (always) + .ow.local.yml (if missing) ----------
# `.example` = checked-in reference template (always present after install)
# `.local.yml` = personal/per-machine config (gitignored) — ow-paths.sh อ่านเป็น override layer
# Both files coexist by design — separation:
#   .ow.yml       → project-wide config (vault_path, subagents baseline, ow version)
#   .ow.local.yml → machine-specific (external_vault, mirror paths, user.name)
if [[ ! -f "$TARGET/.ow.local.yml.example" && -f "$TMP_DIR/.ow.local.yml.example" ]]; then
  run "cp '$TMP_DIR/.ow.local.yml.example' '$TARGET/'"
  log "  installed: .ow.local.yml.example (reference template)"
fi

# Materialize .ow.local.yml from the example so user has a ready-to-edit file
# (skip if user already created one — never overwrite personal config)
if [[ ! -f "$TARGET/.ow.local.yml" && -f "$TMP_DIR/.ow.local.yml.example" && $DRY_RUN -eq 0 ]]; then
  run "cp '$TMP_DIR/.ow.local.yml.example' '$TARGET/.ow.local.yml'"
  log "  installed: .ow.local.yml (personal/per-machine — gitignored, edit เพื่อ override paths)"
fi

# ---------- starter rule scaffolds (#22 — for enabled areas; idempotent) ----------
scaffold_rules

# ---------- conformance lint (#14 — hard gate, post-copy) ----------
# check 4 fails only on an agent carrying obsidian-workflow's signature (a shipped-tree bug). A
# project's own agent is a note whatever it is named, so this gate cannot abort a brownfield
# install over a file obsidian-workflow did not write. It stays fatal here because a signed file that
# breaks the read-mechanism contract is broken everywhere; the abort message names the
# pre-overwrite backup so the run is undoable by hand (upgrade.sh warns instead — it has
# --rollback).
# per-agent AI model: sync each agent's model: frontmatter from the just-written
# .ow.yml (config override > built-in default). After the agents are copied so
# both always-on and any preserved specialized agent honor the config.
if [[ $DRY_RUN -eq 0 ]] && command -v apply_agent_models >/dev/null 2>&1; then
  log ""
  log "Syncing per-agent AI models from .ow.yml..."
  apply_agent_models "$TARGET"
fi

if [[ $DRY_RUN -eq 0 ]] && [[ -f "$TARGET/scripts/conformance-lint.sh" ]]; then
  log ""
  log "Running conformance lint (#14)..."
  if ! bash "$TARGET/scripts/conformance-lint.sh" "$TARGET"; then
    err "❌ conformance lint failed — install aborted (a obsidian-workflow-owned file violates the read-mechanism contract)"
    err "   Only a file obsidian-workflow wrote can fail this gate — your own agents/commands are a note, never a failure."
    if [[ $INSTALL_BAKED -gt 0 ]]; then
      err "   The $INSTALL_BAKED file(s) this run overwrote are intact under ${INSTALL_BAKDIR#$TARGET/}/ — restore with:"
      err "     cp -R '${INSTALL_BAKDIR#$TARGET/}/.' ."
    else
      err "   Nothing pre-existing was overwritten by this run — everything obsidian-workflow added can be deleted as it stands."
    fi
    err "   Re-run with a clean source, or report this as a bug."
    exit 1
  fi
fi

# ---------- finalize ----------
log ""
log "✅ obsidian-workflow installed in $MODE mode"
log "   AI agents: ${INSTALLED_AI[*]:-(none)}"
[[ $INSTALL_BAKED -gt 0 ]] && log "   Overwrote $INSTALL_BAKED pre-existing file(s) — previous copies kept at ${INSTALL_BAKDIR#$TARGET/}/"

# Prune old install backups — keep the 3 most recent. Every overwriting run makes a fresh
# dir (a re-install backs up .claude/commands alone at ~400 KB), so without this they grow
# without bound. Three is enough to undo a bad run after noticing it a couple of installs
# later; upgrade keeps only its latest because --rollback can never use an older one.
if [[ $DRY_RUN -eq 0 && -d "$TARGET/.ow/backups" ]]; then
  _bk_pruned=0
  while IFS= read -r _bk; do
    [[ -n "$_bk" && -d "$_bk" ]] || continue
    rm -rf "$_bk" && _bk_pruned=$((_bk_pruned + 1))
  done < <(ls -td "$TARGET/.ow/backups"/*/ 2>/dev/null | tail -n +4)
  [[ $_bk_pruned -gt 0 ]] && log "   Pruned $_bk_pruned old backup dir(s) — kept the 3 most recent"
fi
log ""
log "ขั้นต่อไป:"
# Guidance for EVERY installed front-end, not just the first — invocation syntax
# genuinely differs (Cline `/ow-plan` vs Kimi `/skill:ow-plan`), so showing only
# INSTALLED_AI[0] left the rest of a multi-select install undocumented.
# Count via a pipeline: bare ${#arr[@]} on an empty array aborts under `set -u`
# on bash 3.2 (the macOS default, and this script's floor).
AI_COUNT=$(printf '%s\n' "${INSTALLED_AI[@]:-}" | grep -c '[^[:space:]]' || true)
if [[ "$AI_COUNT" -eq 0 ]]; then
  log "  1. เลือก AI ที่ install แล้วเปิดใน editor ของคุณ"
  log "  2. รัน command ow-init เป็นอันดับแรก"
else
  for ai in "${INSTALLED_AI[@]:-}"; do
    [[ -n "$ai" ]] || continue
    [[ "$AI_COUNT" -gt 1 ]] && log "  [$ai]"
    while IFS= read -r _step; do
      [[ -n "$_step" ]] && log "  $_step"
    done < <(ow_frontend_nextsteps "$ai")
  done
  [[ "$AI_COUNT" -gt 1 ]] && log "  (มี $AI_COUNT AI frontends ติดตั้ง — ใช้ตัวไหนก็ได้, command ตัวเดียวกัน)"
fi

# Subagent visibility — ผู้ใช้ควรรู้ว่ามี baseline 3 ตัว และจะเพิ่มได้ภายหลัง
if [[ " ${INSTALLED_AI[*]:-} " == *" claude "* ]]; then
  log ""
  log "Subagents (Claude):"
  log "  • Always-on (installed): docs, verifier, security"
  log "  • Specialized (on-demand): backend, frontend, mobile, design, test-runner"
  log "    → /ow-agent suggest  หรือ  /ow-agent enable <name>"
fi

if [[ "$MODE" == "brownfield" ]]; then
  log ""
  log "Brownfield notes:"
  log "  • Stack ที่ตรวจเจอ: $STACK"
  log "  • /ow-init จะถามว่า import README → PRD หรือสร้างใหม่"
  log "  • /ow-init จะเสนอ subagents ตาม stack ($STACK)"
  log "  • ไม่มีการแก้โค้ดเดิมโดย installer — ทุก vault doc สร้างใน docs/ เท่านั้น"
fi

log ""
log "Config files (อ่านโดย scripts/ow-paths.sh — precedence: local > shared > default):"
log "  Shared:   $TARGET/.ow.yml            (git-tracked, ทีมเดียวกัน)"
log "            └─ project, vault_path, subagents baseline, guardrails"
log "  Personal: $TARGET/.ow.local.yml      (gitignored, ของเครื่องคุณเอง)"
log "            └─ paths.external_vault, user.name"
log "  Template: $TARGET/.ow.local.yml.example  (reference สำหรับ key ทั้งหมดที่ override ได้)"
log ""
log "Other:"
log "  Docs:           $TARGET/CLAUDE.md"
log "  Vault:          $TARGET/$VAULT_PATH/"
[[ -n "$EXTERNAL_VAULT" ]] && log "  External vault: $EXTERNAL_VAULT (recorded in .ow.local.yml)"
log "  Design preview: $TARGET/$VAULT_PATH/70-Reference/DesignSystem/preview.html (เปิดด้วย browser)"
