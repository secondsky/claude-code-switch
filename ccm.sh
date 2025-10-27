#!/bin/bash
############################################################
# Claude Code Model Switcher (ccm) - 独立版本
# ---------------------------------------------------------
# 功能: 在不同AI模型之间快速切换
# 支持: Claude, Deepseek, GLM4.6, KIMI2
# 作者: Peng
# 版本: 2.2.0
############################################################

# 脚本颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="$HOME/.ccm_config"
ACCOUNTS_FILE="$HOME/.ccm_accounts"
# Keychain service name (override with CCM_KEYCHAIN_SERVICE)
KEYCHAIN_SERVICE="${CCM_KEYCHAIN_SERVICE:-Claude Code-credentials}"

# 多语言支持
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
LANG_DIR="$SCRIPT_DIR/lang"

# 加载翻译
load_translations() {
    local lang_code="${1:-en}"
    local lang_file="$LANG_DIR/${lang_code}.json"

    # 如果语言文件不存在，默认使用英语
    if [[ ! -f "$lang_file" ]]; then
        lang_code="en"
        lang_file="$LANG_DIR/en.json"
    fi

    # 如果英语文件也不存在，使用内置英文
    if [[ ! -f "$lang_file" ]]; then
        return 0
    fi

    # 清理现有翻译变量
    unset $(set | grep '^TRANS_' | LC_ALL=C cut -d= -f1) 2>/dev/null || true

    # 读取JSON文件并解析到变量
    if [[ -f "$lang_file" ]]; then
        local temp_file=$(mktemp)
        # 提取键值对到临时文件，使用更健壮的方法
        grep -o '"[^"]*":[[:space:]]*"[^"]*"' "$lang_file" | sed 's/^"\([^"]*\)":[[:space:]]*"\([^"]*\)"$/\1|\2/' > "$temp_file"

        # 读取临时文件并设置变量（使用TRANS_前缀）
        while IFS='|' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                # 处理转义字符
                value="${value//\\\"/\"}"
                value="${value//\\\\/\\}"
                # 使用eval设置动态变量名
                eval "TRANS_${key}=\"\$value\""
            fi
        done < "$temp_file"

        rm -f "$temp_file"
    fi
}

# 获取翻译文本
t() {
    local key="$1"
    local default="${2:-$key}"
    local var_name="TRANS_${key}"
    local value
    eval "value=\"\${${var_name}:-}\""
    echo "${value:-$default}"
}

# 检测系统语言
detect_language() {
    # 首先检查环境变量LANG
    local sys_lang="${LANG:-}"
    if [[ "$sys_lang" =~ ^zh ]]; then
        echo "zh"
    else
        echo "en"
    fi
}

