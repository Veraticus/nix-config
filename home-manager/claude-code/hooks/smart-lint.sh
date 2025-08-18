#!/usr/bin/env bash
# smart-lint.sh - Run project-defined lint commands when files are edited
#
# SYNOPSIS
#   PostToolUse hook that runs project lint commands when files are edited
#
# DESCRIPTION
#   When Claude edits a file, this hook looks for and runs project-defined
#   lint commands from Makefiles, justfiles, package.json, or script directories.
#   
#   The hook walks up from the edited file's directory looking for:
#   1. Makefile with 'lint' target
#   2. justfile with 'lint' recipe
#   3. package.json with 'scripts.lint'
#   4. scripts/lint executable
#   5. Cargo.toml (runs 'cargo clippy')
#   6. pyproject.toml or setup.py (runs configured linter)
#
# EXIT CODES (per Claude Code documentation)
#   0 - Success (lint passed - show success message, or no lint command found - silent)
#   2 - Blocking error (lint failed - stderr shown to Claude)
#
# CONFIGURATION
#   CLAUDE_HOOKS_LINT_ENABLED - Enable/disable (default: true)
#   CLAUDE_HOOKS_DEBUG - Enable debug output

set -uo pipefail

# Set up a safety timeout (10 seconds default)
{
    sleep "${CLAUDE_HOOKS_LINT_TIMEOUT:-10}"
    kill -TERM -$$ 2>/dev/null
} &
TIMEOUT_PID=$!

cleanup_timeout() {
    kill "$TIMEOUT_PID" 2>/dev/null
    wait "$TIMEOUT_PID" 2>/dev/null
}
trap cleanup_timeout EXIT

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-helpers.sh"

# Check if hook is enabled
if [[ "${CLAUDE_HOOKS_LINT_ENABLED:-true}" != "true" ]]; then
    log_debug "smart-lint.sh is disabled via CLAUDE_HOOKS_LINT_ENABLED"
    exit 0
fi

# Get workspace directory (current working directory)
WORKSPACE_DIR="$(pwd)"
# Create a safe lock file name based on workspace path
LOCK_FILE_NAME="claude-hook-lint-$(echo "$WORKSPACE_DIR" | sha256sum | cut -d' ' -f1).lock"
LOCK_FILE="/tmp/$LOCK_FILE_NAME"

# Configure cooldown period (seconds after completion before allowing new runs)
COOLDOWN_SECONDS="${CLAUDE_HOOKS_LINT_COOLDOWN:-2}"

# Check if another instance is running or recently completed
if [[ -f "$LOCK_FILE" ]]; then
    # Read PID from first line
    LOCK_PID=$(head -n1 "$LOCK_FILE" 2>/dev/null || echo "")
    
    # Check if PID is still running
    if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null; then
        log_debug "smart-lint.sh is already running in workspace $WORKSPACE_DIR (PID: $LOCK_PID), exiting"
        exit 0
    fi
    
    # Check completion timestamp from second line
    COMPLETION_TIME=$(tail -n1 "$LOCK_FILE" 2>/dev/null || echo "0")
    if [[ "$COMPLETION_TIME" =~ ^[0-9]+$ ]]; then
        CURRENT_TIME=$(date +%s)
        TIME_SINCE_COMPLETION=$((CURRENT_TIME - COMPLETION_TIME))
        
        if [[ $TIME_SINCE_COMPLETION -lt $COOLDOWN_SECONDS ]]; then
            log_debug "smart-lint.sh completed ${TIME_SINCE_COMPLETION}s ago in workspace $WORKSPACE_DIR (cooldown: ${COOLDOWN_SECONDS}s), exiting"
            exit 0
        fi
    fi
fi

# Write our PID to lock file (first line only)
echo "$$" > "$LOCK_FILE"

# Update lock file on exit with completion timestamp
cleanup() {
    # Clear PID and write completion timestamp
    {
        echo ""  # Empty first line (no PID)
        date +%s  # Second line: completion timestamp
    } > "$LOCK_FILE" 2>/dev/null
    cleanup_timeout
}
trap cleanup EXIT

# Read and parse JSON input
if ! read -r -t 1 json_input; then
    log_debug "No input received on stdin"
    exit 0
fi

