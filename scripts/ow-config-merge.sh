#!/usr/bin/env bash
# obsidian-workflow — additive .ow.yml block merge (shared lib; used by upgrade)
# ─────────────────────────────────────────────────────────────────────────────
# Append top-level config blocks that exist in the shipped TEMPLATE but are MISSING
# from the user's .ow.yml — verbatim, including each block's comment preamble.
# So an upgrade surfaces newly-added config (e.g. `commands:`, a new optional block)
# without a manual edit, while NEVER clobbering values the user already filled in.
#
# Guarantees:
#   - Never edits / reorders a block the user already has (matched by top-level key).
#     Their values, comments, and hand edits are preserved byte-for-byte.
#   - No `yq -i` (which strips comments + blank lines from .ow.yml).
#   - Idempotent: a second run finds nothing missing and appends nothing.
#
# Limitation (by design): BLOCK-LEVEL only. A brand-new NESTED key inside a block the
# user already has (e.g. adding `model:` into an existing boolean `subagents:` block)
# is NOT injected — that would require rewriting the user's block and risk mangling.
# The resolver's built-in defaults cover any nested key the user hasn't adopted yet.
#
# A "block" = one blank-line-delimited paragraph containing a top-level `key:` at
# column 0. Comment lines sit in the same paragraph (the file style puts comments
# directly above the key with no blank line between) and travel with the block.
#
# merge_config_blocks <target_yml> <template_yml>
#   appends missing blocks to <target_yml>; prints "  + <key>" per appended block;
#   silent + exit 0 when nothing is missing or either file is absent.

merge_config_blocks() {
  local target="$1" template="$2"
  [ -f "$target" ] && [ -f "$template" ] || return 0

  # top-level keys already present in the user's file (space-padded for word match)
  local have
  have=" $(grep -oE '^[a-z_][a-z0-9_]*:' "$target" 2>/dev/null | sed 's/:$//' | sort -u | tr '\n' ' ')"

  # paragraph-mode scan of the template: emit each paragraph whose top-level key is
  # absent from the user's file (pure-comment paragraphs — no key — are skipped).
  local additions
  additions="$(awk -v have="$have" '
    BEGIN { RS=""; ORS="" }
    {
      key=""
      n=split($0, L, "\n")
      for (i=1;i<=n;i++) if (L[i] ~ /^[a-z_][a-z0-9_]*:/) { key=L[i]; sub(/:.*/,"",key); break }
      if (key=="") next
      if (index(have, " " key " ")>0) next
      print "\n" $0 "\n"
    }
  ' "$template")"

  [ -n "$additions" ] || return 0
  printf '%s' "$additions" >> "$target"
  printf '%s\n' "$additions" | grep -oE '^[a-z_][a-z0-9_]*:' | sed 's/:$//' | sed 's/^/  + /'
}

# merge_local_config <target_local_yml> <template_local_example>
#   Additive backfill for the user's gitignored .ow.local.yml on upgrade — so newly
#   shipped per-machine knobs surface without a hand edit, while NEVER overriding the user's
#   existing values / comments. Two passes, both append-only:
#     1) BLOCK-LEVEL — missing top-level blocks (reuses merge_config_blocks).
#     2) LEAF-LEVEL — a small registry of OPTIONAL nested knobs that live under a block the
#        user already has (block-merge can't reach them). Inserts "  <child>: <default>" right
#        after the parent header line ONLY when the child key is absent anywhere in the file.
#   No `yq -i` (keeps comments). Idempotent. Both files must exist or it's a no-op.
merge_local_config() {
  local target="$1" template="$2"
  [ -f "$target" ] && [ -f "$template" ] || return 0

  merge_config_blocks "$target" "$template"   # pass 1: top-level blocks
  # pass 2 (nested optional-knob backfill) intentionally empty — no leaf knobs registered.
  # Re-introduce a "parent|child|default" loop here if a future release ships one.
}
