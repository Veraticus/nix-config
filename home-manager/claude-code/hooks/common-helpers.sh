#!/usr/bin/env bash
# common-helpers.sh - Shared utilities for Claude Code hooks
#
# This file provides common functions, colors, and patterns used across
# multiple hooks to ensure consistency and reduce duplication.

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_debug() {
    [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# ============================================================================
# PERFORMANCE TIMING
# ============================================================================

time_start() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]]; then
        echo $(($(date +%s%N)/1000000))
    fi
}

time_end() {
    if [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]]; then
        local start=$1
        local end=$(($(date +%s%N)/1000000))
        local duration=$((end - start))
        log_debug "Execution time: ${duration}ms"
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Load project configuration
load_project_config() {
    # User-level config
    [[ -f "$HOME/.claude-hooks.conf" ]] && source "$HOME/.claude-hooks.conf"
    
    # Project-level config (highest priority)
    [[ -f ".claude-hooks-config.sh" ]] && source ".claude-hooks-config.sh"
    
    # Always return success
    return 0
}

# ============================================================================
# ERROR TRACKING
# ============================================================================

declare -a CLAUDE_HOOKS_ERRORS=()
declare -i CLAUDE_HOOKS_ERROR_COUNT=0

add_error() {
    local message="$1"
    CLAUDE_HOOKS_ERROR_COUNT+=1
    CLAUDE_HOOKS_ERRORS+=("${RED}❌${NC} $message")
}

print_error_summary() {
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        # Concise summary for errors
        echo -e "\n${RED}❌ Found $CLAUDE_HOOKS_ERROR_COUNT issue(s) - ALL BLOCKING${NC}" >&2
    fi
}

# ============================================================================
# STANDARD HEADERS
# ============================================================================

print_style_header() {
    echo "" >&2
    echo "🔍 Style Check - Validating code formatting..." >&2
    echo "────────────────────────────────────────────" >&2
}

print_test_header() {
    echo "" >&2
    echo "🧪 Test Check - Running tests for edited file..." >&2
    echo "────────────────────────────────────────────" >&2
}

# ============================================================================
# STANDARD EXIT HANDLERS
# ============================================================================

exit_with_success_message() {
    local message="${1:-Continue with your task.}"
    echo -e "${YELLOW}👉 $message${NC}" >&2
    exit 2
}

exit_with_style_failure() {
    echo -e "\n${RED}🛑 Style check failed. Fix issues and re-run.${NC}" >&2
    exit 2
}

exit_with_test_failure() {
    local file_path="$1"
    echo -e "${RED}⛔ BLOCKING: Must fix ALL test failures above before continuing${NC}" >&2
    exit 2
}

# ============================================================================
# FILE FILTERING
# ============================================================================

# Check if we should skip a file based on .claude-hooks-ignore
should_skip_file() {
    local file="$1"
    
    # Check .claude-hooks-ignore if it exists
    if [[ -f ".claude-hooks-ignore" ]]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            
            # Check if pattern ends with /** for directory matching
            if [[ "$pattern" == */** ]]; then
                local dir_pattern="${pattern%/**}"
                if [[ "$file" == $dir_pattern/* ]]; then
                    log_debug "Skipping $file due to .claude-hooks-ignore directory pattern: $pattern"
                    return 0
                fi
            # Check for glob patterns - use case statement for proper glob matching
            elif [[ "$pattern" == *[*?]* ]]; then
                case "$file" in
                    $pattern)
                        log_debug "Skipping $file due to .claude-hooks-ignore glob pattern: $pattern"
                        return 0
                        ;;
                esac
            # Exact match
            elif [[ "$file" == "$pattern" ]]; then
                log_debug "Skipping $file due to .claude-hooks-ignore pattern: $pattern"
                return 0
            fi
        done < ".claude-hooks-ignore"
    fi
    
    # Check for inline skip comments
    if [[ -f "$file" ]] && head -n 5 "$file" 2>/dev/null | grep -q "claude-hooks-disable"; then
        log_debug "Skipping $file due to inline claude-hooks-disable comment"
        return 0
    fi
    
    return 1
}

# ============================================================================
# PROJECT TYPE DETECTION
# ============================================================================

detect_project_type() {
    local project_type="unknown"
    local types=()
    
    # Go project
    if [[ -f "go.mod" ]] || [[ -f "go.sum" ]] || [[ -n "$(find . -maxdepth 3 -name "*.go" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("go")
    fi
    
    # Python project
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]] || [[ -n "$(find . -maxdepth 3 -name "*.py" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("python")
    fi
    
    # JavaScript/TypeScript project
    if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]] || [[ -n "$(find . -maxdepth 3 \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -type f -print -quit 2>/dev/null)" ]]; then
        types+=("javascript")
    fi
    
    # Rust project
    if [[ -f "Cargo.toml" ]] || [[ -n "$(find . -maxdepth 3 -name "*.rs" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("rust")
    fi
    
    # Nix project
    if [[ -f "flake.nix" ]] || [[ -f "default.nix" ]] || [[ -f "shell.nix" ]]; then
        types+=("nix")
    fi
    
    # Return primary type or "mixed" if multiple
    if [[ ${#types[@]} -eq 1 ]]; then
        project_type="${types[0]}"
    elif [[ ${#types[@]} -gt 1 ]]; then
        project_type="mixed:$(IFS=,; echo "${types[*]}")"
    fi
    
    log_debug "Detected project type: $project_type"
    echo "$project_type"
}