#!/usr/bin/env bash
# SessionStart hook: fast-forward the dotfiles checkout so the plan files and the
# per-project memory that the `claude` stow package syncs are current before the
# session reads them. Never fails a session: every problem is one line on stderr
# and exit 0. Prints one line (which SessionStart adds to the context) only when
# something new arrived.
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
[ -d "$repo/.git" ] || exit 0
exec 9>"$repo/.git/claude-sync.lock"
flock -n 9 || exit 0                       # another session is syncing right now
before=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || exit 0
if ! out=$(timeout 20 git -C "$repo" pull --ff-only --quiet 2>&1); then
    printf 'dotfiles: pull skipped: %s\n' "${out##*$'\n'}" >&2
    exit 0
fi
after=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || exit 0
if [ "$before" != "$after" ]; then
    printf 'dotfiles: pulled %s..%s (plans and memory may have changed)\n' \
        "${before:0:7}" "${after:0:7}"
fi
exit 0
