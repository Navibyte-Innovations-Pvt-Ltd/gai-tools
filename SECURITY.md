# Security Policy

## Scope

gai-tools runs shell scripts locally and calls Ollama at `localhost:11434`. It never makes outbound network requests beyond your machine.

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |

## Reporting a vulnerability

Do **not** open a public issue for security vulnerabilities.

Email: **bhosalenaresh73@gmail.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact

Response within 48 hours. If confirmed, a patch will be released and you'll be credited in the changelog.

## Security considerations for users

- Scripts install to `~/.local/bin/` — no system-level writes, no `sudo` required
- Ollama runs locally — diffs never leave your machine
- Secret file detection skips `.env*`, `credentials`, `secret`, `.key`, `id_rsa`, `id_ed25519`
- PID files written to `/tmp/` — no persistent state beyond the running watcher
- No telemetry, no analytics, no network calls except `localhost:11434`
