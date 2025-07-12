#!/usr/bin/env bash
# Debug script to test forbidden pattern detection

# Create test directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Create go.mod
echo "module test" > go.mod

# Create test file with forbidden patterns
cat > main.go << 'EOF'
package main

import (
    "fmt"
    "time"
)

func main() {
    var data interface{} = "test"
    fmt.Println(data)
    
    // Forbidden pattern: time.Sleep
    time.Sleep(1 * time.Second)
    
    // Forbidden pattern: panic
    panic("oops")
}
EOF

# Create mock jq
mkdir -p mocks
cat > mocks/jq << 'EOF'
#!/usr/bin/env bash
input=$(cat)
if [[ "$1" == "--version" ]]; then
    echo "jq-1.6"
    exit 0
fi
if [[ "$1" == "." ]]; then
    echo "$input"
    exit 0
fi
if [[ "$1" == "-r" ]]; then
    case "$2" in
        ".event // empty")
            echo "PostToolUse"
            ;;
        ".tool // empty")
            echo "Edit"
            ;;
        ".tool_input.file_path // empty")
            echo "$TEMP_DIR/main.go"
            ;;
    esac
fi
EOF
chmod +x mocks/jq

# Add mocks to PATH
export PATH="$PWD/mocks:$PATH"

# Create input JSON
json='{"event":"PostToolUse","tool":"Edit","tool_input":{"file_path":"'$TEMP_DIR'/main.go"}}'

# Enable debug mode
export CLAUDE_HOOKS_DEBUG=1

# Run the hook
echo "Running smart-lint.sh with debug enabled..."
echo "$json" | /home/joshsymonds/nix-config/home-manager/claude-code/hooks/smart-lint.sh

echo "Exit code: $?"
echo "Temp dir: $TEMP_DIR"