#!/usr/bin/env bash
# test-statusline.sh - Test the Claude Code statusline with mock data
#
# This script allows rapid iteration on the statusline design by feeding
# it mock JSON data that simulates what Claude Code would provide.

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for test output
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# Default values
MODEL="Opus"
CWD="$HOME/Personal/nix-config"
TRANSCRIPT=""
SHOW_BORDER=false
QUIET=false
SHOW_TOKENS=false
CONTEXT_PERCENTAGE=""

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test the Claude Code statusline with mock data.

OPTIONS:
    -m MODEL      Set model name (default: Opus)
    -d DIR        Set current directory (default: ~/Personal/nix-config)
    -t            Show token usage (enables mock transcript)
    -p PERCENT    Set context percentage (25, 50, 75, 100) when using -t
    -a PROFILE    Set AWS_PROFILE environment variable
    -k CONTEXT    Mock kubectl context
    -w WIDTH      Set terminal width (default: auto-detect)
    -b            Show output with terminal border
    -q            Quiet mode (only show statusline output)
    -h            Show this help message

EXAMPLES:
    # Basic test
    $0

    # Test with tokens at different percentages
    $0 -t -p 25   # Green bar (25%)
    $0 -t -p 50   # Yellow bar (50%)
    $0 -t -p 75   # Peach bar (75%)
    $0 -t -p 100  # Peach bar (100%)

    # Test with AWS and K8s
    $0 -a dev-account -k production-cluster

    # Test everything with border
    $0 -t -p 75 -a staging -k eks-us-west-2 -b

    # Just the statusline output (for piping)
    $0 -t -q
    
    # Show all percentages
    for p in 25 50 75 100; do echo "=== \$p% ==="; $0 -t -p \$p -q; done

EOF
    exit 0
}

# Parse command line arguments
while getopts "m:d:tp:a:k:w:bqh" opt; do
    case $opt in
        m) MODEL="$OPTARG" ;;
        d) CWD="$OPTARG" ;;
        t) SHOW_TOKENS=true ;;
        p) CONTEXT_PERCENTAGE="$OPTARG" ;;
        a) export AWS_PROFILE="$OPTARG" ;;
        k) K8S_CONTEXT="$OPTARG" ;;
        w) export COLUMNS="$OPTARG" ;;
        b) SHOW_BORDER=true ;;
        q) QUIET=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Create a mock transcript file if tokens are requested
if [[ "$SHOW_TOKENS" == true ]]; then
    TRANSCRIPT=$(mktemp /tmp/claude-transcript-XXXXXX.jsonl)
    
    # Calculate tokens based on percentage if provided
    if [[ -n "$CONTEXT_PERCENTAGE" ]]; then
        # Use specific percentage (160k is the auto-compact threshold)
        TOKENS=$((160000 * CONTEXT_PERCENTAGE / 100))
    else
        # Default to showing high usage
        TOKENS=160000
    fi
    
    cat > "$TRANSCRIPT" << EOF
{"timestamp": "2024-01-01T10:00:00Z", "message": {"usage": {"input_tokens": $TOKENS, "output_tokens": 5000, "cache_read_input_tokens": 0}}}
EOF
    trap 'rm -f "$TRANSCRIPT"' EXIT
fi

# Mock kubectl if K8s context is requested
if [[ -n "${K8S_CONTEXT:-}" ]]; then
    # Create a temporary kubectl mock
    MOCK_BIN=$(mktemp -d /tmp/mock-bin-XXXXXX)
    cat > "$MOCK_BIN/kubectl" << EOF
#!/bin/bash
if [[ "\$1" == "config" ]] && [[ "\$2" == "current-context" ]]; then
    echo "$K8S_CONTEXT"
else
    exit 1
fi
EOF
    chmod +x "$MOCK_BIN/kubectl"
    export PATH="$MOCK_BIN:$PATH"
    trap 'rm -rf "$MOCK_BIN" "$TRANSCRIPT" 2>/dev/null || true' EXIT
fi

# Build the JSON input
JSON=$(jq -n \
    --arg model "$MODEL" \
    --arg cwd "$CWD" \
    --arg transcript "$TRANSCRIPT" \
    --arg session_id "test-session-$(date +%s)" \
    --arg version "1.0.80" \
    '{
        "hook_event_name": "Status",
        "session_id": $session_id,
        "transcript_path": $transcript,
        "cwd": $cwd,
        "model": {
            "id": "claude-\($model | ascii_downcase)",
            "display_name": $model
        },
        "workspace": {
            "current_dir": $cwd,
            "project_dir": $cwd
        },
        "version": $version,
        "output_style": {
            "name": "default"
        }
    }')

# Show what we're testing (unless in quiet mode)
if [[ "$QUIET" != true ]]; then
    echo -e "${BLUE}Testing statusline with:${NC}"
    echo -e "  Model: ${YELLOW}$MODEL${NC}"
    echo -e "  Directory: ${YELLOW}$CWD${NC}"
    if [[ "$SHOW_TOKENS" == true ]]; then
        echo -e "  Tokens: ${GREEN}Enabled${NC}"
    fi
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        echo -e "  AWS Profile: ${YELLOW}${AWS_PROFILE}${NC}"
    fi
    if [[ -n "${K8S_CONTEXT:-}" ]]; then
        echo -e "  K8s Context: ${YELLOW}${K8S_CONTEXT}${NC}"
    fi
    echo ""
fi

# Generate the statusline
STATUSLINE_OUTPUT=$(echo "$JSON" | "$SCRIPT_DIR/statusline.sh")

# Show output based on options
if [[ "$QUIET" == true ]]; then
    # Just output the statusline
    echo "$STATUSLINE_OUTPUT"
elif [[ "$SHOW_BORDER" == true ]]; then
    # Show with terminal border
    WIDTH=$(tput cols 2>/dev/null || echo 80)
    printf '┌%*s┐\n' $((WIDTH-2)) '' | tr ' ' '─'
    echo -n "│"
    echo -n "$STATUSLINE_OUTPUT" | tr -d '\n'
    # Calculate how much padding we need (strip ANSI codes)
    STATUS_PLAIN="$STATUSLINE_OUTPUT"
    # Remove ANSI escape sequences using parameter expansion
    while [[ "$STATUS_PLAIN" =~ $'\x1b''\[[0-9;]*m' ]]; do
        STATUS_PLAIN="${STATUS_PLAIN//${BASH_REMATCH[0]}/}"
    done
    STATUS_LENGTH=${#STATUS_PLAIN}
    PADDING=$((WIDTH - STATUS_LENGTH - 2))
    if [[ $PADDING -gt 0 ]]; then
        printf '%*s' $PADDING ''
    fi
    echo "│"
    printf '└%*s┘\n' $((WIDTH-2)) '' | tr ' ' '─'
else
    # Just show the raw output
    echo -e "${BLUE}Output:${NC}"
    echo "$STATUSLINE_OUTPUT"
fi