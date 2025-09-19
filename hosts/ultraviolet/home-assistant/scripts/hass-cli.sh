#!/usr/bin/env bash
set -euo pipefail

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
