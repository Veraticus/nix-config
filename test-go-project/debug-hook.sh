#!/usr/bin/env bash
# Debug version of smart-test.sh

set -euo pipefail

# Add debug output
echo "DEBUG: Starting hook" >&2

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="/home/joshsymonds/.claude/hooks"  # Override for testing
echo "DEBUG: SCRIPT_DIR=$SCRIPT_DIR" >&2

source "${SCRIPT_DIR}/common-helpers.sh" || { echo "ERROR: Failed to source common-helpers.sh"; exit 1; }
echo "DEBUG: Sourced common-helpers.sh" >&2

# Read input
INPUT=$(cat)
echo "DEBUG: Read input of length ${#INPUT}" >&2

# Parse JSON
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
echo "DEBUG: TOOL_NAME=$TOOL_NAME" >&2

# Check tool name
if [[ ! "$TOOL_NAME" =~ ^(Edit|Write|MultiEdit)$ ]]; then
    echo "DEBUG: Tool name not in allowed list, exiting with 2" >&2
    exit 2
fi

# Get file path
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
echo "DEBUG: FILE_PATH=$FILE_PATH" >&2

# Change directory
if [[ -n "$FILE_PATH" ]] && [[ "$FILE_PATH" != "./..." ]] && [[ -f "$FILE_PATH" ]]; then
    FILE_DIR=$(dirname "$FILE_PATH")
    cd "$FILE_DIR" || true
    echo "DEBUG: Changed to directory: $(pwd)" >&2
fi

# Load config
echo "DEBUG: About to load config" >&2
export CLAUDE_HOOKS_TEST_ON_EDIT="${CLAUDE_HOOKS_TEST_ON_EDIT:-true}"
export CLAUDE_HOOKS_TEST_MODES="${CLAUDE_HOOKS_TEST_MODES:-package}"
echo "DEBUG: Set test config variables" >&2

# Try to source test-go.sh
echo "DEBUG: Checking for test-go.sh at ${SCRIPT_DIR}/test-go.sh" >&2
if [[ -f "${SCRIPT_DIR}/test-go.sh" ]]; then
    echo "DEBUG: Found test-go.sh, sourcing it" >&2
    source "${SCRIPT_DIR}/test-go.sh" || { echo "ERROR: Failed to source test-go.sh with code $?"; exit 1; }
    echo "DEBUG: Successfully sourced test-go.sh" >&2
else
    echo "ERROR: test-go.sh not found at ${SCRIPT_DIR}/test-go.sh" >&2
    exit 1
fi

echo "DEBUG: Hook completed successfully" >&2