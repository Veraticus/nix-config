#!/usr/bin/env bash
# Test the add_error behavior

# Create a minimal test
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Create go.mod and a Go file with forbidden patterns
echo "module test" > go.mod
cat > main.go << 'EOF'
package main
func main() {
    var x interface{} = 42
}
EOF

# Mock jq
mkdir -p mocks
cat > mocks/jq << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
    echo "jq-1.6"
    exit 0
fi
echo '{"event":"PostToolUse","tool":"Edit","tool_input":{"file_path":"main.go"}}'
EOF
chmod +x mocks/jq

# Add to PATH
export PATH="$PWD/mocks:$PATH"

# Source the scripts directly to test add_error behavior
SCRIPT_DIR="/home/joshsymonds/nix-config/home-manager/claude-code/hooks"
source "${SCRIPT_DIR}/common-helpers.sh"

echo "=== Testing original add_error ==="
add_error "Test error 1"
echo "Error count: $CLAUDE_HOOKS_ERROR_COUNT"
echo "Errors array: ${CLAUDE_HOOKS_ERRORS[@]}"

# Now source smart-lint which overrides add_error
echo -e "\n=== After smart-lint override ==="
source <(grep -A 10 "Override add_error" "${SCRIPT_DIR}/smart-lint.sh")

add_error "Test error 2"
echo "Error count: $CLAUDE_HOOKS_ERROR_COUNT"
echo "Errors array: ${CLAUDE_HOOKS_ERRORS[@]}"

# Clean up
cd /
rm -rf "$TEMP_DIR"