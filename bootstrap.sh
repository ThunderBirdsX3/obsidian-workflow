#!/usr/bin/env bash
# bootstrap.sh — install obsidian-workflow into a project without cloning first
#
# Usage (no prior clone needed):
#   bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/bootstrap.sh) .
#   bash <(curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/bootstrap.sh) /path/to/project
#
# Or pipe form:
#   curl -fsSL https://raw.githubusercontent.com/ThunderBirdsX3/obsidian-workflow/main/bootstrap.sh | bash -s -- .

set -euo pipefail

TOOLKIT_REPO="https://github.com/ThunderBirdsX3/obsidian-workflow.git"
TARGET="${1:?usage: bash bootstrap.sh /path/to/target-project}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Fetching obsidian-workflow toolkit..."
git clone --depth=1 "$TOOLKIT_REPO" "$TMP/toolkit" 2>&1 | grep -v "^$" || true

bash "$TMP/toolkit/install.sh" "$TARGET"
