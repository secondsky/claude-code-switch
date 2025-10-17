#!/usr/bin/env bash
################################################################################
# Claude Code Model Switcher - Quick Install Script
#
# One-command installation from GitHub:
#   curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
#
# Features:
#   - Download from GitHub automatically
#   - Network retry mechanism (3 attempts)
#   - File integrity verification
#   - Full error handling
#   - Progress feedback
#   - Idempotent installation
################################################################################

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="${GITHUB_REPO:-foreveryh/claude-code-switch}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"
TEMP_DIR=""
MAX_RETRIES=3
DOWNLOAD_TIMEOUT=30
SCRIPT_VERSION="2.1.0"

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

log_step() {
    echo -e "${CYAN}==>${NC} $*"
}

# Check if running from pipe (curl | bash)
is_piped() {
    [[ ! -t 0 ]] && [[ "${BASH_SOURCE[0]}" == "/dev/stdin" ]]
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements..."

    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is not installed"
        echo "Please install curl and try again"
        exit 1
    fi

    # Check for bash
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_warn "Bash version is ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}, recommended >= 4.0"
    fi

    # Check for required utilities
    for cmd in mkdir cat awk; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done

    log_success "System requirements OK"
}

# Create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d -t ccm-install.XXXXXX) || {
        log_error "Failed to create temporary directory"
        exit 1
    }
    chmod 700 "$TEMP_DIR"
    log_info "Using temporary directory: $TEMP_DIR"
}

# Download file with retries and validation
download_file() {
    local url="$1"
    local output_path="$2"
    local attempt=1

    log_info "Downloading: ${url##*/}"

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if curl -fsSL \
            --max-time "$DOWNLOAD_TIMEOUT" \
            --retry 1 \
            --retry-delay 2 \
            -o "$output_path" \
            "$url"; then

            # Verify file was downloaded and has content
            if [[ -s "$output_path" ]]; then
                log_success "Downloaded: ${url##*/}"
                return 0
            else
                log_warn "Downloaded file is empty, retrying..."
            fi
        else
            log_warn "Download attempt $attempt/$MAX_RETRIES failed for ${url##*/}"
        fi

        attempt=$((attempt + 1))
        if [[ $attempt -le $MAX_RETRIES ]]; then
            sleep 2
        fi
    done

    log_error "Failed to download ${url##*/} after $MAX_RETRIES attempts"
    return 1
}

# Download all required files
download_files() {
    log_step "Downloading installation files from GitHub..."

    # Download ccm.sh
    if ! download_file "$GITHUB_RAW_URL/ccm.sh" "$TEMP_DIR/ccm.sh"; then
        return 1
    fi

    # Create lang directory
    mkdir -p "$TEMP_DIR/lang"

    # Download language files
    for lang in "en" "zh"; do
        if ! download_file "$GITHUB_RAW_URL/lang/${lang}.json" "$TEMP_DIR/lang/${lang}.json"; then
            log_warn "Failed to download lang/${lang}.json (optional)"
        fi
    done

    # Verify ccm.sh exists and is executable
    if [[ ! -f "$TEMP_DIR/ccm.sh" ]]; then
        log_error "ccm.sh was not downloaded successfully"
        return 1
    fi

    if [[ ! -r "$TEMP_DIR/ccm.sh" ]]; then
        log_error "ccm.sh is not readable"
        return 1
    fi

    log_success "All files downloaded successfully"
}

# Verify downloaded files
verify_files() {
    log_step "Verifying downloaded files..."

    # Check ccm.sh
    if ! grep -q "Claude Code Model Switcher" "$TEMP_DIR/ccm.sh"; then
        log_error "ccm.sh verification failed (not a valid CCM script)"
        return 1
    fi

    # Check if script has proper structure
    if ! grep -q "main()" "$TEMP_DIR/ccm.sh"; then
        log_error "ccm.sh appears to be corrupted"
        return 1
    fi

    log_success "File verification passed"
}

# Make scripts executable
make_executable() {
    chmod +x "$TEMP_DIR/ccm.sh"
}

# Run installer from downloaded files
run_installer() {
    log_step "Running installation..."

    # Create a temporary install script that uses downloaded files
    local install_script="$TEMP_DIR/do-install.sh"
    cat > "$install_script" << 'INSTALLER_EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$1"
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
      echo "$HOME/.zshrc"
      ;;
  esac
}

# Remove existing block
remove_existing_block() {
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
  fi
}

# Append function block
append_function_block() {
  local rc="$1"
  mkdir -p "$(dirname "$rc")"
  [[ -f "$rc" ]] || touch "$rc"
  cat >> "$rc" <<'EOF'
# >>> ccm function begin >>>
# CCM: define a shell function that applies exports to current shell
ccm() {
  local script="${XDG_DATA_HOME:-$HOME/.local/share}/ccm/ccm.sh"
  # Fallback search if the installed script was moved or XDG paths changed
  if [[ ! -f "$script" ]]; then
    local default1="${XDG_DATA_HOME:-$HOME/.local/share}/ccm/ccm.sh"
    local default2="$HOME/.ccm/ccm.sh"
    if [[ -f "$default1" ]]; then
      script="$default1"
    elif [[ -f "$default2" ]]; then
      script="$default2"
    fi
  fi
  if [[ ! -f "$script" ]]; then
    echo "ccm error: script not found at $script" >&2
    return 1
  fi

  # All commands use eval to apply environment variables
  case "$1" in
    ""|"help"|"-h"|"--help"|"status"|"st"|"config"|"cfg")
      # These commands don't need eval, execute directly
      "$script" "$@"
      ;;
    *)
      # All other commands (including pp) use eval to set environment variables
      eval "$("$script" "$@")"
      ;;
  esac
}

