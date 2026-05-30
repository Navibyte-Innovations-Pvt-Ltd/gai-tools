# CLAUDE.md

## What is this?

`gai-tools` — AI-powered git auto-commit for macOS. Stage files → they commit themselves with AI-generated conventional commit messages via local Ollama.

## Architecture

| File | Role |
|------|------|
| `gai` | Main CLI: parse flags, call Ollama API, commit staged/all files one by one |
| `gai-watch` | Watcher: uses `fswatch` to detect `.git/index` changes, trigger `gai` |
| `install.sh` | Installs deps (Homebrew, fswatch, ollama, model), copies scripts to `~/.local/bin`, patches `.zshrc` |
| `uninstall.sh` | Removes installed scripts and `.zshrc` hook |
| `docs/` | Troubleshooting and usage docs |

**Flow:** `.zshrc` hook → `gai-watch` starts in background per repo → `fswatch` watches `.git/index` → `gai` called → Ollama generates commit message → `git commit`

## Commands

```bash
# Lint (requires shellcheck)
shellcheck -s bash gai gai-watch install.sh uninstall.sh

# Test manually
gai --dry-run           # preview messages without committing
gai-watch --dry-run     # watch + preview only

# Release
# Triggered automatically on push to main via .github/workflows/release.yml
# Auto-bumps patch version, creates GitHub release tarball, publishes to GitHub Packages (npm)
```

## How to make changes

1. Edit `gai` or `gai-watch` (pure bash — bash 3.2+ compatible, no bashisms)
2. Run `shellcheck -s bash gai gai-watch` — must pass clean
3. Test with `gai --dry-run` in a real git repo
4. Commit with conventional commit format: `type(scope): description`
5. Push to `main` → release workflow auto-runs

## Common issues

- **shellcheck SC2015**: Use `if/else` instead of `cmd && x || y` chains
- **bash 3.2 compat**: macOS ships bash 3.2; no `mapfile`/`readarray`, careful with arrays
- **Lock/race**: `gai` uses a lockfile at `/tmp/gai-<repo-hash>.lock` — don't bypass it
- **Ollama not running**: `ollama serve` then `ollama pull qwen2.5-coder:1.5b`
- **Model override**: `export GAI_MODEL=qwen2.5-coder:7b` before running
