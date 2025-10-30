#!/bin/bash
############################################################
# Claude Code Model Switcher (ccm) - Standalone Version
# ---------------------------------------------------------
# Function: Quick switching between different AI models
# Supports: Claude, Deepseek, GLM4.6, KIMI2
# Author: Peng
# Version: 2.2.0
############################################################

# Script color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file paths
CONFIG_FILE="$HOME/.ccm_config"
ACCOUNTS_FILE="$HOME/.ccm_accounts"
# Keychain service name (override with CCM_KEYCHAIN_SERVICE)
KEYCHAIN_SERVICE="${CCM_KEYCHAIN_SERVICE:-Claude Code-credentials}"

# Multi-language support
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LANG_DIR="$SCRIPT_DIR/lang"

# Load translations
load_translations() {
    local lang_code="${1:-en}"
    local lang_file="$LANG_DIR/${lang_code}.json"

    # If language file doesn't exist, default to English
    if [[ ! -f "$lang_file" ]]; then
        lang_code="en"
        lang_file="$LANG_DIR/en.json"
    fi

    # If English file also doesn't exist, use built-in English
    if [[ ! -f "$lang_file" ]]; then
        return 0
    fi

    # Clear existing translation variables
    unset $(set | grep '^TRANS_' | LC_ALL=C cut -d= -f1) 2>/dev/null || true

    # Read JSON file and parse to variables
    if [[ -f "$lang_file" ]]; then
        local temp_file=$(mktemp)
        # Extract key-value pairs to temp file using more robust method
        grep -o '"[^"]*":[[:space:]]*"[^"]*"' "$lang_file" | sed 's/^"\([^"]*\)":[[:space:]]*"\([^"]*\)"$/\1|\2/' > "$temp_file"

        # Read temp file and set variables (using TRANS_ prefix)
        while IFS='|' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                # Handle escape characters
                value="${value//\\\"/\"}"
                value="${value//\\\\/\\}"
                # Use eval to set dynamic variable names
                eval "TRANS_${key}=\"\$value\""
            fi
        done < "$temp_file"

        rm -f "$temp_file"
    fi
}

# Get translation text
t() {
    local key="$1"
    local default="${2:-$key}"
    local var_name="TRANS_${key}"
    local value
    eval "value=\"\${${var_name}:-}\""
    echo "${value:-$default}"
}

# Detect system language
detect_language() {
    # First check LANG environment variable
    local sys_lang="${LANG:-}"
    if [[ "$sys_lang" =~ ^zh ]]; then
        echo "zh"
    else
        echo "en"
    fi
}

