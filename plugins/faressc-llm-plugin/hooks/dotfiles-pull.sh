#!/usr/bin/env bash
# SessionStart hook: fast-forward the dotfiles checkout so the plan files and the
# per-project memory that the `claude` stow package syncs are current before the
# session reads them. Never fails a session: every problem is one line on stderr
# and exit 0. Prints one line (which SessionStart adds to the context) only when
# something new arrived.
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per run: the audit trail
note() { printf '%s pull %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true; }
[ -d "$repo/.git" ] || { note "no repo at $repo"; exit 0; }
exec 9>"$repo/.git/claude-sync.lock"
flock -w 5 9 || { note "skipped: another session is syncing"; exit 0; }
before=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || { note "skipped: no HEAD"; exit 0; }
if ! out=$(timeout 20 git -C "$repo" pull --ff-only --quiet 2>&1); then
    note "skipped: ${out##*$'\n'}"
    printf 'dotfiles: pull skipped: %s\n' "${out##*$'\n'}" >&2
    exit 0
fi
after=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || exit 0
if [ "$before" != "$after" ]; then
    note "pulled ${before:0:7}..${after:0:7}"
    printf 'dotfiles: pulled %s..%s (plans and memory may have changed)\n' \
        "${before:0:7}" "${after:0:7}"
else
    note "up to date at ${after:0:7}"
fi
exit 0
