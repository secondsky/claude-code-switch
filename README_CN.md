# Claude Code Model Switcher (CCM) 🔧

> 一个强大的Claude Code模型切换工具，支持多家AI服务商的快速切换，包含智能备用机制

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg)](https://github.com/yourusername/claude-code-switch)

## 🚀 一分钟上手（最简）

- 安装（不修改 zshrc）
```bash
chmod +x install.sh ccm.sh && ./install.sh
```

- 配置（环境变量 > 配置文件）
```bash
# 方式A：创建/编辑配置文件
ccm            # 首次运行会生成 ~/.ccm_config
ccm config     # 打开编辑

# 方式B：设置环境变量（优先级最高）
export DEEPSEEK_API_KEY=sk-...
export LONGCAT_API_KEY=your-longcat-api-key
```

- 使用（当前 shell 生效）
```bash
eval "$(ccm env deepseek)"
ccm status
```

- 卸载
```bash
./uninstall.sh
```

说明：不会修改 ~/.zshrc；status 输出已脱敏；建议为 ~/.ccm_config 设置 600 权限

## 🌟 特性

- 🤖 **多模型支持**：Claude、Deepseek、KIMI、GLM、Qwen等主流AI模型
- 🔄 **智能备用机制**：官方API优先，自动切换到PPINFRA备用服务
- ⚡ **快速切换**：一键切换不同AI模型，提升开发效率
- 🎨 **彩色界面**：直观的命令行界面，清晰显示切换状态
- 🛡️ **安全配置**：独立配置文件管理API密钥，支持多编辑器
- 📊 **状态监控**：实时显示当前模型配置和密钥状态

## 📦 支持的模型

| 模型 | 官方支持 | 备用支持(PPINFRA) | 特色 |
|------|---------|------------------|------|
| 🌙 **KIMI2** | ✅ kimi-k2-turbo-preview | ✅ kimi-k2-turbo-preview | 长文本处理 |
| 🤖 **Deepseek** | ✅ deepseek-chat | ✅ deepseek/deepseek-v3.1 | 高性价比推理 |
| 🐱 **LongCat** | ✅ LongCat-Flash-Chat | ❌ 仅官方 | 快速对话 |
| 🐪 **Qwen** | ✅ qwen3-max（阿里云） | ✅ qwen3-next-80b-a3b-thinking | 阿里云官方 |
| 🇨🇳 **GLM4.6** | ✅ glm-4.6 | ❌ 仅官方 | 智谱清言 |
| 🧠 **Claude Sonnet 4.5** | ✅ claude-sonnet-4-5-20250929 | ❌ 仅官方 | 平衡性能 |
| 🚀 **Claude Opus 4.1** | ✅ claude-opus-4-1-20250805 | ❌ 仅官方 | 最强推理 |

> 💰 **PPINFRA 备用服务注册**
>
> 注册PPINFRA服务可获得 **15元代金券**：
> - **注册链接**：https://ppio.com/user/register?invited_by=ZQRQZZ
> - **邀请码**：`ZQRQZZ`
>
> PPINFRA为Deepseek、KIMI和Qwen模型提供可靠的备用服务，当官方API不可用时自动切换。

## 🚀 快速开始

### 1. 下载脚本

```bash
# 克隆项目
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch

# 或直接下载脚本
wget https://raw.githubusercontent.com/yourusername/claude-code-switch/main/ccm.sh
chmod +x ccm.sh
```

### 2. 首次运行

```bash
./ccm.sh
```

首次运行会自动创建配置文件 `~/.ccm_config`，请编辑此文件添加你的API密钥。

### 3. 配置API密钥

**🔑 优先级：环境变量 > 配置文件**

CCM 采用智能的配置层次结构：
1. **环境变量**（最高优先级） - `export DEEPSEEK_API_KEY=your-key`
2. **配置文件** `~/.ccm_config`（环境变量未设置时的备选）

```bash
# 方式1：设置环境变量（推荐，安全性更好）
export DEEPSEEK_API_KEY=sk-your-deepseek-api-key
export KIMI_API_KEY=your-moonshot-api-key
export LONGCAT_API_KEY=your-longcat-api-key
export QWEN_API_KEY=sk-your-qwen-api-key
export PPINFRA_API_KEY=your-ppinfra-api-key

# 方式2：编辑配置文件
./ccm.sh config
# 或手动： vim ~/.ccm_config
```

配置文件示例：
```bash
# CCM 配置文件
# 注意：环境变量优先级高于此文件

# 官方API密钥
DEEPSEEK_API_KEY=sk-your-deepseek-api-key
KIMI_API_KEY=your-moonshot-api-key
LONGCAT_API_KEY=your-longcat-api-key
GLM_API_KEY=your-glm-api-key
QWEN_API_KEY=your-qwen-api-key  # 阿里云 DashScope

# 备用服务（仅当官方密钥缺失时启用）
PPINFRA_API_KEY=your-ppinfra-api-key
```

## 📖 使用方法

### 基本命令

```bash
# 切换到不同模型
ccm kimi          # 切换到KIMI2
ccm deepseek      # 切换到Deepseek  
ccm qwen          # 切换到Qwen
ccm glm           # 切换到GLM4.6
ccm longcat       # 切换到LongCat
ccm claude        # 切换到Claude Sonnet 4.5
ccm opus          # 切换到Claude Opus 4.1

# 查看当前状态（脱敏）
ccm status

# 编辑配置
ccm config

# 显示帮助
ccm help
```

### 在当前 shell 生效（推荐）

使用 env 子命令，只输出 export 语句，不打印密钥明文：
```bash
# 将模型环境导出到当前 shell
eval "$(ccm env deepseek)"
# 验证
ccm status
```

### 命令简写

```bash
./ccm.sh ds           # deepseek的简写
./ccm.sh s            # claude sonnet的简写  
./ccm.sh o            # opus的简写
./ccm.sh st           # status的简写
```

### 实际使用示例

```bash
# 切换到KIMI进行长文本处理
$ ./ccm.sh kimi
🔄 切换到 KIMI2 模型...
✅ 已切换到 KIMI2（官方）
   BASE_URL: https://api.moonshot.cn/anthropic
   MODEL: kimi-k2-turbo-preview

# 切换到Deepseek进行代码生成（如果没有官方key，自动使用备用）
$ ./ccm.sh deepseek  
🔄 切换到 Deepseek 模型...
✅ 已切换到 Deepseek（PPINFRA 备用）
   BASE_URL: https://api.ppinfra.com/openai/v1/anthropic
   MODEL: deepseek/deepseek-v3.1

# 查看当前配置状态
$ ./ccm.sh status
📊 当前模型配置:
   BASE_URL: https://api.ppinfra.com/openai/v1/anthropic
   AUTH_TOKEN: [已设置]
   MODEL: deepseek/deepseek-v3.1
   SMALL_MODEL: deepseek/deepseek-v3.1

🔧 环境变量状态:
   GLM_API_KEY: [未设置]
   KIMI_API_KEY: [已设置]
   DEEPSEEK_API_KEY: [未设置]
   QWEN_API_KEY: [未设置]
   PPINFRA_API_KEY: [已设置]
```

## 🛠️ 安装（不修改 zshrc）

CCM 支持安全的一键安装，不会修改你的 shell 配置文件。

### 一键安装
```bash
# 在项目目录中
chmod +x install.sh ccm.sh
./install.sh
```

- 在可写时安装到 /usr/local/bin 或 /opt/homebrew/bin
- 无法写入时回退到 ~/.local/bin
- 不会修改 ~/.zshrc 或其它配置文件

### 卸载
```bash
./uninstall.sh
```

如果安装到受保护目录，可能需要 sudo：
```bash
sudo install -m 0755 ./ccm.sh /usr/local/bin/ccm
# 卸载
sudo rm -f /usr/local/bin/ccm
```

## 🔧 高级配置

### 🔑 配置优先级系统

CCM 使用智能的分层配置系统：

1. **环境变量**（最高优先级）
   - 在shell会话中设置：`export DEEPSEEK_API_KEY=your-key`
   - 推荐用于临时测试或CI/CD环境
   - 始终优先于配置文件

2. **配置文件** `~/.ccm_config`（备选）
   - API密钥的持久化存储
   - 仅在对应环境变量未设置时使用
   - 适合日常开发使用

**实际场景示例：**
```bash
# 存在环境变量
export DEEPSEEK_API_KEY=env-key-123

# 配置文件中包含
echo "DEEPSEEK_API_KEY=config-key-456" >> ~/.ccm_config

# CCM 将使用：env-key-123（环境变量胜出）
./ccm.sh status  # 显示 DEEPSEEK_API_KEY: env-key-123
```

### 智能备用机制

CCM实现了智能的备用机制：
- **优先使用官方API**：如果配置了官方密钥，优先使用官方服务
- **自动切换备用**：当官方密钥未配置时，自动切换到PPINFRA备用服务
- **透明切换**：用户无感知，命令保持一致

### 安全与隐私
- status 输出对密钥做脱敏（仅显示前后 4 位）
- env 子命令只输出 export 语句与变量引用，不打印密钥明文
- 配置优先级：环境变量 > ~/.ccm_config
- 建议权限：`chmod 600 ~/.ccm_config`

### PPINFRA备用服务

PPINFRA是一个第三方AI模型聚合服务，提供：
- Base URL: `https://api.ppinfra.com/openai/v1/anthropic`
- 支持模型：
  - `kimi-k2-turbo-preview` (KIMI备用)
  - `deepseek/deepseek-v3.1` (Deepseek备用)
  - `qwen3-next-80b-a3b-thinking` (Qwen备用)

### 配置文件详解

`~/.ccm_config` 文件包含所有API密钥配置：

```bash
# 必需：各服务商官方密钥（至少配置一个）
DEEPSEEK_API_KEY=sk-your-deepseek-key
KIMI_API_KEY=your-moonshot-api-key
GLM_API_KEY=your-glm-key
QWEN_API_KEY=your-qwen-key

# 可选：Qwen官方Anthropic兼容端点
QWEN_ANTHROPIC_BASE_URL=https://your-qwen-gateway

# 可选但推荐：备用服务密钥
PPINFRA_API_KEY=your-ppinfra-key

# Claude（如使用API而非Pro订阅）
CLAUDE_API_KEY=your-claude-key
```

## 🐛 故障排除

### 常见问题

**Q: 显示"未检测到XXX_API_KEY"错误**
```bash
A: 请检查 ~/.ccm_config 文件中对应的API密钥是否正确配置
   ./ccm.sh config  # 打开配置文件检查
```

**Q: 切换后Claude Code无法正常工作**
```bash
A: 确认环境变量已正确设置：
   ./ccm.sh status  # 查看当前配置状态
   echo $ANTHROPIC_BASE_URL  # 检查环境变量
```

**Q: 想强制使用官方服务而非备用**
```bash
A: 配置对应的官方API密钥，脚本会自动优先使用官方服务
```

### 调试模式

```bash
# 显示详细状态信息
./ccm.sh status

# 检查配置文件
cat ~/.ccm_config

# 验证环境变量
env | grep ANTHROPIC
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发设置
```bash
git clone https://github.com/yourusername/claude-code-switch.git
cd claude-code-switch
```

### 提交规范
- 使用清晰的commit message
- 添加适当的测试
- 更新文档

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 🙏 致谢

- [Claude](https://claude.ai) - AI助手
- [Deepseek](https://deepseek.com) - 高效推理模型
- [KIMI](https://kimi.moonshot.cn) - 长文本处理
- [智谱清言](https://zhipuai.cn) - GLM大模型
- [Qwen](https://qwen.alibaba.com) - 阿里通义千问

---

⭐ 如果这个项目对你有帮助，请给个Star！

📧 有问题或建议？欢迎提交 [Issue](https://github.com/yourusername/claude-code-switch/issues)