# Smart config loading: environment variables first, config file supplement
load_config() {
    # Initialize language
    local lang_preference="${CCM_LANGUAGE:-$(detect_language)}"
    load_translations "$lang_preference"

    # Create config file (if it doesn't exist)
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# CCM Configuration File
# Please replace with your actual API keys
# Note: API keys in environment variables take precedence over this file

# Language setting (en: English, zh: Chinese)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM4.6 (Zhipu AI)
GLM_API_KEY=your-glm-api-key

# KIMI2 (Moonshot)
KIMI_API_KEY=your-moonshot-api-key

# LongCat (Meituan)
LONGCAT_API_KEY=your-longcat-api-key

# MiniMax M2
MINIMAX_API_KEY=your-minimax-api-key

# Qwen (Alibaba Cloud DashScope)
QWEN_API_KEY=your-qwen-api-key

# Claude (if using API key instead of Pro subscription)
CLAUDE_API_KEY=your-claude-api-key

# Backup provider (only enabled when official keys are not provided)
PPINFRA_API_KEY=your-ppinfra-api-key

# —— Optional: model ID overrides (use defaults below if not set) ——
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2-turbo-preview
KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview
QWEN_MODEL=qwen3-max
QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct
GLM_MODEL=glm-4.6
GLM_SMALL_FAST_MODEL=glm-4.5-air
CLAUDE_MODEL=claude-sonnet-4-5-20250929
CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-1-20250805
OPUS_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929
HAIKU_MODEL=claude-haiku-4-5
HAIKU_SMALL_FAST_MODEL=claude-haiku-4-5
LONGCAT_MODEL=LongCat-Flash-Thinking
LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat
MINIMAX_MODEL=MiniMax-M2
MINIMAX_SMALL_FAST_MODEL=MiniMax-M2

EOF
        echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}" >&2
        echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}" >&2
        echo -e "${GREEN}🚀 Using default experience keys for now...${NC}" >&2
        # Don't return 1 - continue with default fallback keys
    fi
    
    # First read language setting
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_lang
        config_lang=$(grep -E "^[[:space:]]*CCM_LANGUAGE[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | head -1 | LC_ALL=C cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [[ -n "$config_lang" && -z "$CCM_LANGUAGE" ]]; then
            export CCM_LANGUAGE="$config_lang"
            lang_preference="$config_lang"
            load_translations "$lang_preference"
        fi
    fi

    # Smart loading: only read keys from config file if not set in environment
    local temp_file=$(mktemp)
    local raw
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        # Remove carriage returns, remove inline comments and trim both ends
        raw=${raw%$'\r'}
        # Skip comments and empty lines
        [[ "$raw" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$raw" ]] && continue
        # Remove inline comments (from first # onwards)
        local line="${raw%%#*}"
        # Remove leading and trailing whitespace
        line=$(echo "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        
        # Parse export KEY=VALUE or KEY=VALUE
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            local key="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            # Remove leading and trailing whitespace
            value=$(echo "$value" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
            # Only apply if environment is not set, empty, or placeholder
            local env_value="${!key}"
            local lower_env_value
            lower_env_value=$(printf '%s' "$env_value" | tr '[:upper:]' '[:lower:]')
            # Check if it's a placeholder value
            local is_placeholder=false
            if [[ "$lower_env_value" == *"your"* && "$lower_env_value" == *"api"* && "$lower_env_value" == *"key"* ]]; then
                is_placeholder=true
            fi
            if [[ -n "$key" && ( -z "$env_value" || "$env_value" == "" || "$is_placeholder" == "true" ) ]]; then
                echo "export $key=$value" >> "$temp_file"
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Execute export statements from temp file
    if [[ -s "$temp_file" ]]; then
        source "$temp_file"
    fi
    rm -f "$temp_file"
}

# Create default configuration file
create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# CCM Configuration File
# Please replace with your actual API keys
# Note: API keys in environment variables take precedence over this file

# Language setting (en: English, zh: Chinese)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM4.6 (Zhipu AI)
GLM_API_KEY=your-glm-api-key

# KIMI2 (Moonshot)
KIMI_API_KEY=your-moonshot-api-key

# LongCat (Meituan)
LONGCAT_API_KEY=your-longcat-api-key

# MiniMax M2
MINIMAX_API_KEY=your-minimax-api-key

# Qwen (Alibaba Cloud DashScope)
QWEN_API_KEY=your-qwen-api-key

# Claude (if using API key instead of Pro subscription)
CLAUDE_API_KEY=your-claude-api-key

# Backup provider (only enabled when official keys are not provided)
PPINFRA_API_KEY=your-ppinfra-api-key

# —— Optional: model ID overrides (use defaults below if not set) ——
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2-turbo-preview
KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview
QWEN_MODEL=qwen3-max
QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct
GLM_MODEL=glm-4.6
GLM_SMALL_FAST_MODEL=glm-4.5-air
CLAUDE_MODEL=claude-sonnet-4-5-20250929
CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-1-20250805
OPUS_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929
HAIKU_MODEL=claude-haiku-4-5
HAIKU_SMALL_FAST_MODEL=claude-haiku-4-5
LONGCAT_MODEL=LongCat-Flash-Thinking
LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat
MINIMAX_MODEL=MiniMax-M2
MINIMAX_SMALL_FAST_MODEL=MiniMax-M2

EOF
    echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}" >&2
    echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}" >&2
}

# Check if value is effectively set (not empty and not placeholder)
is_effectively_set() {
    local v="$1"
    if [[ -z "$v" ]]; then
        return 1
    fi
    local lower
    lower=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        *your-*-api-key)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Secure token masking utility
mask_token() {
    local t="$1"
    local n=${#t}
    if [[ -z "$t" ]]; then
        echo "[$(t 'not_set')]"
        return
    fi
    if (( n <= 8 )); then
        echo "[$(t 'set')] ****"
    else
        echo "[$(t 'set')] ${t:0:4}...${t:n-4:4}"
    fi
}

mask_presence() {
    local v_name="$1"
    local v_val="${!v_name}"
    if is_effectively_set "$v_val"; then
        echo "[$(t 'set')]"
    else
        echo "[$(t 'not_set')]"
    fi
}

# ============================================
# Claude Pro Account Management Functions
# ============================================

# Read Claude Code credentials from macOS Keychain
read_keychain_credentials() {
    local credentials
    local -a services=(
        "$KEYCHAIN_SERVICE"
        "Claude Code - credentials"
        "Claude Code"
        "claude"
        "claude.ai"
    )
    for svc in "${services[@]}"; do
        credentials=$(security find-generic-password -s "$svc" -w 2>/dev/null)
        if [[ $? -eq 0 && -n "$credentials" ]]; then
            KEYCHAIN_SERVICE="$svc"
            echo "$credentials"
            return 0
        fi
    done
    echo ""
    return 1
}

# Write credentials to macOS Keychain
write_keychain_credentials() {
    local credentials="$1"
    local username="$USER"

    # Delete existing credentials first
    security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1

    # Add new credentials
    security add-generic-password -a "$username" -s "$KEYCHAIN_SERVICE" -w "$credentials" >/dev/null 2>&1
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo -e "${BLUE}🔑 Credentials written to Keychain${NC}" >&2
    else
        echo -e "${RED}❌ Failed to write credentials to Keychain (error code: $result)${NC}" >&2
    fi

    return $result
}

# Debug function: verify credentials in Keychain
debug_keychain_credentials() {
    echo -e "${BLUE}🔍 Debug: Check credentials in Keychain${NC}"

    local credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        echo -e "${RED}❌ No credentials found in Keychain${NC}"
        return 1
    fi

    # Extract credential information
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token_preview=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4 | head -c 20)

    echo -e "${GREEN}✅ Credentials found:${NC}"
    echo "   Service name: $KEYCHAIN_SERVICE"
    echo "   Subscription type: ${subscription:-Unknown}"
    if [[ -n "$expires" ]]; then
        local expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        echo "   Expiry time: $expires_str"
    fi
    echo "   Token preview: ${access_token_preview}..."

    # Try to match saved accounts
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${BLUE}🔍 Trying to match saved accounts...${NC}"
        while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            local saved_creds=$(echo "$encoded" | base64 -d 2>/dev/null)
            if [[ "$saved_creds" == "$credentials" ]]; then
                echo -e "${GREEN}✅ Matched account: $name${NC}"
                return 0
            fi
        done < <(grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE")
        echo -e "${YELLOW}⚠️  No matching saved accounts found${NC}"
    fi
}

# Initialize account configuration file
init_accounts_file() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo "{}" > "$ACCOUNTS_FILE"
        chmod 600 "$ACCOUNTS_FILE"
    fi
}

# Save current account
save_account() {
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm save-account <name>${NC}" >&2
        return 1
    fi

    # Read current credentials from Keychain
    local credentials
    credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        echo -e "${RED}❌ $(t 'no_credentials_found')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'please_login_first')${NC}" >&2
        return 1
    fi

    # Initialize account file
    init_accounts_file

    # Use pure Bash parsing and saving (not relying on jq)
    local temp_file=$(mktemp)
    local existing_accounts=""

    if [[ -f "$ACCOUNTS_FILE" ]]; then
        existing_accounts=$(cat "$ACCOUNTS_FILE")
    fi

    # Simple JSON update: if empty file or only {}, write directly
    if [[ "$existing_accounts" == "{}" || -z "$existing_accounts" ]]; then
        local encoded_creds=$(echo "$credentials" | base64)
        cat > "$ACCOUNTS_FILE" << EOF
{
  "$account_name": "$encoded_creds"
}
EOF
    else
        # Read existing accounts, add new account
        # Check if account already exists
        if grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
            # Update existing account
            local encoded_creds=$(echo "$credentials" | base64)
            # Use sed to replace existing entry
            sed -i '' "s/\"$account_name\": *\"[^\"]*\"/\"$account_name\": \"$encoded_creds\"/" "$ACCOUNTS_FILE"
        else
            # Add new account
            local encoded_creds=$(echo "$credentials" | base64)
            # Remove last } (using macOS compatible command)
            sed '$d' "$ACCOUNTS_FILE" > "$temp_file"
            # Check if comma needs to be added
            if grep -q '"' "$temp_file"; then
                echo "," >> "$temp_file"
            fi
            echo "  \"$account_name\": \"$encoded_creds\"" >> "$temp_file"
            echo "}" >> "$temp_file"
            mv "$temp_file" "$ACCOUNTS_FILE"
        fi
    fi

    chmod 600 "$ACCOUNTS_FILE"

    # Extract subscription type for display
    local subscription_type=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✅ $(t 'account_saved'): $account_name${NC}"
    echo -e "   $(t 'subscription_type'): ${subscription_type:-Unknown}"

    rm -f "$temp_file"
}

# Switch to specified account
switch_account() {
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm switch-account <name>${NC}" >&2
        return 1
    fi

    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ $(t 'no_accounts_found')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'save_account_first')${NC}" >&2
        return 1
    fi

    # Read account credentials from file
    local encoded_creds=$(grep -o "\"$account_name\": *\"[^\"]*\"" "$ACCOUNTS_FILE" | cut -d'"' -f4)

    if [[ -z "$encoded_creds" ]]; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'use_list_accounts')${NC}" >&2
        return 1
    fi

    # Decode credentials
    local credentials=$(echo "$encoded_creds" | base64 -d)

    # Write to Keychain
    if write_keychain_credentials "$credentials"; then
        echo -e "${GREEN}✅ $(t 'account_switched'): $account_name${NC}"
        echo -e "${YELLOW}⚠️  $(t 'please_restart_claude_code')${NC}"
    else
        echo -e "${RED}❌ $(t 'failed_to_switch_account')${NC}" >&2
        return 1
    fi
}

