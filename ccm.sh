############################################################
# Claude Code Model Switcher (ccm) - Standalone Version
# ---------------------------------------------------------
# Function: Quick switching between different AI models
# Supports: Claude, Deepseek, GLM4.6, KIMI2
# Author: Peng
# Version: 2.3.0
############################################################

# Script color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Color control for account management commands
NO_COLOR=false

# Set colors based on NO_COLOR (used by account management functions)
set_no_color() {
    if [[ "$NO_COLOR" == "true" ]]; then
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

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

    # Source the language file
    if [[ -f "$lang_file" ]]; then
        # Parse JSON file to extract translations
        # This is a simple JSON parser for our specific use case
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$line" ]] && continue
            
            # Parse key-value pairs
            if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*\"([^\"]*)\"[[:space:]]*$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                # Store in a variable with dynamic name
                printf -v "t_$key" '%s' "$value"
            fi
        done < "$lang_file"
    fi
}

# Translation function
t() {
    local key="$1"
    local var_name="t_$key"
    local value="${!var_name}"
    
    # If translation not found, return the key itself
    if [[ -z "$value" ]]; then
        echo "$key"
    else
        echo "$value"
    fi
}

# Clean up environment variables
clean_env() {
    unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL
    unset API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
}

# Check if a value is effectively set (not empty or placeholder)
is_effectively_set() {
    local value="$1"
    [[ -n "$value" && "$value" != *"sk-your-"* && "$value" != *"your-"* ]]
}

