# Claude Code Model Switcher (CCM) 🔧

> A powerful Claude Code model switching tool with support for multiple AI service providers and intelligent fallback mechanisms

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](https://github.com/yourusername/claude-code-switch)

[中文文档](README_CN.md) | [English](README.md)

## 🚀 Quick Start (60 seconds)

- Install (adds ccm function to your shell rc)
```bash
chmod +x install.sh ccm.sh && ./install.sh
source ~/.zshrc  # reload current shell
```

- Configure (env > config)
```bash
# Option A: create/edit config file
ccm            # first run creates ~/.ccm_config
ccm config     # open it in your editor

# Option B: set environment variables (highest priority)
export DEEPSEEK_API_KEY=sk-...
```

- Use (after install)
```bash
ccm deepseek   # or: ccm ds / ccm kimi / ccm qwen / ccm glm / ccm claude / ccm opus
ccm status
```

- Uninstall
```bash
./uninstall.sh
```

Notes: installer adds a ccm() function into your ~/.zshrc (or ~/.bashrc). Secrets are masked in status. Recommend chmod 600 ~/.ccm_config

## 🌟 Features

- 🤖 **Multi-model Support**: Claude, Deepseek, KIMI, GLM, Qwen and other mainstream AI models
- 🔄 **Smart Fallback Mechanism**: Official API priority with automatic fallback to PPINFRA backup service
- ⚡ **Quick Switching**: One-click switching between different AI models to boost productivity
- 🎨 **Colorful Interface**: Intuitive command-line interface with clear switching status display
- 🛡️ **Secure Configuration**: Independent configuration file for API key management, multi-editor support
- 📊 **Status Monitoring**: Real-time display of current model configuration and key status

## 📦 Supported Models

| Model | Official Support | Fallback Support(PPINFRA) | Features |
|-------|------------------|---------------------------|----------|
| 🌙 **KIMI2** | ✅ kimi-k2-turbo-preview | ✅ kimi-k2-turbo-preview | Long text processing |
| 🤖 **Deepseek** | ✅ deepseek-chat | ✅ deepseek/deepseek-v3.1 | Cost-effective reasoning |
| 🐱 **LongCat** | ✅ LongCat-Flash-Chat | ❌ Official only | High-speed chat |
| 🐪 **Qwen** | ✅ qwen3-max (Alibaba DashScope) | ✅ qwen3-next-80b-a3b-thinking | Alibaba Cloud official |
| 🇨🇳 **GLM4.6** | ✅ glm-4.6 | ❌ Official only | Zhipu AI |
| 🧠 **Claude Sonnet 4.5** | ✅ claude-sonnet-4-5-20250929 | ❌ Official only | Balanced performance |
| 🚀 **Claude Opus 4.1** | ✅ claude-opus-4-1-20250805 | ❌ Official only | Strongest reasoning |

> 💰 **PPINFRA Fallback Service Registration**
>
> Get **¥15 voucher** when registering PPINFRA service:
> - **Registration Link**: https://ppio.com/user/register?invited_by=ZQRQZZ
> - **Invitation Code**: `ZQRQZZ`
>
> PPINFRA provides reliable fallback service for Deepseek, KIMI, and Qwen models when official APIs are unavailable.

## 🚀 Quick Start

### 1. Download Script

```bash
# Clone the project
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch

# Or download script directly
wget https://raw.githubusercontent.com/yourusername/claude-code-switch/main/ccm.sh
chmod +x ccm.sh
```

### 2. First Run

```bash
./ccm.sh
```

First run will automatically create configuration file `~/.ccm_config`. Please edit this file to add your API keys.

### 3. Configure API Keys

**🔑 Priority: Environment Variables > Configuration File**

CCM follows a smart configuration hierarchy:
1. **Environment variables** (highest priority) - `export DEEPSEEK_API_KEY=your-key`
2. **Configuration file** `~/.ccm_config` (fallback when env vars not set)

```bash
# Option 1: Set environment variables (recommended for security)
export DEEPSEEK_API_KEY=sk-your-deepseek-api-key
export KIMI_API_KEY=your-moonshot-api-key
export LONGCAT_API_KEY=your-longcat-api-key
export QWEN_API_KEY=sk-your-qwen-api-key
export PPINFRA_API_KEY=your-ppinfra-api-key

# Option 2: Edit configuration file
./ccm.sh config
# Or manually: vim ~/.ccm_config
```

Configuration file example:
```bash
# CCM Configuration File
# Note: Environment variables take priority over this file

# Official API keys
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
KIMI_API_KEY=your-moonshot-api-key
LONGCAT_API_KEY=your-longcat-api-key
GLM_API_KEY=your-glm-api-key
QWEN_API_KEY=your-qwen-api-key  # Alibaba Cloud DashScope

# Optional: override model IDs (if omitted, defaults are used)
DEEPSEEK_MODEL=deepseek-chat
DEEPSEEK_SMALL_FAST_MODEL=deepseek-chat
KIMI_MODEL=kimi-k2-turbo-preview
KIMI_SMALL_FAST_MODEL=kimi-k2-turbo-preview
LONGCAT_MODEL=LongCat-Flash-Thinking
LONGCAT_SMALL_FAST_MODEL=LongCat-Flash-Chat
QWEN_MODEL=qwen3-max
QWEN_SMALL_FAST_MODEL=qwen3-next-80b-a3b-instruct
GLM_MODEL=glm-4.6
GLM_SMALL_FAST_MODEL=glm-4.5-air
CLAUDE_MODEL=claude-sonnet-4-5-20250929
CLAUDE_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929
OPUS_MODEL=claude-opus-4-1-20250805
OPUS_SMALL_FAST_MODEL=claude-sonnet-4-5-20250929

# Fallback service (only enabled when official keys are missing)
PPINFRA_API_KEY=your-ppinfra-api-key
```

## 📖 Usage

### Basic Commands

```bash
# Switch to different models
ccm kimi          # Switch to KIMI2
ccm deepseek      # Switch to Deepseek  
ccm qwen          # Switch to Qwen
ccm glm           # Switch to GLM4.6
ccm longcat       # Switch to LongCat
ccm claude        # Switch to Claude Sonnet 4.5
ccm opus          # Switch to Claude Opus 4.1

# View current status (masked)
ccm status

# Edit configuration
ccm config

# Show help
ccm help
```

### Official keys are required (and model IDs are configurable)

To use a given model, you must provide an official API key either:
- as an environment variable in your shell session; or
- in `~/.ccm_config` (the installer created it on first run)

You may also override the default model IDs in `~/.ccm_config` using per-provider variables
(e.g., `DEEPSEEK_MODEL`, `KIMI_MODEL`, `LONGCAT_MODEL`, etc.). If omitted, sensible defaults are used.
Placeholders like `your-xxx-api-key` or empty values are treated as not configured.

### Command Shortcuts

```bash
ccm ds           # Short for deepseek
ccm s            # Short for claude sonnet  
ccm o            # Short for opus
ccm st           # Short for status
```

### Usage Examples

```bash
# Switch to KIMI for long text processing
ccm kimi
ccm status
📊 Current model configuration:
   BASE_URL: https://api.moonshot.cn/anthropic
   AUTH_TOKEN: [Set]
   MODEL: kimi-k2-turbo-preview
   SMALL_MODEL: kimi-k2-turbo-preview

# Switch to Deepseek for code generation
ccm ds
ccm status
📊 Current model configuration:
   BASE_URL: https://api.deepseek.com/anthropic   # or PPINFRA fallback if official key is missing
   AUTH_TOKEN: [Set]
   MODEL: deepseek-chat
   SMALL_MODEL: deepseek-chat

# Switch to Qwen using Alibaba Cloud DashScope
ccm qwen
ccm status
📊 Current model configuration:
   BASE_URL: https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy
   AUTH_TOKEN: [Set]
   MODEL: qwen3-max
   SMALL_MODEL: qwen3-next-80b-a3b-instruct
```

## 🛠️ Install (adds ccm function to rc)

CCM supports safe one-step installation without modifying your shell configuration files.

### One-step install
```bash
# From the project directory
chmod +x install.sh ccm.sh
./install.sh
```

- Writes a `ccm()` function block into your rc (zsh preferred, bash fallback)
- Does NOT copy binaries or modify PATH
- Idempotent: re-running install replaces the previous block

### Uninstall
```bash
./uninstall.sh
```


## 🔧 Advanced Configuration

### 🔑 Configuration Priority System

CCM uses a smart hierarchical configuration system:

1. **Environment Variables** (Highest Priority)
   - Set in your shell session: `export DEEPSEEK_API_KEY=your-key`
   - Recommended for temporary testing or CI/CD environments
   - Always takes precedence over configuration files

2. **Configuration File** `~/.ccm_config` (Fallback)
   - Persistent storage for API keys
   - Only used when corresponding environment variable is not set
   - Ideal for daily development use

**Example scenario:**
```bash
# Environment variable exists
export DEEPSEEK_API_KEY=env-key-123

# Config file contains
echo "DEEPSEEK_API_KEY=config-key-456" >> ~/.ccm_config

# CCM will use: env-key-123 (environment variable wins)
./ccm.sh status  # Shows DEEPSEEK_API_KEY: env-key-123
```

### Smart Fallback Mechanism

CCM implements intelligent fallback mechanism:
- **Official API Priority**: Uses official service if official keys are configured
- **Auto Fallback**: Automatically switches to PPINFRA backup service when official keys are not configured
- **Transparent Switching**: Seamless to users, commands remain consistent

### Security and Privacy
- Status output masks secrets (shows only first/last 4 chars)
- ccm sets only `ANTHROPIC_AUTH_TOKEN` (not `ANTHROPIC_API_KEY`), plus base URL and model variables
- Configuration file precedence: Environment Variables > ~/.ccm_config
- Recommended file permission: `chmod 600 ~/.ccm_config`

### Alibaba Cloud DashScope Integration

Qwen models are now officially integrated with Alibaba Cloud DashScope:
- **Base URL**: `https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy`
- **Default Models**: `qwen3-max` (primary), `qwen3-next-80b-a3b-instruct` (fast)
- **API Key Format**: Standard `sk-` prefix from Alibaba Cloud console
- **No Custom Configuration Required**: Automatic endpoint configuration

### PPINFRA Fallback Service

PPINFRA is a third-party AI model aggregation service providing:
- Base URL: `https://api.ppinfra.com/openai/v1/anthropic`
- Supported models:
  - `kimi-k2-turbo-preview` (KIMI fallback)
  - `deepseek/deepseek-v3.1` (Deepseek fallback)
  - `qwen3-next-80b-a3b-thinking` (Qwen fallback)

### Configuration File Details

`~/.ccm_config` file contains all API key configurations:

```bash
# Required: Official keys from various providers (at least one)
DEEPSEEK_API_KEY=sk-your-deepseek-key
KIMI_API_KEY=your-moonshot-api-key
GLM_API_KEY=your-glm-key
QWEN_API_KEY=your-qwen-key


# Optional but recommended: Fallback service key
PPINFRA_API_KEY=your-ppinfra-key

# Claude (if using API instead of Pro subscription)
CLAUDE_API_KEY=your-claude-key
```

## 🐛 Troubleshooting

### Common Issues

**Q: Getting "XXX_API_KEY not detected" error**
```bash
A: Check if the corresponding API key is correctly configured in ~/.ccm_config
   ./ccm.sh config  # Open config file to check
```

**Q: Claude Code doesn't work after switching**
```bash
A: Confirm environment variables are set correctly:
   ccm status  # Check current configuration status
   echo $ANTHROPIC_BASE_URL  # Check environment variable
```

**Q: Want to force using official service instead of fallback**
```bash
A: Configure the corresponding official API key, script will automatically prioritize official service
```

### Debug Mode

```bash
# Show detailed status information
ccm status

# Check configuration file
cat ~/.ccm_config

# Verify environment variables
env | grep ANTHROPIC

# If you see an auth conflict about API_KEY vs AUTH_TOKEN
unset ANTHROPIC_API_KEY   # ccm only sets ANTHROPIC_AUTH_TOKEN
```

## 🤝 Contributing

Issues and Pull Requests are welcome!

### Development Setup
```bash
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch
```

### Commit Guidelines
- Use clear commit messages
- Add appropriate tests
- Update documentation

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- [Claude](https://claude.ai) - AI Assistant
- [Deepseek](https://deepseek.com) - Efficient reasoning model
- [KIMI](https://kimi.moonshot.cn) - Long text processing
- [Zhipu AI](https://zhipuai.cn) - GLM large model
- [Qwen](https://qwen.alibaba.com) - Alibaba Tongyi Qianwen

---

⭐ If this project helps you, please give it a Star!

📧 Questions or suggestions? Feel free to submit an [Issue](https://github.com/yourusername/claude-code-switch/issues)
