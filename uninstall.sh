#!/usr/bin/env bash
set -euo pipefail

# Uninstaller for Claude Code Model Switcher (CCM)
# - Removes the ccm() function block from your shell rc files
# - Does NOT remove any binaries or modify PATH

BEGIN_MARK="# >>> ccm function begin >>>"
END_MARK="# <<< ccm function end <<<"

remove_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if grep -qF "$BEGIN_MARK" "$rc"; then
    local tmp
    tmp="$(mktemp)"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0==b {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' "$rc" > "$tmp" && mv "$tmp" "$rc"
    echo "🗑️  Removed ccm function from: $rc"
  fi
}

main() {
  remove_block "$HOME/.zshrc"
  remove_block "$HOME/.bashrc"
  echo "✅ Uninstall complete. Reload your shell or run: source ~/.zshrc (or ~/.bashrc)"
}

main "$@"
