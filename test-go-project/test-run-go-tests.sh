#!/usr/bin/env bash
# Test run_go_tests function directly

# Setup environment
cd /home/joshsymonds/nix-config/test-go-project
source ~/.claude/hooks/common-helpers.sh
source ~/.claude/hooks/test-go.sh

# Set required variables
export CLAUDE_HOOKS_TEST_MODES="package"
export CLAUDE_HOOKS_ENABLE_RACE="true"
export CLAUDE_HOOKS_TEST_VERBOSE="false"
export CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS=""

# Test the function
echo "=== Testing run_go_tests function ===" >&2
echo "Current directory: $(pwd)" >&2
echo "Files in directory:" >&2
ls -la *.go >&2

# Call the function
echo "Calling run_go_tests with math.go" >&2
run_go_tests "math.go" 2>&1
EXIT_CODE=$?

echo "run_go_tests returned: $EXIT_CODE" >&2

# Also test with test file directly
echo -e "\n=== Testing with test file ===" >&2
run_go_tests "math_test.go" 2>&1
EXIT_CODE=$?
echo "run_go_tests returned: $EXIT_CODE" >&2