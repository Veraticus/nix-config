#!/usr/bin/env bash

# Debug test to understand the mock behavior
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Set required variables
export HOOK_DIR="/home/joshsymonds/nix-config/home-manager/claude-code/hooks"
export SPEC_DIR="$HOOK_DIR/spec"

# Source the test helpers
source "$SPEC_DIR/spec_helper.sh"

# Mock tilt command  
mock_command "tilt" 0 '{"result": {"resources": [], "manifests": []}}'

# Now run tilt and see what happens
echo "Running: tilt alpha tiltfile-result -f Tiltfile"
tilt alpha tiltfile-result -f Tiltfile

echo -e "\nOutput:"
tilt alpha tiltfile-result -f Tiltfile 2>&1

echo -e "\nPiping to jq:"
tilt alpha tiltfile-result -f Tiltfile 2>&1 | jq .

echo -e "\nChecking exit code:"
if tilt alpha tiltfile-result -f Tiltfile 2>&1 | jq . >/dev/null 2>&1; then
    echo "jq succeeded"
else
    echo "jq failed"
fi