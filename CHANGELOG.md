# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-27

### Added
- 🎉 Initial release of Claude Code Model Switcher (CCM)
- 🤖 Multi-model support for Claude, Deepseek, KIMI, GLM, Qwen
- 🔄 Smart fallback mechanism with PPINFRA backup service
- ⚡ Quick model switching with one-click commands
- 🎨 Colorful command-line interface with clear status display
- 🛡️ Secure configuration file management (`~/.ccm_config`)
- 📊 Real-time status monitoring and key validation
- 🔧 Support for both official APIs and fallback services

### Features
- **KIMI2**: Official moonshot-v1-128k + PPINFRA moonshotai/kimi-k2-0905 fallback
- **Deepseek**: Official deepseek-chat + PPINFRA deepseek/deepseek-v3.1 fallback
- **Qwen**: Custom endpoint support + PPINFRA qwen3-next-80b-a3b-thinking fallback
- **GLM4.5**: Official glm-4-plus (official only)
- **Claude Sonnet 4**: Official claude-sonnet-4-20250514 (official only)
- **Claude Opus 4.1**: Official claude-opus-4-1-20250805 (official only)

### Commands
- `./ccm.sh kimi` - Switch to KIMI2
- `./ccm.sh deepseek` (or `ds`) - Switch to Deepseek
- `./ccm.sh qwen` - Switch to Qwen
- `./ccm.sh glm` - Switch to GLM4.5
- `./ccm.sh claude` (or `s`) - Switch to Claude Sonnet 4
- `./ccm.sh opus` (or `o`) - Switch to Claude Opus 4.1
- `./ccm.sh status` (or `st`) - Show current configuration
- `./ccm.sh config` - Edit configuration file
- `./ccm.sh help` - Show help information

### Configuration
- Automatic creation of `~/.ccm_config` on first run
- Support for multiple API keys per service
- Intelligent fallback when official keys are missing
- Editor auto-detection for configuration editing

### Documentation
- Comprehensive README in both English and Chinese
- Detailed usage examples and configuration guides
- Troubleshooting section with common issues
- MIT License for open source distribution

## [1.1.0] - 2025-09-25

### Changed
- 🔄 **Qwen Integration Update**: Migrated to Alibaba Cloud DashScope official endpoint
  - Updated base URL to `https://dashscope.aliyuncs.com/api/v2/apps/claude-code-proxy`
  - Changed default model from `qwen-max` to `qwen3-max`
  - Updated small model from `qwen-max` to `qwen3-next-80b-a3b-instruct`
  - Removed dependency on custom `QWEN_ANTHROPIC_BASE_URL` configuration
  - Simplified configuration using standard `sk-` prefixed API keys

### Updated
- 📝 Configuration templates now use latest Qwen model identifiers
- 🛠️ Help text updated to reflect new Qwen capabilities
- 🔧 Maintained backward compatibility with PPINFRA fallback service

### Security
- 🔒 Ensured no API keys are committed to repository
- 📋 Removed temporary documentation files containing sensitive information

## [Unreleased]

### Planned
- [ ] Add support for more AI models (Anthropic, Google Gemini, etc.)
- [ ] Configuration validation and health checks
- [ ] Interactive configuration setup wizard
- [ ] Batch operation support
- [ ] Custom model endpoint configuration
- [ ] Usage statistics and analytics
- [ ] Plugin system for extensibility
- [ ] Web interface for configuration management