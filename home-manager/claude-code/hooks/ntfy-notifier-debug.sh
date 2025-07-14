#!/usr/bin/env bash
# Debug wrapper for ntfy-notifier.sh
# This wrapper enables debug mode and logs all input/output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/ntfy-notifier-debug.log"

{
    echo "=== ntfy-notifier-debug.sh called at $(date) ==="
    echo "Arguments: $*"
    echo "Environment:"
    echo "  CLAUDE_HOOKS_NTFY_ENABLED=${CLAUDE_HOOKS_NTFY_ENABLED:-not set}"
    echo "  CLAUDE_HOOKS_NTFY_URL=${CLAUDE_HOOKS_NTFY_URL:-not set}"
} >> "$LOG_FILE"

# Capture stdin
if [[ ! -t 0 ]]; then
    STDIN_CONTENT=$(cat)
    echo "STDIN content:" >> "$LOG_FILE"
    echo "$STDIN_CONTENT" >> "$LOG_FILE"
    
    # Pass it to the real script with debug enabled
    export CLAUDE_HOOKS_DEBUG=1
    export CLAUDE_HOOKS_NTFY_ENABLED=true
    echo "$STDIN_CONTENT" | "$SCRIPT_DIR/ntfy-notifier.sh" "$@" 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
else
    echo "No stdin input" >> "$LOG_FILE"
    export CLAUDE_HOOKS_DEBUG=1
    export CLAUDE_HOOKS_NTFY_ENABLED=true
    "$SCRIPT_DIR/ntfy-notifier.sh" "$@" 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=$?
fi

{
    echo "Exit code: $EXIT_CODE"
    echo "=== End of ntfy-notifier-debug.sh ==="
    echo ""
} >> "$LOG_FILE"

exit "$EXIT_CODE"