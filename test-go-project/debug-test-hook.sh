#!/usr/bin/env bash
# Debug wrapper for smart-test.sh

echo "DEBUG: Starting hook" >&2

# Remove set -e temporarily
set +e

# Source the original hook with debugging
(
    # Add debug output at key points
    echo "DEBUG: About to source smart-test.sh" >&2
    
    # Read input
    INPUT=$(cat)
    echo "$INPUT" | bash -c '
        set -euo pipefail
        
        # Override log_debug to always show
        log_debug() {
            echo -e "[DEBUG] $*" >&2
        }
        
        # Source helpers
        source ~/.claude/hooks/common-helpers.sh || { echo "Failed to source common-helpers.sh"; exit 1; }
        
        # Check if we have input
        if [ -t 0 ]; then
            FILE_PATH="./..."
        else
            INPUT=$(echo "$@")
            
            # Parse JSON
            if echo "$INPUT" | jq . >/dev/null 2>&1; then
                TOOL_NAME=$(echo "$INPUT" | jq -r ".tool_name // empty")
                TOOL_INPUT=$(echo "$INPUT" | jq -r ".tool_input // empty")
                
                if [[ ! "$TOOL_NAME" =~ ^(Edit|Write|MultiEdit)$ ]]; then
                    exit 2
                fi
                
                FILE_PATH=$(echo "$TOOL_INPUT" | jq -r ".file_path // empty")
                
                if [[ -z "$FILE_PATH" ]]; then
                    exit_with_success_message "No file to test. Continue with your task."
                fi
            else
                FILE_PATH="./..."
            fi
        fi
        
        echo "DEBUG: FILE_PATH=$FILE_PATH" >&2
        
        # Source test-go.sh with error checking
        echo "DEBUG: About to source test-go.sh" >&2
        if [[ -f ~/.claude/hooks/test-go.sh ]]; then
            source ~/.claude/hooks/test-go.sh || { echo "ERROR: Failed to source test-go.sh with code $?"; exit 1; }
            echo "DEBUG: Successfully sourced test-go.sh" >&2
        else
            echo "ERROR: test-go.sh not found" >&2
            exit 1
        fi
        
        # Check if function exists
        if type -t run_go_tests &>/dev/null; then
            echo "DEBUG: run_go_tests function exists" >&2
        else
            echo "ERROR: run_go_tests function not found" >&2
            exit 1
        fi
    ' "$INPUT"
)

EXIT_CODE=$?
echo "DEBUG: Hook exited with code $EXIT_CODE" >&2
exit $EXIT_CODE