# List all saved accounts
list_accounts() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${YELLOW}$(t 'no_accounts_saved')${NC}"
        echo -e "${YELLOW}💡 $(t 'use_save_account')${NC}"
        return 0
    fi

    echo -e "${BLUE}📋 $(t 'saved_accounts'):${NC}"

    # Read and parse account list
    local current_creds=$(read_keychain_credentials)

    grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE" | while IFS=': ' read -r name encoded; do
        # Clean quotes
        name=$(echo "$name" | tr -d '"')
        encoded=$(echo "$encoded" | tr -d '"')

        # Decode and extract information
        local creds=$(echo "$encoded" | base64 -d 2>/dev/null)
        local subscription=$(echo "$creds" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
        local expires=$(echo "$creds" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)

        # Check if it's the current account
        local is_current=""
        if [[ "$creds" == "$current_creds" ]]; then
            is_current=" ${GREEN}✅ ($(t 'active'))${NC}"
        fi

        # Format expiry time
        local expires_str=""
        if [[ -n "$expires" ]]; then
            expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        fi

        echo -e "   - ${YELLOW}$name${NC} (${subscription:-Unknown}${expires_str:+, expires: $expires_str})$is_current"
    done
}

# Delete saved account
delete_account() {
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm delete-account <name>${NC}" >&2
        return 1
    fi

    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ $(t 'no_accounts_found')${NC}" >&2
        return 1
    fi

    # Check if account exists
    if ! grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        return 1
    fi

    # Delete account (using temporary file)
    local temp_file=$(mktemp)
    grep -v "\"$account_name\":" "$ACCOUNTS_FILE" > "$temp_file"

    # Clean up possible comma issues
    sed -i '' 's/,\s*}/}/g' "$temp_file" 2>/dev/null || sed -i 's/,\s*}/}/g' "$temp_file"
    sed -i '' 's/}\s*,/}/g' "$temp_file" 2>/dev/null || sed -i 's/}\s*,/}/g' "$temp_file"

    mv "$temp_file" "$ACCOUNTS_FILE"
    chmod 600 "$ACCOUNTS_FILE"

    echo -e "${GREEN}✅ $(t 'account_deleted'): $account_name${NC}"
}

