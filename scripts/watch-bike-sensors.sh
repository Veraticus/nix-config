#!/usr/bin/env bash
set -euo pipefail

interval="${1:-0.5}"

while true; do
  ts=$(date -u +"%H:%M:%S.%3N")
  loc_json=$(hass-cli -o json state get sensor.josh_nice_bike_location)
  move_json=$(hass-cli -o json state get sensor.joshs_nice_bike_1b75_estimated_distance)

  loc_state=$(jq -r '.[0].state' <<<"$loc_json")
  loc_dist=$(jq -r '.[0].attributes.last_distance // "unknown"' <<<"$loc_json")
  loc_source=$(jq -r '.[0].attributes.last_source // "unknown"' <<<"$loc_json")
  move_dist=$(jq -r '.[0].state' <<<"$move_json")
  move_source=$(jq -r '.[0].attributes.source // "unknown"' <<<"$move_json")

  printf '%s regular:%s %sft via=%s | movement:%sft via=%s\n' \
    "$ts" "$loc_state" "$loc_dist" "$loc_source" "$move_dist" "$move_source"

  sleep "$interval"
done