# Mask sensitive information for display
mask_token() {
    local token="$1"
    if [[ -z "$token" ]]; then
        echo "[Not Set]"
    elif [[ ${#token} -le 8 ]]; then
        echo "[Masked]"
    else
        echo "${token:0:4}****${token: -4}"
    fi
}

# Create configuration file with defaults
create_config_if_needed() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<'EOF'
# CCM Configuration File
# Note: Environment variables take priority over this file

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

# Doubao Seed-Code (Volcengine ARK)
ARK_API_KEY=your-ark-api-key

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
SEED_MODEL=doubao-seed-code-preview-latest
SEED_SMALL_FAST_MODEL=doubao-seed-code-preview-latest

EOF
        echo -e "${YELLOW}⚠️  $(t 'config_created'): $CONFIG_FILE${NC}" >&2
        echo -e "${YELLOW}   $(t 'edit_file_to_add_keys')${NC}" >&2
        echo -e "${GREEN}🚀 Using default experience keys for now...${NC}" >&2
        # Don't return 1 - continue with default fallback keys
    fi
    
    # First read language setting
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_lang
        config_lang=$(grep -E "^[[:space:]]*CCM_LANGUAGE[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | /usr/bin/head -1 | LC_ALL=C cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
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
            # Convert to lowercase for case-insensitive comparison
            lower_env_value=$(echo "$env_value" | LC_ALL=C tr '[:upper:]' '[:lower:]')
            
            # Check if environment variable is not set or is empty
            if [[ -z "$env_value" ]]; then
                # Check if value is not a placeholder
                local lower_value
                lower_value=$(echo "$value" | LC_ALL=C tr '[:upper:]' '[:lower:]')
                if [[ "$lower_value" != *"sk-your-"* && "$lower_value" != *"your-"* ]]; then
                    echo "export $key='$value'" >> "$temp_file"
                fi
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Source the processed config
    if [[ -s "$temp_file" ]]; then
        source "$temp_file"
    fi
    rm -f "$temp_file"
}

# Load configuration (environment variables take priority)
load_config() {
    # Set default language preference
    local lang_preference="${CCM_LANGUAGE:-en}"
    
    # Load translations first
    load_translations "$lang_preference"
    
    # Create config if needed
    create_config_if_needed
    
    # Ensure all required variables have default values
    # Note: Don't set default API keys - let the switch functions handle missing keys
    
    # Default model IDs if not set
    DEEPSEEK_MODEL="${DEEPSEEK_MODEL:-deepseek-chat}"
    DEEPSEEK_SMALL_FAST_MODEL="${DEEPSEEK_SMALL_FAST_MODEL:-deepseek-chat}"
    KIMI_MODEL="${KIMI_MODEL:-kimi-k2-turbo-preview}"
    KIMI_SMALL_FAST_MODEL="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
    KIMI_CN_MODEL="${KIMI_CN_MODEL:-kimi-k2-thinking}"
    KIMI_CN_SMALL_FAST_MODEL="${KIMI_CN_SMALL_FAST_MODEL:-kimi-k2-thinking}"
    QWEN_MODEL="${QWEN_MODEL:-qwen3-max}"
    QWEN_SMALL_FAST_MODEL="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-instruct}"
    GLM_MODEL="${GLM_MODEL:-glm-4.6}"
    GLM_SMALL_FAST_MODEL="${GLM_SMALL_FAST_MODEL:-glm-4.5-air}"
    CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    CLAUDE_SMALL_FAST_MODEL="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    OPUS_MODEL="${OPUS_MODEL:-claude-opus-4-1-20250805}"
    OPUS_SMALL_FAST_MODEL="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    HAIKU_MODEL="${HAIKU_MODEL:-claude-haiku-4-5}"
    HAIKU_SMALL_FAST_MODEL="${HAIKU_SMALL_FAST_MODEL:-claude-haiku-4-5}"
    LONGCAT_MODEL="${LONGCAT_MODEL:-LongCat-Flash-Thinking}"
    LONGCAT_SMALL_FAST_MODEL="${LONGCAT_SMALL_FAST_MODEL:-LongCat-Flash-Chat}"
    MINIMAX_MODEL="${MINIMAX_MODEL:-MiniMax-M2}"
    MINIMAX_SMALL_FAST_MODEL="${MINIMAX_SMALL_FAST_MODEL:-MiniMax-M2}"
    SEED_MODEL="${SEED_MODEL:-doubao-seed-code-preview-latest}"
    SEED_SMALL_FAST_MODEL="${SEED_SMALL_FAST_MODEL:-doubao-seed-code-preview-latest}"
    KAT_MODEL="${KAT_MODEL:-KAT-Coder}"
    KAT_SMALL_FAST_MODEL="${KAT_SMALL_FAST_MODEL:-KAT-Coder}"
    KAT_ENDPOINT_ID="${KAT_ENDPOINT_ID:-ep-default}"
    
    return 0
}

# Switch to Deepseek (official API preferred, fallback to PPINFRA)
switch_to_deepseek() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Deepseek $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$DEEPSEEK_API_KEY"; then
        # Official Deepseek Anthropic compatible endpoint
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_API_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-coder"
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
        echo -e "${RED}❌ Please configure DEEPSEEK_API_KEY or PPINFRA_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Claude Sonnet (Pro account or API key)
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
    # Use official Anthropic endpoint (no need to set BASE_URL)
    # API keys are optional when using Claude Pro accounts
    
    # Check if we have a Claude API key configured
    if is_effectively_set "$CLAUDE_API_KEY"; then
        export ANTHROPIC_AUTH_TOKEN="$CLAUDE_API_KEY"
        echo -e "${GREEN}✅ Using Claude API key${NC}"
    else
        echo -e "${GREEN}✅ Using Claude Pro account${NC}"
    fi
    
    local claude_model="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    local claude_small="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_MODEL="$claude_model"
    export ANTHROPIC_SMALL_FAST_MODEL="$claude_small"
    
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Claude Opus (Pro account or API key)
switch_to_opus() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 Switching to Claude Opus 4.1...${NC}"

    # If account is specified, switch account first
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 Switching to account: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    # Use official Anthropic endpoint
    
    # Check if we have a Claude API key configured
    if is_effectively_set "$CLAUDE_API_KEY"; then
        export ANTHROPIC_AUTH_TOKEN="$CLAUDE_API_KEY"
        echo -e "${GREEN}✅ Using Claude API key${NC}"
    else
        echo -e "${GREEN}✅ Using Claude Pro account${NC}"
    fi
    
    local opus_model="${OPUS_MODEL:-claude-opus-4-1-20250805}"
    local opus_small="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_MODEL="$opus_model"
    export ANTHROPIC_SMALL_FAST_MODEL="$opus_small"
    
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Claude Haiku (Pro account or API key)
switch_to_haiku() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 Switching to Claude Haiku 4.5...${NC}"

    # If account is specified, switch account first
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 Switching to account: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    # Use official Anthropic endpoint
    
    # Check if we have a Claude API key configured
    if is_effectively_set "$CLAUDE_API_KEY"; then
        export ANTHROPIC_AUTH_TOKEN="$CLAUDE_API_KEY"
        echo -e "${GREEN}✅ Using Claude API key${NC}"
    else
        echo -e "${GREEN}✅ Using Claude Pro account${NC}"
    fi
    
    local haiku_model="${HAIKU_MODEL:-claude-haiku-4-5}"
    local haiku_small="${HAIKU_SMALL_FAST_MODEL:-claude-haiku-4-5}"
    export ANTHROPIC_MODEL="$haiku_model"
    export ANTHROPIC_SMALL_FAST_MODEL="$haiku_small"
    
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to GLM4.6 (official API preferred, fallback to PPINFRA)
switch_to_glm() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') GLM4.6 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$GLM_API_KEY"; then
        # Official GLM Anthropic compatible endpoint
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
        echo -e "${RED}❌ Please configure GLM_API_KEY or PPINFRA_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to KIMI2 (official API preferred, fallback to PPINFRA)
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
        echo -e "${RED}❌ Please configure KIMI_API_KEY or PPINFRA_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to MiniMax M2 (official API preferred, fallback to PPINFRA)
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
        echo -e "${RED}❌ Please configure MINIMAX_API_KEY or PPINFRA_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to Doubao Seed-Code (Volcengine ARK)
switch_to_seed() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Seed-Code $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$ARK_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://ark.cn-beijing.volces.com/api/coding"
        export ANTHROPIC_API_URL="https://ark.cn-beijing.volces.com/api/coding"
        export ANTHROPIC_AUTH_TOKEN="$ARK_API_KEY"
        export ANTHROPIC_API_KEY="$ARK_API_KEY"
        export API_TIMEOUT_MS="3000000"
        export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
        # Doubao Seed-Code model
        local seed_model="${SEED_MODEL:-doubao-seed-code-preview-latest}"
        local seed_small="${SEED_SMALL_FAST_MODEL:-doubao-seed-code-preview-latest}"
        export ANTHROPIC_MODEL="$seed_model"
        export ANTHROPIC_SMALL_FAST_MODEL="$seed_small"
        echo -e "${GREEN}✅ $(t 'switched_to') Seed-Code（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ Please configure ARK_API_KEY${NC}"
        return 1
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
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # Backup: PPINFRA Anthropic compatible
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ $(t 'switched_to') Qwen（$(t 'ppinfra_backup')）${NC}"
    else
        echo -e "${RED}❌ Please configure QWEN_API_KEY or PPINFRA_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to StreamLake (KAT)
switch_to_kat() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KAT $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$KAT_API_KEY"; then
        # Use user's endpoint ID, default to ep-default
        local kat_endpoint="${KAT_ENDPOINT_ID:-ep-default}"
        export ANTHROPIC_BASE_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${kat_endpoint}/claude-code-proxy"
        export ANTHROPIC_API_URL="https://vanchin.streamlake.ai/api/gateway/v1/endpoints/${kat_endpoint}/claude-code-proxy"
        export ANTHROPIC_AUTH_TOKEN="$KAT_API_KEY"
        export ANTHROPIC_API_KEY="$KAT_API_KEY"
        local kat_model="${KAT_MODEL:-KAT-Coder}"
        local kat_small="${KAT_SMALL_FAST_MODEL:-KAT-Coder}"
        export ANTHROPIC_MODEL="$kat_model"
        export ANTHROPIC_SMALL_FAST_MODEL="$kat_small"
        echo -e "${GREEN}✅ $(t 'switched_to') KAT（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ Please configure KAT_API_KEY${NC}"
        echo -e "${YELLOW}Get it from: https://www.streamlake.ai/document/DOC/mg6k6nlp8j6qxicx4c9${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to LongCat (Meituan)
switch_to_longcat() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') LongCat $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$LONGCAT_API_KEY"; then
        # Official LongCat Anthropic compatible endpoint
        export ANTHROPIC_BASE_URL="https://api.longcat.chat/anthropic"
        export ANTHROPIC_API_URL="https://api.longcat.chat/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$LONGCAT_API_KEY"
        export ANTHROPIC_API_KEY="$LONGCAT_API_KEY"
        export ANTHROPIC_MODEL="LongCat-Flash-Thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="LongCat-Flash-Chat"
        echo -e "${GREEN}✅ $(t 'switched_to') LongCat（$(t 'official')）${NC}"
    else
        echo -e "${RED}❌ Please configure LONGCAT_API_KEY${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# Switch to PPINFRA backup service
switch_to_ppinfra() {
    local target="$1"
    echo -e "${YELLOW}🔄 $(t 'switching_to') PPINFRA $target $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$PPINFRA_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        
        case "$target" in
            "deepseek"|"ds")
                export ANTHROPIC_MODEL="deepseek/deepseek-v3.2-exp"
                export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.2-exp"
                ;;
            "kimi"|"kimi2")
                export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
                export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
                ;;
            "glm"|"glm4"|"glm4.6")
                export ANTHROPIC_MODEL="zai-org/glm-4.6"
                export ANTHROPIC_SMALL_FAST_MODEL="zai-org/glm-4.6"
                ;;
            "qwen")
                export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
                export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
                ;;
            "minimax"|"mm")
                export ANTHROPIC_MODEL="minimax/minimax-m2"
                export ANTHROPIC_SMALL_FAST_MODEL="minimax/minimax-m2"
                ;;
            *)
                echo -e "${RED}❌ $(t 'unsupported_ppinfra_model'): $target${NC}" >&2
                return 1
                ;;
        esac
        echo -e "${GREEN}✅ $(t 'switched_to') PPINFRA $target${NC}"
        echo "   BASE_URL: $ANTHROPIC_BASE_URL"
        echo "   MODEL: $ANTHROPIC_MODEL"
        echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
    else
        echo -e "${RED}❌ Please configure PPINFRA_API_KEY${NC}"
        return 1
    fi
}

