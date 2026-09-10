#!/usr/bin/env bash
# obsidian-workflow — canonical AI FRONT-END registry (single source of truth)
# ─────────────────────────────────────────────────────────────────────────────
# An "AI front-end" is the CLI/IDE/web assistant the developer talks to — NOT a
# subagent. Sourced by install.sh, upgrade.sh, bin/ow and test.sh so the
# list can never drift between the picker, the folder map, the upgrade refresh
# set and the rollback set. Before this file existed the same seven names were
# re-declared at 14 sites and `gpt`/`glm` had already fallen out of two of them.
#
# Portable: bash 3.2 + BSD userland (no associative arrays, no mapfile).
#
# EMITTER KINDS — what an enabled front-end actually reads:
#   commands  .claude/commands/<verb>.md      generated shims  (Claude Code)
#   skills    .agents/skills/ow-<verb>/SKILL.md + root AGENTS.md
#                                              (Cline, Kimi Code, Codex CLI —
#                                               all three read these neutral paths)
#   router    <folder>/prompts/router.md + system.md
#                                              (paste-into-web / prompt-file tools)
#
# API:
#   ow_frontends                  → canonical names, one per line, menu order
#   ow_frontend_count             → how many
#   ow_frontend_record <name>     → name<TAB>kind<TAB>folder<TAB>label
#   ow_frontend_kind   <name>     → commands | skills | router
#   ow_frontend_folder <name>     → per-front-end asset dir in the template
#   ow_frontend_label  <name>     → one-line human description
#   ow_frontend_by_index <n>      → name for menu position <n> (1-based)
#   ow_frontend_valid  <name>     → exit 0 if known
#   ow_kind_shared_paths <kind>   → repo paths a kind installs beyond its folder
#   ow_frontend_paths  <name>     → every path this front-end owns (folder + shared)
#   ow_frontend_all_paths         → union over ALL front-ends, deduped
#   ow_frontend_paths_for <csv>   → union over an enabled comma list, deduped
#   ow_frontend_nextsteps <name>  → post-install "what to do now" lines
#
# ADDING A FRONT-END: append one row to ow_frontend_table, add a
# ow_frontend_nextsteps case, and — only if it reads paths no existing kind
# emits — a new kind. Nothing else in the codebase carries the list.

# ─── the table ────────────────────────────────────────────────────────────────
# name<TAB>kind<TAB>folder<TAB>label
# Menu order is table order. Existing entries keep positions 1-5 so a returning
# user's muscle memory for the numeric picker still works.
ow_frontend_table() {
  printf '%s\t%s\t%s\t%s\n' \
    claude commands .claude "Claude Code (Anthropic) — slash commands + agents folder" \
    codex  skills   codex   "OpenAI Codex CLI — root AGENTS.md + .agents/skills/" \
    google router   gemini  "Google Gemini CLI/API — gemini/prompts/" \
    gpt    router   gpt     "ChatGPT (web/API) — gpt/prompts/" \
    glm    router   glm     "Zhipu GLM / ChatGLM — glm/prompts/" \
    cline  skills   cline   "Cline (VS Code) — root AGENTS.md + .agents/skills/" \
    kimi   skills   kimi    "Kimi Code CLI (Moonshot) — root AGENTS.md + .agents/skills/"
}

ow_frontends() { ow_frontend_table | cut -f1; }

ow_frontend_count() { ow_frontend_table | wc -l | tr -d ' '; }

ow_frontend_record() {
  ow_frontend_table | awk -F'\t' -v n="$1" '$1==n {print; exit}'
}

_bfe_field() { ow_frontend_record "$1" | cut -f"$2"; }

ow_frontend_kind()   { _bfe_field "$1" 2; }
ow_frontend_folder() { _bfe_field "$1" 3; }
ow_frontend_label()  { _bfe_field "$1" 4; }

ow_frontend_by_index() {
  ow_frontend_table | awk -F'\t' -v i="$1" 'NR==i {print $1; exit}'
}

ow_frontend_valid() { [ -n "$(ow_frontend_record "$1")" ]; }

