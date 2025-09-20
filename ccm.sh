#!/bin/bash
############################################################
# Claude Code Model Switcher (ccm) - 独立版本
# ---------------------------------------------------------
# 功能: 在不同AI模型之间快速切换
# 支持: Claude, Deepseek, GLM4.5, KIMI2
# 作者: Peng
# 版本: 2.0.0
############################################################

# 脚本颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="$HOME/.ccm_config"

# 智能加载配置：环境变量优先，配置文件补充
load_config() {
    # 创建配置文件（如果不存在）
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# CCM 配置文件
# 请替换为你的实际API密钥
# 注意：环境变量中的API密钥优先级高于此文件

# Deepseek
DEEPSEEK_API_KEY=sk-your-deepseek-api-key

# GLM4.5 (智谱清言)
GLM_API_KEY=your-glm-api-key

# KIMI2 (月之暗面)
KIMI_API_KEY=your-kimi-api-key

# Qwen（如使用官方 Anthropic 兼容网关）
QWEN_API_KEY=your-qwen-api-key
# 可选：如果使用官方 Qwen 的 Anthropic 兼容端点，请在此填写
QWEN_ANTHROPIC_BASE_URL=

# Claude (如果使用API key而非Pro订阅)
CLAUDE_API_KEY=your-claude-api-key

# 备用提供商（仅当且仅当官方密钥未提供时启用）
PPINFRA_API_KEY=your-ppinfra-api-key  # https://api.ppinfra.com/openai/v1/anthropic
EOF
        echo -e "${YELLOW}⚠️  配置文件已创建: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}   请编辑此文件添加你的API密钥${NC}"
        return 1
    fi
    
    # 智能加载：只有环境变量未设置的键才从配置文件读取
    local temp_file=$(mktemp)
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # 移除前导空格
        key=$(echo "$key" | sed 's/^[[:space:]]*//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//')
        
        # 只在环境变量未设置时才设置
        if [[ -n "$key" && -z "${!key}" ]]; then
            echo "export $key='$value'" >> "$temp_file"
        fi
    done < "$CONFIG_FILE"
    
    # 执行临时文件中的export语句
    if [[ -s "$temp_file" ]]; then
        source "$temp_file"
    fi
    rm -f "$temp_file"
}

