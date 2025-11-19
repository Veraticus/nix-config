#!/usr/bin/env bash
# ntfy-notifier.sh - Send notifications to ntfy service for Gemini CLI events
#
# DESCRIPTION
#   Sends push notifications via ntfy service when Gemini CLI events occur.
#   Designed to be used as a hook in Gemini CLI.
#
# CONFIGURATION
#   GEMINI_HOOKS_NTFY_DISABLED  Set to "true" to disable notifications (enabled by default)
#   GEMINI_HOOKS_NTFY_URL       Full ntfy URL (e.g., https://ntfy.sh/mytopic)
#   GEMINI_HOOKS_NTFY_TOKEN     Optional authentication token
#   
#   Falls back to CLAUDE_HOOKS_NTFY_* variables if GEMINI_* are not set.
#   Also checks ~/.config/claude-code-ntfy/config.yaml for compatibility.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

DEBUG=false
if [[ "${GEMINI_HOOKS_DEBUG:-0}" == "1" ]]; then
    DEBUG=true
fi

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Check if notifications are disabled
if [[ "${GEMINI_HOOKS_NTFY_DISABLED:-}" == "true" ]]; then
    log_debug "ntfy notifications disabled"
    exit 0
fi

# Resolve configuration (Gemini > Claude > Config File)
NTFY_URL="${GEMINI_HOOKS_NTFY_URL:-${CLAUDE_HOOKS_NTFY_URL:-}}"
NTFY_TOKEN="${GEMINI_HOOKS_NTFY_TOKEN:-${CLAUDE_HOOKS_NTFY_TOKEN:-}}"

if [[ -z "$NTFY_URL" ]]; then
    CONFIG_FILE="$HOME/.config/claude-code-ntfy/config.yaml"
    if [[ -f "$CONFIG_FILE" ]]; then
        NTFY_SERVER=$(grep "^ntfy_server:" "$CONFIG_FILE" 2>/dev/null | sed 's/^ntfy_server:[ ]*//' | tr -d '"' || true)
        NTFY_TOPIC=$(grep "^ntfy_topic:" "$CONFIG_FILE" 2>/dev/null | sed 's/^ntfy_topic:[ ]*//' | tr -d '"' || true)
        
        if [[ -n "$NTFY_SERVER" ]] && [[ -n "$NTFY_TOPIC" ]]; then
            NTFY_URL="${NTFY_SERVER}/${NTFY_TOPIC}"
            log_debug "Loaded ntfy config from $CONFIG_FILE"
        fi
    fi
fi

if [[ -z "$NTFY_URL" ]]; then
    log_debug "NTFY_URL not configured"
    exit 0
fi

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
    log_debug "curl not found"
    exit 0
fi

# Rate limiting
RATE_LIMIT_FILE="/tmp/.gemini-ntfy-rate-limit"
if [[ -f "$RATE_LIMIT_FILE" ]]; then
    LAST_NOTIFICATION=$(cat "$RATE_LIMIT_FILE" 2>/dev/null) || LAST_NOTIFICATION="0"
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_NOTIFICATION))
    
    if [[ $TIME_DIFF -lt 2 ]]; then
        log_debug "Rate limit: skipping notification"
        exit 0
    fi
fi
date +%s > "$RATE_LIMIT_FILE"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

clean_terminal_title() {
    local title="$1"
    echo "$title" | sed -E 's/[✅🤖⚡✨🔮💫☁️🌟🚀🎯🔍🛡️📝🧠🖨️🔐📤⏳❌⚠️]//g' | sed 's/[[:cntrl:]]//g' | xargs
}

get_terminal_title() {
    local title=""
    # Simplified title getter
    if [[ "${TERM_PROGRAM:-}" == "tmux" ]] && command -v tmux >/dev/null 2>&1; then
        if [[ -n "${TMUX:-}" ]]; then
            local window_name
            window_name=$(tmux display-message -p '#W' 2>/dev/null || echo "")
            title="$window_name"
        fi
    else
        title="tty: $(tty 2>/dev/null | xargs basename)"
    fi
    clean_terminal_title "$title"
}

get_context() {
    local cwd_basename
    cwd_basename=$(basename "$PWD")
    local term_title
    term_title=$(get_terminal_title)
    
    local context="Gemini CLI: $cwd_basename"
    if [[ -n "$term_title" ]]; then
        context="$context - $term_title"
    fi
    echo "$context"
}

send_notification() {
    local title="$1"
    local message="$2"
    
    local curl_args=(-s --max-time 5 -X POST)
    curl_args+=(-H "Title: $title")
    
    if [[ -n "${NTFY_TOKEN:-}" ]]; then
        curl_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
    fi
    
    curl_args+=(-d "$message" "$NTFY_URL")
    
    curl "${curl_args[@]}" >/dev/null 2>&1 || true
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

if [[ ! -t 0 ]]; then
    JSON_INPUT=$(cat)
    log_debug "Input: $JSON_INPUT"
    
    if ! command -v jq >/dev/null 2>&1; then
        # Fallback if jq missing
        CONTEXT=$(get_context)
        send_notification "$CONTEXT" "Gemini finished responding"
        exit 0
    fi
    
    # Try to parse prompt or response from JSON
    # Assuming structure has 'prompt' and 'response' or similar
    PROMPT=$(echo "$JSON_INPUT" | jq -r '.prompt // empty' 2>/dev/null | cut -c 1-50)
    RESPONSE=$(echo "$JSON_INPUT" | jq -r '.response // empty' 2>/dev/null | cut -c 1-50)
    
    MESSAGE="Gemini finished responding"
    if [[ -n "$PROMPT" ]]; then
        MESSAGE="Request: $PROMPT..."
    fi
    
    CONTEXT=$(get_context)
    send_notification "$CONTEXT" "$MESSAGE"
else
    # CLI test mode
    CONTEXT=$(get_context)
    send_notification "$CONTEXT" "Test notification from Gemini CLI"
fi
