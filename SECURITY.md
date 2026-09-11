# Security Policy

## Scope

gai-tools runs shell scripts locally. Commit messages come from Ollama at `localhost:11434`; `gai pr` and `gai issue` talk to GitHub through `gh`, and `gai issue` can hand off to a `claude` session you choose to start.

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
- PID files go to `/tmp/`; logs (kept 24 h) and pasted images (kept 7 days) live
  under `~/.gai/`
- `gai issue` reads the clipboard only when you press Ctrl+V at its
  extra-instructions prompt. The image is saved under `~/.gai/images/` and
  reaches Claude only through the session you start; that session is granted
  that run's folder alone
- No telemetry or analytics. Diffs go only to `localhost:11434`; the only other
  traffic is `gh` (GitHub) and the `claude` session you choose to start