# Show current account information
get_current_account() {
    local credentials=$(read_keychain_credentials)

    if [[ -z "$credentials" ]]; then
        echo -e "${YELLOW}$(t 'no_current_account')${NC}"
        echo -e "${YELLOW}💡 $(t 'please_login_or_switch')${NC}"
        return 1
    fi

    # Extract information
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

    # Format expiry time
    local expires_str=""
    if [[ -n "$expires" ]]; then
        expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
    fi

    # Find account name
    local account_name="Unknown"
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            local saved_creds=$(echo "$encoded" | base64 -d 2>/dev/null)
            if [[ "$saved_creds" == "$credentials" ]]; then
                account_name="$name"
                break
            fi
        done < <(grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE")
    fi

    echo -e "${BLUE}📊 $(t 'current_account_info'):${NC}"
    echo "   $(t 'account_name'): ${account_name}"
    echo "   $(t 'subscription_type'): ${subscription:-Unknown}"
    if [[ -n "$expires_str" ]]; then
        echo "   $(t 'token_expires'): ${expires_str}"
    fi
    echo -n "   $(t 'access_token'): "
    mask_token "$access_token"
}

# Show current status (masked)
show_status() {
    echo -e "${BLUE}📊 $(t 'current_model_config'):${NC}"
    echo "   BASE_URL: ${ANTHROPIC_BASE_URL:-'Default (Anthropic)'}"
    echo -n "   AUTH_TOKEN: "
    mask_token "${ANTHROPIC_AUTH_TOKEN}"
    echo "   MODEL: ${ANTHROPIC_MODEL:-'$(t "not_set")'}"
    echo "   SMALL_MODEL: ${ANTHROPIC_SMALL_FAST_MODEL:-'$(t "not_set")'}"
    echo ""
    echo -e "${BLUE}🔧 $(t 'env_vars_status'):${NC}"
    echo "   GLM_API_KEY: $(mask_presence GLM_API_KEY)"
    echo "   KIMI_API_KEY: $(mask_presence KIMI_API_KEY)"
    echo "   LONGCAT_API_KEY: $(mask_presence LONGCAT_API_KEY)"
    echo "   MINIMAX_API_KEY: $(mask_presence MINIMAX_API_KEY)"
    echo "   DEEPSEEK_API_KEY: $(mask_presence DEEPSEEK_API_KEY)"
    echo "   QWEN_API_KEY: $(mask_presence QWEN_API_KEY)"
    echo "   PPINFRA_API_KEY: $(mask_presence PPINFRA_API_KEY)"
}

# Clean environment variables
clean_env() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_API_URL
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_API_KEY
    unset ANTHROPIC_MODEL
    unset ANTHROPIC_SMALL_FAST_MODEL
    unset API_TIMEOUT_MS
    unset CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
}

# Switch to Deepseek
switch_to_deepseek() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Deepseek $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$DEEPSEEK_API_KEY"; then
        # Official Deepseek Anthropic compatible endpoint
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_API_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-chat"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek-coder"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # Backup: PPINFRA Anthropic compatible
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="deepseek/deepseek-v3.2-exp"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.2-exp"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'ppinfra_backup')）${NC}"
    else
        # Hidden Easter egg: default DeepSeek 3.1 experience key (obfuscated)
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="deepseek/deepseek-v3.2-exp"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.2-exp"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# Switch to Claude Sonnet
switch_to_claude() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 Switching to Claude Sonnet 4.5...${NC}"

    # If account is specified, switch account first
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 Switching to account: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_SMALL_FAST_MODEL="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    echo -e "${GREEN}✅ Switched to Claude Sonnet 4.5 (using Claude Pro subscription)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Claude Opus
switch_to_opus() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Opus 4.1...${NC}"

    # If account is specified, switch account first
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 Switching to account: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${OPUS_MODEL:-claude-opus-4-1-20250805}"
    export ANTHROPIC_SMALL_FAST_MODEL="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    echo -e "${GREEN}✅ Switched to Claude Opus 4.1 (using Claude Pro subscription)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Claude Haiku
switch_to_haiku() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Haiku 4.5...${NC}"

    # If account is specified, switch account first
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 Switching to account: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${HAIKU_MODEL:-claude-haiku-4-5}"
    export ANTHROPIC_SMALL_FAST_MODEL="${HAIKU_SMALL_FAST_MODEL:-claude-haiku-4-5}"
    echo -e "${GREEN}✅ Switched to Claude Haiku 4.5 (using Claude Pro subscription)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to GLM4.6
switch_to_glm() {
    echo -e "${YELLOW}🔄 Switching to GLM4.6 model...${NC}"
    clean_env
    if is_effectively_set "$GLM_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
        export ANTHROPIC_API_URL="https://api.z.ai/api/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$GLM_API_KEY"
        export ANTHROPIC_API_KEY="$GLM_API_KEY"
        export ANTHROPIC_MODEL="glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="glm-4.6"
        echo -e "${GREEN}✅ Switched to GLM4.6 (official)${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # Backup: PPINFRA GLM support
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="zai-org/glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="zai-org/glm-4.6"
        echo -e "${GREEN}✅ Switched to GLM4.6 (PPINFRA backup)${NC}"
    else
        # Default experience key
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="zai-org/glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="zai-org/glm-4.6"
        echo -e "${GREEN}✅ Switched to GLM4.6 ($(t 'default_experience_key'))${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to KIMI2
switch_to_kimi() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KIMI2 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$KIMI_API_KEY"; then
        # Official Moonshot KIMI Anthropic compatible endpoint
        export ANTHROPIC_BASE_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_API_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
        export ANTHROPIC_API_KEY="$KIMI_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # Backup: PPINFRA Anthropic compatible
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'ppinfra_backup')）${NC}"
    else
        # Default experience key
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to MiniMax M2
switch_to_minimax() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') MiniMax M2 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$MINIMAX_API_KEY"; then
        # Official MiniMax Anthropic compatible endpoint
        export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
        export ANTHROPIC_API_URL="https://api.minimax.io/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$MINIMAX_API_KEY"
        export ANTHROPIC_API_KEY="$MINIMAX_API_KEY"
        export ANTHROPIC_MODEL="minimax/minimax-m2"
        export ANTHROPIC_SMALL_FAST_MODEL="minimax/minimax-m2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # Backup: PPINFRA Anthropic compatible
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="minimax/minimax-m2"
        export ANTHROPIC_SMALL_FAST_MODEL="minimax/minimax-m2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'ppinfra_backup')）${NC}"
    else
        # Default experience key
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="minimax/minimax-m2"
        export ANTHROPIC_SMALL_FAST_MODEL="minimax/minimax-m2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Qwen (Alibaba Cloud official preferred, default to PPINFRA)