# 智能加载配置：环境变量优先，配置文件补充
load_config() {
    # 初始化语言
    local lang_preference="${CCM_LANGUAGE:-$(detect_language)}"
    load_translations "$lang_preference"

    # 创建配置文件（如果不存在）
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# 语言设置 (en: English, zh: 中文)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM4.6 (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI2 (月之暗面)
KIMI_API_KEY=your-moonshot-api-key

# LongCat（美团）
LONGCAT_API_KEY=your-longcat-api-key

# MiniMax M2
MINIMAX_API_KEY=your-minimax-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# 备用提供商（仅当且仅当官方密钥未提供时启用）
PPINFRA_API_KEY=your-ppinfra-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
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
    
    # 首先读取语言设置
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_lang
        config_lang=$(grep -E "^[[:space:]]*CCM_LANGUAGE[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | head -1 | LC_ALL=C cut -d'=' -f2- | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [[ -n "$config_lang" && -z "$CCM_LANGUAGE" ]]; then
            export CCM_LANGUAGE="$config_lang"
            lang_preference="$config_lang"
            load_translations "$lang_preference"
        fi
    fi

    # 智能加载：只有环境变量未设置的键才从配置文件读取
    local temp_file=$(mktemp)
    local raw
    while IFS= read -r raw || [[ -n "$raw" ]]; do
        # 去掉回车、去掉行内注释并修剪两端空白
        raw=${raw%$'\r'}
        # 跳过注释和空行
        [[ "$raw" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$raw" ]] && continue
        # 删除行内注释（从第一个 # 起）
        local line="${raw%%#*}"
        # 去掉首尾空白
        line=$(echo "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [[ -z "$line" ]] && continue
        
        # 解析 export KEY=VALUE 或 KEY=VALUE
        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            local key="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            # 去掉首尾空白
            value=$(echo "$value" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
            # 仅当环境未设置、为空或为占位符时才应用
            local env_value="${!key}"
            local lower_env_value
            lower_env_value=$(printf '%s' "$env_value" | tr '[:upper:]' '[:lower:]')
            # 检查是否为占位符值
            local is_placeholder=false
            if [[ "$lower_env_value" == *"your"* && "$lower_env_value" == *"api"* && "$lower_env_value" == *"key"* ]]; then
                is_placeholder=true
            fi
            if [[ -n "$key" && ( -z "$env_value" || "$env_value" == "" || "$is_placeholder" == "true" ) ]]; then
                echo "export $key=$value" >> "$temp_file"
            fi
        fi
    done < "$CONFIG_FILE"
    
    # 执行临时文件中的export语句
    if [[ -s "$temp_file" ]]; then
        source "$temp_file"
    fi
    rm -f "$temp_file"
}

# 创建默认配置文件
create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# 语言设置 (en: English, zh: 中文)
CCM_LANGUAGE=en

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM4.6 (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI2 (月之暗面)
KIMI_API_KEY=your-moonshot-api-key

# LongCat（美团）
LONGCAT_API_KEY=your-longcat-api-key

# MiniMax M2
MINIMAX_API_KEY=your-minimax-api-key

# Qwen（阿里云 DashScope）
QWEN_API_KEY=your-qwen-api-key

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# 备用提供商（仅当且仅当官方密钥未提供时启用）
PPINFRA_API_KEY=your-ppinfra-api-key

# —— 可选：模型ID覆盖（不设置则使用下方默认）——
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

# 判断值是否为有效（非空且非占位符）
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

# 安全掩码工具
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
# Claude Pro 账号管理功能
# ============================================

# 从 macOS Keychain 读取 Claude Code 凭证
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

# 写入凭证到 macOS Keychain
write_keychain_credentials() {
    local credentials="$1"
    local username="$USER"

    # 先删除现有的凭证
    security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1

    # 添加新凭证
    security add-generic-password -a "$username" -s "$KEYCHAIN_SERVICE" -w "$credentials" >/dev/null 2>&1
    local result=$?

    if [[ $result -eq 0 ]]; then
        echo -e "${BLUE}🔑 凭证已写入 Keychain${NC}" >&2
    else
        echo -e "${RED}❌ 凭证写入 Keychain 失败 (错误码: $result)${NC}" >&2
    fi

    return $result
}

# 调试函数：验证 Keychain 中的凭证
debug_keychain_credentials() {
    echo -e "${BLUE}🔍 调试：检查 Keychain 中的凭证${NC}"

    local credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        echo -e "${RED}❌ Keychain 中没有凭证${NC}"
        return 1
    fi

    # 提取凭证信息
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token_preview=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4 | head -c 20)

    echo -e "${GREEN}✅ 找到凭证：${NC}"
    echo "   服务名: $KEYCHAIN_SERVICE"
    echo "   订阅类型: ${subscription:-Unknown}"
    if [[ -n "$expires" ]]; then
        local expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        echo "   过期时间: $expires_str"
    fi
    echo "   Token 预览: ${access_token_preview}..."

    # 尝试匹配保存的账号
    if [[ -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${BLUE}🔍 尝试匹配保存的账号...${NC}"
        while IFS=': ' read -r name encoded; do
            name=$(echo "$name" | tr -d '"')
            encoded=$(echo "$encoded" | tr -d '"')
            local saved_creds=$(echo "$encoded" | base64 -d 2>/dev/null)
            if [[ "$saved_creds" == "$credentials" ]]; then
                echo -e "${GREEN}✅ 匹配到账号: $name${NC}"
                return 0
            fi
        done < <(grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE")
        echo -e "${YELLOW}⚠️  没有匹配到任何保存的账号${NC}"
    fi
}

# 初始化账号配置文件
init_accounts_file() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo "{}" > "$ACCOUNTS_FILE"
        chmod 600 "$ACCOUNTS_FILE"
    fi
}

# 保存当前账号
save_account() {
    local account_name="$1"

    if [[ -z "$account_name" ]]; then
        echo -e "${RED}❌ $(t 'account_name_required')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'usage'): ccm save-account <name>${NC}" >&2
        return 1
    fi

    # 从 Keychain 读取当前凭证
    local credentials
    credentials=$(read_keychain_credentials)
    if [[ -z "$credentials" ]]; then
        echo -e "${RED}❌ $(t 'no_credentials_found')${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'please_login_first')${NC}" >&2
        return 1
    fi

    # 初始化账号文件
    init_accounts_file

    # 使用纯 Bash 解析和保存（不依赖 jq）
    local temp_file=$(mktemp)
    local existing_accounts=""

    if [[ -f "$ACCOUNTS_FILE" ]]; then
        existing_accounts=$(cat "$ACCOUNTS_FILE")
    fi

    # 简单的 JSON 更新：如果是空文件或只有 {}，直接写入
    if [[ "$existing_accounts" == "{}" || -z "$existing_accounts" ]]; then
        local encoded_creds=$(echo "$credentials" | base64)
        cat > "$ACCOUNTS_FILE" << EOF
{
  "$account_name": "$encoded_creds"
}
EOF
    else
        # 读取现有账号，添加新账号
        # 检查账号是否已存在
        if grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
            # 更新现有账号
            local encoded_creds=$(echo "$credentials" | base64)
            # 使用 sed 替换现有条目
            sed -i '' "s/\"$account_name\": *\"[^\"]*\"/\"$account_name\": \"$encoded_creds\"/" "$ACCOUNTS_FILE"
        else
            # 添加新账号
            local encoded_creds=$(echo "$credentials" | base64)
            # 移除最后的 } (使用 macOS 兼容的命令)
            sed '$d' "$ACCOUNTS_FILE" > "$temp_file"
            # 检查是否需要添加逗号
            if grep -q '"' "$temp_file"; then
                echo "," >> "$temp_file"
            fi
            echo "  \"$account_name\": \"$encoded_creds\"" >> "$temp_file"
            echo "}" >> "$temp_file"
            mv "$temp_file" "$ACCOUNTS_FILE"
        fi
    fi

    chmod 600 "$ACCOUNTS_FILE"

    # 提取订阅类型用于显示
    local subscription_type=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}✅ $(t 'account_saved'): $account_name${NC}"
    echo -e "   $(t 'subscription_type'): ${subscription_type:-Unknown}"

    rm -f "$temp_file"
}

# 切换到指定账号
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

    # 从文件中读取账号凭证
    local encoded_creds=$(grep -o "\"$account_name\": *\"[^\"]*\"" "$ACCOUNTS_FILE" | cut -d'"' -f4)

    if [[ -z "$encoded_creds" ]]; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        echo -e "${YELLOW}💡 $(t 'use_list_accounts')${NC}" >&2
        return 1
    fi

    # 解码凭证
    local credentials=$(echo "$encoded_creds" | base64 -d)

    # 写入 Keychain
    if write_keychain_credentials "$credentials"; then
        echo -e "${GREEN}✅ $(t 'account_switched'): $account_name${NC}"
        echo -e "${YELLOW}⚠️  $(t 'please_restart_claude_code')${NC}"
    else
        echo -e "${RED}❌ $(t 'failed_to_switch_account')${NC}" >&2
        return 1
    fi
}

# 列出所有已保存的账号
list_accounts() {
    if [[ ! -f "$ACCOUNTS_FILE" ]]; then
        echo -e "${YELLOW}$(t 'no_accounts_saved')${NC}"
        echo -e "${YELLOW}💡 $(t 'use_save_account')${NC}"
        return 0
    fi

    echo -e "${BLUE}📋 $(t 'saved_accounts'):${NC}"

    # 读取并解析账号列表
    local current_creds=$(read_keychain_credentials)

    grep --color=never -o '"[^"]*": *"[^"]*"' "$ACCOUNTS_FILE" | while IFS=': ' read -r name encoded; do
        # 清理引号
        name=$(echo "$name" | tr -d '"')
        encoded=$(echo "$encoded" | tr -d '"')

        # 解码并提取信息
        local creds=$(echo "$encoded" | base64 -d 2>/dev/null)
        local subscription=$(echo "$creds" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
        local expires=$(echo "$creds" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)

        # 检查是否是当前账号
        local is_current=""
        if [[ "$creds" == "$current_creds" ]]; then
            is_current=" ${GREEN}✅ ($(t 'active'))${NC}"
        fi

        # 格式化过期时间
        local expires_str=""
        if [[ -n "$expires" ]]; then
            expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
        fi

        echo -e "   - ${YELLOW}$name${NC} (${subscription:-Unknown}${expires_str:+, expires: $expires_str})$is_current"
    done
}

# 删除已保存的账号
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

    # 检查账号是否存在
    if ! grep -q "\"$account_name\":" "$ACCOUNTS_FILE"; then
        echo -e "${RED}❌ $(t 'account_not_found'): $account_name${NC}" >&2
        return 1
    fi

    # 删除账号（使用临时文件）
    local temp_file=$(mktemp)
    grep -v "\"$account_name\":" "$ACCOUNTS_FILE" > "$temp_file"

    # 清理可能的逗号问题
    sed -i '' 's/,\s*}/}/g' "$temp_file" 2>/dev/null || sed -i 's/,\s*}/}/g' "$temp_file"
    sed -i '' 's/}\s*,/}/g' "$temp_file" 2>/dev/null || sed -i 's/}\s*,/}/g' "$temp_file"

    mv "$temp_file" "$ACCOUNTS_FILE"
    chmod 600 "$ACCOUNTS_FILE"

    echo -e "${GREEN}✅ $(t 'account_deleted'): $account_name${NC}"
}

# 显示当前账号信息
get_current_account() {
    local credentials=$(read_keychain_credentials)

    if [[ -z "$credentials" ]]; then
        echo -e "${YELLOW}$(t 'no_current_account')${NC}"
        echo -e "${YELLOW}💡 $(t 'please_login_or_switch')${NC}"
        return 1
    fi

    # 提取信息
    local subscription=$(echo "$credentials" | grep -o '"subscriptionType":"[^"]*"' | cut -d'"' -f4)
    local expires=$(echo "$credentials" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
    local access_token=$(echo "$credentials" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)

    # 格式化过期时间
    local expires_str=""
    if [[ -n "$expires" ]]; then
        expires_str=$(date -r $((expires / 1000)) "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
    fi

    # 查找账号名称
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

# 显示当前状态（脱敏）
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

# 清理环境变量
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

# 切换到Deepseek
switch_to_deepseek() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Deepseek $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$DEEPSEEK_API_KEY"; then
        # 官方 Deepseek 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_API_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_API_KEY="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-chat"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek-coder"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="deepseek/deepseek-v3.2-exp"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.2-exp"
        echo -e "${GREEN}✅ $(t 'switched_to') Deepseek（$(t 'ppinfra_backup')）${NC}"
    else
        # 隐藏彩蛋：默认 DeepSeek 3.1 体验密钥（经过混淆处理）
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

# 切换到Claude Sonnet
switch_to_claude() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 切换到 Claude Sonnet 4.5...${NC}"

    # 如果指定了账号，先切换账号
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 切换到账号: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5-20250929}"
    export ANTHROPIC_SMALL_FAST_MODEL="${CLAUDE_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    echo -e "${GREEN}✅ 已切换到 Claude Sonnet 4.5 (使用 Claude Pro 订阅)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到Claude Opus
switch_to_opus() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Opus 4.1...${NC}"

    # 如果指定了账号，先切换账号
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 切换到账号: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${OPUS_MODEL:-claude-opus-4-1-20250805}"
    export ANTHROPIC_SMALL_FAST_MODEL="${OPUS_SMALL_FAST_MODEL:-claude-sonnet-4-5-20250929}"
    echo -e "${GREEN}✅ 已切换到 Claude Opus 4.1 (使用 Claude Pro 订阅)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到Claude Haiku
switch_to_haiku() {
    local account_name="$1"

    echo -e "${YELLOW}🔄 $(t 'switching_to') Claude Haiku 4.5...${NC}"

    # 如果指定了账号，先切换账号
    if [[ -n "$account_name" ]]; then
        echo -e "${BLUE}📝 切换到账号: $account_name${NC}"
        if ! switch_account "$account_name"; then
            return 1
        fi
    fi

    clean_env
    export ANTHROPIC_MODEL="${HAIKU_MODEL:-claude-haiku-4-5}"
    export ANTHROPIC_SMALL_FAST_MODEL="${HAIKU_SMALL_FAST_MODEL:-claude-haiku-4-5}"
    echo -e "${GREEN}✅ 已切换到 Claude Haiku 4.5 (使用 Claude Pro 订阅)${NC}"
    if [[ -n "$account_name" ]]; then
        echo "   $(t 'account'): $account_name"
    fi
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到GLM4.6
switch_to_glm() {
    echo -e "${YELLOW}🔄 切换到 GLM4.6 模型...${NC}"
    clean_env
    if is_effectively_set "$GLM_API_KEY"; then
        export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
        export ANTHROPIC_API_URL="https://open.bigmodel.cn/api/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$GLM_API_KEY"
        export ANTHROPIC_API_KEY="$GLM_API_KEY"
        export ANTHROPIC_MODEL="glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="glm-4.6"
        echo -e "${GREEN}✅ 已切换到 GLM4.6（官方）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA GLM 支持
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="zai-org/glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="zai-org/glm-4.6"
        echo -e "${GREEN}✅ 已切换到 GLM4.6（PPINFRA 备用）${NC}"
    else
        # 默认体验密钥
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="zai-org/glm-4.6"
        export ANTHROPIC_SMALL_FAST_MODEL="zai-org/glm-4.6"
        echo -e "${GREEN}✅ 已切换到 GLM4.6（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到KIMI2
switch_to_kimi() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') KIMI2 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$KIMI_API_KEY"; then
        # 官方 Moonshot KIMI 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_API_URL="https://api.moonshot.cn/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
        export ANTHROPIC_API_KEY="$KIMI_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="kimi-k2-turbo-preview"
        export ANTHROPIC_SMALL_FAST_MODEL="kimi-k2-turbo-preview"
        echo -e "${GREEN}✅ $(t 'switched_to') KIMI2（$(t 'ppinfra_backup')）${NC}"
    else
        # 默认体验密钥
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

# 切换到 MiniMax M2
switch_to_minimax() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') MiniMax M2 $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$MINIMAX_API_KEY"; then
        # 官方 MiniMax 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
        export ANTHROPIC_API_URL="https://api.minimax.io/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$MINIMAX_API_KEY"
        export ANTHROPIC_API_KEY="$MINIMAX_API_KEY"
        export ANTHROPIC_MODEL="MiniMax-M2"
        export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-M2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'official')）${NC}"
    elif is_effectively_set "$PPINFRA_API_KEY"; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_API_KEY="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="MiniMax-M2"
        export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-M2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'ppinfra_backup')）${NC}"
    else
        # 默认体验密钥
        local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_API_URL="https://api.ppinfra.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$hidden_key"
        export ANTHROPIC_API_KEY="$hidden_key"
        export ANTHROPIC_MODEL="MiniMax-M2"
        export ANTHROPIC_SMALL_FAST_MODEL="MiniMax-M2"
        echo -e "${GREEN}✅ $(t 'switched_to') MiniMax M2（$(t 'default_experience_key')）${NC}"
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到 Qwen（阿里云官方优先，缺省走 PPINFRA）
switch_to_qwen() {
    echo -e "${YELLOW}🔄 $(t 'switching_to') Qwen $(t 'model')...${NC}"
    clean_env
    if is_effectively_set "$QWEN_API_KEY"; then
        # 阿里云 DashScope 官方 Claude 代理端点
        export ANTHROPIC_BASE_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_API_URL="https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy"
        export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
        export ANTHROPIC_API_KEY="$QWEN_API_KEY"
        # 阿里云 DashScope 支持的模型
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
        # 默认体验密钥
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

# 切换到PPINFRA服务
switch_to_ppinfra() {
    local target="${1:-}"
    local no_color="${2:-false}"

    # 重新加载配置以确保使用最新的值
    load_config || return 1

    # 如果PPINFRA_API_KEY未配置，使用默认体验密钥
    local ppinfra_key="$PPINFRA_API_KEY"
    if ! is_effectively_set "$ppinfra_key"; then
        ppinfra_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
    fi

    # 如果没有指定目标模型，显示选择菜单
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

    # 清理旧环境变量（关键：避免认证冲突）
    echo "unset ANTHROPIC_BASE_URL ANTHROPIC_API_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL API_TIMEOUT_MS CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
    
    # 根据目标模型输出PPINFRA配置的export语句
    case "$target" in
        "deepseek"|"ds")
            # 输出信息到 stderr，避免干扰 eval
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
            echo "export ANTHROPIC_MODEL='MiniMax-M2'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='MiniMax-M2'"
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

# 显示帮助信息
show_help() {
    echo -e "${BLUE}🔧 $(t 'switching_info') v2.2.0${NC}"
    echo ""
    echo -e "${YELLOW}$(t 'usage'):${NC} $(basename "$0") [options]"
    echo ""
    echo -e "${YELLOW}$(t 'model_options'):${NC}"
    echo "  deepseek, ds       - env deepseek"
    echo "  kimi, kimi2        - env kimi"
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
    echo -e "${YELLOW}支持的模型:${NC}"
    echo "  🌙 KIMI2               - 官方：kimi-k2-turbo-preview"
    echo "  🤖 Deepseek            - 官方：deepseek-chat ｜ 备用：deepseek/deepseek-v3.1 (PPINFRA)"
    echo "  🐱 LongCat             - 官方：LongCat-Flash-Thinking / LongCat-Flash-Chat"
    echo "  🎯 MiniMax M2          - 官方：MiniMax-M2 ｜ 备用：MiniMax-M2 (PPINFRA)"
    echo "  🐪 Qwen                - 官方：qwen3-max (阿里云) ｜ 备用：qwen3-next-80b-a3b-thinking (PPINFRA)"
    echo "  🇨🇳 GLM4.6             - 官方：glm-4.6 / glm-4.5-air"
    echo "  🧠 Claude Sonnet 4.5   - claude-sonnet-4-5-20250929"
    echo "  🚀 Claude Opus 4.1     - claude-opus-4-1-20250805"
    echo "  🔷 Claude Haiku 4.5    - claude-haiku-4-5"
}

# 将缺失的模型ID覆盖项追加到配置文件（仅追加缺失项，不覆盖已存在的配置）
ensure_model_override_defaults() {
    local -a pairs=(
        "DEEPSEEK_MODEL=deepseek-chat"
        "DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat"
        "KIMI_MODEL=kimi-k2-turbo-preview"
        "KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview"
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

# 编辑配置文件
edit_config() {
    # 确保配置文件存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}📝 $(t 'config_created'): $CONFIG_FILE${NC}"
        create_default_config
    fi

    # 追加缺失的模型ID覆盖默认值（不触碰已有键）
    ensure_model_override_defaults

    echo -e "${BLUE}🔧 $(t 'opening_config_file')...${NC}"
    echo -e "${YELLOW}$(t 'config_file_path'): $CONFIG_FILE${NC}"
    
    # 按优先级尝试不同的编辑器
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

# 仅输出 export 语句的环境设置（用于 eval）
emit_env_exports() {
    local target="$1"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    # 通用前导：清理旧变量
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
                # 隐藏彩蛋：默认 DeepSeek 3.1 体验密钥，为了方便各位体验，但这个有RPM的限制，需要的话可以在 README.md 里找到 PPINFA 的注册入口
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
                # 默认体验密钥
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
                # 默认体验密钥
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
                # 默认体验密钥
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
            # 官方 Anthropic 默认网关，无需设置 BASE_URL
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
                # 兜底：直接 source 配置文件一次（修复某些行格式导致的加载失败）
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
                echo "if [ -z \"\${MINIMAX_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                local mm_model="${MINIMAX_MODEL:-MiniMax-M2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-MiniMax-M2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            else
                # 默认体验密钥
                local hidden_key="sk_BDdvx2bkOSQsUOZ-fKLCCooUlWf5-fgp1AtTnCPm1OI"
                echo "$prelude"
                echo "export API_TIMEOUT_MS='600000'"
                echo "export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC='1'"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_API_URL='https://api.ppinfra.com/anthropic'"
                echo "export ANTHROPIC_AUTH_TOKEN='${hidden_key}'"
                local mm_model="${MINIMAX_MODEL:-MiniMax-M2}"
                local mm_small="${MINIMAX_SMALL_FAST_MODEL:-MiniMax-M2}"
                echo "export ANTHROPIC_MODEL='${mm_model}'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='${mm_small}'"
            fi
            ;;
        *)
            echo "# $(t 'usage'): $(basename "$0") env [deepseek|kimi|qwen|glm|claude|opus|minimax]" 1>&2
            return 1
            ;;
    esac
}


# 主函数
main() {
    # 加载配置（环境变量优先）
    if ! load_config; then
        return 1
    fi

    # 处理参数
    local cmd="${1:-help}"

    # 检查是否是 model:account 格式
    if [[ "$cmd" =~ ^(claude|sonnet|opus|haiku|s|o|h):(.+)$ ]]; then
        local model_type="${BASH_REMATCH[1]}"
        local account_name="${BASH_REMATCH[2]}"

        # 先切换账号：将输出重定向到stderr，避免污染stdout（stdout仅用于export语句）
        switch_account "$account_name" 1>&2 || return 1

        # 然后仅输出对应模型的 export 语句，供调用方 eval
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
        # 账号管理命令
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
        # 模型切换命令
        "deepseek"|"ds")
            emit_env_exports deepseek
            ;;
        "kimi"|"kimi2")
            emit_env_exports kimi
            ;;
        "qwen")
            emit_env_exports qwen
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

# 执行主函数
main "$@"
