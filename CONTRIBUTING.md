# Contributing to gai-tools

Every change goes through a pull request. Direct pushes to `main` are not allowed.

---

## Workflow

```
fork → branch → change → PR → review → merge → auto-release
```

### 1. Fork and clone

```bash
gh repo fork Navibyte-Innovations-Pvt-Ltd/gai-tools --clone
cd gai-tools
```

### 2. Create a branch

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/short-description` | `feat/add-linux-support` |
| Bug fix | `fix/short-description` | `fix/watcher-not-starting` |
| Docs | `docs/short-description` | `docs/improve-readme` |
| Chore | `chore/short-description` | `chore/update-actions` |

```bash
git checkout -b feat/your-feature
```

### 3. Make your changes

- Edit `gai`, `gai-watch`, `install.sh`, or `uninstall.sh`
- Test locally: `bash install.sh && source ~/.zshrc`
- Run shellcheck: `shellcheck -s bash gai gai-watch install.sh uninstall.sh`
- **Update `CHANGELOG.md`** under `[Unreleased]` — CI auto-fills it if you forget, but better to write it yourself

### 4. Open a PR

```bash
git push origin feat/your-feature
gh pr create --fill
```

PR checklist:
- [ ] `shellcheck` passes — no errors
- [ ] Tested manually on macOS
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

CI runs automatically on every PR:
- **shellcheck** — lint all scripts (must pass)
- **changelog** — auto-updates `[Unreleased]` from commit messages if not already updated

Both checks must pass before merge. Direct push to `main` is blocked.

### 5. After merge

GitHub Actions automatically:
- Bumps patch version
- Builds `gai-tools-vX.Y.Z.tar.gz`
- Creates GitHub Release with tarball + changelog
- Publishes to GitHub Packages (npm)

### 6. Update installed version

After a release, run on any machine that has gai installed:

```bash
gai update
```

---

## Key constraints

| Constraint | Why |
|-----------|-----|
| macOS only | Uses `fswatch`, `md5`, `brew` — not cross-platform |
| bash 3.2 | macOS ships bash 3.2 — no `declare -A`, no `mapfile` |
| BSD sed | Use `sed -i ''`, `-E` for alternation — not GNU sed |
| No API keys | Ollama only — must work 100% offline |

---

## Reporting bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).

## Suggesting features

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).