# 安全掩码工具
mask_token() {
    local t="$1"
    local n=${#t}
    if [[ -z "$t" ]]; then
        echo "[未设置]"
        return
    fi
    if (( n <= 8 )); then
        echo "[已设置] ****"
    else
        echo "[已设置] ${t:0:4}...${t:n-4:4}"
    fi
}

mask_presence() {
    local v_name="$1"
    local v_val="${!v_name}"
    if [[ -n "$v_val" ]]; then
        echo "[已设置]"
    else
        echo "[未设置]"
    fi
}

# 显示当前状态（脱敏）
show_status() {
    echo -e "${BLUE}📊 当前模型配置:${NC}"
    echo "   BASE_URL: ${ANTHROPIC_BASE_URL:-'默认 (Anthropic)'}"
    echo -n "   AUTH_TOKEN: "
    mask_token "${ANTHROPIC_AUTH_TOKEN}"
    echo "   MODEL: ${ANTHROPIC_MODEL:-'未设置'}"
    echo "   SMALL_MODEL: ${ANTHROPIC_SMALL_FAST_MODEL:-'未设置'}"
    echo ""
    echo -e "${BLUE}🔧 环境变量状态:${NC}"
    echo "   GLM_API_KEY: $(mask_presence GLM_API_KEY)"
    echo "   KIMI_API_KEY: $(mask_presence KIMI_API_KEY)"
    echo "   DEEPSEEK_API_KEY: $(mask_presence DEEPSEEK_API_KEY)"
    echo "   QWEN_API_KEY: $(mask_presence QWEN_API_KEY)"
    echo "   PPINFRA_API_KEY: $(mask_presence PPINFRA_API_KEY)"
}

# 清理环境变量
clean_env() {
    unset ANTHROPIC_BASE_URL
    unset ANTHROPIC_AUTH_TOKEN
    unset ANTHROPIC_MODEL
    unset ANTHROPIC_SMALL_FAST_MODEL
}

# 切换到Deepseek
switch_to_deepseek() {
    echo -e "${YELLOW}🔄 切换到 Deepseek 模型...${NC}"
    clean_env
    if [[ -n "$DEEPSEEK_API_KEY" ]]; then
        # 官方 Deepseek 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
        export ANTHROPIC_MODEL="deepseek-chat"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek-coder"
        echo -e "${GREEN}✅ 已切换到 Deepseek（官方）${NC}"
    elif [[ -n "$PPINFRA_API_KEY" ]]; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="deepseek/deepseek-v3.1"
        export ANTHROPIC_SMALL_FAST_MODEL="deepseek/deepseek-v3.1"
        echo -e "${GREEN}✅ 已切换到 Deepseek（PPINFRA 备用）${NC}"
    else
        echo -e "${RED}❌ 未检测到 DEEPSEEK_API_KEY，且 PPINFRA_API_KEY 未配置，无法切换${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
}

# 切换到Claude Sonnet
switch_to_claude() {
    echo -e "${YELLOW}🔄 切换到 Claude Sonnet 4...${NC}"
    clean_env
    export ANTHROPIC_MODEL="claude-sonnet-4-20250514"
    export ANTHROPIC_SMALL_FAST_MODEL="claude-sonnet-4-20250514"
    echo -e "${GREEN}✅ 已切换到 Claude Sonnet 4 (使用 Claude Pro 订阅)${NC}"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到Claude Opus
switch_to_opus() {
    echo -e "${YELLOW}🔄 切换到 Claude Opus 4.1...${NC}"
    clean_env
    export ANTHROPIC_MODEL="claude-opus-4-1-20250805"
    export ANTHROPIC_SMALL_FAST_MODEL="claude-sonnet-4-20250514"
    echo -e "${GREEN}✅ 已切换到 Claude Opus 4.1 (使用 Claude Pro 订阅)${NC}"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到GLM4.5
switch_to_glm() {
    echo -e "${YELLOW}🔄 切换到 GLM4.5 模型...${NC}"
    clean_env
    if [[ -n "$GLM_API_KEY" ]]; then
        export ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/paas/v4/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$GLM_API_KEY"
        export ANTHROPIC_MODEL="glm-4-plus"
        export ANTHROPIC_SMALL_FAST_MODEL="glm-4-flash"
        echo -e "${GREEN}✅ 已切换到 GLM4.5（官方）${NC}"
    else
        echo -e "${RED}❌ 未检测到 GLM_API_KEY。按要求，GLM 不走 PPINFRA 备用，请配置官方密钥${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到KIMI2
switch_to_kimi() {
    echo -e "${YELLOW}🔄 切换到 KIMI2 模型...${NC}"
    clean_env
    if [[ -n "$KIMI_API_KEY" ]]; then
        # 官方 Moonshot KIMI 的 Anthropic 兼容端点
        export ANTHROPIC_BASE_URL="https://api.moonshot.cn/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$KIMI_API_KEY"
        export ANTHROPIC_MODEL="moonshot-v1-128k"
        export ANTHROPIC_SMALL_FAST_MODEL="moonshot-v1-8k"
        echo -e "${GREEN}✅ 已切换到 KIMI2（官方）${NC}"
    elif [[ -n "$PPINFRA_API_KEY" ]]; then
        # 备用：PPINFRA Anthropic 兼容
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="moonshotai/kimi-k2-0905"
        export ANTHROPIC_SMALL_FAST_MODEL="moonshotai/kimi-k2-0905"
        echo -e "${GREEN}✅ 已切换到 KIMI2（PPINFRA 备用）${NC}"
    else
        echo -e "${RED}❌ 未检测到 KIMI_API_KEY，且 PPINFRA_API_KEY 未配置，无法切换${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 切换到 Qwen（官方优先，缺省走 PPINFRA）
switch_to_qwen() {
    echo -e "${YELLOW}🔄 切换到 Qwen 模型...${NC}"
    clean_env
    if [[ -n "$QWEN_API_KEY" && -n "$QWEN_ANTHROPIC_BASE_URL" ]]; then
        export ANTHROPIC_BASE_URL="$QWEN_ANTHROPIC_BASE_URL"
        export ANTHROPIC_AUTH_TOKEN="$QWEN_API_KEY"
        # 若你有官方 Qwen 的具体模型ID，可在此设置；默认启用思考模型占位
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ 已切换到 Qwen（官方配置）${NC}"
    elif [[ -n "$PPINFRA_API_KEY" ]]; then
        export ANTHROPIC_BASE_URL="https://api.ppinfra.com/openai/v1/anthropic"
        export ANTHROPIC_AUTH_TOKEN="$PPINFRA_API_KEY"
        export ANTHROPIC_MODEL="qwen3-next-80b-a3b-thinking"
        export ANTHROPIC_SMALL_FAST_MODEL="qwen3-next-80b-a3b-thinking"
        echo -e "${GREEN}✅ 已切换到 Qwen（PPINFRA 备用）${NC}"
    else
        echo -e "${RED}❌ 未检测到 QWEN_API_KEY 或 PPINFRA_API_KEY，无法切换${NC}"
        return 1
    fi
    echo "   BASE_URL: $ANTHROPIC_BASE_URL"
    echo "   MODEL: $ANTHROPIC_MODEL"
    echo "   SMALL_MODEL: $ANTHROPIC_SMALL_FAST_MODEL"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}🔧 Claude Code 模型切换工具 v2.1.0${NC}"
    echo ""
    echo -e "${YELLOW}用法:${NC} $(basename "$0") [选项]"
    echo ""
    echo -e "${YELLOW}模型选项:${NC}"
    echo "  deepseek, ds       - 切换到 Deepseek 模型（官方优先，缺省走 PPINFRA 备用）"
    echo "  kimi, kimi2        - 切换到 KIMI2 模型（官方优先，缺省走 PPINFRA 备用）"
    echo "  qwen               - 切换到 Qwen（官方优先，缺省走 PPINFRA 备用）"
    echo "  glm, glm4          - 切换到 GLM4.5 模型（仅官方）"
    echo "  claude, sonnet, s  - 切换到 Claude Sonnet 4"
    echo "  opus, o            - 切换到 Claude Opus 4.1"
    echo ""
    echo -e "${YELLOW}工具选项:${NC}"
    echo "  status, st       - 显示当前配置（脱敏显示）"
    echo "  env [模型]       - 仅输出 export 语句（用于 eval），不打印密钥明文"
    echo "  config, cfg      - 编辑配置文件"
    echo "  help, h          - 显示此帮助信息"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $(basename "$0") deepseek          # 切换到 Deepseek 并立即生效（当前进程）"
    echo "  eval \"$($(basename "$0") env deepseek)\"  # 在当前 shell 中生效（推荐）"
    echo "  $(basename "$0") glm               # 切换到 GLM4.5"
    echo "  $(basename "$0") status            # 查看当前状态（脱敏）"
    echo ""
    echo -e "${YELLOW}支持的模型:${NC}"
    echo "  🌙 KIMI2               - 官方：moonshot-v1-128k ｜ 备用：moonshotai/kimi-k2-0905 (PPINFRA)"
    echo "  🤖 Deepseek            - 官方：deepseek-chat ｜ 备用：deepseek/deepseek-v3.1 (PPINFRA)"
    echo "  🐪 Qwen                - 备用：qwen3-next-80b-a3b-thinking (PPINFRA)"
    echo "  🇨🇳 GLM4.5             - 官方：glm-4-plus / glm-4-flash"
    echo "  🧠 Claude Sonnet 4     - claude-sonnet-4-20250514"
    echo "  🚀 Claude Opus 4.1     - claude-opus-4-1-20250805"
}

# 编辑配置文件
edit_config() {
    if command -v code >/dev/null 2>&1; then
        code "$CONFIG_FILE"
    elif command -v vim >/dev/null 2>&1; then
        vim "$CONFIG_FILE"
    elif command -v nano >/dev/null 2>&1; then
        nano "$CONFIG_FILE"
    else
        echo -e "${YELLOW}请手动编辑配置文件: $CONFIG_FILE${NC}"
        echo -e "${YELLOW}或使用: open $CONFIG_FILE${NC}"
    fi
}

# 仅输出 export 语句的环境设置（用于 eval）
emit_env_exports() {
    local target="$1"
    # 加载配置以便进行存在性判断（环境变量优先，不打印密钥）
    load_config || return 1

    # 通用前导：清理旧变量
    local prelude="unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL"

    case "$target" in
        "deepseek"|"ds")
            if [[ -n "$DEEPSEEK_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'"
                echo "# 如果环境变量中未设置，将从 ~/.ccm_config 读取"
                echo "if [ -z \"\${DEEPSEEK_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${DEEPSEEK_API_KEY}\""
                echo "export ANTHROPIC_MODEL='deepseek-chat'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='deepseek-coder'"
            elif [[ -n "$PPINFRA_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                echo "export ANTHROPIC_MODEL='deepseek/deepseek-v3.1'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='deepseek/deepseek-v3.1'"
            else
                echo "# ❌ 未检测到 DEEPSEEK_API_KEY 或 PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "kimi"|"kimi2")
            if [[ -n "$KIMI_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.moonshot.cn/v1/anthropic'"
                echo "if [ -z \"\${KIMI_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${KIMI_API_KEY}\""
                echo "export ANTHROPIC_MODEL='moonshot-v1-128k'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='moonshot-v1-8k'"
            elif [[ -n "$PPINFRA_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                echo "export ANTHROPIC_MODEL='moonshotai/kimi-k2-0905'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='moonshotai/kimi-k2-0905'"
            else
                echo "# ❌ 未检测到 KIMI_API_KEY 或 PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "qwen")
            if [[ -n "$QWEN_API_KEY" && -n "$QWEN_ANTHROPIC_BASE_URL" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='${QWEN_ANTHROPIC_BASE_URL}'"
                echo "if [ -z \"\${QWEN_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${QWEN_API_KEY}\""
                echo "export ANTHROPIC_MODEL='qwen3-next-80b-a3b-thinking'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='qwen3-next-80b-a3b-thinking'"
            elif [[ -n "$PPINFRA_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://api.ppinfra.com/openai/v1/anthropic'"
                echo "if [ -z \"\${PPINFRA_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${PPINFRA_API_KEY}\""
                echo "export ANTHROPIC_MODEL='qwen3-next-80b-a3b-thinking'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='qwen3-next-80b-a3b-thinking'"
            else
                echo "# ❌ 未检测到 QWEN_API_KEY / QWEN_ANTHROPIC_BASE_URL 或 PPINFRA_API_KEY" 1>&2
                return 1
            fi
            ;;
        "glm"|"glm4"|"glm4.5")
            if [[ -n "$GLM_API_KEY" ]]; then
                echo "$prelude"
                echo "export ANTHROPIC_BASE_URL='https://open.bigmodel.cn/api/paas/v4/anthropic'"
                echo "if [ -z \"\${GLM_API_KEY}\" ] && [ -f \"\$HOME/.ccm_config\" ]; then . \"\$HOME/.ccm_config\" >/dev/null 2>&1; fi"
                echo "export ANTHROPIC_AUTH_TOKEN=\"\${GLM_API_KEY}\""
                echo "export ANTHROPIC_MODEL='glm-4-plus'"
                echo "export ANTHROPIC_SMALL_FAST_MODEL='glm-4-flash'"
            else
                echo "# ❌ GLM 仅支持官方密钥，请设置 GLM_API_KEY" 1>&2
                return 1
            fi
            ;;
        "claude"|"sonnet"|"s")
            echo "$prelude"
            # 官方 Anthropic 默认网关，无需设置 BASE_URL
            echo "unset ANTHROPIC_BASE_URL"
            echo "export ANTHROPIC_MODEL='claude-sonnet-4-20250514'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='claude-sonnet-4-20250514'"
            ;;
        "opus"|"o")
            echo "$prelude"
            echo "unset ANTHROPIC_BASE_URL"
            echo "export ANTHROPIC_MODEL='claude-opus-4-1-20250805'"
            echo "export ANTHROPIC_SMALL_FAST_MODEL='claude-sonnet-4-20250514'"
            ;;
        *)
            echo "# 用法: $(basename "$0") env [deepseek|kimi|qwen|glm|claude|opus]" 1>&2
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
    case "${1:-help}" in
        "deepseek"|"ds")
            switch_to_deepseek
            ;;
        "kimi"|"kimi2")
            switch_to_kimi
            ;;
        "qwen")
            switch_to_qwen
            ;;
        "glm"|"glm4"|"glm4.5")
            switch_to_glm
            ;;
        "claude"|"sonnet"|"s")
            switch_to_claude
            ;;
        "opus"|"o")
            switch_to_opus
            ;;
        "env")
            shift
            emit_env_exports "${1:-}"
            ;;
        "status"|"st")
            show_status
            ;;
        "config"|"cfg")
            edit_config
            ;;
        "help"|"h"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"
