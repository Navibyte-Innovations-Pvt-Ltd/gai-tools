# Troubleshooting

## gai-watch not starting automatically

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

Files listed there were skipped on purpose — a secret-looking path
(`.env`, `credentials`, `*.key`), an empty staged diff, or a failed commit. They
stay staged; commit them yourself or rename the file if the secret match was a
false positive.

## Multiple watchers running

```bash
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