# CCC: Claude Code Commander - switch model and launch Claude Code
ccc() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: ccc <model> [claude-options]"
    echo ""
    echo "Examples:"
    echo "  ccc deepseek                              # Launch with DeepSeek"
    echo "  ccc pp deepseek                           # Launch with PPINFRA DeepSeek"
    echo "  ccc glm --dangerously-skip-permissions    # Launch GLM with options"
    echo ""
    echo "Available models:"
    echo "  Official: deepseek, glm, kimi, qwen, claude, opus, longcat"
    echo "  PPINFRA:  pp deepseek, pp glm, pp kimi, pp qwen"
    return 1
  fi

  # Check for pp prefix
  local use_pp=false
  local model=""
  local claude_args=()

  if [[ "$1" == "pp" ]]; then
    use_pp=true
    shift
    model="$1"
    shift
  else
    model="$1"
    shift
  fi

  # Collect additional Claude Code arguments
  claude_args=("$@")

  # Call ccm to set environment variables
  if $use_pp; then
    echo "🔄 Switching to PPINFRA $model..."
    ccm pp "$model" || return 1
  else
    echo "🔄 Switching to $model..."
    ccm "$model" || return 1
  fi

  echo ""
  echo "🚀 Launching Claude Code..."
  echo "   Model: $ANTHROPIC_MODEL"
  echo "   Base URL: ${ANTHROPIC_BASE_URL:-Default (Anthropic)}"
  echo ""

  # Launch Claude Code
  if [[ ${#claude_args[@]} -eq 0 ]]; then
    exec claude
  else
    exec claude "${claude_args[@]}"
  fi
}
# <<< ccm function end <<<
EOF
}

# Main installation
main() {
  local rc
  rc="$(detect_rc_file)"

  # Install files
  mkdir -p "$INSTALL_DIR"
  cp -f "$SCRIPT_DIR/ccm.sh" "$DEST_SCRIPT_PATH"
  chmod +x "$DEST_SCRIPT_PATH"

  if [[ -d "$SCRIPT_DIR/lang" ]]; then
    rm -rf "$INSTALL_DIR/lang"
    cp -R "$SCRIPT_DIR/lang" "$INSTALL_DIR/lang"
  fi

  # Update rc file
  remove_existing_block "$rc"
  append_function_block "$rc"

  echo "✅ Installation successful!"
  echo "   Script: $DEST_SCRIPT_PATH"
  echo "   Config: $HOME/.ccm_config"
  echo ""
  echo "Next steps:"
  echo "  1. Reload your shell: source $rc"
  echo "  2. Or start a new terminal"
  echo "  3. Then try: ccm status"
}

main
INSTALLER_EOF

    chmod +x "$install_script"

    # Run the installer with downloaded files
    if "$install_script" "$TEMP_DIR"; then
        log_success "Installation completed successfully"
        return 0
    else
        log_error "Installation failed"
        return 1
    fi
}

# Print usage information
print_usage() {
    cat << 'EOF'
┌─────────────────────────────────────────────────────────────────┐
│  ✅ Claude Code Model Switcher installed successfully!          │
└─────────────────────────────────────────────────────────────────┘

🚀 Quick Start:
  1. Reload your shell:
     source ~/.zshrc    # for zsh
     source ~/.bashrc   # for bash

  2. Try these commands:
     ccm status         # Show current configuration
     ccm deepseek       # Switch to DeepSeek
     ccc deepseek       # Switch and launch Claude Code
     ccm help           # Show all available models

📖 Documentation:
  ccm help             # View help
  ccm config           # Edit configuration file
  ccm pp glm           # Use PPINFRA fallback service

💡 Example workflows:
  eval "$(ccm env deepseek)"    # Apply to current shell
  ccc kimi                       # Launch with KIMI
  ccc pp qwen                    # Launch with PPINFRA Qwen

🔧 Configuration:
  ~/.ccm_config        # Edit your API keys
  ccm config           # Open config in your editor

🆘 Troubleshooting:
  ccm status           # Check current setup
  cat ~/.ccm_config    # View configuration
  env | grep ANTHROPIC # Check environment variables

For more info: https://github.com/foreveryh/claude-code-switch
EOF
}

# Print next steps
print_next_steps() {
    local shell_name
    shell_name="${SHELL##*/}"
    local rc_file

    case "$shell_name" in
        zsh)
            rc_file="$HOME/.zshrc"
            ;;
        bash)
            rc_file="$HOME/.bashrc"
            ;;
        *)
            rc_file="$HOME/.zshrc"
            ;;
    esac

    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "  1. Reload your shell:"
    echo "     source $rc_file"
    echo ""
    echo "  2. Or open a new terminal"
    echo ""
    echo "  3. Then try:"
    echo "     ccm status"
    echo "     ccm deepseek"
    echo ""
}

# Main flow
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Claude Code Model Switcher - Quick Install (v$SCRIPT_VERSION)  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check if piped
    if is_piped; then
        log_info "Installation via pipe detected"
    fi

    # Check requirements
    check_requirements

    # Create temporary directory
    create_temp_dir

    # Download files
    if ! download_files; then
        log_error "Failed to download installation files"
        exit 1
    fi

    # Verify files
    if ! verify_files; then
        log_error "File verification failed"
        exit 1
    fi

    # Make executable
    make_executable

    # Run installer
    if ! run_installer; then
        log_error "Installation failed"
        exit 1
    fi

    # Print final message
    print_usage
    print_next_steps

    log_success "Quick install completed!"
}

main "$@"
