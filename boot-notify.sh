#!/bin/bash
# boot-notify.sh
# Version: 1.0.0
# Description: Sends an ntfy notification on boot, flagging whether the
#              previous shutdown looked clean (planned reboot/poweroff) or
#              abrupt (crash, panic, power loss) - so an unexpected reboot
#              actually stands out instead of blending in with routine
#              maintenance restarts.
# Usage: add as a cron @reboot entry:
#   @reboot sleep 30 && /usr/local/bin/boot-notify.sh
#   (the sleep gives networking a moment to come up before curl runs)
#
# Changelog:
# 1.0.0 - Initial version

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
BOOT_TIME=$(who -b | awk '{print $3, $4}')

if ! journalctl -b -1 -n 1 &>/dev/null; then
    # No previous boot record available (fresh install, or the journal was
    # rotated/vacuumed past the previous boot) - just confirm the boot,
    # no clean/unclean judgment possible.
    curl -H "Title: 🔄 $HOSTNAME booted" \
         -H "Priority: default" \
         -d "Boot time: $BOOT_TIME
No previous boot record found." \
         "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
    exit 0
fi

# Look at the tail of the previous boot's log for evidence of a clean
# shutdown (reaching a poweroff/reboot/halt target). If that's missing,
# the system went down some other way - crash, panic, power loss, etc.
PREV_BOOT_TAIL=$(journalctl -b -1 -n 15 --no-pager 2>/dev/null)

if echo "$PREV_BOOT_TAIL" | grep -qE "Reached target (Power-Off|Reboot|System Halt)|Stopped target"; then
    curl -H "Title: 🔄 $HOSTNAME rebooted" \
         -H "Priority: default" \
         -d "Boot time: $BOOT_TIME
Previous shutdown looked clean." \
         "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
else
    curl -H "Title: ⚠️ $HOSTNAME rebooted unexpectedly" \
         -H "Priority: high" \
         -d "Boot time: $BOOT_TIME
No clean shutdown found before this boot - possible crash, panic, or power loss.

Last lines from the previous boot's log:
$PREV_BOOT_TAIL" \
         "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
fi