switch_to_qwen() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Qwen $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$QWEN_API_KEY"; then
        # Alibaba Cloud DashScope official Claude proxy endpoint
        export ANTHROPIC_BASE_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_API_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
        export ANTHROPIC_API_KEY="$QWEN_API_KEY"
        # Alibaba Cloud DashScope supported models
        local qwen_model="${QWEN_MODEL:-qwen3-max}"
        local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-instruct}"
        export ANTHROPIC_MODEL="$qwen_model"
        export ANTHROPIC_SMALL_FAST_MODEL="$qwen_small"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'alibaba_dashscope_official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'ppinfra_backup')）${NC}"
    else
        # Default experience key
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to StreamLake AI (KAT)
switch_to_kat() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') StreamLake AI (KAT) $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$KAT_API_KEY"; then
        # Get user's endpoint ID, default to value in config or environment variable
        local endpoint_id="${KAT_ENDPOINT_ID:-ep-default}"
        # StreamLake AI KAT endpoint format:https://vanchin.streamlake.ai/api/gateway/v1/endpoints/{endpoint_id}/claude-code-proxy
        export ANTHROPIC_BASE_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${endpoint_id}/claude-code-proxy"
        export ANTHROPIC_API_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${endpoint_id}/claude-code-proxy"
        export ANTHROPIC_AUTH_TOKEN="$KAT_API_KEY"
        export ANTHROPIC_API_KEY="$KAT_API_KEY"
        # Use KAT-Coder model
        local kat_model="${KAT_MODEL:-KAT-Coder}"
        local kat_small="${KAT_SMALL_FAST_MODEL:-KAT-Coder}"
        export ANTHROPIC_MODEL="$kat_model"
        export ANTHROPIC_SMALL_FAST_MODEL="$kat_small"
        echo -e "${GREEN}✅ $(t 'switched_to') StreamLake AI (KAT)（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ $(t 'missing_api_key'): KAT_API_KEY${NC}"
        echo "$(t 'please_set_in_config'): KAT_API_KEY"
        echo ""
        echo "$(t 'example_config'):"
        echo "  export KAT_API_KEY='YOUR_API_KEY'"
        echo "  export KAT_ENDPOINT_ID='ep-xxx-xxx'"
        echo ""
        echo "$(t 'get_endpoint_id_from'): https://www.streamlake.ai/document/DOC/mg6k6nlp8j6qxicx4c9"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to PPINFRA service
switch_to_ppinfra() {
    local target="${1:-}"
    local no_color="${2:-false}"

    # Reload config to ensure latest values are used
    load_config || return 1

    # If PPINFRA_API_KEY is not configured, use default experience key
    local ppinfra_key="$PPINFRA_API_KEY"
    if ! is_effectively_set "$ppinfra_key"; then
        ppinfra_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
    fi

    # If no target model specified, show selection menu
    if [[ -z "$target" ]]; then
        if [[ "$no_color" == "true" ]]; then
            echo "❌ $(t 'model_not_specified')"
            echo "💡 $(t 'usage_example'): ccm pp glm"
            echo "💡 $(t 'available_ppinfra_models'): deepseek, glm, kimi, qwen, minimax"
        else
            echo -e "${RED}❌ $(t 'model_not_specified')${NC}"
            echo -e "${YELLOW}💡 $(t 'usage_example'): ccm pp glm${NC}"
            echo -e "${YELLOW}💡 $(t 'available_ppinfra_models'): deepseek, glm, kimi, qwen, minimax${NC}"
        fi
        return 1
    fi

    # Clean old environment variables (critical: avoid authentication conflicts)
    echo "unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    
    # Output PPINFRA configuration export statements based on target model
    case "$target" in
        "deepseek"|"ds")
            # Output info to stderr, avoid interfering with eval
            if [[ "$no_color" == "true" ]]; then
                echo "✅ $(t 'switched_to') DeepSeek v3.2-exp（PPINFRA）" >&2
            else
                echo -e "${GREEN}✅ $(t 'switched_to') DeepSeek v3.2-exp（PPINFRA）${NC}" >&2
            fi
            echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_AUTH_TOKEN='$ppinfra_key'"
            echo "export ANTHROPIC_MODEL='deepseek/deepseek-v3.2-exp'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='deepseek/deepseek-v3.2-exp'"
            ;;
        "glm"|"glm4"|"glm4.6")
            if [[ "$no_color" == "true" ]]; then
                echo "✅ $(t 'switched_to') GLM 4.6（PPINFRA）" >&2
            else
                echo -e "${GREEN}✅ $(t 'switched_to') GLM 4.6（PPINFRA）${NC}" >&2
            fi
            echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_AUTH_TOKEN='$ppinfra_key'"
            echo "export ANTHROPIC_MODEL='zai-org/glm-4.6'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='zai-org/glm-4.6'"
            ;;
        "kimi"|"kimi2")
            if [[ "$no_color" == "true" ]]; then
                echo "✅ $(t 'switched_to') KIMI 2（PPINFRA）" >&2
            else
                echo -e "${GREEN}✅ $(t 'switched_to') KIMI 2（PPINFRA）${NC}" >&2
            fi
            echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_AUTH_TOKEN='$ppinfra_key'"
            echo "export ANTHROPIC_MODEL='kimi-k2-turbo-preview'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='kimi-k2-turbo-preview'"
            ;;
        "qwen")
            if [[ "$no_color" == "true" ]]; then
                echo "✅ $(t 'switched_to') Qwen（PPINFRA）" >&2
            else
                echo -e "${GREEN}✅ $(t 'switched_to') Qwen（PPINFRA）${NC}" >&2
            fi
            echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_AUTH_TOKEN='$ppinfra_key'"
            echo "export ANTHROPIC_MODEL='qwen3-next-80b-a3b-thinking'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='qwen3-next-80b-a3b-thinking'"
            ;;
        "minimax"|"mm")
            if [[ "$no_color" == "true" ]]; then
                echo "✅ $(t 'switched_to') MiniMax M2（PPINFRA）" >&2
            else
                echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（PPINFRA）${NC}" >&2
            fi
            echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
            echo "export ANTHROPIC_AUTH_TOKEN='$ppinfra_key'"
            echo "export ANTHROPIC_MODEL='minimax/minimax-m2'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='minimax/minimax-m2'"
            ;;
        *)
            if [[ "$no_color" == "true" ]]; then
                echo "❌ $(t 'unknown_ppinfra_model'): $target"
                echo "💡 $(t 'available_ppinfra_models'): deepseek, glm, kimi, qwen, minimax"
            else
                echo -e "${RED}❌ $(t 'unknown_ppinfra_model'): $target${NC}"
                echo -e "${YELLOW}💡 $(t 'available_ppinfra_models'): deepseek, glm, kimi, qwen, minimax${NC}"
            fi
            return 1
            ;;
    esac

    echo "export API_TIMEOUT_MS='600000'"
    echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
}