log_debug "Read JSON input: ${json_input:0:100}..."

# Parse JSON to get event type and tool name
event_type=$(echo "$json_input" | jq -r '.hook_event_name // empty' 2>/dev/null)
tool_name=$(echo "$json_input" | jq -r '.tool_name // empty' 2>/dev/null)

# Only process PostToolUse events for edit tools
if [[ "$event_type" != "PostToolUse" ]]; then
    log_debug "Ignoring event type: $event_type"
    exit 0
fi

# Check if this is an edit-related tool
case "$tool_name" in
    Edit|MultiEdit|Write|NotebookEdit)
        log_debug "Processing edit tool: $tool_name"
        ;;
    *)
        log_debug "Ignoring non-edit tool: $tool_name"
        exit 0
        ;;
esac

# Extract file path from the appropriate field based on tool
case "$tool_name" in
    NotebookEdit)
        file_path=$(echo "$json_input" | jq -r '.tool_input.notebook_path // empty' 2>/dev/null)
        ;;
    *)
        file_path=$(echo "$json_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        ;;
esac

if [[ -z "$file_path" ]]; then
    log_debug "No file path found in JSON input"
    exit 0
fi

log_debug "Extracted file path: $file_path"

# Check if file exists and should be linted
if [[ ! -f "$file_path" ]]; then
    log_debug "File does not exist: $file_path"
    exit 0
fi

# Check if file should be skipped
if should_skip_file "$file_path"; then
    log_debug "File should be skipped: $file_path"
    exit 0
fi

# Change to the file's directory
file_dir=$(dirname "$file_path")
cd "$file_dir" || exit 0

log_debug "Changed to directory: $file_dir"

# Function to check if a make target exists
check_make_target() {
    local makefile="$1"
    local target="$2"
    make -f "$makefile" -n "$target" &>/dev/null
}

# Function to check if a just recipe exists
check_just_recipe() {
    local justfile="$1"
    local recipe="$2"
    just --justfile "$justfile" --show "$recipe" &>/dev/null
}

# Function to check if npm/yarn/pnpm script exists
check_npm_script() {
    local package_json="$1"
    local script="$2"
    jq -e ".scripts.\"$script\"" "$package_json" &>/dev/null
}

# Function to find and run lint command
# Returns: 0 = no command found, 1 = lint passed, 2 = lint failed
find_and_run_lint() {
    local start_dir="$PWD"
    local current_dir="$PWD"
    
    while [[ "$current_dir" != "/" ]]; do
        log_debug "Checking for lint commands in: $current_dir"
        
        # Check for Makefile
        if [[ -f "$current_dir/Makefile" ]] || [[ -f "$current_dir/makefile" ]]; then
            local makefile="$current_dir/Makefile"
            [[ ! -f "$makefile" ]] && makefile="$current_dir/makefile"
            
            if check_make_target "$makefile" "lint"; then
                log_info "🔍 Running 'make lint' from $current_dir"
                cd "$current_dir" || return 2
                
                if make lint >/dev/null 2>&1; then
                    log_debug "Linting passed"
                    return 1  # Lint passed
                else
                    # Re-run to show output on failure
                    echo -e "${RED}❌ Linting failed${NC}" >&2
                    make lint 2>&1
                    return 2  # Lint failed
                fi
            fi
        fi
        
        # Check for justfile
        if [[ -f "$current_dir/justfile" ]] || [[ -f "$current_dir/Justfile" ]]; then
            local justfile="$current_dir/justfile"
            [[ ! -f "$justfile" ]] && justfile="$current_dir/Justfile"
            
            if check_just_recipe "$justfile" "lint"; then
                log_info "🔍 Running 'just lint' from $current_dir"
                cd "$current_dir" || return 2
                
                if just lint >/dev/null 2>&1; then
                    log_debug "Linting passed"
                    return 1  # Lint passed
                else
                    # Re-run to show output on failure
                    echo -e "${RED}❌ Linting failed${NC}" >&2
                    just lint 2>&1
                    return 2  # Lint failed
                fi
            fi
        fi
        
        # Check for package.json (npm/yarn/pnpm)
        if [[ -f "$current_dir/package.json" ]]; then
            if check_npm_script "$current_dir/package.json" "lint"; then
                log_info "🔍 Running npm/yarn lint from $current_dir"
                cd "$current_dir" || return 2
                
                # Detect package manager
                local pm="npm"
                if [[ -f "yarn.lock" ]]; then
                    pm="yarn"
                elif [[ -f "pnpm-lock.yaml" ]]; then
                    pm="pnpm"
                fi
                
                if $pm run lint >/dev/null 2>&1; then
                    log_debug "Linting passed"
                    return 1  # Lint passed
                else
                    # Re-run to show output on failure
                    echo -e "${RED}❌ Linting failed${NC}" >&2
                    $pm run lint 2>&1
                    return 2  # Lint failed
                fi
            fi
        fi
        
        # Check for scripts/lint
        if [[ -x "$current_dir/scripts/lint" ]]; then
            log_info "🔍 Running scripts/lint from $current_dir"
            cd "$current_dir" || return 2
            
            if ./scripts/lint >/dev/null 2>&1; then
                log_debug "Linting passed"
                return 1  # Lint passed
            else
                # Re-run to show output on failure
                echo -e "${RED}❌ Linting failed${NC}" >&2
                ./scripts/lint 2>&1
                return 2  # Lint failed
            fi
        fi
        
        # Check for Cargo.toml (Rust)
        if [[ -f "$current_dir/Cargo.toml" ]]; then
            if command -v cargo &>/dev/null; then
                log_info "🔍 Running 'cargo clippy' from $current_dir"
                cd "$current_dir" || return 2
                
                if cargo clippy -- -D warnings >/dev/null 2>&1; then
                    log_debug "Linting passed"
                    return 1  # Lint passed
                else
                    # Re-run to show output on failure
                    echo -e "${RED}❌ Linting failed${NC}" >&2
                    cargo clippy -- -D warnings 2>&1
                    return 2  # Lint failed
                fi
            fi
        fi
        
        # Check for pyproject.toml or setup.py (Python)
        if [[ -f "$current_dir/pyproject.toml" ]] || [[ -f "$current_dir/setup.py" ]]; then
            # Check for common Python lint tools in order of preference
            local python_linters=("ruff" "flake8" "pylint")
            for linter in "${python_linters[@]}"; do
                if command -v "$linter" &>/dev/null; then
                    log_info "🔍 Running '$linter' from $current_dir"
                    cd "$current_dir" || return 1
                    
                    case "$linter" in
                        ruff)
                            if ruff check . >/dev/null 2>&1; then
                                log_debug "Linting passed"
                                return 1  # Lint passed
                            else
                                # Re-run to show output on failure
                                echo -e "${RED}❌ Linting failed${NC}" >&2
                                ruff check . 2>&1
                                return 2  # Lint failed
                            fi
                            ;;
                        flake8)
                            if flake8 . >/dev/null 2>&1; then
                                log_debug "Linting passed"
                                return 1  # Lint passed
                            else
                                # Re-run to show output on failure
                                echo -e "${RED}❌ Linting failed${NC}" >&2
                                flake8 . 2>&1
                                return 2  # Lint failed
                            fi
                            ;;
                        pylint)
                            if pylint . >/dev/null 2>&1; then
                                log_debug "Linting passed"
                                return 1  # Lint passed
                            else
                                # Re-run to show output on failure
                                echo -e "${RED}❌ Linting failed${NC}" >&2
                                pylint . 2>&1
                                return 2  # Lint failed
                            fi
                            ;;
                    esac
                    break
                fi
            done
        fi
        
        # Move up one directory
        current_dir=$(dirname "$current_dir")
    done
    
    # No lint command found
    log_debug "No lint command found in project hierarchy"
    return 0
}

# Run the lint command search
find_and_run_lint
exit_code=$?

case $exit_code in
    0)
        # No lint command found - exit silently
        log_debug "No lint command found, exiting silently"
        exit 0
        ;;
    1)
        # Lint passed - show success message and exit 0
        echo -e "${YELLOW}👉 Lints pass. Continue with your task.${NC}" >&2
        exit 0
        ;;
    2)
        # Lint failed - show blocking message and exit 2
        echo -e "${RED}⛔ BLOCKING: Must fix ALL lint failures above before continuing${NC}" >&2
        exit 2
        ;;
esac