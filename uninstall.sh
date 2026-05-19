#!/usr/bin/env bash
# gai-tools uninstall script
# Usage: bash uninstall.sh

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"

echo "━━━ gai-tools uninstaller ━━━"
echo ""

# ── remove scripts ────────────────────────────────────────────────────────────

for bin in gai gai-watch; do
  if [[ -f "$INSTALL_DIR/$bin" ]]; then
    rm -f "$INSTALL_DIR/$bin"
    echo "✓ Removed $INSTALL_DIR/$bin"
  fi
done

# ── stop any running watchers ─────────────────────────────────────────────────

pkill -f gai-watch 2>/dev/null || true
rm -f /tmp/gai-watch-*.pid
echo "✓ Stopped all gai-watch processes"

# ── remove zshrc hook ─────────────────────────────────────────────────────────

if grep -q "gai-tools:" "$ZSHRC" 2>/dev/null; then
  # Remove block between "# gai-tools: auto-start" and "# end gai-tools"
  sed -i '' '/# gai-tools: auto-start/,/# end gai-tools/d' "$ZSHRC"
  echo "✓ Removed hook from $ZSHRC"
else
  echo "  (no hook found in $ZSHRC)"
fi

echo ""
echo "━━━ gai-tools uninstalled ━━━"
echo ""
echo "  Ollama and fswatch were NOT removed (used by other tools)."
echo "  To remove them: brew uninstall ollama fswatch"
echo ""
echo "  Reload shell: source ~/.zshrc"
