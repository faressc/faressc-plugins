# Sourced by dotfiles-pull.sh and dotfiles-push.sh, which set $repo first. Both run on
# Linux and macOS, so only what stock macOS has is used: bash 3.2 and the BSD userland,
# no flock(1), setsid(1) or timeout(1) (util-linux and coreutils).

# The sync lock, shared by every hook run on this machine: a directory in the checkout's
# .git, since mkdir is atomic everywhere. It records its holder's pid. A lock whose holder
# is gone, or that has no pid a minute after it was made (the holder died right after
# mkdir), is broken.
sync_lockdir() { printf '%s' "$repo/.git/claude-sync.lock.d"; }

# sync_lock <seconds>: take the lock, waiting up to <seconds>; it is released on exit.
sync_lock() {
    local lock tries holder
    lock=$(sync_lockdir)
    tries=$(($1 * 5))
    while ! mkdir "$lock" 2>/dev/null; do
        holder=$(cat "$lock/pid" 2>/dev/null)
        if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
            rm -rf "$lock"
            continue
        fi
        if [ -z "$holder" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
            rm -rf "$lock"
            continue
        fi
        [ "$tries" -gt 0 ] || return 1
        tries=$((tries - 1))
        sleep 0.2
    done
    printf '%s\n' "$$" >"$lock/pid"
    trap sync_unlock EXIT
}

sync_unlock() {
    trap - EXIT
    rm -rf "$(sync_lockdir)"
}

# with_timeout <seconds> <command...>: run the command, killed after <seconds>; returns
# its exit status.
with_timeout() {
    local seconds pid watchdog status
    seconds=$1
    shift
    "$@" &
    pid=$!
    (sleep "$seconds" && kill "$pid") >/dev/null 2>&1 &
    watchdog=$!
    wait "$pid" 2>/dev/null                  # without bash's "Terminated" notice
    status=$?
    kill "$watchdog" 2>/dev/null
    return "$status"
}
