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
gai issue <url>  # attach a GitHub issue to an open PR, then offer a Claude session
gai-watch        # start watcher manually
gai-watch --dry-run  # watch + preview only
```

## Working an Issue

```bash
gai issue https://github.com/owner/repo/issues/123
```

Two things happen, in order:

1. **Attach.** `gai` lists the open PRs on that repo, auto-picks the only one or
   shows an arrow-key menu, and appends `Closes #123` to its body. If the issue is
   already referenced it says so and moves on — it does not stop.
2. **Offer a Claude session.** It asks `Start a Claude session on issue #123 with
   full context? [Y/n]`. Answer yes and it pulls the issue's title, labels,
   description and every comment through `gh`, then prompts for one optional line
   of extra instructions. It builds a single prompt out of all of it and `exec`s
   `claude` in the current directory — so the session starts in your repo, already
   holding the whole thread. No pasting the URL and waiting for Claude to fetch it.

The offer fires on **every** run, including when the issue is already attached, so
re-running the command is how you start work on an issue you linked yesterday.

Flags and edge cases:

- `--dry-run` prints the composed prompt and exits instead of launching Claude.
- Answering `n` skips the session; the attach already happened.
- No TTY (piped or scripted) skips the offer and prints the manual command.
- No `claude` on `PATH` skips the offer silently.
- No open PRs in the repo skips the attach but still offers the session.

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

Two independent secret gates, both deliberately narrow. A directory name never
counts — `app/api/client-credentials/route.ts` is ordinary source and commits
normally.

**1. Filename** — only names that *are* a secret store, matched on the basename:

| Rule | Examples |
|------|----------|
| Environment files | `.env`, `.env.local`, `.env.production`, `app.env` |
| Private keys / keystores | `id_rsa`, `id_ed25519`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.gpg` |
| Credential stores | `credentials.json`, `secrets.yml`, `*.secret`, `.netrc`, `.pgpass`, `.htpasswd`, `service-account*.json` |

`.env.example`, `.env.sample` and `.env.template` are **not** blocked — they are
meant to be committed. Their contents are still scanned by gate 2.

**2. Content** — the *added* lines are checked for live credential prefixes
issued by a known provider (AWS access keys, OpenAI/Anthropic keys, GitHub
tokens, Slack tokens, Google API keys, GitLab PATs, npm/PyPI tokens, Twilio
SIDs, PEM private-key headers). No entropy guessing, so a `password = "hunter2"`
test fixture commits fine. This gate applies to every file, source extensions
included — a leak lives in the diff, never in the path. `.npmrc` and `.pypirc`
are therefore committed on name alone and blocked only if a real token is in the
diff.

A file rejected by this gate has already been added to the index (the diff has
to be read from somewhere). Nothing is committed, but if you had `git add -p`'d
a partial hunk, unstage before re-splitting it: `git reset HEAD -- <file>`.

Also skipped: files with no staged diff, files where the model returns an empty
message.

### Overriding a false positive

Each skip prints why it was flagged and how to override it:

```
⚠ skip (secret): apps/api/client-credentials/route.ts
    why: filename 'route.ts' is a known credential store
    commit anyway: gai --force   |   always allow: echo 'allow=apps/...' >> .gairc
```

| Override | Scope |
|----------|-------|
| `gai --force` | One interactive run. Skips both gates entirely. `gai-watch` never passes it. |
| `export GAI_ALLOW_PATHS='src/lib/keys.ts:fixtures/*.env'` | Your shell. Colon-separated repo-relative globs. |
| `allow=<glob>` lines in `<repo>/.gairc` | The whole team, committed with the repo. Also what `gai-watch` reads, since a background watcher has no flags to pass. |

```bash
# <repo>/.gairc
# Anything listed here is never treated as a secret.
allow=apps/web/lib/secrets/*.ts
allow=fixtures/*.env
```

The file is read line by line — it is never `source`d, so it cannot execute
anything.

### Where skipped files end up

In the default (staged) mode these files **stay staged** and are named at the end
of the run, so nothing loses its staged state:

```
⚠ 1 file(s) still staged and uncommitted:
  - app.env
```

In `--all` mode they are left unstaged instead, since nothing had staged them.
