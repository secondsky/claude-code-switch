# Changelog

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
- 修复 `ccm pp` 命令环境变量不生效的问题
- 修复 GLM 模型版本配置（从 4.5 升级到 4.6）
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
