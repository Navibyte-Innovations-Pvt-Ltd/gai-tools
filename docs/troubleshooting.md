# Troubleshooting

## gai-watch not starting automatically

```bash
source ~/.zshrc                  # reload zshrc in current shell
ls /tmp/gai-watch-*.pid          # check if PID file exists
cat /tmp/gai-watch.log           # check watcher log for errors
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
cat /tmp/gai-watch.log           # errors from watcher
gai --dry-run                    # test manually
git diff --cached --name-only    # confirm files are actually staged
ps aux | grep gai-watch          # confirm watcher is running
```

## Multiple watchers running

```bash
ps aux | grep gai-watch          # should show exactly 1 per repo
pkill -f gai-watch && rm -f /tmp/gai-watch-*.pid
source ~/.zshrc                  # restart cleanly
```

## Watcher stops mid-session

`fswatch` may have crashed. Check and restart:

```bash
cat /tmp/gai-watch.log
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
