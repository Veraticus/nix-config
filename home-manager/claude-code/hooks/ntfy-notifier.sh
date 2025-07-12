#!/usr/bin/env bash
# ntfy-notifier.sh - Send notifications to ntfy service for Claude Code events
#
# SYNOPSIS
#   ntfy-notifier.sh [--debug]
#   echo '{"event":"PostToolUse","tool":"Edit","tool_input":{"file_path":"test.go"}}' | ntfy-notifier.sh
#
# DESCRIPTION
#   Sends push notifications via ntfy service when Claude Code events occur.
#   Supports both CLI mode for testing and hook mode for actual notifications.
#
# CONFIGURATION
#   CLAUDE_HOOKS_NTFY_ENABLED   Set to "true" to enable notifications
#   CLAUDE_HOOKS_NTFY_URL       Full ntfy URL (e.g., https://ntfy.sh/mytopic)
#   CLAUDE_HOOKS_NTFY_TOKEN     Optional authentication token
#
# EXAMPLES
#   # Test notification in CLI mode
#   ./ntfy-notifier.sh
#
#   # Hook mode (JSON input from stdin)
#   echo '{"event":"PostToolUse","tool":"Edit","tool_input":{"file_path":"test.go"}}' | ./ntfy-notifier.sh
#
# ERROR HANDLING
#   - Validates configuration
#   - Retries failed notifications
#   - Rate limits to prevent spam

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Check if notifications are enabled (allow easy disable)
if [[ "${CLAUDE_HOOKS_NTFY_ENABLED:-}" != "true" ]]; then
    exit 0
fi

# Parse command line arguments
DEBUG=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Debug logging function
log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Check configuration
if [[ -z "${CLAUDE_HOOKS_NTFY_URL:-}" ]]; then
    echo "CLAUDE_HOOKS_NTFY_URL not configured" >&2
    exit 0
fi

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found" >&2
    exit 0
fi

if [[ "$DEBUG" == "true" ]]; then
    log_debug "ntfy is enabled"
    log_debug "URL: ${CLAUDE_HOOKS_NTFY_URL}"
    if [[ -n "${CLAUDE_HOOKS_NTFY_TOKEN:-}" ]]; then
        log_debug "Token: [configured]"
    fi
fi

# Rate limiting - prevent notification spam
RATE_LIMIT_FILE="/tmp/.claude-ntfy-rate-limit"
if [[ -f "$RATE_LIMIT_FILE" ]]; then
    LAST_NOTIFICATION=$(cat "$RATE_LIMIT_FILE" 2>/dev/null) || LAST_NOTIFICATION="0"
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_NOTIFICATION))
    
    # Limit to one notification per 2 seconds
    if [[ $TIME_DIFF -lt 2 ]]; then
        exit 0
    fi
fi
date +%s > "$RATE_LIMIT_FILE"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Get context information
get_context() {
    local cwd_basename
    cwd_basename=$(basename "$PWD")
    echo "Claude Code: $cwd_basename"
}

# Function to send notification with retry
send_notification() {
    local message="$1"
    local max_retries=2
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        local curl_args=(-s --max-time 5 -X POST)
        
        # Add authentication if token is configured
        if [[ -n "${CLAUDE_HOOKS_NTFY_TOKEN:-}" ]]; then
            curl_args+=(-H "Authorization: Bearer ${CLAUDE_HOOKS_NTFY_TOKEN}")
        fi
        
        # Add message and URL
        curl_args+=(-d "$message" "$CLAUDE_HOOKS_NTFY_URL")
        
        if curl "${curl_args[@]}" >/dev/null 2>&1; then
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        [[ $retry_count -lt $max_retries ]] && sleep 1
    done
    
    echo "Failed to send notification after $max_retries attempts" >&2
    return 1
}

# Format notification message for different tools
format_notification() {
    local tool="$1"
    local tool_input="$2"
    
    case "$tool" in
        "Edit"|"Write"|"MultiEdit")
            if command -v jq >/dev/null 2>&1; then
                local file_path
                file_path=$(echo "$tool_input" | jq -r '.file_path // empty' 2>/dev/null)
                if [[ -n "$file_path" ]]; then
                    echo "$tool: $file_path"
                else
                    echo "$tool"
                fi
            else
                echo "$tool"
            fi
            ;;
        "Bash")
            if command -v jq >/dev/null 2>&1; then
                local command
                command=$(echo "$tool_input" | jq -r '.command // empty' 2>/dev/null)
                if [[ -n "$command" ]]; then
                    echo "$tool: $command"
                else
                    echo "$tool"
                fi
            else
                echo "$tool"
            fi
            ;;
        "Read")
            # Ignore Read tool notifications
            return 1
            ;;
        *)
            echo "$tool"
            ;;
    esac
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Check if we have JSON input (hook mode)
if [[ ! -t 0 ]]; then
    # Read JSON input
    JSON_INPUT=$(cat)
    
    # Ensure jq is available for JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        log_debug "jq not available for JSON parsing"
        exit 0
    fi
    
    # Parse JSON input
    if echo "$JSON_INPUT" | jq . >/dev/null 2>&1; then
        EVENT=$(echo "$JSON_INPUT" | jq -r '.event // empty' 2>/dev/null)
        TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool // empty' 2>/dev/null)
        TOOL_INPUT=$(echo "$JSON_INPUT" | jq -r '.tool_input // "{}"' 2>/dev/null)
        
        # Only process PostToolUse events
        if [[ "$EVENT" == "PostToolUse" ]]; then
            # Format notification message
            if MESSAGE=$(format_notification "$TOOL_NAME" "$TOOL_INPUT"); then
                log_debug "Sending notification: $MESSAGE"
                send_notification "$MESSAGE"
            else
                log_debug "Ignoring tool: $TOOL_NAME"
                exit 0
            fi
        else
            log_debug "Ignoring event: $EVENT"
            exit 0
        fi
    else
        log_debug "Invalid JSON input"
        exit 0
    fi
else
    # CLI mode - send test notification
    MESSAGE="Test notification"
    log_debug "Sending test notification"
    send_notification "$MESSAGE"
fi

# Clean up old rate limit files (older than 1 hour)
find /tmp -name ".claude-ntfy-rate-limit" -mmin +60 -delete 2>/dev/null || true