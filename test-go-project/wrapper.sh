#!/usr/bin/env bash
# Wrapper to capture all output from smart-test.sh

echo "=== Starting wrapper ===" >&2

# Capture both stdout and stderr
exec 2>&1

# Run the hook with input
cat test-hook-input.json | ~/.claude/hooks/smart-test.sh

EXIT_CODE=$?
echo "=== Hook exited with code: $EXIT_CODE ===" >&2
exit $EXIT_CODE