#!/bin/bash

# Define the workspace-icon mapping
WORKSPACE_ICONS=$(jq -n '{
  "1": "",
  "2": "",
  "3": "",
  "4": "",
  "5": "",
  "6": "",
}')

spaces (){
	WORKSPACE_WINDOWS=$(hyprctl workspaces -j | jq 'map({key: .id | tostring, value: .windows}) | from_entries')
	seq 1 10 | jq --argjson icons "${WORKSPACE_ICONS}" --argjson windows "${WORKSPACE_WINDOWS}" --slurp -Mc 'map(tostring) | map({id: ., windows: ($windows[.]//0), icon: ($icons[.]//null)}) | map(select(.windows != 0))'
}

spaces
socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
	spaces
done
