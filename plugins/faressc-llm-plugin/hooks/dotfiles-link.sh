#!/usr/bin/env bash
# Links ~/.claude/plans and every project's auto-memory directory into the dotfiles, so
# the session hooks sync them. Claude Code creates ~/.claude/projects/<key>/memory as a
# plain directory for every new project, and a plain directory is never synced. Stow
# folds ~/.claude/plans into one link only when nothing is there yet: over an existing
# directory (plans written before `stow claude`, `stow --adopt`) it links entry by entry,
# and every plan written since is a plain file nothing syncs. Run by dotfiles-pull.sh
# (after the pull) and dotfiles-push.sh (before staging), under their lock. For
# ~/.claude/plans and every project key that is not excluded, whichever is not linked yet:
#
#   - a local directory with files and no copy in the repo is moved into the `claude`
#     package (claude/.claude/plans, claude/.claude/projects/<key>/memory) and replaced
#     by a link;
#   - a copy in the repo and none here (another host adopted it) gets a link, so this
#     host reads and writes the same files;
#   - both (two hosts kept memory for the same project, or stow linked entry by entry):
#     the local entries are merged into the repo copy first. Stow's links into the repo
#     copy are dropped (also those whose file the repo has dropped since), new files and
#     directories move, identical ones are dropped, and MEMORY.md gets the index lines it
#     lacks. An entry on both sides with different content, or one that is no plain file,
#     directory or stow link, stops the merge for that directory before anything moves;
#     the log names it, for a human.
#
# An empty local directory is replaced by a link when the repo has a copy, and otherwise
# left alone until it has a file. A directory holding links is never adopted. The exclude
# list is claude/.claude/memory-sync-exclude in the dotfiles: one bash glob per line,
# matched against <key>. Links are relative, the way stow makes them, so `stow -R claude`
# takes them as its own. --dry-run prints what would happen and changes nothing. Every
# path exits 0: a session never fails on the sync.
#
# Runs on Linux and macOS: bash 3.2 (no associative arrays; an empty array expands under
# `set -u` only through ${a[@]+...}) and the BSD userland (no realpath --relative-to,
# ln -T or mv -T).
set -u
repo="${CLAUDE_DOTFILES_DIR:-$HOME/.dotfiles}"
log="${CLAUDE_DOTFILES_SYNC_LOG:-$HOME/.claude/dotfiles-sync.log}"   # one line per step: the audit trail
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
package="$repo/claude/.claude"
exclude_file="$package/memory-sync-exclude"
dry=false
[ "${1:-}" = "--dry-run" ] && dry=true
note() {
    if $dry; then printf 'link %s\n' "$*"; return; fi
    printf '%s link %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$log" 2>/dev/null || true
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

# link <here> <there>: point the local path <here>, which must not exist, at the package
# copy <there>, relative like stow.
link() {
    local from to
    mkdir -p "${1%/*}" || return 1
    from=$(cd "${1%/*}" && pwd -P) || return 1
    to=$(cd "$2" && pwd -P) || return 1
    if [ -e "$1" ] || [ -L "$1" ]; then return 1; fi
    ln -s "$(relpath "$from" "$to")" "$1"
}

# stow_link <entry> <there>: true when the local <entry> is a link to the entry of the
# same name in the package copy <there>, the kind stow makes when it links entry by
# entry, whether or not that entry still exists. It holds nothing to merge.
stow_link() {
    local target dir
    [ -L "$1" ] || return 1
    target=$(readlink "$1") || return 1
    [ "${target##*/}" = "${1##*/}" ] || return 1
    case "$target" in /*) ;; *) target="${1%/*}/$target" ;; esac
    dir=$(cd "${target%/*}" 2>/dev/null && pwd -P) || return 1
    [ "$dir" = "$(cd "$2" && pwd -P)" ]
}

# conflicts <here> <there>: say why the first local entry that cannot be merged into the
# package copy cannot (no plain file, directory or stow link, or different content under
# the same name), else nothing.
conflicts() {
    local f name
    while IFS= read -r -d '' f; do
        name=${f##*/}
        stow_link "$f" "$2" && continue
        if [ -L "$f" ] || { [ ! -f "$f" ] && [ ! -d "$f" ]; }; then
            printf '%s is no plain file or directory' "$name"
            return
        fi
        [ "$name" = MEMORY.md ] && [ -f "$f" ] && continue
        [ -e "$2/$name" ] || [ -L "$2/$name" ] || continue
        if [ -d "$f" ]; then
            diff -r -q "$f" "$2/$name" >/dev/null 2>&1 || { printf '%s differs from the repo copy' "$name"; return; }
        else
            cmp -s "$f" "$2/$name" || { printf '%s differs from the repo copy' "$name"; return; }
        fi
    done < <(find "$1" -mindepth 1 -maxdepth 1 -print0)
}

