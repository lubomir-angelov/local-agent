#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="docs/AGENT_LOG.md"

# If not staged, nothing to check
git diff --cached --name-only | grep -qx "$LOG_FILE" || exit 0

# numstat: added<TAB>deleted<TAB>file
read -r added deleted file < <(git diff --cached --numstat -- "$LOG_FILE")

deleted=${deleted:-0}

if [[ "$deleted" != "0" && "$deleted" != "-" ]]; then
  echo "ERROR: $LOG_FILE is append-only. Detected deletions/edits (deleted=$deleted)."
  echo "Only append to the end; do not edit or remove past lines."
  exit 1
fi
