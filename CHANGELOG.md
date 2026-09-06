# Changelog

All notable changes to gai-tools are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) — [Semantic Versioning](https://semver.org)

---

## [Unreleased]
### Added

- feat(gai): `gai issue` accepts a bare issue number (`gai issue 1677`) and resolves
  the repo from the current directory via `gh repo view`. Full URLs still work from
  anywhere
- feat(gai): when the repo has no open PR, `gai issue` offers to create one and runs
  the `gai pr` flow, then attaches the issue to the PR it just made. Creating requires
  you to be standing in the issue's repo; a `gai pr` failure aborts rather than
  attaching to nothing. `gai issue --dry-run` makes no GitHub writes — it neither
  opens a PR nor edits a PR body
- feat(gai): `gai issue <url>` now offers to start a Claude session seeded with the
  full issue thread — title, labels, description and every comment — plus one
  optional line of extra instructions, then `exec`s `claude` in the current repo.
  The offer fires on every run, including when the issue is already attached to the
  PR, so re-running the command is how you pick work back up. `--dry-run` prints the
  composed prompt instead of launching; no TTY or no `claude` on `PATH` skips it

- feat(gai): `--force` flag plus a `GAI_ALLOW_PATHS` env glob list and `allow=<glob>`
  lines in a repo-root `.gairc` to override the secret check. `.gairc` is read line
  by line, never `source`d, and is the only override `gai-watch` can see (#31)
- feat(gai): scan the added lines of each diff for known provider key prefixes
  (`AKIA`, `sk-`, `ghp_`, `github_pat_`, `xox?-`, `AIza`, `glpat-`, `npm_`,
  `pypi-`, PEM headers). No entropy heuristics, so ordinary fixtures still
  commit (#31)

### Fixed

- fix(gai): an invalid issue reference printed nothing and exited 1 — `set -e` aborted
  on the non-matching `grep` before the error message ran

- fix(gai): match secret filenames on the **basename**, not a substring of the whole
  path — a directory named `client-credentials/` or `secrets/` no longer blocks every
  source file beneath it. `.env.example`/`.sample`/`.template` now commit too, and
  every skip prints why it was flagged and the exact command to override it (#31)
- fix(gai): run from the repository root. Invoked from a subdirectory, the
  root-relative paths git hands back were resolved against the wrong base and
  nothing committed at all (#31)

- fix(gai-watch): survive a dead `fswatch` and never exit silently — the watch
  pipeline re-arms after 2 s, an `EXIT` trap logs the exit code, `INT`/`TERM` tear
  the pipeline down instead of sitting queued behind it, and throttled triggers
  are logged rather than dropped (#28)
- fix(gai-watch): own the PID file (`$$`), heartbeat it on every trigger, and
  remove it on exit — a hand-started watcher previously left none and got
  duplicated (#28)
- fix(gai-watch): watch `$GIT_DIR` filtered to `/index$` instead of the
  `.git/index` path, which git replaces on every `git add`; covers submodule
  indices for free (#28)
- fix(gai-watch): run `gai` with stdin from `/dev/null` — an inherited stdin
  drains the fswatch pipe and ends the watch loop with nothing in the log (#28)
- fix(gai): stop unstaging the whole index at the start of a run. Each file is
  committed with a pathspec (`git commit -m … -- <file>`), so files further down
  the queue keep their staged state and a file staged by another process mid-run
  is never swept into another file's commit under the wrong message (#29)
- fix(gai): re-scan the index when a run finishes and start another pass for
  anything staged while it was busy, up to 5 passes (#29)
- fix(gai): name anything left staged at the end of a run instead of finishing in
  silence (#29)
- fix(gai, install): confirm a PID really belongs to a gai-watch before trusting
  it — a recycled PID made a dead watcher look alive forever (#28)
- fix(install): register the auto-start hook with `add-zsh-hook` instead of
  defining a bare `chpwd()`, which clobbered any user `chpwd` and printed
  `chpwd:3: command not found: _gai_watch_start` on every `cd` in a
  non-interactive shell. `HOOK_MARKER` makes existing installs pick up the new
  block (#28)

### Added

- feat(gai): add `gai pr` subcommand — branch guard + Ollama-generated title/body + `gh pr create`
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
