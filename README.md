# `faressc-plugins`

Fares's personal Claude Code marketplace. Mirrors the structure of
[`tanh-lab/tanh-tooling`](https://github.com/tanh-lab/tanh-tooling), but scoped to
my own machine-level tooling rather than shared lab config.

| Plugin | Provides |
|---|---|
| [`faressc-llm-plugin`](plugins/faressc-llm-plugin/) | MCP servers (Zotero, `computer-use-linux`, GitHub) + the `control-fares-linux-computer` skill + the dotfiles sync hooks |

## What's in `faressc-llm-plugin`

- **`.mcp.json`** — two stdio MCP servers, declared once and version-controlled
  instead of bootstrapped imperatively via `claude mcp add`:
  - `zotero` — local Zotero API (`ZOTERO_LOCAL=true`), needs Zotero running with
    *Settings → Advanced → "Allow other applications…"* enabled.
  - `computer-use-linux` — Hyprland/Wayland desktop control. **Linux-only**: the
    static manifest can't gate on OS, so on macOS the binary simply won't be found
    and the server fails to start (harmless noise). Prereqs are not provisioned by
    the plugin — still need `cargo install computer-use-linux`, the `/dev/uinput`
    udev rule, the `ydotoold` user service, and `computer-use-linux setup` for
    AT-SPI. Full setup guide:
    `~/tubcloud.tu-berlin.de/memory-bridge/guides/computer-use-linux-mcp.md`.
- **`skills/control-fares-linux-computer`** — how to drive this machine through the
  `computer-use-linux` MCP (Ctrl/Super are swapped at the xkb level, Hyprland
  keybinds, monitor layout).

- **`hooks/`** — two session hooks that keep `~/.claude/plans` and every
  `~/.claude/projects/<key>/memory` in sync between machines through the dotfiles repo
  (`~/.dotfiles`, or `$CLAUDE_DOTFILES_DIR`). opencode runs the same hooks through the
  dotfiles' `claude-bridge` plugin (SessionEnd once a session has been idle for 10
  minutes). They run on Linux and macOS: bash 3.2 and the BSD userland, so no `flock`,
  `setsid`, `timeout` or GNU-only flags; `sync-lib.sh` has the lock (a directory, since
  `mkdir` is atomic everywhere) and the timeout they share. Both are *directory* links into the
  `claude` package, so whatever a session writes there lands in the repo by itself:
  `~/.claude/plans` is stowed, the memory directories are linked by the hooks (below).
  On a fresh machine `mkdir -p ~/.claude/projects` **before** `stow claude`, or stow folds
  the whole `projects` directory into the package.
  - `dotfiles-pull.sh` (**SessionStart**): `git -c pull.rebase=false pull --ff-only` on the
    dotfiles, under a lock, 20 s bound (with `pull.rebase=true` in the repo config,
    `--ff-only` alone refuses on any unstaged change in the checkout), then
    `dotfiles-link-memory.sh`. Prints one line only when new commits arrived
    (SessionStart stdout goes into the context); any problem is one stderr line and exit 0.
  - `dotfiles-link-memory.sh` (run by both hooks, under their lock): Claude Code creates
    each new project's `memory` as a plain directory, which nothing would sync. This moves
    every plain one that has files into the package and leaves a relative link (the kind
    stow makes); links the package copy on a machine that has none yet; and when both
    exist, merges the local files in first (new files move, identical ones are dropped,
    `MEMORY.md` gets the missing index lines; a file that differs on the two sides stops
    that project's merge and is logged for a human). Globs in
    `claude/.claude/memory-sync-exclude` in the dotfiles, matched against `<key>`, are
    never adopted. An empty local directory is replaced by a link when the repo has a
    copy. `--dry-run` prints what it would do; a real run by hand must not overlap a
    session's start or end (it takes no lock of its own).
  - `dotfiles-push.sh` (**SessionEnd**): runs `dotfiles-link-memory.sh`, then stages only
    `claude/.claude/plans` and `claude/.claude/projects/*/memory` and commits them with a
    host-and-time message in the foreground (milliseconds), then hands the network half
    (fetch, rebase onto upstream, push) to a detached copy of itself in its own process
    group (`set -m`, `nohup`): Claude Code cancels a SessionEnd hook that is still running
    when the process exits ("Hook cancelled"), and a fetch and a push are seconds of
    network time. Nothing else in the working tree is touched; nothing is committed while
    a rebase, merge, cherry-pick or revert is in progress; a commit that cannot be pushed
    (offline) stays local and goes out next time; a rebase conflict is aborted and left
    for a human. Always exit 0.
  - Both write one line per step to `~/.claude/dotfiles-sync.log` (`$CLAUDE_DOTFILES_SYNC_LOG`):
    `pull up to date at <sha>` / `pull pulled a..b`, `push committed <sha>; pushing detached`,
    `push detached: pushed <sha>` or the reason it did not. That log is how to check the hooks run.
  Prereqs on each machine: the dotfiles cloned with a pushable remote (SSH key for
  GitHub), a git identity, bash (3.2 is enough) and git. The `.gitignore`
  line `claude/.claude/projects/**/*.jsonl` in the dotfiles keeps session transcripts out
  should stow ever fold too high.

> Plugins cannot ship a `CLAUDE.md` — it is *not* auto-loaded as context. Always-on
> guidance lives in the skill (model-invoked) or in `~/.claude/CLAUDE.md`.

## Install

```sh
# local (before pushing to GitHub) — test from this checkout:
claude plugin marketplace add ~/faressc/faressc-plugins
claude plugin install faressc-llm-plugin@faressc-plugins

# or, once pushed to github.com/faressc/faressc-plugins, the marketplace is already
# declared in ~/.claude/settings.json (managed via dotfiles) and auto-enabled.
```
