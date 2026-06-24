# `faressc-plugins`

Fares's personal Claude Code marketplace. Mirrors the structure of
[`tanh-lab/tanh-tooling`](https://github.com/tanh-lab/tanh-tooling), but scoped to
my own machine-level tooling rather than shared lab config.

| Plugin | Provides |
|---|---|
| [`faressc-llm-plugin`](plugins/faressc-llm-plugin/) | MCP servers (Zotero, `computer-use-linux`) + the `control-fares-linux-computer` skill |

## What's in `faressc-llm-plugin`

- **`.mcp.json`** — two stdio MCP servers, declared once and version-controlled
  instead of bootstrapped imperatively via `claude mcp add`:
  - `zotero` — local Zotero API (`ZOTERO_LOCAL=true`), needs Zotero running with
    *Settings → Advanced → "Allow other applications…"* enabled.
  - `computer-use-linux` — Hyprland/Wayland desktop control. **Linux-only**: the
    static manifest can't gate on OS, so on macOS the binary simply won't be found
    and the server fails to start (harmless noise). Prereqs are not provisioned by
    the plugin — still need `cargo install computer-use-linux`, the `/dev/uinput`
    udev rule, the `ydotoold` user service, and `computer-use-linux setup`.
- **`skills/control-fares-linux-computer`** — how to drive this machine through the
  `computer-use-linux` MCP (Ctrl/Super are swapped at the xkb level, Hyprland
  keybinds, monitor layout).

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
