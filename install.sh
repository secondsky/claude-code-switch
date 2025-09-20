#!/usr/bin/env bash
set -euo pipefail

# Simple installer for Claude Code Model Switcher (CCM)
# - Installs ccm to a safe, standard path
# - Does NOT modify your shell rc files (e.g., ~/.zshrc)
# - Falls back to ~/.local/bin if system paths are not writable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/ccm.sh"
TARGET_NAME="ccm"

choose_prefix() {
  local candidates=("/usr/local/bin" "/opt/homebrew/bin" "$HOME/.local/bin")
  for d in "${candidates[@]}"; do
    if [[ -d "$d" && -w "$d" ]]; then
      echo "$d"
      return 0
    fi
  done
  # Create ~/.local/bin if needed
  mkdir -p "$HOME/.local/bin"
  echo "$HOME/.local/bin"
}

main() {
  if [[ ! -f "$SRC" ]]; then
    echo "Error: ccm.sh not found next to install.sh: $SRC" >&2
    exit 1
  fi

  chmod +x "$SRC"

  local prefix
  prefix=$(choose_prefix)
  local dest="$prefix/$TARGET_NAME"

  # Try to copy
  if cp "$SRC" "$dest" 2>/dev/null; then
    chmod 0755 "$dest" || true
    echo "✅ Installed: $dest"
  else
    echo "⚠️  No permission to write $dest. Try running with sudo:"
    echo "   sudo install -m 0755 '$SRC' '$dest'"
    exit 1
  fi

  # Guidance for PATH if using ~/.local/bin
  if [[ "$prefix" == "$HOME/.local/bin" ]]; then
    echo ""
    echo "ℹ️  $prefix was used. If not already in PATH, add it to your shell rc:"
    echo "   echo 'export PATH=\$PATH:$HOME/.local/bin' >> ~/.zshrc && source ~/.zshrc"
  fi

  echo ""
  echo "Next steps:"
  echo "  - Ensure ~/.ccm_config exists: run 'ccm' once or edit via 'ccm config'"
  echo "  - To activate in current shell: eval \"$(ccm env deepseek)\" (example)"
}

main "$@"
