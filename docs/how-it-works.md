# How It Works

## Architecture

```
Shell opens in a git repo
        ↓
~/.zshrc sources → _gai_watch_start() fires
        ↓
PID file check: /tmp/gai-watch-<md5-of-repo>.pid
  already running? → skip (multiple tabs safe)
  not running?     → gai-watch starts in background
        ↓
You stage files (VS Code or git add)
        ↓
fswatch detects .git/index change (2s debounce)
        ↓
5-second guard prevents loop (commit changes index too)
        ↓
gai runs:
  1. git reset HEAD          (unstages all)
  2. for each file:
     a. git add -- <file>    (re-stages individually)
     b. git diff --cached    (get the diff)
     c. POST to Ollama API   (generate commit message)
     d. git commit -m "..."  (commit that file)
        ↓
One commit per file. Conventional format.
```

## Components

### `gai` (`~/.local/bin/gai`)

- Reads `GAI_MODEL` env var (default: `qwen2.5-coder:1.5b`)
- Calls Ollama at `http://localhost:11434/api/generate`
- Uses `python3` for safe JSON encoding (always on macOS)
- Two modes: `staged` (default), `all`
- Skips secret files, missing files, empty diffs

### `gai-watch` (`~/.local/bin/gai-watch`)

- Uses `fswatch -o --latency 2` on `.git/index`
- 5-second guard: `LAST_RUN` prevents loop from commit triggering re-run
- Runs `gai` in repo root via `(cd "$REPO_ROOT" && gai)`

### `~/.zshrc` hook

```zsh
_gai_pidfile()     → /tmp/gai-watch-$(echo "$repo" | md5).pid
_gai_watch_start() → checks PID file, starts watcher if not alive
chpwd()            → fires on every cd
_gai_watch_start   → also fires on shell init (covers VS Code terminal open)
```

One PID file per repo path → multiple terminal tabs share one watcher.

## Ollama API

Request:
```json
{
  "model": "qwen2.5-coder:1.5b",
  "prompt": "Write a git commit message in conventional commit format...\n\nDiff:\n<diff>",
  "stream": false
}
```

Response: parses `.response`, takes first non-empty line, strips quotes/backticks.
