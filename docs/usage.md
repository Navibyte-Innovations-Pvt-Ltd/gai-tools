# Usage

## Automatic (normal workflow)

1. Open any terminal inside a git repo
2. `gai-watch` starts in the background automatically
3. Stage files with VS Code UI or `git add`
4. Commits happen — one per file, AI message per file

## Manual Commands

```bash
gai              # commit staged files one by one
gai --all        # commit ALL dirty files (staged + unstaged)
gai --dry-run    # preview messages without committing
gai update       # update to latest release from GitHub
gai-watch        # start watcher manually
gai-watch --dry-run  # watch + preview only
```

## Commit Format

`type(scope): description`

| Type | When |
|------|------|
| `feat` | new feature or capability |
| `fix` | bug fix |
| `refactor` | restructure without behavior change |
| `style` | formatting, spacing, no logic change |
| `docs` | documentation only |
| `test` | adding or updating tests |
| `chore` | build, config, dependencies |
| `perf` | performance improvement |

Scope = most specific directory/component name from the file path.

Example: `refactor(input-address): convert Controller to useController hook`

## Custom Model

```bash
# one-off
GAI_MODEL=qwen2.5-coder:7b gai

# permanent for session
export GAI_MODEL=qwen2.5-coder:7b

# add to ~/.zshrc to persist across sessions
echo 'export GAI_MODEL=qwen2.5-coder:7b' >> ~/.zshrc
```

Available models (pull first with `ollama pull <name>`):

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| `qwen2.5-coder:1.5b` | 986MB | ~200ms | good (default) |
| `qwen2.5-coder:7b` | 4.7GB | ~800ms | better |
| `llama3.2:3b` | 2GB | ~400ms | general purpose |

## What gai Skips

- Files matching: `*.env*`, `*credentials*`, `*secret*`, `*.key`, `id_rsa`, `id_ed25519`
- Files with no staged diff
- Files where model returns empty message

These files are unstaged and left for you to handle.
