# Changelog

## [2.3.0] - 2025-10-30

### Changed
- 🌐 **Language support**: Removed Chinese language support and translated all documentation to English
  - Removed README_CN.md (Chinese documentation)
  - Translated lang/zh.json to English
  - Updated PPINFRA_USAGE.md to English
  - Translated TROUBLESHOOTING.md to English
  - Updated all Chinese comments in shell scripts to English
- 🔧 **GLM endpoint**: Updated GLM model to use global endpoint instead of China-specific endpoint
  - Changed from `https://api.z.ai/api/anthropic` to global configuration
  - Improved international accessibility for GLM models

## [2.2.0] - 2025-10-27

### Added - Claude Pro Account Management 🔐
- ✨ **Multiple Claude Pro account support**: Manage and switch between multiple Claude Pro subscription accounts
  - `ccm save-account <name>` - Save current logged-in account credentials
  - `ccm switch-account <name>` - Switch to a saved account without re-login
  - `ccm list-accounts` - List all saved accounts with status
  - `ccm delete-account <name>` - Delete saved account
  - `ccm current-account` - Show current account information
- 🚀 **Quick account switching**: `ccm opus:account` or `ccm haiku:account` syntax
  - Switch account and select model in one command
  - Works with `ccc` launcher: `ccc opus:work`
- 🔒 **Secure credential storage**: Primary storage in macOS Keychain with local backup
  - Local backup stored in `~/.ccm_accounts` (chmod 600) with base64 encoding
  - Automatic token refresh support
  - Persists across system reboots
  - Keychain service name configurable via `CCM_KEYCHAIN_SERVICE`
- 🌐 **Multi-language support**: Added 24 new translation keys for account management
  - English and Chinese translations
  - Seamless integration with existing i18n system

### Added
- 🔍 **Debug utilities**: `ccm debug-keychain` command for troubleshooting Keychain issues
- 🛠️ **Enhanced ccc launcher**: Support for account-only and model:account syntax
  - `ccc <account>` - Switch account and launch with default model
  - `ccc <model>:<account>` - Switch account and use specific model

### Changed
- 📚 Updated documentation:
  - Added comprehensive account management guide in README.md and README_CN.md
  - Updated help text (`ccm help`) with account commands
  - Added troubleshooting section for common issues
- 🔧 Enhanced Claude model functions:
  - `switch_to_claude()`, `switch_to_opus()`, `switch_to_haiku()` now support account parameter
  - Better error handling and user feedback
- 🎯 Improved installer: Updated to handle new account management commands

### Fixed
- 🔧 Fixed eval pattern issues with colored terminal output
- 🐛 Resolved account file permission handling
- ✨ Improved JSON parsing robustness for account storage

### Use Case
This update enables users to bypass Claude Pro usage limits by managing multiple Pro accounts, which is more cost-effective than upgrading to Claude Max. Each account has independent usage quotas (5 hours/day, weekly limits).

## [2.0.0] - 2025-10-01

### Added - Plan B Implementation
- ✨ **New `ccc` command**: One-command launcher that switches model and starts Claude Code
  - `ccc deepseek` - Switch to DeepSeek and launch
  - `ccc pp glm` - Switch to PPINFRA GLM and launch
  - Supports all Claude Code options (e.g., `--dangerously-skip-permissions`)
- 🔄 Enhanced `ccm` command: Improved environment management
  - Simplified `ccm pp` handling with unified eval logic
  - Better environment variable propagation
- 📦 Improved installer: Now installs both `ccm()` and `ccc()` functions

### Changed
- 🏗️ **Major refactor**: Consolidated all functionality into `ccm.sh` and `install.sh`
- 🎨 Improved user experience with two workflow options:
  - **Method 1**: `ccm` for environment management only
  - **Method 2**: `ccc` for one-command launch (recommended)
- 📝 Updated all documentation to reflect Plan B design
- 🧹 Cleaned up project structure (removed 16 obsolete files)

### Removed
- Deprecated scripts (functionality integrated into main scripts):
  - `ccm_pp_source.sh` - Integrated into `ccm.sh`
  - `claude-pp.sh` - Replaced by `ccc` function
  - `ccm_pp.sh` - No longer needed
- Obsolete test scripts (moved to backup)

### Fixed
- Fixed `ccm pp` command environment variable not taking effect
- Fixed GLM model version configuration (upgraded from 4.5 to 4.6)
- Fixed PPINFRA API endpoint (removed duplicate `/v1`)
- Fixed authentication conflicts (use only `ANTHROPIC_AUTH_TOKEN`)

---

## Usage Examples

### Quick Start with ccc (Recommended)

```bash
# Switch to DeepSeek and launch Claude Code in one command
ccc deepseek

# Use PPINFRA service
ccc pp glm

# With Claude Code options
ccc kimi --dangerously-skip-permissions
```

### Traditional ccm Workflow

```bash
# Switch environment
ccm pp deepseek

# Verify
ccm status

# Then launch Claude Code manually
claude
```

### Verify Configuration

```bash
# Check current settings
ccm status

# Should display:
# 📊 Current model configuration:
#    BASE_URL: https://api.ppinfra.com/anthropic
#    AUTH_TOKEN: [Set]
#    MODEL: deepseek/deepseek-v3.2-exp
```
