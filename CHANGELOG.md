# Changelog

All notable changes to gai-tools are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) — [Semantic Versioning](https://semver.org)

---

## [Unreleased]
### Added

- feat(gai): update local Ollama with latest version

### Fixed

- fix(gai-watch): add logging and prune old logs

### Fixed

- fix(install): strip leading v from tag_name to avoid double-v in banner

### Changed

- docs: update contributing guide, usage, and README


---

## [1.0.0] — 2026-05-19

### Added
- `gai` — AI git commit script using Ollama (`qwen2.5-coder:1.5b`)
- `gai-watch` — `fswatch`-based watcher that auto-runs `gai` when files are staged
- `install.sh` — one-command installer (Homebrew, Ollama, fswatch, model pull, shell hook)
- `uninstall.sh` — clean removal of all installed components
- `~/.zshrc` hook — auto-starts `gai-watch` on shell open, one watcher per repo via PID file
- Staged mode (default): commit each staged file individually with its own AI message
- `--all` mode: commit all dirty files
- `--dry-run` flag: preview messages without committing
- Secret file detection: skips `*.env*`, `*credentials*`, `*secret*`, `*.key`, `id_rsa`, `id_ed25519`
- `GAI_MODEL` env var to switch Ollama models

[Unreleased]: https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Navibyte-Innovations-Pvt-Ltd/gai-tools/releases/tag/v1.0.0
