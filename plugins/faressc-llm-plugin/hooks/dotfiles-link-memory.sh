#!/usr/bin/env bash
# Links every project's auto-memory directory into the dotfiles, so the session hooks
# sync it. Claude Code creates ~/.claude/projects/<key>/memory as a plain directory for
# every new project, and a plain directory is never synced. Run by dotfiles-pull.sh
# (after the pull) and dotfiles-push.sh (before staging), under their lock. For every
# project key that is not excluded and not linked yet:
#
#   - a local memory directory with files and no copy in the repo is moved into the
#     `claude` package (claude/.claude/projects/<key>/memory) and replaced by a link;
#   - a copy in the repo and none here (another host adopted it) gets a link, so this
#     host reads and writes the same files;
#   - both (two hosts kept memory for the same project): the local files are merged into
#     the repo copy first. New files move, identical ones are dropped, and MEMORY.md gets
#     the index lines it lacks. A file on both sides with different content stops the
#     merge for that project before anything moves; the log names the file, for a human.
#
# An empty local directory is replaced by a link when the repo has a copy, and otherwise
# left alone until it has a file. The exclude list is
# claude/.claude/memory-sync-exclude in the dotfiles: one bash glob per line, matched
# against <key>. Links are relative, the way stow makes them, so `stow -R claude` takes
# them as its own. --dry-run prints what would happen and changes nothing. Every path
# exits 0: a session never fails on the sync.
#
# Runs on Linux and macOS: bash 3.2 (no associative arrays; an empty array expands under
# `set -u` only through ${a[@]+...}) and the BSD userland (no realpath --relative-to,
# ln -T or mv -T).
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per step: the audit trail
projects="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
package="$repo/claude/.claude/projects"
exclude_file="$repo/claude/.claude/memory-sync-exclude"
dry=false
[ "${1:-}" = "--dry-run" ] && dry=true
note() {
    if $dry; then printf 'memory %s\n' "$*"; return; fi
    printf '%s memory %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true
}
[ -d "$repo/.git" ] || { note "no repo at $repo"; exit 0; }

excludes=()
if [ -f "$exclude_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '' | '#'*) continue ;; esac
        excludes+=("$line")
    done <"$exclude_file"
fi
excluded() {
    local pattern
    for pattern in ${excludes[@]+"${excludes[@]}"}; do
        # shellcheck disable=SC2053  # unquoted on purpose: the pattern is a glob
        [[ $1 == $pattern ]] && return 0
    done
    return 1
}

# relpath <from-dir> <to>: <to> as a path relative to <from-dir>; both absolute and
# physical (pwd -P), so plain string prefixes decide it.
relpath() {
    local from=$1 up=""
    while [ "${2#"$from"/}" = "$2" ]; do
        from=${from%/*}
        up="../$up"
    done
    printf '%s%s' "$up" "${2#"$from"/}"
}

# link <key>: point the local memory path, which must not exist, at the package copy,
# relative like stow.
link() {
    local from to
    mkdir -p "$projects/$1" || return 1
    from=$(cd "$projects/$1" && pwd -P) || return 1
    to=$(cd "$package/$1/memory" && pwd -P) || return 1
    if [ -e "$projects/$1/memory" ] || [ -L "$projects/$1/memory" ]; then return 1; fi
    ln -s "$(relpath "$from" "$to")" "$projects/$1/memory"
}

# conflicts <here> <there>: print the first local entry that cannot be merged into the
# package copy (not a plain file, or a different file of the same name), else nothing.
conflicts() {
    local f name
    while IFS= read -r -d '' f; do
        name=${f##*/}
        [ -f "$f" ] && [ ! -L "$f" ] || { printf '%s' "$name"; return; }
        [ "$name" = MEMORY.md ] && continue
        [ -e "$2/$name" ] && ! cmp -s "$f" "$2/$name" && { printf '%s' "$name"; return; }
    done < <(find "$1" -mindepth 1 -maxdepth 1 -print0)
}

# merge <here> <there>: move the local files into the package copy; MEMORY.md gets the
# lines the package index lacks, in their local order.
merge() {
    local f name missing
    while IFS= read -r -d '' f; do
        name=${f##*/}
        if [ "$name" = MEMORY.md ] && [ -e "$2/$name" ]; then
            missing=$(awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' "$2/$name" "$f")
            if [ -n "$missing" ]; then
                [ -s "$2/$name" ] && [ -n "$(tail -c1 "$2/$name")" ] && printf '\n' >>"$2/$name"
                printf '%s\n' "$missing" >>"$2/$name"
            fi
            rm -f "$f"
        elif [ -e "$2/$name" ]; then
            rm -f "$f"                              # identical, checked by conflicts()
        else
            mv "$f" "$2/$name"
        fi
    done < <(find "$1" -mindepth 1 -maxdepth 1 -print0)
    rmdir "$1"
}

# Every key with a memory directory (or link) on either side, once.
keys=$(
    for dir in "$projects"/*/memory "$package"/*/memory; do
        [ -e "$dir" ] || [ -L "$dir" ] || continue
        key=${dir%/memory}
        printf '%s\n' "${key##*/}"
    done | sort -u
)

while IFS= read -r key <&3; do
    [ -n "$key" ] || continue
    excluded "$key" && continue
    here="$projects/$key/memory"
    there="$package/$key/memory"
    [ -L "$here" ] && continue                      # linked: by stow or an earlier run
    [ "$here" -ef "$there" ] && continue            # stow folded <key> itself into the package
    if [ ! -e "$here" ]; then
        [ -d "$there" ] || continue
        if $dry; then note "$key: would link the repo copy"; continue; fi
        if link "$key"; then note "$key: linked the repo copy"; else note "$key: link failed"; fi
        continue
    fi
    [ -d "$here" ] || { note "$key: memory is not a directory, skipped"; continue; }
    if [ -z "$(find "$here" -mindepth 1 -print -quit)" ]; then
        [ -d "$there" ] || continue                 # empty, and nothing to link: nothing yet
        if $dry; then note "$key: would link the repo copy over an empty directory"; continue; fi
        if rmdir "$here" && link "$key"; then note "$key: linked the repo copy"; else note "$key: link failed"; fi
        continue
    fi
    if [ ! -e "$there" ]; then
        if $dry; then note "$key: would adopt"; continue; fi
        if mkdir -p "$package/$key" && mv "$here" "$there" && link "$key"; then
            note "$key: adopted"
        else
            note "$key: adopt failed"
        fi
        continue
    fi
    conflict=$(conflicts "$here" "$there")
    if [ -n "$conflict" ]; then
        note "$key: $conflict differs from the repo copy, left for a human"
        continue
    fi
    if $dry; then note "$key: would merge into the repo copy"; continue; fi
    if merge "$here" "$there" && link "$key"; then
        note "$key: merged into the repo copy"
    else
        note "$key: merge failed"
    fi
done 3<<EOF
$keys
EOF
exit 0
