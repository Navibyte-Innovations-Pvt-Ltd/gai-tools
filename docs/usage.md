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
gai pr           # open a PR from the current branch (offers to branch off main)
gai issue 123    # attach an issue to a PR and rewrite its title/body, repo from cwd
gai issue <url>  # same, for an issue in any repo
gai issue 123 --remove   # detach an issue you attached by mistake
gai-watch        # start watcher manually
gai-watch --dry-run  # watch + preview only
```

## Opening a PR

```bash
gai pr
```

Pushes the current branch, AI-generates a title and body from the commits ahead of
the base branch, and opens the PR with you as assignee.

**Standing on `main` (or `master`, or the repo's default branch)** it no longer
dead-ends. It asks:

```
On 'main' — a PR needs a feature branch.
Branch name [dev] (n to abort):
```

Press Enter to take `dev`, type any other name to use that, or type `n` to abort.
If the branch already exists it switches to it instead of failing; naming a base
branch is rejected. Piped or scripted (no TTY) it still errors out rather than
creating a branch behind your back.

With no commits ahead of the base it then offers `Create an empty commit to open
the PR anyway? [Y/n]` — Enter accepts. That is the fast path to an empty PR you can
fill in later with `gai issue`. If a PR already exists for the branch, `gai pr`
prints its URL instead of erroring.

## Working an Issue

```bash
gai issue 123                                        # repo from cwd
gai issue https://github.com/owner/repo/issues/123   # any repo
gai issue 123 --remove                               # detach it again
```

A bare number (or `#123`) resolves against the repo you are standing in, via
`gh repo view`. A full URL works from anywhere.

Three things happen, in order:

1. **Make sure a PR exists.** If the repo has no open PR, `gai` asks
   `Create one now? [Y/n]` and runs the full `gai pr` flow — push the branch,
   AI-generate title and body, open the PR — then picks it up. Answer `n` and it
   skips the attach and goes straight to step 3. Creating requires you to be
   standing in that same repo; a URL for a different repo stops with an error
   telling you where to `cd`. On `main`/`master`, `gai pr` offers to cut a branch
   first (see below) instead of failing. If `gai pr` fails for another reason
   (nothing to push, Ollama down) the command aborts — fix the blocker and re-run.
2. **Attach and rewrite.** `gai` lists the open PRs, auto-picks the only one or
   shows an arrow-key menu, then rebuilds that PR from the issue thread: it pulls
   the issue's title and body, regenerates the PR **title** and **body** through
   Ollama, and rewrites the closing block. Everything the PR already closed stays —
   `Fixes #9`, `resolved #7` and `Closes #12` are all collected, deduped and
   re-emitted as one canonical block with the new issue appended:

   ```markdown
   <!-- gai:closes -->
   Closes #9
   Closes #12
   Closes #31
   ```

   So the usual loop — `gai pr` opens an empty PR, then `gai issue 31` fills it in,
   then `gai issue 47` fills it in again — ends with a PR whose title and body cover
   both issues and whose closing block lists both. Re-running on an already-attached
   issue is a refresh, not a no-op.

   **Attached the wrong issue?** `gai issue 34 --remove` (or `-r`) is the undo.
   It drops `#34` from the closing block, keeps every other issue, and rewrites
   the title and body from the issues that *remain* — the mistaken attach is
   usually what the old title was generated from, so removing only the `Closes`
   line would leave the visible half of the mistake behind. Remove the last one
   and the block goes with it: the PR ends up with a plain body and no
   `<!-- gai:closes -->` marker, and the title and body fall back to describing
   the commits. `--remove` never creates a PR (there would be nothing to detach
   from) and never offers a Claude session — you are stepping away from that
   issue, not starting on it. Removing an issue the PR does not reference prints
   `nothing to remove` and exits without touching the PR.

   Context comes from the **PR's own** `headRefName` and commit list via `gh`, never
   from local `git log`, so picking a PR for a branch you do not have checked out
   still produces a body that describes that PR.

   It asks `Apply this title and body to PR #35? [Y/n]` before writing — answer `n`
   to keep the PR as-is and go to step 3. Rewriting never happens unattended: with
   Ollama stopped, or with no TTY to confirm at, it says so and updates only the
   closing block, leaving the title and body untouched.

   The whole rewrite gets a **15-second budget** — title and body together, not
   each. On a machine with no spare GPU or RAM a 1.5b model can grind for
   minutes, and attaching the issue matters more than a fresh title, so a run
   that blows the budget prints `⚠ Model did not finish inside 15s` and writes
   only the closing block. It is all-or-nothing: a fresh title above a stale
   body describes neither, so a body that misses the deadline discards the title
   too. The title is generated first because it is the cheaper prompt; if it
   times out, the body is skipped outright. Raise the budget with
   `GAI_ISSUE_TIMEOUT=60 gai issue 123`. `gai pr` has no budget: it has no
   existing title or body to fall back on, so it waits as long as the model needs.

   Only *standalone* closing lines are absorbed into the block. A closing reference
   buried in a sentence — `This PR closes #9 and adds retries.` — still counts
   toward the block, but the sentence itself stays in the prose, so #9 ends up
   mentioned twice. Harmless, and it beats dropping a genuinely linked issue.

   Under `--remove` that same asymmetry is not harmless: the canonical line goes
   away while the sentence keeps closing the issue, so GitHub would still shut it
   on merge. `gai` checks for it and prints
   `⚠ #34 is still closed by prose left in the PR body` with the offending line
   and its number. It will not rewrite your prose — edit that line by hand.
3. **Offer a Claude session.** It asks `Start a Claude session on issue #123 with
   full context? [Y/n]`. Answer yes and it pulls the issue's title, labels,
   description and every comment through `gh`, then prompts for one optional line
   of extra instructions. It builds a single prompt out of all of it and `exec`s
   `claude` in the current directory — so the session starts in your repo, already
   holding the whole thread. No pasting the URL and waiting for Claude to fetch it.

The offer fires on **every** run, including when the issue is already attached, so
re-running the command is how you start work on an issue you linked yesterday.

Flags and edge cases:

- `--dry-run` makes **no GitHub writes at all** — it never opens a PR, never edits a
  PR title or body, and prints the composed prompt instead of launching Claude. It
  does print the title and body it *would* have written.
- `--remove` (`-r`) detaches instead of attaching; combine with `--dry-run` to see
  the resulting title and body before writing anything.
- Answering `n` skips the session; the attach already happened.
- No TTY (piped or scripted) skips the offer and prints the manual command.
- No `claude` on `PATH` skips the offer silently.
- Declining PR creation skips the attach but still offers the session.

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
