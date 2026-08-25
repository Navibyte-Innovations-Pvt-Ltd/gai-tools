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
fswatch detects an index write under .git/ (2s debounce)
        ↓
5-second guard prevents loop (commit changes index too)
        ↓
gai runs:
  for each staged file:
    a. git add -- <file>            (index == worktree for this file)
    b. git diff --cached -- <file>  (get the diff)
    c. POST to Ollama API           (generate commit message)
    d. git commit -m "..." -- <file>(commit ONLY this file)
  then re-scan the index and repeat for anything staged mid-run
        ↓
One commit per file. Conventional format.
```

## Components

### `gai` (`~/.local/bin/gai`)

- Reads `GAI_MODEL` env var (default: `qwen2.5-coder:1.5b`)
- Calls Ollama at `http://localhost:11434/api/generate`
- Uses `python3` for safe JSON encoding (always on macOS)
- Two modes: `staged` (default), `all`
- Skips secret files, missing files, empty diffs. Secret detection is two gates:
  basename match (`.env`, `*.pem`, `credentials.json` — never a directory name)
  and a scan of the added lines for known provider key prefixes. Both are
  overridable via `--force`, `GAI_ALLOW_PATHS`, or `allow=` lines in `.gairc`

### `gai-watch` (`~/.local/bin/gai-watch`)

- Uses `fswatch -o --latency 2` on `$GIT_DIR`, filtered to `/index$`. It watches
  the directory, not the `index` path: git replaces that inode on every `git add`
  (it writes `index.lock` and renames), and the directory watch covers
  `.git/modules/<name>/index` for submodules for free
- Re-arms: if `fswatch` exits for any reason the pipeline is restarted after 2s
  and the restart is logged — it never dies in silence
- Owns `/tmp/gai-watch-<md5-of-repo>.pid` (its own `$$`), touches it on every
  trigger as a heartbeat, and removes it in an `EXIT` trap that logs the exit code
- 5-second guard: `LAST_RUN` prevents loop from commit triggering re-run; a
  throttled trigger is logged rather than dropped silently
- Runs `gai` with stdin from `/dev/null` — anything gai read from an inherited
  stdin would drain the fswatch pipe and end the watch loop

### `~/.zshrc` hook

```zsh
_gai_pidfile()     → /tmp/gai-watch-$(echo "$repo" | md5).pid
_gai_watch_start() → checks PID file, confirms the PID is really a gai-watch
                     (a recycled PID otherwise makes a dead watcher look alive
                     forever), starts the watcher if not
_gai_chpwd_hook()  → registered with add-zsh-hook, fires on every cd
_gai_watch_start   → also fires on shell init (covers VS Code terminal open)
```

Registered via `add-zsh-hook chpwd`, not a bare `chpwd()` definition — a bare one
clobbers any `chpwd` the user already has. The hook returns early when
`_gai_watch_start` is undefined, which is what non-interactive shells (scripts,
CI, agent shells) get; before that guard every `cd` in such a shell printed
`chpwd:3: command not found: _gai_watch_start`.

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
