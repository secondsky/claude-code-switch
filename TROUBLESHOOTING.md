# Claude Code 故障排除 (Troubleshooting)

本指南帮助您解决使用 CCM 切换模型时遇到的常见问题。

---

## 问题 1：404 错误

### 症状
```
> 你是？
  ⎿  API Error: 404 404 page not found
```

### 原因分析

1. **认证冲突**：Claude Code 同时检测到两个认证方式：
   - `ANTHROPIC_AUTH_TOKEN`（环境变量设置的）
   - `/login` 管理的 API key（Claude Code 内置的）

2. **错误的 API 端点**：Base URL 配置不正确或包含重复的路径

### 解决方案

#### 方法 1：清除 Claude Code 的登录状态（推荐）

1. **在 Claude Code 中执行 logout**：
   ```
   /logout
   ```
   或在终端中：
   ```bash
   claude /logout
   ```

2. **使用 ccc 命令重新启动**：
   ```bash
   # 重新加载 shell 配置
   source ~/.zshrc
   
   # 使用 ccc 启动（会自动设置环境变量）
   ccc deepseek
   
   # 或使用 PPINFRA
   ccc pp glm
   ```

3. **验证**：启动后不应该再看到认证冲突警告。

#### 方法 2：检查环境变量

在启动 Claude Code 之前验证配置：

```bash
# 切换模型
ccm deepseek

# 检查配置
ccm status

# 应该看到正确的 BASE_URL 和 AUTH_TOKEN
```

#### 方法 3：检查 claude-code-router 配置

如果使用了 `claude-code-router`，可能会干扰配置：

```bash
# 查看配置
cat ~/.claude-code-router/config.json

# 临时禁用（如果需要）
mv ~/.claude-code-router ~/.claude-code-router.disabled

# 重新启动
ccc deepseek

# 测试完成后恢复
mv ~/.claude-code-router.disabled ~/.claude-code-router
```

---

## 问题 2：环境变量未生效

### 症状

Claude Code 启动后仍然使用旧的 API 端点。

### 原因

Claude Code 继承的是**启动时**的环境变量，不是当前 shell 的环境变量。

### 解决方案

**使用 `ccc` 命令（推荐）**：

```bash
# 一步到位：切换模型并启动 Claude Code
ccc deepseek

# 使用 PPINFRA
ccc pp glm
```

**或者两步走**：

```bash
# 1. 先切换环境
ccm deepseek

# 2. 再启动 Claude Code
claude
```

⚠️ **注意**：不要先启动 Claude Code，然后再切换环境变量，这样不会生效。

---

## 问题 3：PPINFRA API Key 未配置

### 症状
```
❌ PPINFRA_API_KEY not configured
```

### 解决方案

编辑配置文件：

```bash
# 打开配置文件
ccm config

# 或直接编辑
vim ~/.ccm_config
```

添加您的 PPINFRA API Key：
```bash
PPINFRA_API_KEY=your-actual-api-key-here
```

保存后重新切换：
```bash
ccm pp deepseek
ccm status  # 验证配置
```

---

## 常见警告及解决方法

### ⚠️ Auth conflict 警告

```
⚠ Auth conflict: Both a token (ANTHROPIC_AUTH_TOKEN) and an API key (/login managed key) are set.
```

**解决**：
```bash
# 在 Claude Code 中执行
/logout

# 或在终端执行
claude /logout

# 然后重新启动
ccc deepseek
```

### ❌ Model not found 错误

**可能原因**：
- 模型名称拼写错误
- PPINFRA 服务不支持该模型
- API Key 无效

**解决**：
```bash
# 查看支持的模型
ccm help

# 验证配置
ccm status

# 确保 API Key 正确
ccm config
```

---

## Debug 检查清单

在报告问题前，请逐一检查：

- [ ] 已安装最新版本：`./install.sh`
- [ ] 已重新加载 shell：`source ~/.zshrc`
- [ ] 已执行 `claude /logout` 清除认证冲突
- [ ] 配置文件正确：`ccm config` 检查 API keys
- [ ] 环境变量正确：`ccm status` 验证配置
- [ ] 使用 `ccc` 命令启动（不是手动 `ccm` + `claude`）
- [ ] 没有 `claude-code-router` 干扰

---

## 成功启动的标志

### 使用 ccc 启动时

正确的启动流程应该显示：

```bash
$ ccc deepseek
🔄 Switching to deepseek...
✅ Environment configured for: DeepSeek

🚀 Launching Claude Code...
   Model: deepseek-chat
   Base URL: https://api.deepseek.com/anthropic

╭─────────────────────────────────────────────────────╮
│ ✻ Welcome to Claude Code!                           │
│                                                     │
│   Overrides (via env):                              │
│   • API Base URL:                                   │
│   https://api.deepseek.com/anthropic                │
╰─────────────────────────────────────────────────────╯
```

**关键点**：
- ✅ 没有认证冲突警告
- ✅ Base URL 显示正确
- ✅ 可以直接开始对话

---

## 快速测试命令

```bash
# 测试官方 API
ccc deepseek
# 输入: 你好
# 应该得到正常回复

# 测试 PPINFRA
ccc pp glm
# 输入: 你好  
# 应该得到正常回复
```

---

## 需要帮助？

如果以上方法都无法解决，请提供以下信息：

1. **系统信息**：
   ```bash
   uname -a
   echo $SHELL
   ```

2. **CCM 版本**：
   ```bash
   head -5 ccm.sh  # 查看版本注释
   ```

3. **配置状态**：
   ```bash
   ccm status
   ```

4. **启动命令和完整输出**：
   ```bash
   ccc deepseek 2>&1 | tee debug.log
   ```

5. **错误消息**：完整的错误信息截图或文本

将以上信息提交到项目 Issues 页面。
