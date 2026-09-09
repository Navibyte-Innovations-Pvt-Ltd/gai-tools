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

**Every question comes first, then it runs on its own.** Nothing after the last
prompt asks anything — it prints a one-line plan and works through it:

```
On 'main' — a PR needs a feature branch.
Branch name [dev] (n to abort):
No commits ahead of 'origin/main' — nothing to diff.
Create an empty commit to open the PR anyway (e.g. for issue tracking)? [Y/n]
→ Plan: branch dev → empty commit → title and body → push → open PR against main
```

That ordering is the point. The two questions used to sit each right above the
step it gated, so answering the first one meant waiting through a branch switch
before being asked the second, and the model runs sat between you and the end.
Now you answer both, walk away, and read the log.

**Branch question** — only on `main`/`master`/the default branch. Enter takes
`dev`, any other name uses that, `n` aborts. An existing branch is switched to
rather than failing; naming a base branch is rejected.

**Empty-commit question** — only when nothing is ahead of the base. Counted
against the branch you are *going* to be on, so an existing `dev` that already
has commits is never asked about. That is the fast path to an empty PR you fill
in later with `gai issue`. If a PR already exists for the branch, `gai pr` prints
its URL instead of erroring.

Piped or scripted (no TTY) it still errors rather than creating a branch or an
empty commit behind your back — unless you answer ahead of time:

| Flag | Answers |
|------|---------|
| `--branch=<name>` | the branch question |
| `--allow-empty` | the empty-commit question |
| `--yes` (`-y`) | both, with the defaults (`dev`, yes) |
| `--no-generate` | skips the model entirely — deterministic title and body |

`--no-generate` is what `gai issue` passes: it rewrites the title and body from
the issue thread seconds later, so generating them here is a model run you wait
through and never see. It also drops the "Ollama not running" hard stop, which
only ever guarded generation.

## Working an Issue

```bash
gai issue 123                                        # repo from cwd
gai issue https://github.com/owner/repo/issues/123   # any repo
gai issue 123 --remove                               # detach it again
```

A bare number (or `#123`) resolves against the repo you are standing in, via
`gh repo view`. A full URL works from anywhere.

**All the questions come first.** `gai issue` asks everything it needs in one
block, before the first slow step, then runs to the end without stopping:

```
── a few questions, then it runs on its own ──
Create a PR for #354? [Y/n]
Rewrite the PR title and body from the issue thread? [Y/n]
Start a Claude session on #354 when this is done? [Y/n]
Extra instructions for Claude (optional):
```

Only the questions your situation actually raises are asked — an issue going onto
the one open PR of a repo you are already on a branch in gets two, not four. If a
PR has to be created, `gai pr`'s own two questions (branch name, empty commit)
follow immediately, with no slow step in between.

Answering yes to the rewrite **is** the approval. The old flow asked
`Apply this title and body? [Y/n]` *after* the model finished, which is exactly
the wait this ordering removes: you sat watching a generation just to be asked
whether you wanted it.

Then it executes, in order:

1. **Make sure a PR exists.** With no open PR and a `yes` to the creation
   question, it runs `gai pr --no-generate` — branch, empty commit, push, open —
   then resolves the new PR by asking GitHub which PR belongs to the branch you
   are now on. Answer `n` and it skips the attach and goes straight to step 3.
   Creating requires you to be standing in that same repo; a URL for a different
   repo stops with an error telling you where to `cd`, and it stops *before*
   asking anything. If `gai pr` fails for another reason (nothing to push) the
   command aborts — fix the blocker and re-run.
2. **Attach and rewrite.** `gai` rebuilds the PR from the issue thread: it pulls
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

   Rewriting never happens unattended: answer `n` to the rewrite question, or run
   with Ollama stopped or with no TTY, and it updates only the closing block,
   leaving the title and body untouched.

   The whole rewrite gets a **40-second budget** — title and body together, not
   each. On a machine with no spare GPU or RAM a 1.5b model can grind for
   minutes, and attaching the issue matters more than a fresh title, so a run
   that blows the budget prints `⚠ Model did not finish inside 40s` and writes
   only the closing block. It is all-or-nothing: a fresh title above a stale
   body describes neither, so a body that misses the deadline discards the title
   too. The title is generated first because it is the cheaper prompt; if it
   times out, the body is skipped outright. Raise or lower it with
   `GAI_ISSUE_TIMEOUT=60 gai issue 123`.

   The budget is 40 s rather than the old 15 s because this is now the **only**
   generation in the flow. `gai issue` drives PR creation with `--no-generate`,
   so nothing is thrown away — but that also makes this run load-bearing: miss
   the budget on a fresh PR and it keeps the plain `feat(dev): changes from
   branch` fallback.

   Only *standalone* closing lines are absorbed into the block. A closing reference
   buried in a sentence — `This PR closes #9 and adds retries.` — still counts
   toward the block, but the sentence itself stays in the prose, so #9 ends up
   mentioned twice. Harmless, and it beats dropping a genuinely linked issue.

   Under `--remove` that same asymmetry is not harmless: the canonical line goes
   away while the sentence keeps closing the issue, so GitHub would still shut it
   on merge. `gai` checks for it and prints
   `⚠ #34 is still closed by prose left in the PR body` with the offending line
   and its number. It will not rewrite your prose — edit that line by hand.
3. **Launch Claude.** If you said yes up front, it pulls the issue's title,
   labels, description and every comment through `gh`, folds in the extra
   instructions line you already typed, and `exec`s `claude` in the current
   directory — so the session starts in your repo, already holding the whole
   thread. No pasting the URL and waiting for Claude to fetch it.

The question is asked on **every** run, including when the issue is already
attached, so re-running the command is how you start work on an issue you linked
yesterday.

Flags and edge cases:

- `--dry-run` makes **no GitHub writes at all** — it never opens a PR, never edits a
  PR title or body, and prints the composed prompt instead of launching Claude. It
  does print the title and body it *would* have written.
- `--remove` (`-r`) detaches instead of attaching; combine with `--dry-run` to see
  the resulting title and body before writing anything.
- Answering `n` to the session question skips it; the attach still happens.
- No TTY (piped or scripted) asks nothing and takes the conservative answers:
  attach to an existing PR, no branch, no empty commit, no rewrite, no session.
  Batching the questions never turns an unattended run into yes-to-everything.
  `--dry-run` is the one exception to "no PR": with no open PR it prints the PR
  it *would* have created, since it writes nothing either way.
- No `claude` on `PATH` skips the session question silently.
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
