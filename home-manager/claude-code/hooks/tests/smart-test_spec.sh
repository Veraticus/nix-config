#!/usr/bin/env bash
# Tests for smart-test.sh hook

# Test framework setup
set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(dirname "$TEST_DIR")"
HOOK_SCRIPT="$HOOK_DIR/smart-test.sh"

# Create temporary test directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"
    
    assert_equals "$expected" "$actual" "$test_name"
}

# Test: Hook exits with code 0 for non-testable files
test_non_testable_files() {
    cd "$TEMP_DIR" || return 1
    
    # Test YAML file
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {"file_path": "test.yaml"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "YAML file should exit with 0"
    
    # Test JSON file
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {"file_path": "test.json"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "JSON file should exit with 0"
    
    # Test Markdown file
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {"file_path": "README.md"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "Markdown file should exit with 0"
}

# Test: Hook exits with code 0 for non-edit tools (silently ignores them)
test_non_edit_tools() {
    cd "$TEMP_DIR" || return 1
    
    # Test Read tool - should exit 0 since it's not an edit operation
    echo '{"event": "PostToolUse", "tool": "Read", "tool_input": {"file_path": "test.go"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "Read tool should exit with 0"
    
    # Test Bash tool - should exit 0 since it's not an edit operation
    echo '{"event": "PostToolUse", "tool": "Bash", "tool_input": {"command": "ls"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "Bash tool should exit with 0"
}

# Test: Hook handles missing file path
test_missing_file_path() {
    cd "$TEMP_DIR" || return 1
    
    # Test empty file path - should exit 0 silently
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "Missing file path should exit 0"
}

# Test: Hook handles invalid JSON
test_invalid_json() {
    cd "$TEMP_DIR" || return 1
    
    # Test malformed JSON
    echo 'not valid json' | "$HOOK_SCRIPT" 2>/dev/null
    # Should exit with error code 1 for invalid JSON
    assert_exit_code 1 $? "Invalid JSON should exit with 1"
}

# Test: Hook processes shell scripts
test_shell_script_handling() {
    cd "$TEMP_DIR" || return 1
    
    # Create a shell script in a scripts directory (which doesn't require tests)
    mkdir -p scripts
    echo '#!/bin/bash
echo "test"' > scripts/test.sh
    
    # Test that shell script is recognized - should exit 2 (tests pass, no tests required)
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {"file_path": "scripts/test.sh"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 2 $? "Shell script should be processed"
}

# Test: Hook configuration can disable testing
test_config_disable() {
    cd "$TEMP_DIR" || return 1
    
    # Create config to disable testing
    echo 'export CLAUDE_HOOKS_TEST_ON_EDIT="false"' > .claude-hooks-config.sh
    
    # Create a test file
    echo 'print("test")' > test.py
    
    # Should exit immediately silently
    echo '{"event": "PostToolUse", "tool": "Edit", "tool_input": {"file_path": "test.py"}}' | \
        "$HOOK_SCRIPT" 2>/dev/null
    assert_exit_code 0 $? "Disabled testing should exit 0"
}

# Run all tests
echo "Running smart-test.sh hook tests..."
echo "================================="

test_non_testable_files
test_non_edit_tools
test_missing_file_path
test_invalid_json
test_shell_script_handling
test_config_disable

# Summary
echo "================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    exit 1
else
    echo "All tests passed!"
fi