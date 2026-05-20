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
    pid=$(awk '"'"'{print $1}'"'"' "$pidfile" 2>/dev/null)
    kill -0 "$pid" 2>/dev/null && return
    rm -f "$pidfile"
  fi
  local repo_hash
  repo_hash=$(echo "$repo" | md5)
  gai-watch > "/tmp/gai-watch-${repo_hash}.log" 2>&1 &
  echo "$! $repo" > "$pidfile"
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

# ── add/update zshrc hook (idempotent, upgrades old format) ──────────────────

if grep -q "gai-tools:" "$ZSHRC" 2>/dev/null; then
  # Update hook if it uses old pidfile format (single PID, no repo path stored)
  # shellcheck disable=SC2016
  if grep -q 'echo $! > "$pidfile"' "$ZSHRC" 2>/dev/null; then
    echo "→ Updating zshrc hook to new format…"
    python3 - <<PYEOF
import re, sys
with open("$ZSHRC") as f:
    content = f.read()
updated = re.sub(
    r'\n# gai-tools:.*?# end gai-tools\n?',
    '',
    content,
    flags=re.DOTALL
)
with open("$ZSHRC", "w") as f:
    f.write(updated)
PYEOF
    echo "" >> "$ZSHRC"
    echo "$GAI_WATCH_HOOK" >> "$ZSHRC"
    echo "✓ Updated zshrc hook"
  else
    echo "✓ zshrc hook already up to date"
  fi
else
  echo "" >> "$ZSHRC"
  echo "$GAI_WATCH_HOOK" >> "$ZSHRC"
  echo "✓ Added auto-start hook to $ZSHRC"
fi

# ── restart all running gai-watch instances ───────────────────────────────────

echo "→ Restarting gai-watch instances…"
RESTARTED=0

while IFS= read -r pidfile; do
  [[ -f "$pidfile" ]] || continue

  old_pid=$(awk '{print $1}' "$pidfile" 2>/dev/null)
  [[ -n "$old_pid" ]] || continue

  # New pidfile format stores "PID /repo/path"; old format stores just PID.
  # Fall back to lsof to find the repo from the live process.
  repo=$(awk 'NF>1{print $2}' "$pidfile" 2>/dev/null)
  if [[ -z "$repo" ]]; then
    repo=$(lsof -p "$old_pid" 2>/dev/null | awk '$4=="cwd"{print $9}' | head -1)
  fi

  kill "$old_pid" 2>/dev/null || true
  rm -f "$pidfile"

  [[ -n "$repo" && -d "$repo/.git" ]] || continue

  repo_hash=$(echo "$repo" | md5)
  (
    cd "$repo" || exit
    gai-watch > "/tmp/gai-watch-${repo_hash}.log" 2>&1 &
    new_pid=$!
    disown "$new_pid" 2>/dev/null || true
    echo "$new_pid $repo" > "$pidfile"
  )
  RESTARTED=$((RESTARTED + 1))
  echo "  ✓ $(basename "$repo")"

done < <(find /tmp -maxdepth 1 -name 'gai-watch-*.pid' 2>/dev/null)

if [[ $RESTARTED -eq 0 ]]; then
  echo "  (no prior watchers found)"
fi

# Also start watcher in the current directory if it is a git repo
if git rev-parse --git-dir > /dev/null 2>&1; then
  CURR_REPO=$(git rev-parse --show-toplevel)
  CURR_HASH=$(echo "$CURR_REPO" | md5)
  CURR_PID="/tmp/gai-watch-${CURR_HASH}.pid"
  CURR_RUNNING=false
  if [[ -f "$CURR_PID" ]]; then
    CURR_OLD=$(awk '{print $1}' "$CURR_PID" 2>/dev/null)
    kill -0 "$CURR_OLD" 2>/dev/null && CURR_RUNNING=true
  fi
  if [[ "$CURR_RUNNING" == "false" ]]; then
    (cd "$CURR_REPO" && gai-watch > "/tmp/gai-watch-${CURR_HASH}.log" 2>&1 &
    disown $! 2>/dev/null || true
    echo "$! $CURR_REPO" > "$CURR_PID")
    echo "  ✓ started watcher in current repo: $(basename "$CURR_REPO")"
  fi
fi

# ── start watchers in all open VS Code workspaces ────────────────────────────

VSCODE_STORAGE="$HOME/Library/Application Support/Code/User/globalStorage/storage.json"
if [[ -f "$VSCODE_STORAGE" ]]; then
  echo "→ Starting watchers for open VS Code workspaces…"
  VS_STARTED=0
  while IFS= read -r repo; do
    [[ -n "$repo" && -d "$repo/.git" ]] || continue
    repo_hash=$(echo "$repo" | md5)
    pidfile="/tmp/gai-watch-${repo_hash}.pid"
    if [[ -f "$pidfile" ]]; then
      pid=$(awk '{print $1}' "$pidfile" 2>/dev/null)
      kill -0 "$pid" 2>/dev/null && continue
      rm -f "$pidfile"
    fi
    (
      cd "$repo" || exit
      gai-watch > "/tmp/gai-watch-${repo_hash}.log" 2>&1 &
      new_pid=$!
      disown "$new_pid" 2>/dev/null || true
      echo "$new_pid $repo" > "$pidfile"
    )
    VS_STARTED=$((VS_STARTED + 1))
    echo "  ✓ $(basename "$repo")"
  done < <(python3 - <<'PYEOF'
import json, os, sys
path = os.path.expanduser(
    "~/Library/Application Support/Code/User/globalStorage/storage.json"
)
try:
    with open(path) as f:
        d = json.load(f)
    folders = d.get("backupWorkspaces", {}).get("folders", [])
    for item in folders:
        uri = item.get("folderUri", "")
        if uri.startswith("file://"):
            print(uri[7:])
except Exception:
    pass
PYEOF
)
  [[ $VS_STARTED -gt 0 ]] || echo "  (no new workspaces to watch)"
fi

# ── done ─────────────────────────────────────────────────────────────────────

echo ""
echo "━━━ gai-tools v$VERSION installed ━━━"
echo ""
echo "  Stage any file in a git repo — it will auto-commit."
echo ""
echo "  (First install only: open a new terminal or run 'source ~/.zshrc')"
echo ""
echo "  Commands:"
echo "    gai              # commit staged files"
echo "    gai --all        # commit all dirty files"
echo "    gai --dry-run    # preview without committing"
echo "    gai --logs       # view last 24 h of activity"
echo "    gai-watch        # start watcher manually"
echo ""
echo "  Docs: https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools"
