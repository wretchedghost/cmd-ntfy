#!/bin/sh
# pve-remove-nag.sh
# Version: 1.1.0
# Description: Removes the Proxmox VE "no valid subscription" nag from both
#              the web UI and the mobile UI. Idempotent - safe to re-run
#              after every Proxmox update, since it only patches files that
#              aren't already patched.
# Usage: sudo ./pve-remove-nag.sh
#
# Changelog:
# 1.1.0 - Added backup of original files before first patch (*.orig, never
#         overwritten once it exists) so either patch can be reverted.
#         Added root check. Added exit-code checks on sed/write operations.
#         Fixed the mobile UI's injected JS: setInterval polling every
#         300ms was never cleared, so it ran forever in the background
#         after the 10s MutationObserver window closed - wastes CPU/battery
#         on a phone left on the Proxmox mobile GUI. Now both are cleared
#         together.
# 1.0.0 - Initial version

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (needs to write to /usr/share/...)." >&2
    exit 1
fi

WEB_JS=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
if [ -s "$WEB_JS" ] && ! grep -q NoMoreNagging "$WEB_JS"; then
    echo "Patching Web UI nag..."
    [ -f "${WEB_JS}.orig" ] || cp "$WEB_JS" "${WEB_JS}.orig"
    if sed -i -e "/data\.status/ s/!//" -e "/data\.status/ s/active/NoMoreNagging/" "$WEB_JS"; then
        echo "  Web UI patched. Original saved to ${WEB_JS}.orig"
    else
        echo "  Failed to patch Web UI nag." >&2
    fi
fi

MOBILE_TPL=/usr/share/pve-yew-mobile-gui/index.html.tpl
MARKER="<!-- MANAGED BLOCK FOR MOBILE NAG -->"
if [ -f "$MOBILE_TPL" ] && ! grep -q "$MARKER" "$MOBILE_TPL"; then
    echo "Patching Mobile UI nag..."
    [ -f "${MOBILE_TPL}.orig" ] || cp "$MOBILE_TPL" "${MOBILE_TPL}.orig"
    if printf "%s\n" \
      "$MARKER" \
      "<script>" \
      "  function removeSubscriptionElements() {" \
      "    // --- Remove subscription dialogs ---" \
      "    const dialogs = document.querySelectorAll('dialog.pwt-outer-dialog');" \
      "    dialogs.forEach(dialog => {" \
      "      const text = (dialog.textContent || '').toLowerCase();" \
      "      if (text.includes('subscription')) {" \
      "        dialog.remove();" \
      "        console.log('Removed subscription dialog');" \
      "      }" \
      "    });" \
      "" \
      "    // --- Remove subscription cards, but keep Reboot/Shutdown/Console ---" \
      "    const cards = document.querySelectorAll('.pwt-card.pwt-p-2.pwt-d-flex.pwt-interactive.pwt-justify-content-center');" \
      "    cards.forEach(card => {" \
      "      const text = (card.textContent || '').toLowerCase();" \
      "      const hasButton = card.querySelector('button');" \
      "      if (!hasButton && text.includes('subscription')) {" \
      "        card.remove();" \
      "        console.log('Removed subscription card');" \
      "      }" \
      "    });" \
      "  }" \
      "" \
      "  const observer = new MutationObserver(removeSubscriptionElements);" \
      "  const pollId = setInterval(removeSubscriptionElements, 300);" \
      "  observer.observe(document.body, { childList: true, subtree: true });" \
      "  removeSubscriptionElements();" \
      "  setTimeout(() => { observer.disconnect(); clearInterval(pollId); }, 10000);" \
      "</script>" \
      "" >> "$MOBILE_TPL"; then
        echo "  Mobile UI patched. Original saved to ${MOBILE_TPL}.orig"
    else
        echo "  Failed to patch Mobile UI nag." >&2
    fi
fi
