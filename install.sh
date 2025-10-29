#!/usr/bin/env bash
set -euo pipefail

# Installer for Claude Code Model Switcher (CCM)
# - Writes a ccm() function into your shell rc so that `ccm kimi` works directly
# - Does NOT rely on modifying PATH or copying binaries
# - Idempotent: will replace previous CCM function block if exists

# GitHub repository info
GITHUB_REPO="foreveryh/claude-code-switch"
GITHUB_BRANCH="main"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Detect if running from local directory or piped from curl
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  # Running locally
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_MODE=true
else
  # Piped from curl or running without source file
  SCRIPT_DIR=""
  LOCAL_MODE=false
fi

# Install destination (stable per-user location)
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ccm"
DEST_SCRIPT_PATH="$INSTALL_DIR/ccm.sh"
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
  cat >> "$rc" <<EOF 2>/dev/null
$BEGIN_MARK
# CCM: define a shell function that applies exports to current shell
# Ensure no alias/function clashes
unalias ccm 2>/dev/null || true
unset -f ccm 2>/dev/null || true
ccm() {
  local script="$DEST_SCRIPT_PATH"
  # Fallback search if the installed script was moved or XDG paths changed
  if [[ ! -f "\$script" ]]; then
    local default1="\${XDG_DATA_HOME:-\$HOME/.local/share}/ccm/ccm.sh"
    local default2="\$HOME/.ccm/ccm.sh"
    if [[ -f "\$default1" ]]; then
      script="\$default1"
    elif [[ -f "\$default2" ]]; then
      script="\$default2"
    fi
  fi
  if [[ ! -f "\$script" ]]; then
    echo "ccm error: script not found at \$script" >&2
    return 1
  fi

  # All commands use eval to apply environment variables
  case "\$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg"|"save-account"|"switch-account"|"list-accounts"|"delete-account"|"current-account"|"debug-keychain")
      # These commands don't need eval, execute directly
      "\$script" "\$@"
      ;;
    *)
      # All other commands (including pp, model switching) use eval to set environment variables
      eval "\$("\$script" "\$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
# Ensure no alias/function clashes
unalias ccc 2>/dev/null || true
unset -f ccc 2>/dev/null || true
ccc() {
  if [[ \$# -eq 0 ]]; then
    echo "Usage: ccc <model> [claude-options]"
    echo "       ccc <account> [claude-options]            # Switch account then launch"
    echo "       ccc <model>:<account> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc pp deepseek                           # Launch with PPINFRA DeepSeek"
    echo "  ccc woohelps                              # Switch to 'woohelps' account and launch"
    echo "  ccc opus:work                             # Switch to 'work' account and launch Opus"
    echo "  ccc glm --dangerously-skip-permissions    # Launch GLM with options"
    echo ""
    echo "Available models:"
    echo "  Official: deepseek, glm, kimi, qwen, claude, opus, haiku, longcat"
    echo "  PPINFRA:  pp deepseek, pp glm, pp kimi, pp qwen"
    echo "  Account:  <account> | claude:<account> | opus:<account> | haiku:<account>"
    return 1
  fi

  # Check for pp prefix
  local use_pp=false
  local model=""
  local claude_args=()
  
  if [[ "\$1" == "pp" ]]; then
    use_pp=true
    shift
    model="\$1"
    shift
  else
    model="\$1"
    shift
  fi
  
  # Collect additional Claude Code arguments
  claude_args=("\$@")
  
  # Helper: known model keyword
  _is_known_model() {
    case "\$1" in
      deepseek|ds|glm|glm4|glm4.6|kimi|kimi2|qwen|longcat|lc|minimax|mm|claude|sonnet|s|opus|o|haiku|h)
        return 0 ;;
      *)
        return 1 ;;
    esac
  }

  # Configure environment via ccm
  if \$use_pp; then
    echo "🔄 Switching to PPINFRA \$model..."
    ccm pp "\$model" || return 1
  else
    if [[ "\$model" == *:* ]]; then
      # model:account form handled by ccm
      echo "🔄 Switching to \$model..."
      ccm "\$model" || return 1
    elif _is_known_model "\$model"; then
      echo "🔄 Switching to \$model..."
      ccm "\$model" || return 1
    else
      # Treat as account name
      local account="\$model"
      echo "🔄 Switching account to \$account..."
      ccm switch-account "\$account" || return 1
      # Set default model (Claude Sonnet)
      ccm claude || return 1
    fi
  fi

  echo ""
  echo "🚀 Launching Claude Code..."
  echo "   Model: \$ANTHROPIC_MODEL"
  echo "   Base URL: \${ANTHROPIC_BASE_URL:-Default (Anthropic)}"
  echo ""

  # Ensure `claude` CLI exists
  if ! type -p claude >/dev/null 2>&1; then
    echo "❌ 'claude' CLI not found. Install: npm install -g @anthropic-ai/claude-code" >&2
    return 127
  fi

  # Launch Claude Code
  if [[ \${#claude_args[@]} -eq 0 ]]; then
    exec claude
  else
    exec claude "\${claude_args[@]}"
  fi
}
$END_MARK
EOF
}

download_from_github() {
  local url="$1"
  local dest="$2"
  echo "Downloading from $url..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    echo "Error: neither curl nor wget found" >&2
    return 1
  fi
}

main() {
  # Filter out specific Claude CLI error during installation
  # This error doesn't affect functionality but can confuse users
  filter_claude_errors() {
    grep -v "Error: Input must be provided either through stdin or as a prompt argument when using --print" || true
  }

  mkdir -p "$INSTALL_DIR"

  if $LOCAL_MODE && [[ -f "$SCRIPT_DIR/ccm.sh" ]]; then
    # Local mode: copy from local directory
    echo "Installing from local directory..." 2>&1 | filter_claude_errors
    cp -f "$SCRIPT_DIR/ccm.sh" "$DEST_SCRIPT_PATH" 2>&1 | filter_claude_errors
    if [[ -d "$SCRIPT_DIR/lang" ]]; then
      rm -rf "$INSTALL_DIR/lang"
      cp -R "$SCRIPT_DIR/lang" "$INSTALL_DIR/lang"
    fi
  else
    # Remote mode: download from GitHub
    echo "Installing from GitHub..." 2>&1 | filter_claude_errors
    download_from_github "${GITHUB_RAW}/ccm.sh" "$DEST_SCRIPT_PATH" || {
      echo "Error: failed to download ccm.sh" >&2
      exit 1
    }

    # Download lang files
    mkdir -p "$INSTALL_DIR/lang"
    download_from_github "${GITHUB_RAW}/lang/zh.json" "$INSTALL_DIR/lang/zh.json" || true
    download_from_github "${GITHUB_RAW}/lang/en.json" "$INSTALL_DIR/lang/en.json" || true
  fi

  chmod +x "$DEST_SCRIPT_PATH"

  local rc
  rc="$(detect_rc_file)"
  remove_existing_block "$rc"

  # Redirect stderr for function block creation to filter the error
  append_function_block "$rc" 2>&1 | filter_claude_errors

  echo "✅ Installed ccm and ccc functions into: $rc"
  echo "   Script installed to: $DEST_SCRIPT_PATH"
  echo "   Reload your shell or run: source $rc"
  echo ""
  echo "   Then use:"
  echo "     ccm deepseek       # Switch model in current terminal"
  echo "     ccc deepseek       # Switch model and launch Claude Code"
  echo "     ccm pp glm         # Use PPINFRA fallback service"
  echo "     ccc pp glm         # PPINFRA + launch Claude Code"
}

main "$@"