# Save current Claude Pro account
save_account() {
    local account_name="$1"
    
    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ Please provide an account name${NC}" >&2
        echo "Usage: ccm save-account <account-name>" >&2
        return 1
    fi
    
    # Validate account name (alphanumeric, underscore, hyphen)
    if [[ ! "$account_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}❌ Account name can only contain letters, numbers, underscores, and hyphens${NC}" >&2
        return 1
    fi
    
    # Try to get token from keychain first
    local token=""
    local service="$KEYCHAIN_SERVICE"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Try Keychain
        token=$(security find-generic-password -s "$service" -a "claude-code" -w 2>/dev/null || true)
        
        if [[ -z "$token" ]]; then
            # Try alternative service names
            for alt_service in "Claude Code" "claude-code" "claude_code"; do
                token=$(security find-generic-password -s "$alt_service" -a "claude-code" -w 2>/dev/null || true)
                if [[ -n "$token" ]]; then
                    service="$alt_service"
                    break
                fi
            done
        fi
    fi
    
    if [[ -z "$token" ]]; then
        echo -e "${RED}❌ No Claude Code session found${NC}" >&2
        echo "Please make sure you're logged in to Claude Code in your browser or IDE" >&2
        return 1
    fi
    
    # Create accounts file if it doesn't exist
    mkdir -p "$(dirname "$ACCOUNTS_FILE")"
    touch "$ACCOUNTS_FILE"
    chmod 600 "$ACCOUNTS_FILE"
    
    # Read existing accounts
    local accounts_json=""
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        # Decode and read
        if command -v base64 >/dev/null 2>&1; then
            accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
        else
            accounts_json="{}"
        fi
    fi
    
    # Add or update account
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local account_entry="{\"token\":\"$(echo "$token" | base64 | tr -d '\n')\",\"service\":\"$service\",\"saved_at\":\"$timestamp\",\"type\":\"Pro\"}"
    
    # Simple JSON manipulation (add/update account)
    local temp_file=$(mktemp)
    echo "$accounts_json" | sed -E 's/}/,"'"$account_name"'":'"$account_entry"'}' | sed -E 's/,([^,]*$)/\1/' > "$temp_file"
    
    # Save back
    if command -v base64 >/dev/null 2>&1; then
        cat "$temp_file" | base64 > "$ACCOUNTS_FILE"
    else
        cp "$temp_file" "$ACCOUNTS_FILE"
    fi
    rm -f "$temp_file"
    chmod 600 "$ACCOUNTS_FILE"
    
    echo -e "${GREEN}✅ Account '$account_name' saved successfully${NC}"
}

# Switch to saved Claude Pro account
switch_account() {
    local account_name="$1"
    
    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ Please provide an account name${NC}" >&2
        echo "Usage: ccm switch-account <account-name>" >&2
        return 1
    fi
    
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ No saved accounts found${NC}" >&2
        echo "Use 'ccm save-account <name>' to save an account first" >&2
        return 1
    fi
    
    # Read accounts
    local accounts_json=""
    if command -v base64 >/dev/null 2>&1; then
        accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
    else
        accounts_json="{}"
    fi
    
    # Extract account info (simple JSON parsing)
    local account_info=$(echo "$accounts_json" | grep -o "\"$account_name\":[^}]*}" | sed "s/\"$account_name\"://" | sed 's/}//')
    
    if [[ -z "$account_info" ]]; then
        echo -e "${RED}❌ Account '$account_name' not found${NC}" >&2
        echo "Use 'ccm list-accounts' to see all saved accounts" >&2
        return 1
    fi
    
    # Extract token and service
    local token=$(echo "$account_info" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"$//' | base64 -d 2>/dev/null)
    local service=$(echo "$account_info" | grep -o '"service":"[^"]*"' | sed 's/"service":"//' | sed 's/"$//')
    
    if [[ -z "$token" || -z "$service" ]]; then
        echo -e "${RED}❌ Invalid account data for '$account_name'${NC}" >&2
        return 1
    fi
    
    # Save to keychain
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Delete existing password first
        security delete-generic-password -s "$service" -a "claude-code" 2>/dev/null || true
        
        # Add new password
        echo "$token" | security add-generic-password -s "$service" -a "claude-code" -w - 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Switched to account '$account_name'${NC}"
            echo -e "${YELLOW}Please restart Claude Code for the change to take effect${NC}"
        else
            echo -e "${RED}❌ Failed to save token to Keychain${NC}" >&2
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ Account switching only supports macOS Keychain${NC}" >&2
        echo "On other platforms, please manually log out and log in with the desired account" >&2
    fi
}

# List all saved accounts
list_accounts() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${YELLOW}No saved accounts found${NC}"
        return 0
    fi
    
    # Read accounts
    local accounts_json=""
    if command -v base64 >/dev/null 2>&1; then
        accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
    else
        accounts_json="{}"
    fi
    
    # Check if empty
    if [[ "$accounts_json" == "{}" ]]; then
        echo -e "${YELLOW}No saved accounts found${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📋 Saved Claude Pro accounts:${NC}"
    
    # Get current account
    local current_service=""
    local current_token=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        for svc in "$KEYCHAIN_SERVICE" "Claude Code" "claude-code" "claude_code"; do
            current_token=$(security find-generic-password -s "$svc" -a "claude-code" -w 2>/dev/null || true)
            if [[ -n "$current_token" ]]; then
                current_service="$svc"
                break
            fi
        done
    fi
    
    # Parse and display accounts
    echo "$accounts_json" | grep -o '"[^"]*":[^}]*}' | while read -r entry; do
        local name=$(echo "$entry" | grep -o '"[^"]*":' | sed 's/":$//' | sed 's/"//g')
        local saved_at=$(echo "$entry" | grep -o '"saved_at":"[^"]*"' | sed 's/"saved_at":"//' | sed 's/"$//' | sed 's/T.*//')
        local type=$(echo "$entry" | grep -o '"type":"[^"]*"' | sed 's/"type":"//' | sed 's/"$//')
        
        # Check if this is the current account
        local marker=""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local entry_service=$(echo "$entry" | grep -o '"service":"[^"]*"' | sed 's/"service":"//' | sed 's/"$//')
            local entry_token=$(echo "$entry" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"$//' | base64 -d 2>/dev/null)
            if [[ "$entry_service" == "$current_service" && "$entry_token" == "$current_token" ]]; then
                marker=" ✅ ${GREEN}(current)${NC}"
            fi
        fi
        
        echo "  - $name ($type, saved: $saved_at)$marker"
    done
}

# Delete saved account
delete_account() {
    local account_name="$1"
    
    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ Please provide an account name${NC}" >&2
        echo "Usage: ccm delete-account <account-name>" >&2
        return 1
    fi
    
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${RED}❌ No saved accounts found${NC}" >&2
        return 1
    fi
    
    # Read accounts
    local accounts_json=""
    if command -v base64 >/dev/null 2>&1; then
        accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
    else
        accounts_json="{}"
    fi
    
    # Check if account exists
    if ! echo "$accounts_json" | grep -q "\"$account_name\":"; then
        echo -e "${RED}❌ Account '$account_name' not found${NC}" >&2
        return 1
    fi
    
    # Remove account (simple JSON manipulation)
    local temp_file=$(mktemp)
    echo "$accounts_json" | sed -E "s/\"$account_name\":[^,}]*,?//" | sed -E 's/,([^,]*$)/\1/' | sed -E 's/{,/{/' | sed -E 's/,}/}/' > "$temp_file"
    
    # Save back
    if command -v base64 >/dev/null 2>&1; then
        cat "$temp_file" | base64 > "$ACCOUNTS_FILE"
    else
        cp "$temp_file" "$ACCOUNTS_FILE"
    fi
    rm -f "$temp_file"
    
    echo -e "${GREEN}✅ Account '$account_name' deleted${NC}"
}

# Get current account info
get_current_account() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}⚠️ Current account detection only supports macOS${NC}" >&2
        return 0
    fi
    
    # Try to find current token
    local current_service=""
    local current_token=""
    for svc in "$KEYCHAIN_SERVICE" "Claude Code" "claude-code" "claude_code"; do
        current_token=$(security find-generic-password -s "$svc" -a "claude-code" -w 2>/dev/null || true)
        if [[ -n "$current_token" ]]; then
            current_service="$svc"
            break
        fi
    done
    
    if [[ -z "$current_token" ]]; then
        echo -e "${YELLOW}No Claude Code session found${NC}"
        echo "Please make sure you're logged in to Claude Code" >&2
        return 0
    fi
    
    # Check if this matches any saved account
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        local accounts_json=""
        if command -v base64 >/dev/null 2>&1; then
            accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
        else
            accounts_json="{}"
        fi
        
        # Find matching account
        echo "$accounts_json" | grep -o '"[^"]*":[^}]*}' | while read -r entry; do
            local name=$(echo "$entry" | grep -o '"[^"]*":' | sed 's/":$//' | sed 's/"//g')
            local entry_service=$(echo "$entry" | grep -o '"service":"[^"]*"' | sed 's/"service":"//' | sed 's/"$//')
            local entry_token=$(echo "$entry" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"$//' | base64 -d 2>/dev/null)
            
            if [[ "$entry_service" == "$current_service" && "$entry_token" == "$current_token" ]]; then
                echo -e "${GREEN}✅ Current account: $name${NC}"
                echo "   Service: $entry_service"
                return 0
            fi
        done
    fi
    
    echo -e "${YELLOW}Current session found but not saved${NC}"
    echo "   Service: $current_service"
    echo "Use 'ccm save-account <name>' to save this account"
}

# Debug keychain credentials
debug_keychain_credentials() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}Keychain debugging only available on macOS${NC}" >&2
        return 0
    fi
    
    echo -e "${BLUE}🔍 Checking Keychain for Claude Code credentials...${NC}"
    
    # List all possible services
    local services=("$KEYCHAIN_SERVICE" "Claude Code" "claude-code" "claude_code")
    
    for service in "${services[@]}"; do
        echo -e "\n${YELLOW}Checking service: $service${NC}"
        local token=$(security find-generic-password -s "$service" -a "claude-code" -w 2>/dev/null || echo "Not found")
        if [[ "$token" != "Not found" ]]; then
            echo -e "${GREEN}✅ Found token (length: ${#token})${NC}"
            echo "   First 10 chars: ${token:0:10}..."
            
            # Check if matches any saved account
            if [[ -f "$ACCOUNTS_FILE" ]]; then
                local accounts_json=""
                if command -v base64 >/dev/null 2>&1; then
                    accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
                else
                    accounts_json="{}"
                fi
                
                echo "$accounts_json" | grep -o '"[^"]*":[^}]*}' | while read -r entry; do
                    local name=$(echo "$entry" | grep -o '"[^"]*":' | sed 's/":$//' | sed 's/"//g')
                    local entry_service=$(echo "$entry" | grep -o '"service":"[^"]*"' | sed 's/"service":"//' | sed 's/"$//')
                    local entry_token=$(echo "$entry" | grep -o '"token":"[^"]*"' | sed 's/"token":"//' | sed 's/"$//' | base64 -d 2>/dev/null)
                    
                    if [[ "$entry_service" == "$service" && "$entry_token" == "$token" ]]; then
                        echo -e "   ${GREEN}✅ Matches saved account: $name${NC}"
                        return 0
                    fi
                done
            fi
        else
            echo -e "${RED}❌ Token not found${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}💡 If tokens are found but not matching saved accounts, check:${NC}"
    echo "   1. Keychain service name (set CCM_KEYCHAIN_SERVICE if different)"
    echo "   2. Account file permissions: chmod 600 ~/.ccm_accounts"
    echo "   3. Whether the browser/IDE is properly logged in"
}

