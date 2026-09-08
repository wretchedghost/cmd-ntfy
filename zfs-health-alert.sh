#!/bin/bash
# zfs-health-alert.sh
# Version: 1.0.0
# Description: Checks all ZFS pools for degraded/faulted state or nonzero
#              read/write/checksum errors, and reports scrub/resilver
#              results as soon as one finishes. Only alerts when something
#              changes (health gets worse, health recovers, or a new scan
#              completes) - not on every cron run while a known issue
#              persists.
# Usage: run via cron, e.g. every 30 minutes:
#   */30 * * * * /usr/local/bin/zfs-health-alert.sh
#
# Changelog:
# 1.0.0 - Initial version

STATE_DIR="/var/lib/zfs-health-alert"
mkdir -p "$STATE_DIR"

if [ -f /etc/cron-notify.conf ]; then
    source /etc/cron-notify.conf
else
    echo "Warning: /etc/cron-notify.conf not found - notifications will fail." >&2
    NTFY_SERVER=""
    NTFY_TOPIC=""
fi

if [ -z "$NTFY_SERVER" ] || [ -z "$NTFY_TOPIC" ]; then
    echo "Warning: NTFY_SERVER or NTFY_TOPIC is not set (check /etc/cron-notify.conf)." >&2
fi

HOSTNAME=$(hostname)

notify() {
    local title="$1"
    local body="$2"
    local priority="${3:-default}"
    curl -H "Title: $title" \
         -H "Priority: $priority" \
         -d "$body" \
         "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
}

for POOL in $(zpool list -H -o name); do
    STATUS_OUTPUT=$(zpool status "$POOL")

    STATE_LINE=$(echo "$STATUS_OUTPUT" | awk '/^[[:space:]]*state:/{print $2; exit}')
    SCAN_LINE=$(echo "$STATUS_OUTPUT" | awk '/^[[:space:]]*scan:/{sub(/^[[:space:]]*scan:[[:space:]]*/,""); print; exit}')
    ERROR_COUNTS=$(echo "$STATUS_OUTPUT" | awk '/ONLINE|DEGRADED|FAULTED|UNAVAIL|OFFLINE/{print $3,$4,$5}' | grep -vE '^0 0 0$')

    PREV_STATE_FILE="$STATE_DIR/${POOL}.state"
    PREV_SCAN_FILE="$STATE_DIR/${POOL}.scan"

    PREV_STATE=$(cat "$PREV_STATE_FILE" 2>/dev/null || echo "ONLINE")
    PREV_SCAN=$(cat "$PREV_SCAN_FILE" 2>/dev/null || echo "")

    # Alert when the pool is unhealthy or has error counters and this is a
    # change from last run - avoids re-alerting every cycle for a known,
    # unresolved issue. Also alert once when it recovers back to healthy.
    if { [ "$STATE_LINE" != "ONLINE" ] || [ -n "$ERROR_COUNTS" ]; } && [ "$PREV_STATE" != "$STATE_LINE" ]; then
        notify "🚨 ZFS pool $POOL is $STATE_LINE on $HOSTNAME" \
               "$STATUS_OUTPUT" \
               "urgent"
    elif [ "$STATE_LINE" == "ONLINE" ] && [ -z "$ERROR_COUNTS" ] && [ "$PREV_STATE" != "ONLINE" ]; then
        notify "✅ ZFS pool $POOL is healthy again on $HOSTNAME" \
               "$STATUS_OUTPUT" \
               "default"
    fi
    echo "$STATE_LINE" > "$PREV_STATE_FILE"

    # Report scrub/resilver completion the first time we see a finished
    # scan line different from the last one we reported. Skip while a
    # scan is still in progress - wait for it to actually finish.
    if [ -n "$SCAN_LINE" ] && [ "$SCAN_LINE" != "$PREV_SCAN" ] && [ "$SCAN_LINE" != "none requested" ]; then
        if echo "$SCAN_LINE" | grep -q "in progress"; then
            : # still running - wait for it to finish before reporting
        else
            if echo "$SCAN_LINE" | grep -qE "with [1-9][0-9]* errors"; then
                PRIORITY="urgent"
                ICON="⚠️"
            else
                PRIORITY="default"
                ICON="✅"
            fi
            notify "$ICON ZFS scan finished on $POOL ($HOSTNAME)" \
                   "$SCAN_LINE" \
                   "$PRIORITY"
            echo "$SCAN_LINE" > "$PREV_SCAN_FILE"
        fi
    fi
done
