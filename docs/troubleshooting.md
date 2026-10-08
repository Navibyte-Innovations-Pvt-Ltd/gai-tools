# Troubleshooting

## gai-watch not starting automatically

Some repos are skipped on purpose (CI checkouts, temp dirs, worktrees, your
`~/.gai/watch` rules); the reason is in `/tmp/gai-watch-<hash>.log`. See
[Which Repos Are Watched](usage.md#which-repos-are-watched).

```bash
source ~/.zshrc                  # reload zshrc in current shell
ls /tmp/gai-watch-*.pid          # check if PID file exists
cat ~/.gai/logs/$(date +%F).watch.log   # check watcher log for errors
```

## "Ollama not running" error

```bash
ollama serve                     # start manually in a terminal
```

To start Ollama automatically at login:
- Open **System Settings → General → Login Items**
- Add **Ollama.app** (install from [ollama.com](https://ollama.com))

## "model not found" error

```bash
ollama pull qwen2.5-coder:1.5b
```

## Files staged but nothing commits

```bash
cat ~/.gai/logs/$(date +%F).watch.log   # errors from watcher
gai --dry-run                    # test manually
git diff --cached --name-only    # confirm files are actually staged
ps aux | grep gai-watch          # confirm watcher is running
```

The watcher writes a line for every reason it declines to act — `index.lock` held,
throttled, fswatch restarted, exiting — so the day's log is the first place to
look:

```bash
cat ~/.gai/logs/$(date +%F).watch.log
```

A watcher that dies now logs `gai-watch exiting (code N)` and removes its PID
file, and `fswatch` exiting on its own is restarted after 2s with a logged line.
If the log simply stops with no exit line, the process was killed with `SIGKILL`
(or the machine slept) — restart it by `cd`-ing into the repo, or run `gai-watch`.

## gai stops mid-run, or staged files sit until you type `gai`

Three things used to strand staged files with nothing in the log:

- **Ollama never answered.** Each commit message now has a 60 s budget
  (`GAI_COMMIT_TIMEOUT`), the reply is capped and diffs are cut at
  `GAI_MAX_DIFF_CHARS` (12000). A timeout logs
  `✗ Ollama timed out after 60s (GAI_COMMIT_TIMEOUT) — leaving <file> uncommitted`.
  Each message line ends with its time, e.g. `→ fix(x): … (14s)`; a slow model
  (busy GPU, low RAM, model reloading after 5 min idle) shows up there.
- **A trigger was lost** — staged while another run held the lock, or a commit
  lost an `index.lock` race. Commits now retry `index.lock` twice, and every
  watcher sweeps every 2 min (`GAI_WATCH_SWEEP`, `0` = off) and once at start:
  `sweep: N file(s) left staged — running gai`. Unchanged leftovers (a secret
  skip) are retried every 15 min, not every pass.
- **A stale run lock** (`/tmp/gai-run-<hash>.lock`) whose PID was reused by
  another process. It now counts only if the owner is a running `gai`.

Every run header names the repo and who started it:
`── gai 2026-10-08 00:00:17 repo:glitchgrab (watcher) ──` — `(manual)` is a
hand-typed `gai`. Logs are kept `GAI_LOG_DAYS` days (default 7).

## Part of a large batch was left uncommitted

`gai` commits one file per commit with a pathspec (`git commit -m … -- <file>`),
so files further down the queue keep their staged state until their turn, and a
file staged by something else mid-run is never swept into another file's commit.
When a run finishes it re-scans the index and starts another pass for anything
staged while it was busy (up to 5 passes).

Anything still staged at the end is named in the run's own output:

```
⚠ 2 file(s) still staged and uncommitted:
  - prisma/schema.prisma
```

Files listed there were skipped on purpose — a secret filename (`.env`,
`*.key`, `credentials.json`), a live credential prefix found in the added lines,
an empty staged diff, or a failed commit. Every secret skip prints *why* it was
flagged and the exact command to override it. See
[What gai Skips](usage.md#what-gai-skips).

Directory names are not matched: a path containing `credentials/` or `secrets/`
commits normally. If gai is still wrong about a file, commit it with
`gai --force`, or add `allow=<glob>` to `<repo>/.gairc` so `gai-watch` stops
retrying it too.

## Multiple watchers running

```bash
gai status                       # every watcher, its repo, when last used
ps aux | grep gai-watch          # should show exactly 1 per repo
pkill -f gai-watch && rm -f /tmp/gai-watch-*.pid
source ~/.zshrc                  # restart cleanly
```

## Watcher stops mid-session

`fswatch` may have crashed. Check and restart:

```bash
cat ~/.gai/logs/$(date +%F).watch.log
pkill -f gai-watch; rm -f /tmp/gai-watch-*.pid
gai-watch &                      # restart manually
```

## Poor commit message quality

Switch to a larger model:

```bash
ollama pull qwen2.5-coder:7b
export GAI_MODEL=qwen2.5-coder:7b
pkill -f gai-watch; rm -f /tmp/gai-watch-*.pid
source ~/.zshrc
```

## Accidentally committed a secret file

`gai` never force-pushes. Rotate the secret immediately, then:

```bash
git revert HEAD    # create a revert commit
# OR
git reset HEAD~1   # undo commit, keep file staged
```

Then add the file pattern to `.gitignore`.

## Reinstalling on a new laptop

```bash
git clone https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools
cd gai-tools
bash install.sh
source ~/.zshrc
```

Everything is handled by `install.sh` — Homebrew deps, Ollama, model download, script install, shell hook.
