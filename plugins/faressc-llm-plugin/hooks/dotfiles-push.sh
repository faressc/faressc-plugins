#!/usr/bin/env bash
# SessionEnd hook: commit what this session wrote under the paths the `claude` stow
# package syncs (the plan files, every project's memory directory) and push. Only
# those paths are staged, never the rest of the working tree; a commit that cannot
# be pushed (offline) stays local and goes out with the next session's end. Never
# fails a session: exit 0 on every path.
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per run: the audit trail
note() { printf '%s push %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true; }
[ -d "$repo/.git" ] || { note "no repo at $repo"; exit 0; }
cd "$repo" || exit 0
exec 9>"$repo/.git/claude-sync.lock"
flock -w 30 9 || { note "skipped: lock held for 30 s"; exit 0; }
paths=()
[ -d claude/.claude/plans ] && paths+=(claude/.claude/plans)
for d in claude/.claude/projects/*/memory; do
    [ -d "$d" ] && paths+=("$d")
done
[ ${#paths[@]} -gt 0 ] || { note "nothing: no synced paths"; exit 0; }
git add -- "${paths[@]}" >/dev/null 2>&1 || { note "failed: git add"; exit 0; }
result="nothing to commit"
if ! git diff --cached --quiet -- "${paths[@]}"; then
    if git commit --quiet --only \
        -m "claude: sync plans and memory from $(hostname) ($(date -u +%Y-%m-%dT%H:%MZ))" \
        -- "${paths[@]}" >/dev/null 2>&1; then
        result="committed $(git rev-parse --short HEAD)"
    else
        note "failed: git commit"; exit 0
    fi
fi
# Push what is committed and not yet upstream, this commit or an earlier one.
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || { note "$result; no upstream"; exit 0; }
[ -n "$(git rev-list "$upstream"..HEAD 2>/dev/null)" ] || { note "$result; nothing to push"; exit 0; }
if ! timeout 30 git fetch --quiet >/dev/null 2>&1; then
    note "$result; fetch failed (offline?), retried at the next session end"
    exit 0
fi
if ! git rebase --autostash --quiet "$upstream" >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1        # leave the tree as it was
    note "$result; rebase conflict with $upstream, left for a human"
    exit 0
fi
if timeout 30 git push --quiet >/dev/null 2>&1; then
    note "$result; pushed"
else
    note "$result; push failed (offline?), retried at the next session end"
fi
exit 0
