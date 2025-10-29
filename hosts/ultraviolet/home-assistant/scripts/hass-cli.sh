#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2317 # referenced from injected Nix code
find_timeout_command() {
  if command -v timeout >/dev/null 2>&1; then
    echo timeout
    return 0
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    echo gtimeout
    return 0
  fi
  return 1
}

# shellcheck disable=SC2317 # referenced from injected Nix code
run_hass_cli() {
  local real_cli="$1"
  shift

  local wrapper_timeout="${HASS_CLI_WRAP_TIMEOUT:-}"
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wrap-timeout=*)
        wrapper_timeout="${1#*=}"
        shift
        ;;
      --wrap-timeout)
        if [[ $# -lt 2 ]]; then
          echo "hass-cli wrapper: --wrap-timeout requires a value (e.g. --wrap-timeout 30s)." >&2
          return 2
        fi
        wrapper_timeout="$2"
        shift 2
        ;;
      --)
        args+=("$@")
        break
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -n "$wrapper_timeout" ]]; then
    if ! timeout_cmd="$(find_timeout_command)"; then
      echo "hass-cli wrapper: timeout command not found (tried timeout and gtimeout)." >&2
      return 127
    fi
    exec "$timeout_cmd" "$wrapper_timeout" "$real_cli" "${args[@]}"
  fi

  "$real_cli" "${args[@]}" &
  local child_pid=$!

  trap 'kill -TERM "$child_pid" 2>/dev/null' TERM
  trap 'kill -INT "$child_pid" 2>/dev/null' INT

  local status=0
  if ! wait "$child_pid"; then
    status=$?
  fi

  trap - TERM INT
  return "$status"
}

# Default server to local instance if not provided
if [ -z "${HASS_SERVER:-}" ]; then
  export HASS_SERVER="http://localhost:8123"
fi

# Try to source a token if not already provided in env
if [ -z "${HASS_TOKEN:-}" ]; then
  cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  token_path="$cfg_home/home-assistant/token"
  if [ -r "$token_path" ]; then
    export HASS_TOKEN="$(cat "$token_path")"
  else
    echo "hass-cli: token not found at $token_path. Create it with your long-lived access token (chmod 600)." >&2
    exit 1
  fi
fi

# The real hass-cli will be appended by Nix during build
