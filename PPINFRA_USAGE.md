# PPINFRA Usage Guide

PPINFRA is a third-party AI model aggregation service providing backup access to DeepSeek, GLM, KIMI, Qwen, and other models.

---

## Quick Start

### Method 1: One-Command Launch with ccc (Recommended)

The simplest way is to use the `ccc pp` command to switch models and launch Claude Code in one step:

```bash
# Use PPINFRA DeepSeek
ccc pp deepseek

# Use PPINFRA GLM 4.6
ccc pp glm

# Use PPINFRA KIMI 2
ccc pp kimi

# Use PPINFRA Qwen
ccc pp qwen

# With Claude Code options
ccc pp deepseek --dangerously-skip-permissions
```

### Method 2: Two-Step Method

If you want to verify configuration before launching:

```bash
# 1. Switch to PPINFRA model
ccm pp deepseek

# 2. Verify configuration
ccm status

# 3. Launch Claude Code (inherits environment variables)
claude
```

---

## Configure PPINFRA API Key

### Get API Key

1. Register PPINFRA account: https://ppio.com/user/register?invited_by=ZQRQZZ
2. Use invitation code `ZQRQZZ` to get ¥15 coupon
3. Get API Key from console

### Configure API Key

```bash
# Open configuration file
ccm config

# Add the following line
PPINFRA_API_KEY=your-ppinfra-api-key-here
```

Or edit directly:
```bash
vim ~/.ccm_config
```

---

## Verify Configuration

### Check Environment Variables

```bash
# Switch to PPINFRA model
ccm pp deepseek

# View current configuration
ccm status
```

Should display:
```
📊 Current model configuration:
   BASE_URL: https://api.ppinfra.com/anthropic
   AUTH_TOKEN: [Set]
   MODEL: deepseek/deepseek-v3.2-exp
   SMALL_MODEL: deepseek/deepseek-v3.2-exp
```

### Test Connection

Launch Claude Code and send a test message:
```bash
ccc pp deepseek
# Input: Hello
# Should get normal response
```

---

## Supported PPINFRA Models

| Command | Model Name | Description |
|---------|------------|-------------|
| `ccc pp deepseek` | deepseek/deepseek-v3.2-exp | DeepSeek V3.2 Experimental Version |
| `ccc pp glm` | zai-org/glm-4.6 | Zhipu AI GLM 4.6 |
| `ccc pp kimi` | kimi-k2-turbo-preview | Moonshot KIMI 2 |
| `ccc pp qwen` | qwen3-next-80b-a3b-thinking | Alibaba Cloud Qwen |

**Shortcuts**:
```bash
ccc pp ds    # DeepSeek shortcut
```

---

## How It Works

### ccm pp Command (Environment Management)

1. `ccm pp <model>` calls `ccm.sh`
2. `ccm.sh` outputs export statements
3. Shell executes these statements via `eval`
4. Environment variables take effect in current shell

```bash
ccm pp deepseek  # Only sets environment variables
```

### ccc pp Command (One-Click Launch)

1. `ccc pp <model>` calls `ccm pp <model>` to set environment variables
2. Shows switching status and configuration information
3. Uses `exec claude` to launch Claude Code
4. Claude Code inherits all environment variables

```bash
ccc pp deepseek  # Set environment + launch Claude Code
```

---

## Common Issues

### Q: Why doesn't Claude Code show the PPINFRA URL?

**A:** Claude Code inherits environment variables from startup. Solution:

```bash
# Method 1: Use ccc (recommended)
ccc pp deepseek

# Method 2: Two-step method
ccm pp deepseek  # Set environment first
claude           # Then launch
```

### Q: How to switch back to official API?

**A:** Use commands without `pp`:

```bash
# Official API
ccc deepseek  # or: ccm deepseek
ccc glm
ccc claude

# PPINFRA
ccc pp deepseek  # or: ccm pp deepseek
ccc pp glm
```

### Q: Where to configure PPINFRA API Key?

**A:** Use configuration command:

```bash
ccm config  # Open configuration file

# Add this line
PPINFRA_API_KEY=your-ppinfra-api-key
```

### Q: How to verify PPINFRA configuration is correct?

**A:** Use status command:

```bash
ccm pp deepseek
ccm status

# Should show:
# BASE_URL: https://api.ppinfra.com/anthropic
# MODEL: deepseek/deepseek-v3.2-exp
```

---

## Use Cases

### Scenario 1: Quick Testing Different Models

```bash
# Quick switch testing
ccc pp deepseek  # Test DeepSeek
# Ctrl+C to exit

ccc pp glm       # Test GLM
# Ctrl+C to exit

ccc pp kimi      # Test KIMI
```

### Scenario 2: Mixed Official API and PPINFRA Usage

```bash
# Use official Claude API (requires subscription)
ccc claude

# Switch to PPINFRA for cost-sensitive tasks
ccc pp deepseek
```

### Scenario 3: Batch Processing Tasks

```bash
# Set environment for batch operations
ccm pp deepseek

# Launch Claude Code multiple times for different tasks
claude task1.txt
claude task2.txt
claude task3.txt
```

---

## Price Advantages

PPINFRA advantages over official API:

- **DeepSeek**: PPINFRA offers more competitive pricing
- **GLM**: Access through PPINFRA without separate application
- **KIMI**: More economical for long text processing
- **Qwen**: Stable domestic access

---

## Troubleshooting

For issues, please refer to:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Complete troubleshooting guide

Common issues:
```bash
# 404 error
claude /logout  # Clear authentication conflicts
ccc pp deepseek # Restart

# Environment variables not taking effect
ccm status      # Check configuration
source ~/.zshrc # Reload shell
```