# Show help information
show_help() {
    echo -e "${BLUE}🔧 $(t 'switching_info') v2.2.0${NC}"
    echo ""
    echo -e "${YELLOW}$(t 'usage'):${NC} $(basename "$0") [options]"
    echo ""
    echo -e "${YELLOW}$(t 'model_options'):${NC}"
    echo "  deepseek, ds       - env deepseek"
    echo "  kimi, kimi2        - env kimi"
    echo "  kat                - env kat"
    echo "  longcat, lc        - env longcat"
    echo "  minimax, mm        - env minimax"
    echo "  qwen               - env qwen"
    echo "  glm, glm4          - env glm"
    echo "  claude, sonnet, s  - env claude"
    echo "  opus, o            - env opus"
    echo "  haiku, h           - env haiku"
    echo ""
    echo -e "${YELLOW}Claude Pro Account Management:${NC}"
    echo "  save-account <name>     - Save current Claude Pro account"
    echo "  switch-account <name>   - Switch to saved account"
    echo "  list-accounts           - List all saved accounts"
    echo "  delete-account <name>   - Delete saved account"
    echo "  current-account         - Show current account info"
    echo "  claude:account         - Switch account and use Claude (Sonnet)"
    echo "  opus:account           - Switch account and use Opus model"
    echo "  haiku:account          - Switch account and use Haiku model"
    echo ""
    echo -e "${YELLOW}$(t 'tool_options'):${NC}"
    echo "  status, st       - $(t 'show_current_config')"
    echo "  env [model]      - $(t 'output_export_only')"
    echo "  pp [model]       - Switch to PPINFRA service (deepseek/glm/kimi/qwen/minimax)"
    echo "  config, cfg      - $(t 'edit_config_file')"
    echo "  help, h          - $(t 'show_help')"
    echo ""
    echo -e "${YELLOW}$(t 'examples'):${NC}"
    echo "  eval \"\$(ccm deepseek)\"                   # Apply in current shell (recommended)"
    echo "  $(basename "$0") status                      # Check current status (masked)"
    echo "  $(basename "$0") save-account work           # Save current account as 'work'"
    echo "  $(basename "$0") opus:personal               # Switch to 'personal' account with Opus"
    echo ""
    echo -e "${YELLOW}Supported models:${NC}"
    echo "  🌙 KIMI2               - Official: kimi-k2-turbo-preview"
    echo "  🤖 Deepseek            - Official: deepseek-chat | Backup: deepseek/deepseek-v3.1 (PPINFRA)"
    echo "  🌊 StreamLake (KAT)    - Official: KAT-Coder"
    echo "  🐱 LongCat             - Official: LongCat-Flash-Thinking / LongCat-Flash-Chat"
    echo "  🎯 MiniMax M2          - Official: MiniMax-M2 | Backup: MiniMax-M2 (PPINFRA)"
    echo "  🐪 Qwen                - Official: qwen3-max (Alibaba Cloud) | Backup: qwen3-next-80b-a3b-thinking (PPINFRA)"
    echo "  🇨🇳 GLM4.6             - Official: glm-4.6 / glm-4.5-air"
    echo "  🧠 Claude Sonnet 4.5   - claude-sonnet-4-5-20250929"
    echo "  🚀 Claude Opus 4.1     - claude-opus-4-1-20250805"
    echo "  🔷 Claude Haiku 4.5    - claude-haiku-4-5"
}

# Append missing model ID override items to config file (only append missing items, don't overwrite existing config)
ensure_model_override_defaults() {
    local -a pairs=(
        "DEEPSEEK_MODEL=deepseek-chat"
        "DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat"
        "KIMI_MODEL=kimi-k2-turbo-preview"
        "KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview"
        "KAT_MODEL=KAT-Coder"
        "KAT_SMALL_FAST_MODEL=KAT-Coder"
        "KAT_ENDPOINT_ID=ep-default"
        "LONGCAT_MODEL=LongCat-Flash-Thinking"
        "LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat"
        "MINIMAX_MODEL=MiniMax-M2"
        "MINIMAX_SMALL_FAST_MODEL=MiniMax-M2"
        "QWEN_MODEL=qwen3-max"
        "QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct"
        "GLM_MODEL=glm-4.6"
        "GLM_SMALL_FAST_MODEL=glm-4.5-air"
        "CLAUDE_MODEL=claude-sonnet-4-5-20250929"
        "CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929"
        "OPUS_MODEL=claude-opus-4-1-20250805"
        "OPUS_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929"
        "HAIKU_MODEL=claude-haiku-4-5"
        "HAIKU_SMALL_FAST_MODEL=claude-haiku-4-5"
    )
    local added_header=0
    for pair in "${pairs[@]}"; do
        local key="${pair%%=*}"
        local default="${pair#*=}"
        if ! grep -Eq "^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null; then
            if [[ $added_header -eq 0 ]]; then
                {
                    echo ""
                    echo "# ---- CCM model ID overrides (auto-added) ----"
                } >> "$CONFIG_FILE"
                added_header=1
            fi
            printf "%s=%s\n" "$key" "$default" >> "$CONFIG_FILE"
        fi
    done
}

