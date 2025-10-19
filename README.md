# Claude Code Model Switcher (CCM) 🔧

> A powerful Claude Code model switching tool with support for multiple AI service providers and intelligent fallback mechanisms

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](https://github.com/foreveryh/claude-code-switch)

[中文文档](README_CN.md) | [English](README.md)

## 🚀 Quick Start (60 seconds)

### ⚡ One-Command Installation (Recommended)
The easiest way - no cloning needed:

```bash
# Step 1: Download and install
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
```

```bash
# Step 2: Reload your shell (choose one)
source ~/.zshrc  # for zsh users
# OR
source ~/.bashrc # for bash users
```

```bash
# Step 3: Verify installation and try it
ccm status                    # Check configuration
ccm deepseek                  # Switch to DeepSeek model
ccc deepseek                  # Launch Claude Code with DeepSeek (recommended)
```

**What happens:**
- ✅ Downloads ccm.sh from GitHub
- ✅ Installs to `~/.local/share/ccm/`
- ✅ Adds `ccm()` and `ccc()` functions to your shell rc
- ✅ Creates `~/.ccm_config` for API key storage

---

### Alternative: Clone & Install Locally
If you prefer to clone the repository (useful for development):

```bash
# Step 1: Clone the repository
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch

# Step 2: Make scripts executable and install
chmod +x install.sh ccm.sh
./install.sh

# Step 3: Reload shell
source ~/.zshrc  # or source ~/.bashrc for bash
```

**Without installation** (run from cloned directory):
```bash
# Try without modifying your shell
./ccc deepseek                              # Launch with DeepSeek (current process only)

# Or apply to current shell only
eval "$(./ccm env deepseek)"               # Set env vars in current shell only
./ccm status                                # View configuration
```

---

### Configuration

**Option A: Environment Variables** (Highest Priority)
```bash
export DEEPSEEK_API_KEY=sk-your-key
export KIMI_API_KEY=your-key
export QWEN_API_KEY=your-key
# Then use: ccm deepseek
```

**Option B: Configuration File** (Persistent)
```bash
ccm config                    # Opens config in your editor
# Or edit manually: vim ~/.ccm_config
```

---

### Using CCM (After Installation)

```bash
# Check current setup
ccm status

# Switch models in current terminal
ccm deepseek                              # Switch to DeepSeek
ccm kimi                                  # Switch to KIMI
ccm glm                                   # Switch to GLM
ccm pp qwen                              # Use PPINFRA Qwen

# Launch Claude Code with selected model
ccc deepseek                              # Recommended way
ccc pp kimi                               # PPINFRA version
ccc claude --dangerously-skip-permissions # Pass options to Claude Code
```

---

### Uninstall

```bash
# Run uninstall script
./uninstall.sh

# Or manually remove
rm -rf ~/.local/share/ccm
# Then remove ccm() and ccc() function blocks from ~/.zshrc or ~/.bashrc
```

**Note:** Installer adds `ccm()` and `ccc()` functions to your shell rc file. API keys in `~/.ccm_config` are masked for security (recommend `chmod 600 ~/.ccm_config`)

## 🎯 Quick Experience (30 seconds)

Want to try immediately **without any API key configuration**? No problem! CCM includes a built-in DeepSeek experience key for testing.

### Complete Flow - No Config Needed:

```bash
# 1. Install (one-liner)
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash

# 2. Reload shell
source ~/.zshrc

# 3. Try it immediately (no keys needed!)
ccm status                    # View configuration
ccc deepseek                  # Launch Claude Code with DeepSeek
```

✨ **That's it!** You now have a working Claude Code setup with model switching.

### Next Steps:
```bash
ccm config                    # Add your own API keys (optional)
ccm help                      # View all available models and commands
```

**What's Included:**
- ✅ Built-in DeepSeek 3.1 experience key (via PPINFRA)
- ✅ Works immediately without configuration
- ✅ Switch models: `ccm kimi`, `ccm glm`, `ccm qwen`, etc.
- ✅ Add your own API keys later for unlimited usage

## 🌟 Features

- 🤖 **Multi-model Support**: Claude, Deepseek, KIMI, GLM, Qwen and other mainstream AI models
- 🔄 **Smart Fallback Mechanism**: Official API priority with automatic fallback to PPINFRA backup service
- ⚡ **Quick Switching**: One-click switching between different AI models to boost productivity
- 🚀 **One-Command Launch**: `ccc` command switches model and launches Claude Code in a single step
- 🎨 **Colorful Interface**: Intuitive command-line interface with clear switching status display
- 🛡️ **Secure Configuration**: Independent configuration file for API key management, multi-editor support
- 📊 **Status Monitoring**: Real-time display of current model configuration and key status

## 📦 Supported Models

| Model | Official Support | Fallback Support(PPINFRA) | Features |
|-------|------------------|---------------------------|----------|
| 🌙 **KIMI2** | ✅ kimi-k2-turbo-preview | ✅ kimi-k2-turbo-preview | Long text processing |
| 🤖 **Deepseek** | ✅ deepseek-chat | ✅ deepseek/deepseek-v3.2-exp | Cost-effective reasoning |
| 🐱 **LongCat** | ✅ LongCat-Flash-Chat | ❌ Official only | High-speed chat |
| 🐪 **Qwen** | ✅ qwen3-max (Alibaba DashScope) | ✅ qwen3-next-80b-a3b-thinking | Alibaba Cloud official |
| 🇨🇳 **GLM4.6** | ✅ glm-4.6 | ✅ zai-org/glm-4.6 | Zhipu AI |
| 🧠 **Claude Sonnet 4.5** | ✅ claude-sonnet-4-5-20250929 | ❌ Official only | Balanced performance |
|| 🚀 **Claude Opus 4.1** | ✅ claude-opus-4-1-20250805 | ❌ Official only | Strongest reasoning |
|| 🔷 **Claude Haiku 4.5** | ✅ claude-haiku-4-5 | ❌ Official only | Fast and efficient |

> 🎁 **GLM-4.6 Official Registration**
>
> Get started with Zhipu AI's official Claude Code integration:
> - **Registration Link**: https://www.bigmodel.cn/claude-code?ic=5XMIOZPPXB
> - **Invitation Code**: `5XMIOZPPXB`
>
> GLM-4.6 supports official Claude Code integration with zero-configuration experience. No API key needed to get started!

> 💰 **PPINFRA Fallback Service Registration**
>
> Get **¥15 voucher** when registering PPINFRA service:
> - **Registration Link**: https://ppio.com/user/register?invited_by=ZQRQZZ
> - **Invitation Code**: `ZQRQZZ`
>
> PPINFRA provides reliable fallback service for Deepseek, KIMI, Qwen, and GLM models when official APIs are unavailable.

## 🚀 Quick Start

### 1. Download Script

```bash
# Clone the project
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch

# Or download script directly
wget https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/ccm.sh
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

### Two Ways to Use CCM

**Method 1: `ccm` - Environment Management Only**
```bash
# Switch models in your current terminal session
ccm deepseek      # Switch to DeepSeek
ccm glm           # Switch to GLM4.6
ccm pp kimi       # Switch to PPINFRA KIMI

# Then manually launch Claude Code
claude
```

**Method 2: `ccc` - One-Command Launch (Recommended)**
```bash
# Switch model and launch Claude Code in one step
ccc deepseek                            # Launch with DeepSeek
ccc pp glm                              # Launch with PPINFRA GLM
ccc kimi --dangerously-skip-permissions # Launch KIMI with options
```

### Basic Commands

```bash
# Switch to different models (ccm)
ccm kimi          # Switch to KIMI2
ccm deepseek      # Switch to Deepseek
ccm qwen          # Switch to Qwen
ccm glm           # Switch to GLM4.6
ccm longcat       # Switch to LongCat
ccm claude        # Switch to Claude Sonnet 4.5
ccm opus          # Switch to Claude Opus 4.1
ccm haiku         # Switch to Claude Haiku 4.5

# Switch to PPINFRA service
ccm pp            # Interactive PPINFRA model selection
ccm pp deepseek   # Direct switch to PPINFRA DeepSeek
ccm pp glm        # Direct switch to PPINFRA GLM
ccm pp kimi       # Direct switch to PPINFRA KIMI
ccm pp qwen       # Direct switch to PPINFRA Qwen

# Launch Claude Code with model switching (ccc)
ccc deepseek      # Switch to DeepSeek and launch
ccc pp glm        # Switch to PPINFRA GLM and launch
ccc opus          # Switch to Claude Opus and launch

# View current status (masked)
ccm status

# Edit configuration
ccm config

# Show help
ccm help
ccc              # Show ccc usage help
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
# ccm shortcuts
ccm ds           # Short for deepseek
ccm s            # Short for claude sonnet  
ccm o            # Short for opus
ccm h            # Short for haiku
ccm st           # Short for status

# ccc shortcuts
ccc ds           # Launch with DeepSeek
ccc pp ds        # Launch with PPINFRA DeepSeek
```

### Usage Examples

**Example 1: Using ccm (environment management only)**
```bash
# Switch to KIMI for long text processing
ccm kimi
ccm status
📊 Current model configuration:
   BASE_URL: https://api.moonshot.cn/anthropic
   AUTH_TOKEN: [Set]
   MODEL: kimi-k2-turbo-preview
   SMALL_MODEL: kimi-k2-turbo-preview

# Then manually launch Claude Code
claude
```

**Example 2: Using ccc (one-command launch - recommended)**
```bash
# Switch to DeepSeek and launch Claude Code immediately
ccc deepseek
🔄 Switching to deepseek...
✅ Environment configured for: DeepSeek

🚀 Launching Claude Code...
   Model: deepseek-chat
   Base URL: https://api.deepseek.com/anthropic

# Switch to PPINFRA GLM and launch with options
ccc pp glm --dangerously-skip-permissions
🔄 Switching to PPINFRA glm...
✅ Environment configured for: GLM (PPINFRA)

🚀 Launching Claude Code...
   Model: zai-org/glm-4.6
   Base URL: https://api.ppinfra.com/anthropic
```

**Example 3: Advanced workflows**
```bash
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

# Switch to PPINFRA service explicitly
ccm pp deepseek
ccm status
📊 Current model configuration:
   BASE_URL: https://api.ppinfra.com/anthropic
   AUTH_TOKEN: [Set]
   MODEL: deepseek/deepseek-v3.2-exp
   SMALL_MODEL: deepseek/deepseek-v3.2-exp
```

### Current Shell Activation (Recommended)

To apply model settings to your current shell session only, use the env subcommand which outputs export statements without printing secret values:

```bash
# Apply model environment to current shell
eval "$(ccm env deepseek)"
# Verify
ccm status
```

This approach is recommended for temporary use or testing, as it only affects the current shell session.

## 🛠️ Installation Methods

CCM supports multiple installation methods. Choose the one that works best for you.

### Method 1: Quick Install (Recommended) ⚡
One-command installation from GitHub - no cloning required:

```bash
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/quick-install.sh | bash
source ~/.zshrc  # reload shell
```

**Features:**
- ✅ No cloning needed
- ✅ Automatic file download from GitHub
- ✅ Retry mechanism for network failures
- ✅ File integrity verification
- ✅ Progress feedback
- ✅ Full error handling

### Method 2: Local Install
Clone the repository and install locally:

```bash
git clone https://github.com/foreveryh/claude-code-switch.git
cd claude-code-switch
chmod +x install.sh ccm.sh
./install.sh
source ~/.zshrc  # reload shell
```

### Method 3: Manual Installation
For advanced users who want to inspect the code first:

```bash
# Download the script directly
curl -fsSL https://raw.githubusercontent.com/foreveryh/claude-code-switch/main/ccm.sh -o ccm.sh
chmod +x ccm.sh

# Use without installation
./ccm deepseek
eval "$(./ccm env deepseek)"
```

### What Gets Installed?

The installation process:
- Copies `ccm.sh` to `~/.local/share/ccm/ccm.sh`
- Copies language files to `~/.local/share/ccm/lang/`
- Injects `ccm()` and `ccc()` shell functions into your rc file (~/.zshrc or ~/.bashrc)
- Creates `~/.ccm_config` on first use (if it doesn't exist)

**Does NOT:**
- Modify system files
- Change your PATH
- Require sudo/root access
- Affect other shell configurations

### Uninstall

To remove CCM from your system:

```bash
# If installed via quick-install.sh or install.sh
./uninstall.sh

# Or manually:
# 1. Remove the ccm/ccc function blocks from ~/.zshrc or ~/.bashrc
# 2. Delete the installation directory
rm -rf ~/.local/share/ccm
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
- Base URL: `https://api.ppinfra.com/anthropic`
- Supported models:
  - `kimi-k2-turbo-preview` (KIMI fallback)
  - `deepseek/deepseek-v3.2-exp` (Deepseek fallback)
  - `qwen3-next-80b-a3b-thinking` (Qwen fallback)
  - `zai-org/glm-4.6` (GLM fallback)

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
``bash
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
git clone https://github.com/foreveryh/claude-code-switch.git
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

📧 Questions or suggestions? Feel free to submit an [Issue](https://github.com/foreveryh/claude-code-switch/issues)