# ─── what each kind installs beyond its own folder ────────────────────────────
# These are REPO-ROOT paths shared by every front-end of that kind — installed
# once when at least one such front-end is enabled.
ow_kind_shared_paths() {
  case "$1" in
    commands) printf '%s\n' "CLAUDE.md" ;;
    skills)   printf '%s\n' "AGENTS.md" ".agents" ;;
    router)   printf '%s\n' "prompts" ;;
  esac
}

ow_frontend_paths() {
  local n="$1" folder kind
  folder="$(ow_frontend_folder "$n")"
  kind="$(ow_frontend_kind "$n")"
  [ -n "$folder" ] && printf '%s\n' "$folder"
  [ -n "$kind" ] && ow_kind_shared_paths "$kind"
}

# Dedupe preserving first-seen order (no sort -u: order is meaningful for the
# upgrade refresh loop, and `sort` would reorder dotpaths unpredictably).
_bfe_dedupe() { awk '!seen[$0]++'; }

ow_frontend_all_paths() {
  local n
  for n in $(ow_frontends); do ow_frontend_paths "$n"; done | _bfe_dedupe
}

# ow_frontend_paths_for <comma-list>  — union for the ENABLED set only.
# Unknown names are skipped silently; validation is the caller's job.
ow_frontend_paths_for() {
  local csv="$1" n
  # NOTE: printf '%s\n' — without the trailing newline `read` returns non-zero on
  # the final field and the loop body silently skips the LAST front-end.
  printf '%s\n' "$csv" | tr ',' '\n' | while IFS= read -r n; do
    n="$(printf '%s' "$n" | tr -d '[:space:]')"
    [ -n "$n" ] || continue
    ow_frontend_valid "$n" || continue
    ow_frontend_paths "$n"
  done | _bfe_dedupe
}

# ─── post-install guidance ────────────────────────────────────────────────────
# Invocation syntax genuinely differs per tool even for the shared `skills`
# bundle — Cline registers a skill as a bare /verb, Kimi as /skill:verb — so this
# stays a per-name case rather than a per-kind one.
ow_frontend_nextsteps() {
  case "$1" in
    claude)
      printf '%s\n' \
        "1. เปิด Claude Code ใน folder นี้" \
        "2. รัน: /ow-init               (ตั้งค่า vault + detect stack)" \
        "3. รัน: /ow-agent suggest      (แนะนำ subagent เฉพาะทางตาม stack)" \
        "4. ไม่รู้จะใช้ command ไหน? → /ow-help"
      ;;
    codex)
      printf '%s\n' \
        "1. รัน Codex CLI ใน folder นี้ (อ่าน AGENTS.md ที่ root อัตโนมัติ)" \
        "2. ลองว่า: codex run 'ow-init'" \
        "3. ไม่รู้จะใช้ command ไหน? → codex run 'ow-help'"
      ;;
    cline)
      printf '%s\n' \
        "1. เปิด project นี้ใน VS Code แล้วเปิด Cline" \
        "2. Cline อ่าน AGENTS.md + .agents/skills/ เอง — พิมพ์ /ow-init ได้เลย" \
        "3. ไม่รู้จะใช้ command ไหน? → /ow-help"
      ;;
    kimi)
      printf '%s\n' \
        "1. รัน kimi ใน folder นี้ (อ่าน AGENTS.md ที่ root อัตโนมัติ)" \
        "2. เรียก skill ด้วย prefix: /skill:ow-init" \
        "3. ไม่รู้จะใช้ command ไหน? → /skill:ow-help"
      ;;
    google)
      printf '%s\n' \
        "1. ใช้ gemini CLI: gemini chat --system \"\$(cat gemini/prompts/system.md)\"" \
        "2. หรือ paste gemini/prompts/start-here.md ใน Gemini web"
      ;;
    gpt)
      printf '%s\n' \
        "1. ไปที่ chatgpt.com — paste gpt/prompts/system.md เป็น Custom Instructions" \
        "2. เริ่มงานด้วย prompts/general-ai/start-here.md"
      ;;
    glm)
      printf '%s\n' \
        "1. ไปที่ chatglm.cn / z.ai — paste glm/prompts/system.md เป็น system" \
        "2. เริ่มงานด้วย prompts/general-ai/start-here.md"
      ;;
  esac
}