# Edit configuration file
edit_config() {
    # Ensure config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}📝 $(t 'config_created'): $CONFIG_FILE${NC}"
        create_default_config
    fi

    # Append missing model ID override defaults (don't touch existing keys)
    ensure_model_override_defaults

    echo -e "${BLUE}🔧 $(t 'opening_config_file')...${NC}"
    echo -e "${YELLOW}$(t 'config_file_path'): $CONFIG_FILE${NC}"
    
    # Try different editors by priority
    if command -v cursor >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_cursor')${NC}"
        cursor "$CONFIG_FILE" &
        echo -e "${YELLOW}💡 $(t 'config_opened') Cursor $(t 'opened_edit_save')${NC}"
    elif command -v code >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_vscode')${NC}"
        code "$CONFIG_FILE" &
        echo -e "${YELLOW}💡 $(t 'config_opened') VS Code $(t 'opened_edit_save')${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]] && command -v open >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_default_editor')${NC}"
        open "$CONFIG_FILE"
        echo -e "${YELLOW}💡 $(t 'config_opened_default')${NC}"
    elif command -v vim >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_vim')${NC}"
        vim "$CONFIG_FILE"
    elif command -v nano >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $(t 'using_nano')${NC}"
        nano "$CONFIG_FILE"
    else
        echo -e "${RED}❌ $(t 'no_editor_found')${NC}"
        echo -e "${YELLOW}$(t 'edit_manually'): $CONFIG_FILE${NC}"
        echo -e "${YELLOW}$(t 'install_editor'): cursor, code, vim, nano${NC}"
        return 1
    fi
}

# Only output export statement environment settings (for eval)
emit_env_exports() {
    local target="$1"
    # Load config for existence judgment (environment variables first, don't print keys)
    load_config || return 1

    # Common prelude: clean old variables
    local prelude="unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"

    case "$target" in
        "deepseek"|"ds")
            if is_effectively_set "$DEEPSEEK_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.deepseek.com/anthropic'"
                echo "# $(t 'export_if_env_not_set')"
                echo "if [ -z \"\${DEEPSEEK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${DEEPSEEK_API_KEY}\""
                local ds_model="${DEEPSEEK_MODEL:-deepseek-chat}"
                local ds_small="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek-chat}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${ds_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local ds_model="${DEEPSEEK_MODEL:-deepseek/deepseek-v3.2-exp}"
                local ds_small="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek/deepseek-v3.2-exp}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${ds_small}'"
            else
                # Hidden Easter egg: default DeepSeek 3.1 experience key, for everyone's convenience to try, but this has RPM limitations, you can find PPINFRA registration entry in README.md if needed
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local ds_model="${DEEPSEEK_MODEL:-deepseek/deepseek-v3.2-exp}"
                local ds_small="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek/deepseek-v3.2-exp}"
                echo "export ANTHROPIC_MODEL='${ds_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${ds_small}'"
            fi
            ;;
        "kimi"|"kimi2")
            if is_effectively_set "$KIMI_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.moonshot.cn/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.moonshot.cn/anthropic'"
                echo "if [ -z \"\${KIMI_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${KIMI_API_KEY}\""
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${KIMI_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            else
                # Default experience key
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            fi
            ;;
        "qwen")
            if is_effectively_set "$QWEN_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy'"
                echo "export ANTHROPIC_API_URL='https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy'"
                echo "if [ -z \"\${QWEN_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${QWEN_API_KEY}\""
                local qwen_model="${QWEN_MODEL:-qwen3-max}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-instruct}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${QWEN_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local qwen_model="${QWEN_MODEL:-qwen3-next-80b-a3b-thinking}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-thinking}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            else
                # Default experience key
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local qwen_model="${QWEN_MODEL:-qwen3-next-80b-a3b-thinking}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-thinking}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            fi
            ;;
        "glm"|"glm4"|"glm4.6")
            if is_effectively_set "$GLM_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://open.bigmodel.cn/api/anthropic'"
                echo "export ANTHROPIC_API_URL='https://open.bigmodel.cn/api/anthropic'"
                echo "if [ -z \"\${GLM_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${GLM_API_KEY}\""
                local glm_model="${GLM_MODEL:-glm-4.6}"
                local glm_small="${GLM_SMALL_FAST_MODEL:-glm-4.5-air}"
                echo "export ANTHROPIC_MODEL='${glm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${glm_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local glm_model="${GLM_MODEL:-zai-org/glm-4.6}"
                local glm_small="${GLM_SMALL_FAST_MODEL:-zai-org/glm-4.6}"
                echo "export ANTHROPIC_MODEL='${glm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${glm_small}'"
            else
                # Default experience key
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local glm_model="${GLM_MODEL:-zai-org/glm-4.6}"
                local glm_small="${GLM_SMALL_FAST_MODEL:-zai-org/glm-4.6}"
                echo "export ANTHROPIC_MODEL='${glm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${glm_small}'"
            fi
            ;;
        "claude"|"sonnet"|"s")
            echo "$prelude"
            # Official Anthropic default gateway, no need to set BASE_URL
            echo "unset ANTHROPIC_BASE_URL"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local claude_model="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
            local claude_small="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
            echo "export ANTHROPIC_MODEL='${claude_model}'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='${claude_small}'"
            ;;
        "opus"|"o")
            echo "$prelude"
            echo "unset ANTHROPIC_BASE_URL"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local opus_model="${OPUS_MODEL:-claude-opus-4-1-20250805}"
            local opus_small="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
            echo "export ANTHROPIC_MODEL='${opus_model}'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='${opus_small}'"
            ;;
        "haiku"|"h")
            echo "$prelude"
            echo "unset ANTHROPIC_BASE_URL"
            echo "unset ANTHROPIC_API_URL"
            echo "unset ANTHROPIC_API_KEY"
            local haiku_model="${HAIKU_MODEL:-claude-haiku-4-5}"
            local haiku_small="${HAIKU_SMALL_FAST_MODEL:-claude-haiku-4-5}"
            echo "export ANTHROPIC_MODEL='${haiku_model}'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='${haiku_small}'"
            ;;
        "longcat")
            if ! is_effectively_set "$LONGCAT_API_KEY"; then
                # Fallback: directly source config file once (fix loading failure due to some line format issues)
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
            if is_effectively_set "$LONGCAT_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.longcat.chat/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.longcat.chat/anthropic'"
                echo "if [ -z \"\${LONGCAT_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${LONGCAT_API_KEY}\""
                local lc_model="${LONGCAT_MODEL:-LongCat-Flash-Thinking}"
                local lc_small="${LONGCAT_SMALL_FAST_MODEL:-LongCat-Flash-Chat}"
                echo "export ANTHROPIC_MODEL='${lc_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${lc_small}'"
            else
                echo "# ❌ $(t 'not_detected') LONGCAT_API_KEY" 1>&2
                return 1
            fi
            ;;
        "minimax"|"mm")
            if is_effectively_set "$MINIMAX_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.minimax.io/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.minimax.io/anthropic'"
                echo "if [ -z \"\${MINIMAX_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${MINIMAX_API_KEY}\""
                local mm_model="${MINIMAX_MODEL:-minimax/minimax-m2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-minimax/minimax-m2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${MINIMAX_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local mm_model="${MINIMAX_MODEL:-minimax/minimax-m2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-minimax/minimax-m2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            else
                # Default experience key
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local mm_model="${MINIMAX_MODEL:-minimax/minimax-m2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-minimax/minimax-m2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            fi
            ;;
        "kat")
            if ! is_effectively_set "$KAT_API_KEY"; then
                # Fallback: directly source config file once
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
            if is_effectively_set "$KAT_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                # Use user's endpoint ID, default to ep-default
                local kat_endpoint="${KAT_ENDPOINT_ID:-ep-default}"
                echo "export ANTHROPIC_BASE_URL='https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${kat_endpoint}/claude-code-proxy'"
                echo "export ANTHROPIC_API_URL='https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${kat_endpoint}/claude-code-proxy'"
                echo "if [ -z \"\${KAT_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${KAT_API_KEY}\""
                local kat_model="${KAT_MODEL:-KAT-Coder}"
                local kat_small="${KAT_SMALL_FAST_MODEL:-KAT-Coder}"
                echo "export ANTHROPIC_MODEL='${kat_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kat_small}'"
            else
                echo "# ❌ $(t 'missing_api_key'): KAT_API_KEY" 1>&2
                echo "# $(t 'please_set_in_config'): KAT_API_KEY" 1>&2
                echo "# $(t 'get_endpoint_id_from'): https://www.streamlake.ai/document/DOC/mg6k6nlp8j6qxicx4c9" 1>&2
                return 1
            fi
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|claude|opus|minimax|kat]" 1>&2
            return 1
            ;;
    esac
}


