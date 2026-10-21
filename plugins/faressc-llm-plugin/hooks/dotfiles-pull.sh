#!/usr/bin/env bash
# SessionStart hook: fast-forward the dotfiles checkout so the plan files and the
# per-project memory that the `claude` stow package syncs are current before the
# session reads them, then link the memory directories (dotfiles-link-memory.sh).
# Never fails a session: every problem is one line on stderr and exit 0. Prints one
# line (which SessionStart adds to the context) only when something new arrived.
#
# Runs on Linux and macOS (bash 3.2, BSD userland): see sync-lib.sh.
set -u
hooks="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per run: the audit trail
note() { printf '%s pull %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true; }
. "$hooks/sync-lib.sh"
[ -d "$repo/.git" ] || { note "no repo at $repo"; exit 0; }
sync_lock 5 || { note "skipped: another session is syncing"; exit 0; }
before=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || { note "skipped: no HEAD"; exit 0; }
# pull.rebase=false: with pull.rebase=true in the repo config, `pull --ff-only` still
# takes the rebase path, which refuses on any unstaged change, even in an unrelated file
# and with nothing to pull. A plain fast-forward only refuses when an incoming commit
# touches a locally changed file.
if ! out=$(with_timeout 20 git -C "$repo" -c pull.rebase=false pull --ff-only --quiet 2>&1); then
    note "skipped: ${out##*$'\n'}"
    printf 'dotfiles: pull skipped: %s\n' "${out##*$'\n'}" >&2
else
    after=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || after=$before
    if [ "$before" != "$after" ]; then
        note "pulled ${before:0:7}..${after:0:7}"
        printf 'dotfiles: pulled %s..%s (plans and memory may have changed)\n' \
            "${before:0:7}" "${after:0:7}"
    else
        note "up to date at ${after:0:7}"
    fi
fi
"$hooks/dotfiles-link-memory.sh"
exit 0
