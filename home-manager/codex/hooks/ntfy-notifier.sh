#!/usr/bin/env bash
# ntfy-notifier.sh - Send ntfy notifications for Codex CLI turns
#
# This script mirrors the Claude Code notifier but adapts to Codex's notify hook.

set -euo pipefail

DEBUG=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      DEBUG=true
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ntfy-notifier.sh [--debug] [NOTIFICATION_JSON]

With Codex, this script is invoked automatically via the `notify` hook and
receives a single JSON argument describing the event. Running it manually
without JSON sends a test notification (if configured).
USAGE
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

log_debug() {
  if [[ "$DEBUG" == "true" ]]; then
    printf '[DEBUG] %s\n' "$*" >&2
  fi
}

clean_text() {
  # Remove control characters and collapse whitespace.
  printf '%s' "$1" | tr '\n' ' ' | tr -d '\r' | sed 's/[[:cntrl:]]//g' | tr -s ' ' | sed 's/^ *//;s/ *$//'
}

truncate_text() {
  local text="$1"
  local limit="$2"
  local length=${#text}
  if (( length > limit )); then
    printf '%s…' "${text:0:limit}"
  else
    printf '%s' "$text"
  fi
}

CONFIG_FILE="$HOME/.config/claude-code-ntfy/config.yaml"
NTFY_URL="${CODEX_NTFY_URL:-${CLAUDE_HOOKS_NTFY_URL:-}}"
NTFY_TOKEN="${CODEX_NTFY_TOKEN:-${CLAUDE_HOOKS_NTFY_TOKEN:-}}"

if [[ -z "$NTFY_URL" ]] && [[ -f "$CONFIG_FILE" ]]; then
  NTFY_SERVER=$(grep "^ntfy_server:" "$CONFIG_FILE" 2>/dev/null | sed 's/^ntfy_server:[ ]*//' | tr -d '"' || true)
  NTFY_TOPIC=$(grep "^ntfy_topic:" "$CONFIG_FILE" 2>/dev/null | sed 's/^ntfy_topic:[ ]*//' | tr -d '"' || true)
  if [[ -z "$NTFY_TOKEN" ]]; then
    NTFY_TOKEN=$(grep "^ntfy_token:" "$CONFIG_FILE" 2>/dev/null | sed 's/^ntfy_token:[ ]*//' | tr -d '"' || true)
  fi
  if [[ -n "$NTFY_SERVER" ]] && [[ -n "$NTFY_TOPIC" ]]; then
    NTFY_SERVER=${NTFY_SERVER%/}
    NTFY_URL="$NTFY_SERVER/$NTFY_TOPIC"
    log_debug "Loaded ntfy configuration from $CONFIG_FILE"
  fi
fi

if [[ -z "$NTFY_URL" ]]; then
  log_debug "ntfy URL not configured; skipping notification"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  log_debug "curl not found; skipping notification"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log_debug "jq not found; skipping notification"
  exit 0
fi

RATE_LIMIT_FILE="/tmp/.codex-ntfy-rate-limit"
if [[ -f "$RATE_LIMIT_FILE" ]]; then
  LAST_TS=$(cat "$RATE_LIMIT_FILE" 2>/dev/null || printf '0')
  NOW_TS=$(date +%s)
  if (( NOW_TS - LAST_TS < 2 )); then
    log_debug "Rate limit active; skipping notification"
    exit 0
  fi
fi

JSON_INPUT="${1:-}"
if [[ -z "$JSON_INPUT" ]] && [[ ! -t 0 ]]; then
  JSON_INPUT=$(cat)
fi

if [[ -z "$JSON_INPUT" ]]; then
  log_debug "No JSON payload supplied; sending test notification"
  TITLE="Codex: Test Notification"
  HOSTNAME_VALUE=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown-host')
  PWD_PATH="${PWD:-$(pwd)}"
  PWD_DISPLAY="${PWD_PATH/#$HOME/~}"
  CONTEXT="Host $HOSTNAME_VALUE • $PWD_DISPLAY"
  MESSAGE="${CONTEXT}"
else
  if ! echo "$JSON_INPUT" | jq . >/dev/null 2>&1; then
    log_debug "Invalid JSON payload"
    exit 0
  fi

  TYPE=$(echo "$JSON_INPUT" | jq -r '.type // empty')
  if [[ "$TYPE" != "agent-turn-complete" ]]; then
    log_debug "Ignoring unsupported notification type: $TYPE"
    exit 0
  fi

  HOSTNAME_VALUE=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'unknown-host')
  DEVSPACE="${TMUX_DEVSPACE:-}"; DEVSPACE=$(printf '%s' "$DEVSPACE" | tr -d '[:cntrl:]')
  PWD_PATH="${PWD:-$(pwd)}"
  PWD_DISPLAY="${PWD_PATH/#$HOME/~}"

  CONTEXT="${HOSTNAME_VALUE}"
  if [[ -n "$DEVSPACE" ]]; then
    CONTEXT+=":${DEVSPACE}"
  fi
  CONTEXT+=" • ${PWD_DISPLAY}"

  INPUT_SUMMARY=$(echo "$JSON_INPUT" | jq -r '."input-messages" | select(type=="array") | map(tostring) | join(" ") // empty')
  LAST_ASSISTANT=$(echo "$JSON_INPUT" | jq -r '."last-assistant-message" // empty')

  INPUT_SUMMARY=$(clean_text "$INPUT_SUMMARY")
  LAST_ASSISTANT=$(clean_text "$LAST_ASSISTANT")

  TITLE_SOURCE="$LAST_ASSISTANT"
  if [[ -z "$TITLE_SOURCE" ]]; then
    TITLE_SOURCE="$INPUT_SUMMARY"
  fi
  if [[ -z "$TITLE_SOURCE" ]]; then
    TITLE="Codex: Turn Complete"
  else
    TITLE="Codex: $TITLE_SOURCE"
  fi
  TITLE=$(truncate_text "$(clean_text "$TITLE")" 160)

  MESSAGE="Host ${CONTEXT}"
  if [[ -n "$LAST_ASSISTANT" ]]; then
    MESSAGE+=" — ${LAST_ASSISTANT}"
  elif [[ -n "$INPUT_SUMMARY" ]]; then
    MESSAGE+=" — ${INPUT_SUMMARY}"
  fi
  MESSAGE=$(truncate_text "$(clean_text "$MESSAGE")" 240)
fi

date +%s > "$RATE_LIMIT_FILE"

log_debug "Sending notification to $NTFY_URL"

CURL_ARGS=(
  -s
  --max-time 5
  -X POST
  -H "Title: $TITLE"
)

if [[ -n "$NTFY_TOKEN" ]]; then
  CURL_ARGS+=( -H "Authorization: Bearer ${NTFY_TOKEN}" )
fi

CURL_ARGS+=( -d "$MESSAGE" "$NTFY_URL" )

if [[ "$DEBUG" == "true" ]]; then
  SAFE_ARGS=("${CURL_ARGS[@]}")
  for i in "${!SAFE_ARGS[@]}"; do
    if [[ "${SAFE_ARGS[i]}" == Authorization:* ]]; then
      SAFE_ARGS[i]='Authorization: Bearer [REDACTED]'
    fi
  done
  log_debug "curl ${SAFE_ARGS[*]}"
fi

if ! curl "${CURL_ARGS[@]}" >/dev/null 2>&1; then
  log_debug "Failed to send notification"
  exit 1
fi

find /tmp -name ".codex-ntfy-rate-limit" -mmin +60 -delete 2>/dev/null || true
