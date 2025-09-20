#!/usr/bin/env bash
set -euo pipefail

# Uninstaller for Claude Code Model Switcher (CCM)
# - Removes ccm from standard locations
# - Does NOT touch your shell rc files

TARGETS=(
  "/usr/local/bin/ccm"
  "/opt/homebrew/bin/ccm"
  "$HOME/.local/bin/ccm"
)

removed_any=0
for t in "${TARGETS[@]}"; do
  if [[ -f "$t" ]]; then
    if rm -f "$t" 2>/dev/null; then
      echo "🗑️  Removed: $t"
      removed_any=1
    else
      echo "⚠️  No permission to remove $t. Try: sudo rm -f '$t'"
    fi
  fi
done

if [[ "$removed_any" -eq 0 ]]; then
  echo "ℹ️  No ccm executable found in standard locations."
  echo "    Checked: ${TARGETS[*]}"
else
  echo "✅ Uninstall complete."
fi
