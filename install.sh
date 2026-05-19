#!/usr/bin/env bash
# gai-tools install script
# Usage: bash install.sh
#
# Installs gai + gai-watch on macOS with all dependencies.

set -euo pipefail

VERSION=$(curl -fsSL https://api.github.com/repos/Navibyte-Innovations-Pvt-Ltd/gai-tools/releases/latest \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))" 2>/dev/null || echo "dev")
INSTALL_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"
MODEL="${GAI_MODEL:-qwen2.5-coder:1.5b}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck disable=SC2016
GAI_WATCH_HOOK='
# gai-tools: auto-start gai-watch when entering a git repo
_gai_pidfile() {
  local repo="$1"
  echo "/tmp/gai-watch-$(echo "$repo" | md5).pid"
}

_gai_watch_start() {
  local repo
  repo=$(git rev-parse --show-toplevel 2>/dev/null) || return
  local pidfile
  pidfile=$(_gai_pidfile "$repo")
  if [[ -f "$pidfile" ]]; then
    local pid
    pid=$(cat "$pidfile")
    kill -0 "$pid" 2>/dev/null && return
    rm -f "$pidfile"
  fi
  gai-watch > /tmp/gai-watch.log 2>&1 &
  echo $! > "$pidfile"
}

chpwd() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    _gai_watch_start
  fi
}

_gai_watch_start  # start for initial shell directory
# end gai-tools'

echo "━━━ gai-tools v$VERSION installer ━━━"
echo ""

# ── check macOS ──────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: gai-tools requires macOS." >&2
  exit 1
fi

# ── check Homebrew ───────────────────────────────────────────────────────────

if ! command -v brew > /dev/null 2>&1; then
  echo "error: Homebrew not found. Install from https://brew.sh" >&2
  exit 1
fi

echo "✓ Homebrew found"

# ── install fswatch ──────────────────────────────────────────────────────────

if ! command -v fswatch > /dev/null 2>&1; then
  echo "→ Installing fswatch…"
  brew install fswatch
else
  echo "✓ fswatch already installed"
fi

# ── install Ollama ───────────────────────────────────────────────────────────

if ! command -v ollama > /dev/null 2>&1; then
  echo "→ Installing Ollama…"
  brew install ollama
else
  echo "✓ Ollama already installed"
fi

# ── start Ollama + pull model ─────────────────────────────────────────────────

echo "→ Starting Ollama…"
if ! curl -s --connect-timeout 2 "http://localhost:11434" > /dev/null 2>&1; then
  ollama serve > /tmp/ollama.log 2>&1 &
  echo "  Waiting for Ollama to start…"
  for i in {1..10}; do
    sleep 1
    curl -s --connect-timeout 1 "http://localhost:11434" > /dev/null 2>&1 && break
    [[ $i -eq 10 ]] && echo "error: Ollama didn't start. Check /tmp/ollama.log" >&2 && exit 1
  done
fi
echo "✓ Ollama running"

if ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  echo "✓ Model $MODEL already pulled"
else
  echo "→ Pulling model $MODEL (986MB, one-time download)…"
  ollama pull "$MODEL"
fi

# ── install scripts ───────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR"

echo "→ Installing gai to $INSTALL_DIR/gai…"
cp "$SCRIPT_DIR/gai" "$INSTALL_DIR/gai"
chmod +x "$INSTALL_DIR/gai"

echo "→ Installing gai-watch to $INSTALL_DIR/gai-watch…"
cp "$SCRIPT_DIR/gai-watch" "$INSTALL_DIR/gai-watch"
chmod +x "$INSTALL_DIR/gai-watch"

# ── ensure ~/.local/bin is in PATH ───────────────────────────────────────────

if ! grep -q 'HOME/.local/bin' "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
  echo "✓ Added ~/.local/bin to PATH in $ZSHRC"
fi

# ── add zshrc hook (idempotent) ───────────────────────────────────────────────

if grep -q "gai-tools:" "$ZSHRC" 2>/dev/null; then
  echo "✓ zshrc hook already installed"
else
  echo "" >> "$ZSHRC"
  echo "$GAI_WATCH_HOOK" >> "$ZSHRC"
  echo "✓ Added auto-start hook to $ZSHRC"
fi

# ── done ─────────────────────────────────────────────────────────────────────

echo ""
echo "━━━ gai-tools v$VERSION installed ━━━"
echo ""
echo "  Reload your shell:"
echo "    source ~/.zshrc"
echo ""
echo "  Then stage any file in a git repo — it will auto-commit."
echo ""
echo "  Commands:"
echo "    gai              # commit staged files"
echo "    gai --all        # commit all dirty files"
echo "    gai --dry-run    # preview without committing"
echo "    gai-watch        # start watcher manually"
echo ""
echo "  Docs: https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools"
