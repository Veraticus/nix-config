#!/usr/bin/env bash
# Debug with error trap

cat test-hook-input.json | bash -c '
# Add error trap
trap '\''echo "ERROR at line $LINENO, exit code $?" >&2'\'' ERR

# Remove set -e temporarily to see where it fails
set +e

# Source and run the hook manually
source ~/.claude/hooks/common-helpers.sh
echo "Sourced common-helpers.sh: $?" >&2

# Simulate the hook logic
INPUT=$(cat)
echo "Read input: $?" >&2

TOOL_NAME=$(echo "$INPUT" | jq -r ".tool_name // empty")
echo "Got TOOL_NAME=$TOOL_NAME: $?" >&2

if [[ ! "$TOOL_NAME" =~ ^(Edit|Write|MultiEdit)$ ]]; then
    echo "Tool not in list, would exit 2" >&2
    exit 2
fi

TOOL_INPUT=$(echo "$INPUT" | jq -r ".tool_input // empty")
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r ".file_path // empty")
echo "Got FILE_PATH=$FILE_PATH: $?" >&2

# Check if test-go.sh exists
SCRIPT_DIR="/home/joshsymonds/.claude/hooks"
if [[ -f "${SCRIPT_DIR}/test-go.sh" ]]; then
    echo "test-go.sh exists" >&2
    # Try to source it
    source "${SCRIPT_DIR}/test-go.sh"
    echo "Sourced test-go.sh: $?" >&2
else
    echo "test-go.sh not found" >&2
fi
'