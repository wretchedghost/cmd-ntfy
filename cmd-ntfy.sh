#!/bin/bash
# command-notify.sh
# Description: Wrapper script that runs any command and sends ntfy notifications on completion
# Usage: command-notify.sh [-v|--verbose] <command> [arguments...]
# Example: command-notify.sh rsync -av /source /dest
# Example: command-notify.sh -v zpool status


### SOURCE NOTIFICATION CONFIG
if [ -f /etc/cron-notify.conf ]; then
    source /etc/cron-notify.conf
else
    # Default values if config file doesn't exist
    # Example:
    # NTFY_SERVER="your-ntfy-server.com"
    # NTFY_TOPIC="your-topic"
    # NTFY_USER="your-username"  # if needed
    # NTFY_PASS="your-password"  # if needed
    NTFY_SERVER=""
    NTFY_TOPIC=""
    NTFY_USER=""
    NTFY_PASS=""
fi

# Full paths for utilities
curl=/usr/bin/curl
date=/bin/date

# Parse verbose option
VERBOSE=false
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    VERBOSE=true
    shift
fi

# Function to send ntfy notifications
send_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    
    if [ -n "$NTFY_USER" ] && [ -n "$NTFY_PASS" ]; then
        $curl -u "$NTFY_USER:$NTFY_PASS" \
              -H "Title: $title" \
              -H "Priority: $priority" \
              -d "$message" \
              "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
    else
        $curl -H "Title: $title" \
              -H "Priority: $priority" \
              -d "$message" \
              "$NTFY_SERVER/$NTFY_TOPIC" 2>/dev/null
    fi
}

# Function to get human-readable duration
get_duration() {
    local duration=$1
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# Function to sanitize command for display (remove sensitive info if needed)
sanitize_command() {
    local cmd="$1"
    # Add any sanitization rules here if needed
    # For example, mask passwords: cmd=$(echo "$cmd" | sed 's/--password=[^ ]*/--password=****/g')
    echo "$cmd"
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [-v|--verbose] <command> [arguments...]"
    echo "  -v, --verbose  Show all output (default: limit to 30 lines)"
    echo "Example: $0 rsync -av /source /dest"
    echo "Example: $0 -v zpool status"
    exit 1
fi

# Capture the full command
FULL_COMMAND="$*"
COMMAND_NAME=$(basename "$1")

# Record start time
START_TIME=$(date +%s)
START_TIME_HUMAN=$($date)

# Optional: Send start notification (uncomment if desired)
# SANITIZED_CMD=$(sanitize_command "$FULL_COMMAND")
# send_notification "🔄 Command Started: $COMMAND_NAME" "Command: $SANITIZED_CMD"$'\n'"Started: $START_TIME_HUMAN"

# Execute the command and capture output and exit code
OUTPUT_FILE=$(mktemp)
"$@" 2>&1 | tee "$OUTPUT_FILE"
EXIT_CODE=${PIPESTATUS[0]}

# Record end time and calculate duration
END_TIME=$(date +%s)
END_TIME_HUMAN=$($date)
DURATION=$((END_TIME - START_TIME))
DURATION_HUMAN=$(get_duration $DURATION)

# Get the complete output and apply line limit if not verbose
OUTPUT_RAW="$(cat "$OUTPUT_FILE")"
OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE")
OUTPUT_LINES=$(wc -l < "$OUTPUT_FILE")

if $VERBOSE; then
    # Verbose mode: show all output
    OUTPUT_PREVIEW="$OUTPUT_RAW"
    OUTPUT_NOTE=""
else
    # Limited mode: show first 30 lines
    if [ $OUTPUT_LINES -gt 30 ]; then
        OUTPUT_PREVIEW="$(head -n 30 "$OUTPUT_FILE")"
        OUTPUT_NOTE="Output limited to 30 lines (total: $OUTPUT_LINES lines, use -v for full output)"
    else
        OUTPUT_PREVIEW="$OUTPUT_RAW"
        OUTPUT_NOTE=""
    fi
fi

# Clean up temp file
rm "$OUTPUT_FILE"

# Sanitize command for notification
SANITIZED_CMD=$(sanitize_command "$FULL_COMMAND")

# Send notification based on exit code
if [ $EXIT_CODE -eq 0 ]; then
    # Success notification - using actual newlines instead of \n
    MESSAGE="✅ Command: $SANITIZED_CMD
⏱️ Duration: $DURATION_HUMAN
🕒 Completed: $END_TIME_HUMAN"
    
    if [ -n "$OUTPUT_PREVIEW" ]; then
        MESSAGE="$MESSAGE

📋 Output:
$OUTPUT_PREVIEW"
    fi
    
    if [ -n "$OUTPUT_NOTE" ]; then
        MESSAGE="$MESSAGE

ℹ️ $OUTPUT_NOTE"
    fi
    
    send_notification "✅ $COMMAND_NAME Completed" "$MESSAGE"
else
    # Failure notification - using actual newlines instead of \n
    MESSAGE="❌ Command: $SANITIZED_CMD
💥 Exit code: $EXIT_CODE
⏱️ Duration: $DURATION_HUMAN
🕒 Failed: $END_TIME_HUMAN"
    
    if [ -n "$OUTPUT_PREVIEW" ]; then
        MESSAGE="$MESSAGE

📋 Output/Error:
$OUTPUT_PREVIEW"
    fi
    
    if [ -n "$OUTPUT_NOTE" ]; then
        MESSAGE="$MESSAGE

ℹ️ $OUTPUT_NOTE"
    fi
    
    send_notification "❌ $COMMAND_NAME Failed" "$MESSAGE" "high"
fi

# Exit with the same code as the wrapped command
exit $EXIT_CODE
