#!/usr/bin/env bash
set -euo pipefail

# Test installation script for CCM
# Simulates fresh install and upgrade scenarios

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/ccm_test_$$"
FAKE_HOME="$TEST_DIR/home"
FAKE_ZSHRC="$FAKE_HOME/.zshrc"

echo "=========================================="
echo "CCM Installation Test Suite"
echo "=========================================="
echo ""

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test 1: Fresh install (empty .zshrc)
test_fresh_install() {
  echo "📋 Test 1: Fresh install (empty .zshrc)"
  echo "------------------------------------------"
  
  mkdir -p "$FAKE_HOME"
  touch "$FAKE_ZSHRC"
  
  # Run installer with fake HOME
  HOME="$FAKE_HOME" "$REPO_DIR/install.sh" >/dev/null 2>&1 || {
    echo "❌ Install failed"
    return 1
  }
  
  # Check function block exists
  if grep -q ">>> ccm function begin >>>" "$FAKE_ZSHRC"; then
    echo "✅ Function block added"
  else
    echo "❌ Function block not found"
    return 1
  fi
  
  # Check eval line is correct (no excessive escaping)
  if grep -q 'eval "\\$(\\"\\$script\\" \\"\\$@\\")"' "$FAKE_ZSHRC"; then
    echo "❌ Eval line has escaping bug (old version)"
    return 1
  elif grep -q 'eval "\\$(\\"$script\\" \\"$@\\")"' "$FAKE_ZSHRC"; then
    echo "✅ Eval line is correct (fixed version)"
  else
    echo "⚠️  Eval line format unexpected, checking manually..."
    grep "eval" "$FAKE_ZSHRC" || true
  fi
  
  # Check installed assets
  if [[ -f "$FAKE_HOME/.local/share/ccm/ccm.sh" ]]; then
    echo "✅ ccm.sh installed to ~/.local/share/ccm/"
  else
    echo "❌ ccm.sh not found"
    return 1
  fi
  
  echo "✅ Test 1 PASSED"
  echo ""
  return 0
}

# Test 2: Upgrade (old function block exists)
test_upgrade() {
  echo "📋 Test 2: Upgrade (old ccm function exists)"
  echo "------------------------------------------"
  
  mkdir -p "$FAKE_HOME"
  cat > "$FAKE_ZSHRC" <<'EOF'
# User's existing config
export PATH=/usr/local/bin:$PATH

# >>> ccm function begin >>>
# Old version with bug
ccm() {
  eval "$(\"/old/path/ccm.sh\" \"$@\")"
}
# <<< ccm function end <<<

# More user config
alias ll='ls -la'
EOF
  
  # Run installer (should replace old block)
  HOME="$FAKE_HOME" "$REPO_DIR/install.sh" >/dev/null 2>&1 || {
    echo "❌ Upgrade install failed"
    return 1
  }
  
  # Check old block removed and new one added
  if grep -q "/old/path/ccm.sh" "$FAKE_ZSHRC"; then
    echo "❌ Old function block not removed"
    return 1
  else
    echo "✅ Old function block removed"
  fi
  
  if grep -q ".local/share/ccm/ccm.sh" "$FAKE_ZSHRC"; then
    echo "✅ New function block added"
  else
    echo "❌ New function block not found"
    return 1
  fi
  
  # Check user config preserved
  if grep -q "alias ll='ls -la'" "$FAKE_ZSHRC"; then
    echo "✅ User config preserved"
  else
    echo "❌ User config lost"
    return 1
  fi
  
  echo "✅ Test 2 PASSED"
  echo ""
  return 0
}

# Test 3: Uninstall and reinstall
test_uninstall_reinstall() {
  echo "📋 Test 3: Uninstall and reinstall"
  echo "------------------------------------------"
  
  mkdir -p "$FAKE_HOME/.local/share/ccm"
  cat > "$FAKE_ZSHRC" <<'EOF'
# User config
export PATH=/usr/local/bin:$PATH

# >>> ccm function begin >>>
ccm() {
  eval "$("$HOME/.local/share/ccm/ccm.sh" "$@")"
}
# <<< ccm function end <<<
EOF
  
  echo "dummy" > "$FAKE_HOME/.local/share/ccm/ccm.sh"
  
  # Run uninstaller
  HOME="$FAKE_HOME" "$REPO_DIR/uninstall.sh" >/dev/null 2>&1 || {
    echo "❌ Uninstall failed"
    return 1
  }
  
  # Check function block removed
  if grep -q ">>> ccm function begin >>>" "$FAKE_ZSHRC"; then
    echo "❌ Function block not removed"
    return 1
  else
    echo "✅ Function block removed"
  fi
  
  # Check assets removed
  if [[ -d "$FAKE_HOME/.local/share/ccm" ]]; then
    echo "❌ Assets directory not removed"
    return 1
  else
    echo "✅ Assets directory removed"
  fi
  
  # Reinstall
  HOME="$FAKE_HOME" "$REPO_DIR/install.sh" >/dev/null 2>&1 || {
    echo "❌ Reinstall failed"
    return 1
  }
  
  if grep -q ">>> ccm function begin >>>" "$FAKE_ZSHRC"; then
    echo "✅ Reinstall successful"
  else
    echo "❌ Reinstall failed"
    return 1
  fi
  
  echo "✅ Test 3 PASSED"
  echo ""
  return 0
}

# Run all tests
failed=0
test_fresh_install || ((failed++))
test_upgrade || ((failed++))
test_uninstall_reinstall || ((failed++))

echo "=========================================="
if [[ $failed -eq 0 ]]; then
  echo "✅ All tests PASSED"
  echo "=========================================="
  exit 0
else
  echo "❌ $failed test(s) FAILED"
  echo "=========================================="
  exit 1
fi
