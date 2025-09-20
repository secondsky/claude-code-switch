#!/usr/bin/env bash
set -euo pipefail

# Installer for Claude Code Model Switcher (CCM)
# - Writes a ccm() function into your shell rc so that `ccm kimi` works directly
# - Does NOT rely on modifying PATH or copying binaries
# - Idempotent: will replace previous CCM function block if exists

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/ccm.sh"
BEGIN_MARK="# >>> ccm function begin >>>"
END_MARK="# <<< ccm function end <<<"

# Detect which rc file to modify (prefer zsh)
detect_rc_file() {
  local shell_name
  shell_name="${SHELL##*/}"
  case "$shell_name" in
    zsh)
      echo "$HOME/.zshrc"
      ;;
    bash)
      echo "$HOME/.bashrc"
      ;;
    *)
      # Fallback to zshrc
      echo "$HOME/.zshrc"
      ;;
  esac
}

remove_existing_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if grep -qF "$BEGIN_MARK" "$rc"; then
    # Remove the existing block between markers (inclusive)
    local tmp
    tmp="$(mktemp)"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0==b {inblock=1; next}
      $0==e {inblock=0; next}
      !inblock {print}
    ' "$rc" > "$tmp" && mv "$tmp" "$rc"
  fi
}

append_function_block() {
  local rc="$1"
  mkdir -p "$(dirname "$rc")"
  [[ -f "$rc" ]] || touch "$rc"
  cat >> "$rc" <<EOF
$BEGIN_MARK
# CCM: define a shell function that applies exports to current shell
ccm() {
  local script="$SCRIPT_PATH"
  if [[ ! -f "\$script" ]]; then
    echo "ccm error: script not found at \$script" >&2
    return 1
  fi
  case "\$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg")
      "\$script" "\$@"
      ;;
    *)
      eval "\$("\$script" "\$@")"
      ;;
  esac
}
$END_MARK
EOF
}

main() {
  if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: ccm.sh not found next to install.sh: $SCRIPT_PATH" >&2
    exit 1
  fi
  chmod +x "$SCRIPT_PATH"

  local rc
  rc="$(detect_rc_file)"
  remove_existing_block "$rc"
  append_function_block "$rc"

  echo "✅ Installed ccm function into: $rc"
  echo "   Reload your shell or run: source $rc"
  echo "   Then use: ccm kimi  (or: ccm ds / ccm qwen / ccm glm / ccm claude / ccm opus)"
}

main "$@"
