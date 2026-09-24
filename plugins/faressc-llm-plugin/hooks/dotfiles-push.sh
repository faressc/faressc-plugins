#!/usr/bin/env bash
# SessionEnd hook: commit what this session wrote under the paths the `claude` stow
# package syncs (the plan files, every project's memory directory) and push. Only
# those paths are staged, never the rest of the working tree; a commit that cannot
# be pushed (offline) stays local and goes out with the next session's end. Never
# fails a session: exit 0 on every path.
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
[ -d "$repo/.git" ] || exit 0
cd "$repo" || exit 0
exec 9>"$repo/.git/claude-sync.lock"
flock -w 30 9 || exit 0
paths=()
[ -d claude/.claude/plans ] && paths+=(claude/.claude/plans)
for d in claude/.claude/projects/*/memory; do
    [ -d "$d" ] && paths+=("$d")
done
[ ${#paths[@]} -gt 0 ] || exit 0
git add -- "${paths[@]}" >/dev/null 2>&1 || exit 0
if ! git diff --cached --quiet -- "${paths[@]}"; then
    git commit --quiet --only \
        -m "claude: sync plans and memory from $(hostname) ($(date -u +%Y-%m-%dT%H:%MZ))" \
        -- "${paths[@]}" >/dev/null 2>&1 || exit 0
fi
# Push what is committed and not yet upstream, this commit or an earlier one.
upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || exit 0
[ -n "$(git rev-list "$upstream"..HEAD 2>/dev/null)" ] || exit 0
if ! timeout 30 git pull --rebase --autostash --quiet >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1        # leave the tree as it was; retry next time
    exit 0
fi
timeout 30 git push --quiet >/dev/null 2>&1
exit 0
