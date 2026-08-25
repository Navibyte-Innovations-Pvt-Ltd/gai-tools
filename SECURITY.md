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
- Secret detection has two gates: the **basename** (`.env*`, `*.pem`, `*.key`,
  `id_rsa`, `credentials.json`, `.netrc`, …) and the **added lines** of the diff,
  scanned for known provider key prefixes (`AKIA`, `sk-`, `ghp_`, `npm_`, PEM
  headers, …). Directory names are never matched. Both gates are overridable by
  the user via `gai --force`, `GAI_ALLOW_PATHS`, or `allow=<glob>` lines in a
  repo-root `.gairc` — see [docs/usage.md](docs/usage.md#what-gai-skips)
- `.gairc` is read line by line and never `source`d, so a repo cannot execute
  code through it
- PID files written to `/tmp/` — no persistent state beyond the running watcher
- No telemetry, no analytics, no network calls except `localhost:11434`
