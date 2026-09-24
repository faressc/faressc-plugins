#!/usr/bin/env bash
# SessionEnd hook: commit what this session wrote under the paths the `claude` stow
# package syncs (the plan files, every project's memory directory) and push.
#
# Two halves. The foreground half stages and commits, which takes milliseconds, and
# returns: Claude Code cancels a SessionEnd hook that is still running when the process
# exits ("Hook cancelled"), and a fetch and a push are seconds of network time. So the
# network half runs detached, in its own session (setsid), where the cancel cannot reach
# it: fetch, rebase onto upstream, push, and one log line for the result. Only the synced
# paths are ever staged; a commit that cannot be pushed stays local and goes out with the
# next session's end. Every path exits 0: a session never fails on the sync.
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per step: the audit trail
note() { printf '%s push %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true; }
[ -d "$repo/.git" ] || { note "no repo at $repo"; exit 0; }
cd "$repo" || exit 0

if [ "${1:-}" = "--detached" ]; then
    # ---- the network half, in its own session ----
    exec 9>"$repo/.git/claude-sync.lock"
    flock -w 60 9 || { note "detached: skipped, lock held for 60 s"; exit 0; }
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || { note "detached: no upstream"; exit 0; }
    [ -n "$(git rev-list "$upstream"..HEAD 2>/dev/null)" ] || { note "detached: nothing to push"; exit 0; }
    if ! timeout 60 git fetch --quiet >/dev/null 2>&1; then
        note "detached: fetch failed (offline?), retried at the next session end"; exit 0
    fi
    if ! git rebase --autostash --quiet "$upstream" >/dev/null 2>&1; then
        git rebase --abort >/dev/null 2>&1        # leave the tree as it was
        note "detached: rebase conflict with $upstream, left for a human"; exit 0
    fi
    if timeout 60 git push --quiet >/dev/null 2>&1; then
        note "detached: pushed $(git rev-parse --short HEAD)"
    else
        note "detached: push failed, retried at the next session end"
    fi
    exit 0
fi

# ---- the foreground half: stage and commit, then hand over ----
exec 9>"$repo/.git/claude-sync.lock"
flock -w 30 9 || { note "skipped: lock held for 30 s"; exit 0; }
paths=()
[ -d claude/.claude/plans ] && paths+=(claude/.claude/plans)
for d in claude/.claude/projects/*/memory; do
    [ -d "$d" ] && paths+=("$d")
done
[ ${#paths[@]} -gt 0 ] || { note "nothing: no synced paths"; exit 0; }
git add -- "${paths[@]}" >/dev/null 2>&1 || { note "failed: git add"; exit 0; }
# The staged files under the synced paths, by name: a directory with nothing staged (an
# empty plans directory on a fresh machine) is no pathspec git commit accepts.
changed=()
while IFS= read -r -d '' f; do changed+=("$f"); done < <(git diff --cached --name-only -z -- "${paths[@]}")
result="nothing to commit"
if [ ${#changed[@]} -gt 0 ]; then
    if git commit --quiet --only \
        -m "claude: sync plans and memory from $(hostname) ($(date -u +%Y-%m-%dT%H:%MZ))" \
        -- "${changed[@]}" >/dev/null 2>&1; then
        result="committed $(git rev-parse --short HEAD)"
    else
        note "failed: git commit"; exit 0
    fi
fi
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || { note "$result; no upstream"; exit 0; }
[ -n "$(git rev-list "$upstream"..HEAD 2>/dev/null)" ] || { note "$result; nothing to push"; exit 0; }
note "$result; pushing detached"
exec 9>&-                                  # the child takes its own lock
setsid -f "$0" --detached </dev/null >/dev/null 2>&1
exit 0
