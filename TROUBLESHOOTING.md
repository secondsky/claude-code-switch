# Claude Code Troubleshooting Guide

This guide helps you solve common issues when using CCM for model switching.

---

## Issue 1: 404 Error

### Symptoms
```
> Who are you?
  ⎿  API Error: 404 404 page not found
```

### Cause Analysis

1. **Authentication conflict**: Claude Code detects two authentication methods simultaneously:
   - `ANTHROPIC_AUTH_TOKEN` (environment variable set)
   - `/login` managed API key (built-in to Claude Code)

2. **Wrong API endpoint**: Base URL configuration is incorrect or contains duplicate paths

### Solutions

#### Method 1: Clear Claude Code Login Status (Recommended)

1. **Execute logout in Claude Code**:
   ```
   /logout
   ```
   Or in terminal:
   ```bash
   claude /logout
   ```

2. **Restart using ccc command**:
   ```bash
   # Reload shell configuration
   source ~/.zshrc
   
   # Use ccc to launch (automatically sets environment variables)
   ccc deepseek
   
   # Or use PPINFRA
   ccc pp glm
   ```

3. **Verify**: After startup, you should no longer see authentication conflict warnings.

#### Method 2: Check Environment Variables

Verify configuration before starting Claude Code:

```bash
# Switch model
ccm deepseek

# Check configuration
ccm status

# Should see correct BASE_URL and AUTH_TOKEN
```

#### Method 3: Check claude-code-router Configuration

If using `claude-code-router`, it may interfere with configuration:

```bash
# View configuration
cat ~/.claude-code-router/config.json

# Temporarily disable (if needed)
mv ~/.claude-code-router ~/.claude-code-router.disabled

# Restart
ccc deepseek

# Restore after testing
mv ~/.claude-code-router.disabled ~/.claude-code-router
```

---

## Issue 2: Commands Fail or Error After Code Updates

### Symptoms

When running `ccm` commands, you see one of these errors:

```bash
# Error example 1: New commands don't exist
ccm h
(eval):1: bad pattern: ^[[0
zsh: parse error near `:1:'

# Error example 2: New features unavailable
ccm haiku
zsh: command not found: haiku

# Error example 3: Old version behavior
ccm status  # Shows old configuration, no new models
```

### Cause Analysis

**Important**: The `ccm` shell function uses the **installed script** (located at `~/.local/share/ccm/ccm.sh`), not the development version you've modified in your working directory.

When you:
1. ✏️ Modify the `ccm.sh` file
2. ❌ But forget to reinstall
3. 🔍 Run `ccm` command

Result: You're still using the **old version** of the code, new features won't take effect at all.

### Solutions

#### ✅ Standard Development Process (Required After Every Code Modification)

```bash
# 1. After modifying code, reinstall
./install.sh

# 2. Reload shell configuration
source ~/.zshrc  # or source ~/.bashrc

# 3. Verify update
ccm status      # Check if version is updated
ccm help        # Confirm new commands appear in help
```

#### 🔍 Verify If Reinstallation Is Needed

```bash
# Check installed version location
type ccm
# Output: ccm is a shell function from /Users/xxx/.zshrc

# View installed script modification time
ls -lh ~/.local/share/ccm/ccm.sh

# Compare with working directory version
ls -lh ccm.sh

# If times don't match, reinstallation is needed
```

#### 🎯 Developer Workflow Quick Reference

```bash
# Development cycle
1. vim ccm.sh              # Edit code
2. ./install.sh            # Install updates
3. source ~/.zshrc         # Reload configuration  
4. ccm <test-command>      # Test functionality
5. If issues, return to step 1
```

### Special Reminder

⚠️ **Common Error Pattern**:
- ❌ Modify code → run `ccm` directly → wonder why it doesn't work
- ✅ Modify code → `./install.sh` → `source ~/.zshrc` → run `ccm`

💡 **Memory Tip**: Consider `./install.sh && source ~/.zshrc` as a fixed operation, execute after every code change.

---

## Issue 3: Environment Variables Not Taking Effect

### Symptoms

After starting Claude Code, it still uses the old API endpoint.

### Cause

Claude Code inherits environment variables from **startup time**, not the current shell environment.

### Solutions

**Use `ccc` command (Recommended)**:

```bash
# One-step: switch model and start Claude Code
ccc deepseek

# Use PPINFRA
ccc pp glm
```

**Or two-step approach**:

```bash
# 1. Switch environment first
ccm deepseek

# 2. Then start Claude Code
claude
```

⚠️ **Note**: Don't start Claude Code first, then switch environment variables - this won't work.

---

## Issue 4: PPINFRA API Key Not Configured

### Symptoms
```
❌ PPINFRA_API_KEY not configured
```

### Solutions

Edit configuration file:

```bash
# Open configuration file
ccm config

# Or edit directly
vim ~/.ccm_config
```

Add your PPINFRA API Key:
```bash
PPINFRA_API_KEY=your-actual-api-key-here
```

After saving, switch again:
```bash
ccm pp deepseek
ccm status  # Verify configuration
```

---

## Common Warnings and Solutions

### ⚠️ Auth Conflict Warning

```
⚠ Auth conflict: Both a token (ANTHROPIC_AUTH_TOKEN) and an API key (/login managed key) are set.
```

**Solution**:
```bash
# Execute in Claude Code
/logout

# Or in terminal
claude /logout

# Then restart
ccc deepseek
```

### ❌ Model Not Found Error

**Possible causes**:
- Incorrect model name spelling
- PPINFRA service doesn't support that model
- Invalid API Key

**Solution**:
```bash
# View supported models
ccm help

# Verify configuration
ccm status

# Ensure API Key is correct
ccm config
```

---

## Debug Checklist

Before reporting issues, please check each item:

- [ ] Latest version installed: `./install.sh`
- [ ] Shell reloaded: `source ~/.zshrc`
- [ ] Executed `claude /logout` to clear authentication conflicts
- [ ] Configuration file correct: `ccm config` check API keys
- [ ] Environment variables correct: `ccm status` verify configuration
- [ ] Used `ccc` command to start (not manually `ccm` + `claude`)
- [ ] No `claude-code-router` interference

---

## Signs of Successful Launch

### When Using ccc to Start

The correct startup flow should display:

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

**Key points**:
- ✅ No authentication conflict warnings
- ✅ Base URL displays correctly
- ✅ Can start conversation directly

---

## Quick Test Commands

```bash
# Test official API
ccc deepseek
# Input: Hello
# Should get normal response

# Test PPINFRA
ccc pp glm
# Input: Hello  
# Should get normal response
```

---

## Need Help?

If none of the above methods solve the problem, please provide the following information:

1. **System Information**:
   ```bash
   uname -a
   echo $SHELL
   ```

2. **CCM Version**:
   ```bash
   head -5 ccm.sh  # View version comments
   ```

3. **Configuration Status**:
   ```bash
   ccm status
   ```

4. **Startup Command and Full Output**:
   ```bash
   ccc deepseek 2>&1 | tee debug.log
   ```

5. **Error Messages**: Complete error message screenshot or text

Submit the above information to the project Issues page.