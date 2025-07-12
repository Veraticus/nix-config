#!/usr/bin/env bash
# Minimal test to find where smart-test.sh fails

echo "Starting minimal test" >&2

# Test 1: Can we source the files?
echo "Test 1: Sourcing files" >&2
source ~/.claude/hooks/common-helpers.sh || { echo "FAIL: common-helpers.sh"; exit 1; }
echo "  ✓ common-helpers.sh" >&2

# Test 2: Can we source test-go.sh?
echo "Test 2: Sourcing test-go.sh" >&2
SCRIPT_DIR="/home/joshsymonds/.claude/hooks"
source "${SCRIPT_DIR}/test-go.sh" || { echo "FAIL: test-go.sh"; exit 1; }
echo "  ✓ test-go.sh" >&2

# Test 3: Does run_go_tests function exist?
echo "Test 3: Checking run_go_tests function" >&2
if type -t run_go_tests &>/dev/null; then
    echo "  ✓ run_go_tests exists" >&2
else
    echo "  ✗ run_go_tests not found" >&2
fi

# Test 4: What happens if we call the function?
echo "Test 4: Calling run_go_tests" >&2
FILE_PATH="math.go"
run_go_tests "$FILE_PATH" 2>&1 || echo "  Function returned: $?" >&2

echo "Minimal test completed" >&2