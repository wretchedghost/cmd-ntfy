#!/bin/bash
# root-login-alert.sh
# Version: 1.0.0
# Description: Watches sshd logs for successful root logins. Alerts only
#              the first time a given source IP is ever seen logging in as
#              root on this host - known/repeat IPs stay silent so this
#              doesn't duplicate every normal admin login.
# Usage: run via cron every few minutes, e.g.:
#   */5 * * * * /usr/local/bin/root-login-alert.sh
# Setup:
#   First run seeds the known-IP list from whatever's found in the lookback
#   window WITHOUT alerting (so your own existing management IPs don't all
#   trigger alerts on day one). Every IP seen after that point is
#   considered known going forward.
#
# Changelog:
# 1.0.0 - Initial version

STATE_DIR="/var/lib/root-login-alert"
KNOWN_IPS_FILE="$STATE_DIR/known_ips"
LAST_CHECK_FILE="$STATE_DIR/last_check"
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
FIRST_RUN=false

if [ ! -f "$KNOWN_IPS_FILE" ]; then
    touch "$KNOWN_IPS_FILE"
    FIRST_RUN=true
fi

# Only scan since the last check to avoid re-processing old logins on
# every cron cycle. Default lookback on first run: 1 hour.
if [ -f "$LAST_CHECK_FILE" ]; then
    SINCE=$(cat "$LAST_CHECK_FILE")
else
    SINCE=$(date -d "1 hour ago" "+%Y-%m-%d %H:%M:%S")
fi
NOW=$(date "+%Y-%m-%d %H:%M:%S")

LOGINS=$(journalctl -u ssh -S "$SINCE" -U "$NOW" | \
         grep -E "Accepted (publickey|password|keyboard-interactive/pam) for root from" | \
         grep -oP 'from \K(?:[0-9]{1,3}\.){3}[0-9]{1,3}' | \
         sort -u)

echo "$NOW" > "$LAST_CHECK_FILE"

if [ -z "$LOGINS" ]; then
    exit 0
fi

NEW_IPS=""
while read -r ip; do
    if ! grep -qxF "$ip" "$KNOWN_IPS_FILE"; then
        echo "$ip" >> "$KNOWN_IPS_FILE"
        if ! $FIRST_RUN; then
            NEW_IPS="${NEW_IPS}
$ip"
        fi
    fi
done <<< "$LOGINS"

if $FIRST_RUN; then
    echo "First run: seeded known-IP baseline, no alert sent."
    exit 0
fi

if [ -n "$NEW_IPS" ]; then
    curl -H "Title: 🔑 New root login on $HOSTNAME" \
         -H "Priority: urgent" \
         -d "Root logged in via SSH from an IP not seen before on this host:
$NEW_IPS

Check: journalctl -u ssh -n 50" \
         "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
fi
