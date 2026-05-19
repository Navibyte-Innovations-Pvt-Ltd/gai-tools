# gai-tools

> AI-powered git auto-commit for macOS — stage files, they commit themselves.

[![Lint](https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/actions/workflows/lint.yml/badge.svg)](https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/actions/workflows/lint.yml)
[![Release](https://img.shields.io/github/v/release/Navibyte-Innovations-Pvt-Ltd/gai-tools?include_prereleases)](https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey)
![Shell: bash](https://img.shields.io/badge/shell-bash%203.2%2B-blue)
![AI: Ollama local](https://img.shields.io/badge/AI-Ollama%20local-green)

---

## What it does

Stage a file → it auto-commits with an AI-generated conventional commit message. No typing. No API keys. Runs 100% locally using [Ollama](https://ollama.com).

```
$ git add components/Input.tsx

━━━ staged: 1 file(s) ━━━

── components/Input.tsx
  → refactor(input): reduce height to 46px and update border radius

Committed: 1 file(s).
```

---

## Install

**Quick install (latest release):**
```bash
curl -L https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/releases/latest/download/gai-tools-latest.tar.gz | tar -xz
bash install.sh
source ~/.zshrc
```

**From source:**
```bash
git clone https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools
cd gai-tools
bash install.sh
source ~/.zshrc
```

The installer handles everything: Homebrew check, `fswatch`, `ollama`, model download (~986MB one-time), script install, and shell hook.

---

## Usage

| Command | Description |
|---------|-------------|
| `gai` | Commit staged files one by one |
| `gai --all` | Commit all dirty files |
| `gai --dry-run` | Preview messages without committing |
| `gai-watch` | Start watcher manually |
| `gai-watch --dry-run` | Watch + preview only |
| `gai --help` | Show help |

### Custom model

```bash
export GAI_MODEL=qwen2.5-coder:7b   # use a larger model
```

Default: `qwen2.5-coder:1.5b` (~200ms on Apple Silicon)

---

## How it works

```
Shell opens in a git repo
      ↓
~/.zshrc hook starts gai-watch in background (one per repo globally via PID file)
      ↓
You stage files (VS Code or git add)
      ↓
fswatch detects .git/index change
      ↓
gai: unstages all → re-stages + commits each file individually
      ↓
Ollama generates conventional commit message per file
      ↓
git commit -m "type(scope): description"
```

---

## Requirements

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh)
- bash 3.2+ (macOS default)
- zsh shell

---

## Uninstall

```bash
cd gai-tools
bash uninstall.sh
```

---

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

**Quick checks:**
```bash
cat /tmp/gai-watch.log   # watcher log
gai --dry-run            # test manually
ollama serve             # if Ollama not running
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © [Navibyte Innovations Pvt Ltd](https://github.com/Navibyte-Innovations-Pvt-Ltd)
