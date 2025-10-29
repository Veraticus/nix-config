#!/usr/bin/env bash
set -euo pipefail

ADDRESS=$(echo "${1:-DD:88:00:00:0D:13}" | tr '[:lower:]' '[:upper:]')

if ! command -v hass-cli >/dev/null 2>&1; then
  echo "hass-cli not found in PATH" >&2
  exit 1
fi

hass-cli -o json event watch ble_passthrough.adv_received \
  | jq --unbuffered --arg address "$ADDRESS" '
      select(.data.address != null)
      | select((.data.address | ascii_upcase) == $address)
      | {
          time: .time_fired,
          address: .data.address,
          rssi: .data.rssi,
          uuid: (
            if (.data.data | length) >= 25 then
              ((.data.data[9:25] | join("")) as $raw
                | ($raw[:8] + "-" + $raw[8:12] + "-" + $raw[12:16] + "-" + $raw[16:20] + "-" + $raw[20:]))
            else
              null
            end
          ),
          major: (
            if (.data.data | length) >= 27 then
              (.data.data[25:27] | join(""))
            else
              null
            end
          ),
          minor: (
            if (.data.data | length) >= 26 then
              (.data.data[24:26] | join(""))
            else
              null
            end
          ),
          manufacturer_data: .data.manufacturer_data,
          service_data: .data.service_data
        }
    '
