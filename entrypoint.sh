#!/bin/sh
set +e

# Set timezone via environment variable (no root required)
TZ=${TZ:-UTC}
if [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    export TZ
else
    echo "Warning: Invalid timezone , using UTC as fallback"
    export TZ=UTC
fi

# Push the run result to an Uptime Kuma push monitor, if configured.
# Args: $1 - status (up|down), $2 - URL-safe message
heartbeat() {
    [ -n "${HEARTBEAT_URL:-}" ] || return 0
    for attempt in 1 2 3; do
        if wget -q -O /dev/null -T 30 "${HEARTBEAT_URL}?status=$1&msg=$2"; then
            echo "Heartbeat pushed ($1)"
            return 0
        fi
        [ "$attempt" -lt 3 ] && sleep 10
    done
    echo "Warning: failed to push heartbeat after 3 attempts" >&2
    return 0
}

# Run backup immediately and terminate
echo "Running backup..."
/usr/local/bin/backup
rc=$?
if [ "$rc" -eq 0 ]; then
    heartbeat up "OK"
    echo "Backup completed. Container terminating."
else
    heartbeat down "backup_failed_exit_$rc"
    echo "Backup failed (exit $rc). Container terminating." >&2
fi
exit $rc