# Show current configuration
show_status() {
    echo -e "${BLUE}📊 Current model configuration:${NC}"
    echo ""
    
    # Load config to get current values
    load_config || return 1
    
    # Check environment
    if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
        echo -e "   BASE_URL: $ANTHROPIC_BASE_URL"
    else
        echo -e "   BASE_URL: ${YELLOW}[Using default]${NC}"
    fi
    
    if [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
        echo -e "   AUTH_TOKEN: $(mask_token "$ANTHROPIC_AUTH_TOKEN")"
    else
        echo -e "   AUTH_TOKEN: ${YELLOW}[Not Set]${NC}"
    fi
    
    if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
        echo -e "   MODEL: $ANTHROPIC_MODEL"
    else
        echo -e "   MODEL: ${YELLOW}[Not Set]${NC}"
    fi
    
    if [[ -n "${ANTHROPIC_SMALL_FAST_MODEL:-}" ]]; then
        echo -e "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
    else
        echo -e "   SMALL_MODEL: ${YELLOW}[Not Set]${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔑 API Keys (from environment or config):${NC}"
    
    # Check each API key
    local keys=(
        "DEEPSEEK_API_KEY:Deepseek"
        "GLM_API_KEY:GLM4.6"
        "KIMI_API_KEY:KIMI2"
        "LONGCAT_API_KEY:LongCat"
        "MINIMAX_API_KEY:MiniMax M2"
        "ARK_API_KEY:Doubao Seed-Code"
        "QWEN_API_KEY:Qwen"
        "CLAUDE_API_KEY:Claude"
        "PPINFRA_API_KEY:PPINFRA"
    )
    
    for key_info in "${keys[@]}"; do
        local key_var="${key_info%:*}"
        local key_name="${key_info#*:}"
        local key_value="${!key_var}"
        
        if is_effectively_set "$key_value"; then
            echo -e "   $key_name: $(mask_token "$key_value")"
        else
            echo -e "   $key_name: ${YELLOW}[Not Set]${NC}"
        fi
    done
    
    # Show current account if using Claude
    if [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" && -z "${CLAUDE_API_KEY:-}" ]]; then
        echo ""
        echo -e "${BLUE}👤 Account:${NC}"
        get_current_account
    fi
}

# Show help information
show_help() {
    echo -e "${BLUE}🔧 $(t 'switching_info') v2.3.0${NC}"
    echo ""
    echo -e "${YELLOW}$(t 'usage'):${NC} $(basename "$0") [options]"
    echo ""
    echo -e "${YELLOW}$(t 'model_options'):${NC}"
    echo "  deepseek, ds       - env deepseek"
    echo "  kimi, kimi2        - env kimi"
    echo "  kat                - env kat"
    echo "  longcat, lc        - env longcat"
    echo "  minimax, mm        - env minimax"
    echo "  seed, doubao       - env seed"
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
    echo "  config, cfg      - $(t 'edit_config_file')"
    echo "  help, -h         - $(t 'show_help')"
    echo "  env <model>      - $(t 'output_env_only')"
    echo ""
    echo -e "${YELLOW}PPINFRA Backup:${NC}"
    echo "  pp <model>       - Use PPINFRA backup service"
    echo ""
    echo -e "${YELLOW}$(t 'examples'):${NC}"
    echo "  ccm deepseek                  # Switch to Deepseek"
    echo "  ccm claude                    # Switch to Claude (using Pro account)"
    echo "  ccm opus:work                 # Switch to 'work' account and use Opus"
    echo "  ccm save-account personal     # Save current account as 'personal'"
    echo "  ccm pp glm                    # Use PPINFRA GLM backup"
    echo "  ccm status                    # Show current configuration"
    echo ""
    echo -e "${BLUE}$(t 'supported_models'):${NC}"
    echo "  🌙 KIMI2                - Official: kimi-k2-turbo-preview | Backup: PPINFRA"
    echo "  🤖 Deepseek            - Official: deepseek-chat | Backup: PPINFRA"
    echo "  🌊 StreamLake (KAT)    - Official: KAT-Coder"
    echo "  🐱 LongCat             - Official: LongCat-Flash-Thinking / LongCat-Flash-Chat"
    echo "  🎯 MiniMax M2          - Official: MiniMax-M2 | Backup: MiniMax-M2 (PPINFRA)"
    echo "  🌰 Doubao Seed-Code   - doubao-seed-code-preview-latest"
    echo "  🐪 Qwen                - Official: qwen3-max (Alibaba Cloud) | Backup: PPINFRA"
    echo "  🇨🇳 GLM4.6             - Official: glm-4.6 / glm-4.5-air"
    echo "  🧠 Claude Sonnet 4.5   - claude-sonnet-4-5-20250929"
    echo "  🚀 Claude Opus 4.1     - claude-opus-4-1-20250805"
    echo "  🔷 Claude Haiku 4.5    - claude-haiku-4-5"
}

# Edit configuration file
edit_config() {
    # Create config if it doesn't exist
    create_config_if_needed
    
    # Set proper permissions
    chmod 600 "$CONFIG_FILE"
    
    # Try different editors based on availability
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
                echo -e "${RED}❌ Please configure DEEPSEEK_API_KEY or PPINFRA_API_KEY${NC}" >&2
                echo -e "${YELLOW}$(t 'get_ppinfra_key'): https://ppio.com/user/register?invited_by=ZQRQZZ${NC}" >&2
                return 1
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
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local kimi_model="${KIMI_MODEL:-kimi-k2-turbo-preview}"
                local kimi_small="${KIMI_SMALL_FAST_MODEL:-kimi-k2-turbo-preview}"
                echo "export ANTHROPIC_MODEL='${kimi_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${kimi_small}'"
            else
                echo -e "${RED}❌ Please configure KIMI_API_KEY or PPINFRA_API_KEY${NC}" >&2
                echo -e "${YELLOW}$(t 'get_ppinfra_key'): https://ppio.com/user/register?invited_by=ZQRQZZ${NC}" >&2
                return 1
            fi
            ;;
        "glm"|"glm4"|"glm4.6")
            if is_effectively_set "$GLM_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.z.ai/api/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.z.ai/api/anthropic'"
                echo "if [ -z \"\${GLM_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${GLM_API_KEY}\""
                local glm_model="${GLM_MODEL:-glm-4.6}"
                local glm_small="${GLM_SMALL_FAST_MODEL:-glm-4.6}"
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
                echo -e "${RED}❌ Please configure GLM_API_KEY or PPINFRA_API_KEY${NC}" >&2
                echo -e "${YELLOW}Register: https://www.bigmodel.cn/claude-code?ic=5XMIOZPPXB${NC}" >&2
                echo -e "${YELLOW}Invitation code: 5XMIOZPPXB${NC}" >&2
                echo -e "${YELLOW}$(t 'get_ppinfra_key'): https://ppio.com/user/register?invited_by=ZQRQZZ${NC}" >&2
                return 1
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
                local longcat_model="${LONGCAT_MODEL:-LongCat-Flash-Thinking}"
                local longcat_small="${LONGCAT_SMALL_FAST_MODEL:-LongCat-Flash-Chat}"
                echo "export ANTHROPIC_MODEL='${longcat_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${longcat_small}'"
            else
                echo -e "${RED}❌ Please configure LONGCAT_API_KEY${NC}" 1>&2
                echo -e "${YELLOW}Get it from: https://www.longcat.ai${NC}" 1>&2
                return 1
            fi
            ;;
        "minimax"|"mm")
            if ! is_effectively_set "$MINIMAX_API_KEY"; then
                # Fallback: directly source config file once
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
            if is_effectively_set "$MINIMAX_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.minimax.io/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.minimax.io/anthropic'"
                echo "if [ -z \"\${MINIMAX_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${MINIMAX_API_KEY}\""
                local mm_model="${MINIMAX_MODEL:-MiniMax-M2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-MiniMax-M2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            elif is_effectively_set "$PPINFRA_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local mm_model="${MINIMAX_MODEL:-minimax/minimax-m2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-minimax/minimax-m2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            else
                echo -e "${RED}❌ Please configure MINIMAX_API_KEY or PPINFRA_API_KEY${NC}" 1>&2
                echo -e "${YELLOW}Get it from: https://www.minimaxi.com${NC}" 1>&2
                echo -e "${YELLOW}$(t 'get_ppinfra_key'): https://ppio.com/user/register?invited_by=ZQRQZZ${NC}" 1>&2
                return 1
            fi
            ;;
        "seed")
            if ! is_effectively_set "$ARK_API_KEY"; then
                # Fallback: directly source config file once
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
            if is_effectively_set "$ARK_API_KEY"; then
                echo "$prelude"
                echo "export API_TIMEOUT_MS='3000000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://ark.cn-beijing.volces.com/api/coding'"
                echo "export ANTHROPIC_API_URL='https://ark.cn-beijing.volces.com/api/coding'"
                echo "if [ -z \"\${ARK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${ARK_API_KEY}\""
                local seed_model="${SEED_MODEL:-doubao-seed-code-preview-latest}"
                local seed_small="${SEED_SMALL_FAST_MODEL:-doubao-seed-code-preview-latest}"
                echo "export ANTHROPIC_MODEL='${seed_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${seed_small}'"
            else
                echo "# ❌ Please configure ARK_API_KEY" 1>&2
                echo "# Get it from: https://console.volcengine.com/ark" 1>&2
                return 1
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
        "qwen")
            if ! is_effectively_set "$QWEN_API_KEY"; then
                # Fallback: directly source config file once
                if [ -f "$HOME/.ccm_config" ]; then . "$HOME/.ccm_config" >/dev/null 2>&1; fi
            fi
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
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local qwen_model="${QWEN_MODEL:-qwen3-next-80b-a3b-thinking}"
                local qwen_small="${QWEN_SMALL_FAST_MODEL:-qwen3-next-80b-a3b-thinking}"
                echo "export ANTHROPIC_MODEL='${qwen_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${qwen_small}'"
            else
                echo -e "${RED}❌ Please configure QWEN_API_KEY or PPINFRA_API_KEY${NC}" 1>&2
                echo -e "${YELLOW}Get it from: https://dashscope.aliyuncs.com${NC}" 1>&2
                echo -e "${YELLOW}$(t 'get_ppinfra_key'): https://ppio.com/user/register?invited_by=ZQRQZZ${NC}" 1>&2
                return 1
            fi
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|claude|opus|minimax|kat|seed]" 1>&2
            return 1
            ;;
    esac
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
        "SEED_MODEL=doubao-seed-code-preview-latest"
        "SEED_SMALL_FAST_MODEL=doubao-seed-code-preview-latest"
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
    # Create config if it doesn't exist
    create_config_if_needed
    
    # Set proper permissions
    chmod 600 "$CONFIG_FILE"
    
    # Ensure model override defaults are present
    ensure_model_override_defaults
    
    # Try different editors based on availability
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
        local model="${BASH_REMATCH[1]}"
        local account="${BASH_REMATCH[2]}"
        
        # Map model aliases
        case "$model" in
            "claude"|"sonnet"|"s") model="claude" ;;
            "opus"|"o") model="opus" ;;
            "haiku"|"h") model="haiku" ;;
        esac
        
        # Switch account first
        if ! switch_account "$account"; then
            return 1
        fi
        
        # Then switch model
        case "$model" in
            "claude") switch_to_claude ;;
            "opus") switch_to_opus ;;
            "haiku") switch_to_haiku ;;
        esac
        return $?
    fi

    # Check if it's account:model format (backward compatibility)
    if [[ "$cmd" =~ ^(.+):(claude|sonnet|opus|haiku|s|o|h)$ ]]; then
        local account="${BASH_REMATCH[1]}"
        local model="${BASH_REMATCH[2]}"
        
        # Map model aliases
        case "$model" in
            "claude"|"sonnet"|"s") model="claude" ;;
            "opus"|"o") model="opus" ;;
            "haiku"|"h") model="haiku" ;;
        esac
        
        # Switch account first
        if ! switch_account "$account"; then
            return 1
        fi
        
        # Then switch model
        case "$model" in
            "claude") switch_to_claude ;;
            "opus") switch_to_opus ;;
            "haiku") switch_to_haiku ;;
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
        "seed"|"doubao")
            emit_env_exports seed
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
            if [[ $# -lt 1 ]]; then
                echo -e "${RED}❌ Please specify a model for PPINFRA${NC}" >&2
                echo "Usage: $(basename "$0") pp <model>" >&2
                echo "Supported models: deepseek, kimi, glm, qwen, minimax" >&2
                return 1
            fi
            emit_env_exports "${1}_ppinfra"
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
            # Check if it's an account name (switch account without specifying model)
            if [[ -f "$ACCOUNTS_FILE" ]]; then
                local accounts_json=""
                if command -v base64 >/dev/null 2>&1; then
                    accounts_json=$(base64 -d "$ACCOUNTS_FILE" 2>/dev/null || echo "{}")
                fi
                
                # Check if this matches a saved account
                if echo "$accounts_json" | grep -q "\"$cmd\":"; then
                    switch_account "$cmd"
                    return $?
                fi
            fi
            
            # Not a valid command or account
            echo -e "${RED}❌ Unknown command: $cmd${NC}" >&2
            echo "Use '$(basename "$0") --help' for help" >&2
            return 1
            ;;
    esac
}

# If script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