# Main function
main() {
    # Load config (environment variables first)
    if ! load_config; then
        return 1
    fi

    # Process arguments
    local cmd="${1:-help}"

    # Check if it's model:account format
    if [[ "$cmd" =~ ^(claude|sonnet|opus|haiku|s|o|h):(.+)$ ]]; then
        local model_type="${BASH_REMATCH[1]}"
        local account_name="${BASH_REMATCH[2]}"

        # Switch account first: redirect output to stderr, avoid contaminating stdout (stdout only for export statements)
        switch_account "$account_name" 1>&2 || return 1

        # Then only output corresponding model's export statements, for caller eval
        case "$model_type" in
            "claude"|"sonnet"|"s")
                emit_env_exports claude
                ;;
            "opus"|"o")
                emit_env_exports opus
                ;;
            "haiku"|"h")
                emit_env_exports haiku
                ;;
        esac
        return $?
    fi

    case "$cmd" in
        # Account management commands
        "save-account")
            shift
            save_account "$1"
            ;;
        "switch-account")
            shift
            switch_account "$1"
            ;;
        "list-accounts")
            list_accounts
            ;;
        "delete-account")
            shift
            delete_account "$1"
            ;;
        "current-account")
            get_current_account
            ;;
        "debug-keychain")
            debug_keychain_credentials
            ;;
        # Model switching commands
        "deepseek"|"ds")
            emit_env_exports deepseek
            ;;
        "kimi"|"kimi2")
            emit_env_exports kimi
            ;;
        "qwen")
            emit_env_exports qwen
            ;;
        "kat")
            emit_env_exports kat
            ;;
        "longcat"|"lc")
            emit_env_exports longcat
            ;;
        "minimax"|"mm")
            emit_env_exports minimax
            ;;
        "glm"|"glm4"|"glm4.6")
            emit_env_exports glm
            ;;
        "claude"|"sonnet"|"s")
            emit_env_exports claude
            ;;
        "opus"|"o")
            emit_env_exports opus
            ;;
        "haiku"|"h")
            emit_env_exports haiku
            ;;
        "env")
            shift
            emit_env_exports "${1:-}"
            ;;
        "pp")
            shift
            local target="${1:-}"
            local no_color="${2:-false}"
            switch_to_ppinfra "$target" "$no_color"
            ;;
        "status"|"st")
            show_status
            ;;
        "config"|"cfg")
            edit_config
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ $(t 'unknown_option'): $1${NC}" >&2
            echo "" >&2
            show_help >&2
            return 1
            ;;
    esac
}

# Execute main function
main "$@"