# merge <here> <there>: move the local entries into the package copy; MEMORY.md gets the
# lines the package index lacks, in their local order.
merge() {
    local f name missing
    while IFS= read -r -d '' f; do
        name=${f##*/}
        if stow_link "$f" "$2"; then
            rm -f "$f"
        elif [ "$name" = MEMORY.md ] && [ -e "$2/$name" ]; then
            missing=$(awk 'NR == FNR { have[$0] = 1; next } !($0 in have)' "$2/$name" "$f")
            if [ -n "$missing" ]; then
                [ -s "$2/$name" ] && [ -n "$(tail -c1 "$2/$name")" ] && printf '\n' >>"$2/$name"
                printf '%s\n' "$missing" >>"$2/$name"
            fi
            rm -f "$f"
        elif [ -e "$2/$name" ]; then
            rm -rf "$f"                             # identical, checked by conflicts()
        else
            mv "$f" "$2/$name"
        fi
    done < <(find "$1" -mindepth 1 -maxdepth 1 -print0)
    rmdir "$1"
}

# fold <name> <here> <there>: replace the local directory <here> by a link to the package
# copy <there>, adopting or merging what <here> holds first (see the top). <name> labels
# the log lines.
fold() {
    local name=$1 here=$2 there=$3 conflict
    [ -L "$here" ] && return                        # linked: by stow or an earlier run
    [ "$here" -ef "$there" ] && return              # stow folded a parent into the package
    if [ ! -e "$here" ]; then
        [ -d "$there" ] || return
        if $dry; then note "$name: would link the repo copy"; return; fi
        if link "$here" "$there"; then note "$name: linked the repo copy"; else note "$name: link failed"; fi
        return
    fi
    [ -d "$here" ] || { note "$name: not a directory, skipped"; return; }
    if [ -z "$(find "$here" -mindepth 1 -print -quit)" ]; then
        [ -d "$there" ] || return                   # empty, and nothing to link: nothing yet
        if $dry; then note "$name: would link the repo copy over an empty directory"; return; fi
        if rmdir "$here" && link "$here" "$there"; then note "$name: linked the repo copy"; else note "$name: link failed"; fi
        return
    fi
    if [ ! -e "$there" ]; then
        if [ -n "$(find "$here" -type l -print -quit)" ]; then
            note "$name: holds links and the repo has no copy, left for a human"
            return
        fi
        if $dry; then note "$name: would adopt"; return; fi
        if mkdir -p "${there%/*}" && mv "$here" "$there" && link "$here" "$there"; then
            note "$name: adopted"
        else
            note "$name: adopt failed"
        fi
        return
    fi
    conflict=$(conflicts "$here" "$there")
    if [ -n "$conflict" ]; then
        note "$name: $conflict, left for a human"
        return
    fi
    if $dry; then note "$name: would merge into the repo copy"; return; fi
    if merge "$here" "$there" && link "$here" "$there"; then
        note "$name: merged into the repo copy"
    else
        note "$name: merge failed"
    fi
}

fold plans "$config/plans" "$package/plans"

# Every key with a memory directory (or link) on either side, once.
keys=$(
    for dir in "$config"/projects/*/memory "$package"/projects/*/memory; do
        [ -e "$dir" ] || [ -L "$dir" ] || continue
        key=${dir%/memory}
        printf '%s\n' "${key##*/}"
    done | sort -u
)

while IFS= read -r key <&3; do
    [ -n "$key" ] || continue
    excluded "$key" && continue
    fold "$key" "$config/projects/$key/memory" "$package/projects/$key/memory"
done 3<<EOF
$keys
EOF
exit 0
