# gai team: one Claude Code setup for the whole team

Share global rules, skills, slash commands, hooks, docs and project memory between
teammates' laptops. Everything is encrypted on GitHub. Nobody pastes a key.

## How it works

1. Your GitHub org has a **private repo named `claude-config`**. It holds the content: a
   `CLAUDE.md`, `skills/`, `commands/`, `hooks/`, `scripts/`, `docs/`, `git-hooks/`, `agents/`,
   `memory/<project>/`, and optionally `settings.shared.json`.
2. **`gai update`** (or `gai team setup`) finds that repo in your orgs, clones it to
   `~/claude-config`, unlocks it, and turns `~/.claude/<folder>` into symlinks to it.
   Anything of your own already in those folders is copied into the shared repo first, and
   the originals are backed up to `~/.claude/pre-gai-team-<time>/`.
3. Claude hooks keep it in sync: `gai-team sync pull` when a session starts, and
   `gai-team sync push` (in the background) when a turn ends.

Without a `claude-config` repo, `gai update` doesn't touch any of this.

## Encryption

- Content is encrypted with **git-crypt** (AES-256). Readable files: `README.md`,
  `.gitattributes`, `.gitignore` and `keys/`.
- Each person gets a personal **age** key (`~/.gai/team-identity`, also in the Keychain
  under `gai-team`).
- **Joining:** a newcomer's `gai update` pushes `keys/<login>.pub`. On the next sync, any
  unlocked teammate's laptop checks the newcomer is a repo collaborator, then locks the team
  key to their public key (`keys/<login>.age`). The newcomer's next sync unlocks itself.
- The team key is kept in the Keychain (`gai-team` / `team-key`). On a laptop's first
  unlock, gai offers a copy to Apple Passwords or Google Password Manager.
- Sync refuses to push any file that isn't ciphertext.
- **What stays visible on GitHub:** file and folder *names* (e.g. a memory note's filename), and
  commit times and authors. Contents are encrypted. gai-team commits use bare messages (`sync`,
  `team: key granted`) and no stamp trailers, and `gai`/`gai-watch` never auto-commit in a repo
  with a `.gai-team` marker, so no AI-written summary of the content is ever published.
- A repo is only adopted when it has the plaintext `.gai-team` marker **and** you answer yes once.
  A repo that merely happens to be called `claude-config` is ignored.

## Commands

| Command | What it does |
|---|---|
| `gai team` | status: repo, locked or unlocked, members |
| `gai team setup` | what `gai update` runs; safe to repeat |
| `gai team add <user>` | makes them a collaborator; they just run `gai update` |
| `gai team remove <user>` | removes access, **rotates the team key**, re-grants everyone left |
| `gai team init <owner>/claude-config` | publishes `~/claude-config` as a new encrypted repo |
| `gai team sync pull` / `push` | used by Claude hooks |

## Conflicts

Git can't merge ciphertext. When the same file was changed on two laptops before
syncing, `MEMORY.md` is merged on the decrypted text (both sides' lines kept). Any
other file pauses the sync without overwriting anything, and the next Claude session
shows a notice telling you how to resolve it.

## Org-wide bots that write into every repo

Some orgs run a workflow that pushes the same files (often `.github/workflows/*`) into
every repo. In a team repo, sync would encrypt those files, GitHub Actions couldn't read
them, and the bot would push them back on every run.

- `gai team init` keeps `.github/**` readable (`!filter !diff` in `.gitattributes`).
- The encryption check follows `.gitattributes`. Anything marked readable on purpose
  passes, while plain text in an encrypted path is still refused.
- For another bot writing somewhere else, add its path to `.gitattributes` as `!filter !diff`,
  or exclude the team repo in the bot's repo list. Never put secrets in a path marked readable.

## Limits

- Write access to the repo means your code runs on every teammate's laptop (hooks). Only add people you trust.
- `gai team remove` protects everything changed after removal. The person keeps what they already pulled.
- Project memory only loads when the project is cloned at the same path under `~` on every laptop.
