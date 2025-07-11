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

# Find project root by looking for common project markers
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        # Check for various project root indicators
        if [[ -f "$dir/.git/HEAD" ]] || [[ -d "$dir/.git" ]] || 
           [[ -f "$dir/.claude-hooks-config.sh" ]] ||
           [[ -f "$dir/go.mod" ]] || 
           [[ -f "$dir/package.json" ]] || 
           [[ -f "$dir/Cargo.toml" ]] ||
           [[ -f "$dir/setup.py" ]] ||
           [[ -f "$dir/pyproject.toml" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # No project root found, return current directory
    echo "$PWD"
    return 1
}

# Load project configuration
load_project_config() {
    # User-level config
    [[ -f "$HOME/.claude-hooks.conf" ]] && source "$HOME/.claude-hooks.conf"
    
    # Debug current directory
    log_debug "load_project_config called from PWD: $(pwd)"
    
    # Find project root and load config from there
    local project_root=$(find_project_root)
    log_debug "Project root found: $project_root"
    
    if [[ -f "$project_root/.claude-hooks-config.sh" ]]; then
        log_debug "Found config file at: $project_root/.claude-hooks-config.sh"
        source "$project_root/.claude-hooks-config.sh"
        log_debug "After sourcing project config, CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS='${CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS:-}'"
    else
        log_debug "No .claude-hooks-config.sh found at: $project_root"
    fi
    
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
    local project_root=$(find_project_root)
    
    # Check .claude-hooks-ignore if it exists in project root
    if [[ -f "$project_root/.claude-hooks-ignore" ]]; then
        # Make file path relative to project root for pattern matching
        local relative_file="${file#$project_root/}"
        
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            
            # Check if pattern ends with /** for directory matching
            if [[ "$pattern" == */** ]]; then
                local dir_pattern="${pattern%/**}"
                if [[ "$relative_file" == $dir_pattern/* ]]; then
                    log_debug "Skipping $file due to .claude-hooks-ignore directory pattern: $pattern"
                    return 0
                fi
            # Check for glob patterns - use case statement for proper glob matching
            elif [[ "$pattern" == *[*?]* ]]; then
                case "$relative_file" in
                    $pattern)
                        log_debug "Skipping $file due to .claude-hooks-ignore glob pattern: $pattern"
                        return 0
                        ;;
                esac
            # Exact match
            elif [[ "$relative_file" == "$pattern" ]]; then
                log_debug "Skipping $file due to .claude-hooks-ignore pattern: $pattern"
                return 0
            fi
        done < "$project_root/.claude-hooks-ignore"
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