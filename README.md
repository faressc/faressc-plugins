# `faressc-plugins`

Fares's personal Claude Code marketplace. Mirrors the structure of
[`tanh-lab/tanh-tooling`](https://github.com/tanh-lab/tanh-tooling), but scoped to
my own machine-level tooling rather than shared lab config.

| Plugin | Provides |
|---|---|
| [`faressc-llm-plugin`](plugins/faressc-llm-plugin/) | MCP servers (Zotero, `computer-use-linux`, GitHub) + user-invoked and model-invoked skills + the dotfiles sync hooks |

## What's in `faressc-llm-plugin`

- **`.mcp.json`** — the MCP servers, declared once and version-controlled
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
  - `github-anira`, `github-tanh`, `github-faressc` — GitHub's remote MCP server
    (`api.githubcopilot.com/mcp/`), one per fine-grained token: a fine-grained token
    reaches the repositories of a single owner only (the anira-project organisation,
    `GITHUB_TOKEN_ANIRA`; the tanh-lab organisation, `GITHUB_TOKEN_TANH`; my own
    account, `GITHUB_TOKEN_FARESSC`). The `?variant=` only keeps the three URLs apart.
    `GITHUB_TOKEN` is not read here: it belongs to tanh-tools' `github` server.
    All three also load the `actions` toolset (`X-MCP-Toolsets`: the default
    `context,repos,issues,pull_requests,users` plus `actions`): GitHub does not let
    fine-grained tokens call the Checks API on private repositories (check runs answer
    403; public ones are readable with any token), so CI on a private repository is
    followed through workflow runs, jobs and job logs, which need the token's
    *Actions: read*.
- **`skills/`** — skills in bucket folders (`engineering/`, `machine/`,
  `productivity/`), laid out like [mattpocock/skills](https://github.com/mattpocock/skills).
  Claude Code scans `skills/` only one level deep, so each skill is listed in
  `.claude-plugin/plugin.json`'s `skills` array. They split on who can invoke them
  (conventions in [`AGENTS.md`](AGENTS.md)):
  - **User-invoked** (`disable-model-invocation: true`, reachable only by typing them; they
    orchestrate):
    - [`grill-me`](plugins/faressc-llm-plugin/skills/productivity/grill-me/SKILL.md) —
      get relentlessly interviewed about a plan or design; hands off to `grilling`.
    - [`grill-with-docs`](plugins/faressc-llm-plugin/skills/engineering/grill-with-docs/SKILL.md) —
      the same interview, which also writes the glossary and ADRs as it goes; hands off to
      `grilling` and `domain-modeling`.
    - [`to-tickets`](plugins/faressc-llm-plugin/skills/engineering/to-tickets/SKILL.md) —
      break a plan into GitHub issues in order, a parent issue and its sub-issues, published
      once you approved the split.
    - [`implement`](plugins/faressc-llm-plugin/skills/engineering/implement/SKILL.md) —
      implement a feature's issues in order, up to and including the one you name, each as
      a reviewed and merged sub-PR into the feature branch; or one standalone issue as a
      draft PR.
    - [`explain-pr`](plugins/faressc-llm-plugin/skills/engineering/explain-pr/SKILL.md) —
      explain a branch, PR or sub-PR in plain language and in execution order.
    - [`retro`](plugins/faressc-llm-plugin/skills/engineering/retro/SKILL.md) —
      a retrospective on a coding session: candidates for improving the agent's environment,
      presented to you; it edits nothing by itself.
  - **Model-invoked** (the model reaches for them when the task fits; they hold the
    reusable discipline):
    - [`grilling`](plugins/faressc-llm-plugin/skills/productivity/grilling/SKILL.md) —
      the interview itself: rounds of numbered questions over the design tree's frontier,
      each with a recommended answer, until nothing is left silently assumed.
    - [`pr-flow`](plugins/faressc-llm-plugin/skills/engineering/pr-flow/SKILL.md) —
      the rules for issue and pull-request work: one big PR per feature against the default
      branch, one sub-PR per issue into the feature branch (merged by the agent with a merge
      commit), the ledger in the big PR's description, commits, tests, the CI decision, and
      the glossary and ADRs to read first. Repo facts come from an "Agent workflow" section
      in the repo's `AGENTS.md`.
    - [`issue-review`](plugins/faressc-llm-plugin/skills/engineering/issue-review/SKILL.md) —
      reviews one pull request against its base in two parallel sub-agents: the repo's
      standards (and missing tests), and the issue it implements.
    - [`diagnosing-bugs`](plugins/faressc-llm-plugin/skills/engineering/diagnosing-bugs/SKILL.md) —
      diagnosis loop for hard bugs: no fix before one command reproduces the bug.
    - [`domain-modeling`](plugins/faressc-llm-plugin/skills/engineering/domain-modeling/SKILL.md) —
      builds and sharpens the domain model: challenges terms, and writes `GLOSSARY.md` and
      ADRs (`docs/adr/`) the moment a term or a decision is settled.
    - [`control-fares-linux-computer`](plugins/faressc-llm-plugin/skills/machine/control-fares-linux-computer/SKILL.md)
      — how to drive this machine through the `computer-use-linux` MCP (Ctrl/Super are
      swapped at the xkb level, Hyprland keybinds, monitor layout).

  The issue workflow in one line: `/grill-me` or `/grill-with-docs`, `/to-tickets`,
  `/implement <issue number>`, then review on the feature branch with `/explain-pr <sub-PR
  number>`, and `/retro` after a run. Its skills reach GitHub only through the MCP server of
  the repository's owner, never through `gh`.

  `grill-me`, `grilling`, `grill-with-docs`, `domain-modeling`, `to-tickets`,
  `issue-review`, `diagnosing-bugs` and `retro` are vendored from mattpocock/skills (MIT,
  commit `d6539114`), each with the upstream `LICENSE` beside its `SKILL.md`; `to-tickets`,
  `issue-review` (upstream `code-review`) and `retro` are adapted, the list of changes is
  in [`AGENTS.md`](AGENTS.md). opencode gets the same skills through the dotfiles'
  `claude-bridge`, which has to follow the `skills` array too.

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
  the whole `projects` directory into the package. Stow folds `~/.claude/plans` only when
  nothing is there yet; over an existing directory (or with `--adopt`) it links entry by
  entry, and `dotfiles-link.sh` folds that directory at the next session start.
  - `dotfiles-pull.sh` (**SessionStart**): `git -c pull.rebase=false pull --ff-only` on the
    dotfiles, under a lock, 20 s bound (with `pull.rebase=true` in the repo config,
    `--ff-only` alone refuses on any unstaged change in the checkout), then
    `dotfiles-link.sh`. Prints one line only when new commits arrived
    (SessionStart stdout goes into the context); any problem is one stderr line and exit 0.
  - `dotfiles-link.sh` (run by both hooks, under their lock): Claude Code creates each new
    project's `memory` as a plain directory, which nothing would sync, and a
    `~/.claude/plans` that stow linked entry by entry keeps every new plan as a plain file.
    For `~/.claude/plans` and every memory directory this moves a plain one that has files
    into the package and leaves a relative link (the kind stow makes); links the package
    copy on a machine that has none yet; and when both exist, merges the local entries in
    first (stow's per-entry links into the package are dropped, also dangling ones; new
    files and directories move, identical ones are dropped, `MEMORY.md` gets the missing
    index lines; an entry that differs on the two sides, or a link pointing anywhere else,
    stops that directory's merge and is logged for a human). Globs in
    `claude/.claude/memory-sync-exclude` in the dotfiles, matched against `<key>`, are
    never adopted, and neither is a directory holding links. An empty local directory is
    replaced by a link when the repo has a copy. `--dry-run` prints what it would do; a
    real run by hand must not overlap a session's start or end (it takes no lock of its
    own).
  - `dotfiles-push.sh` (**SessionEnd**): runs `dotfiles-link.sh`, then stages only
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
    `push detached: pushed <sha>` or the reason it did not, `link <dir>: merged into the repo
    copy` / `link <dir>: <entry> differs from the repo copy, left for a human`. That log is
    how to check the hooks run.
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
