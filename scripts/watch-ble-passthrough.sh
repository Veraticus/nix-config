#!/usr/bin/env bash
set -euo pipefail

if ! command -v hass-cli >/dev/null 2>&1; then
  echo "hass-cli not found in PATH" >&2
  exit 1
fi

hass-cli -o json event watch ble_passthrough.adv_received \
  | jq --unbuffered '.'
