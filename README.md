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
  (`~/.dotfiles`, or `$CLAUDE_DOTFILES_DIR`). Both directories are stowed from the
  `claude` package as *directory* links (move the real directory into the package, then
  `stow -R claude`; on a fresh machine `mkdir -p ~/.claude/projects/<key>` **before**
  stowing, or stow folds the whole `projects` directory into the package), so whatever a
  session writes there lands in the repo by itself.
  - `dotfiles-pull.sh` (**SessionStart**): `git pull --ff-only` on the dotfiles, under a
    lock, 20 s bound. Prints one line only when new commits arrived (SessionStart stdout
    goes into the context); any problem is one stderr line and exit 0.
  - `dotfiles-push.sh` (**SessionEnd**): stages only `claude/.claude/plans` and
    `claude/.claude/projects/*/memory` and commits them with a host-and-time message in
    the foreground (milliseconds), then hands the network half (fetch, rebase onto
    upstream, push) to a detached copy of itself (`setsid -f`): Claude Code cancels a
    SessionEnd hook that is still running when the process exits ("Hook cancelled"), and
    a fetch and a push are seconds of network time. Nothing else in the working tree is
    touched; a commit that cannot be pushed (offline) stays local and goes out next time;
    a rebase conflict is aborted and left for a human. Always exit 0.
  - Both write one line per step to `~/.claude/dotfiles-sync.log` (`$CLAUDE_DOTFILES_SYNC_LOG`):
    `pull up to date at <sha>` / `pull pulled a..b`, `push committed <sha>; pushing detached`,
    `push detached: pushed <sha>` or the reason it did not. That log is how to check the hooks run.
  Prereqs on each machine: the dotfiles cloned with a pushable remote (SSH key for
  GitHub), a git identity, `flock` and `timeout` (util-linux / coreutils). The `.gitignore`
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
