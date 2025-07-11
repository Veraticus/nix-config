#!/usr/bin/env bash
# smart-lint.sh - Intelligent project-aware code quality checks for Claude Code
#
# SYNOPSIS
#   smart-lint.sh [options]
#
# DESCRIPTION
#   Automatically detects project type and runs ALL quality checks.
#   Every issue found is blocking - code must be 100% clean to proceed.
#
# OPTIONS
#   --debug       Enable debug output
#
# EXIT CODES
#   0 - Success (all checks passed - everything is ✅ GREEN)
#   1 - General error (missing dependencies, etc.)
#   2 - ANY issues found - ALL must be fixed
#
# CONFIGURATION
#   Project-specific overrides can be placed in .claude-hooks-config.sh
#   See inline documentation for all available options.
#
#   Go-specific options:
#     CLAUDE_HOOKS_GO_DEADCODE_ENABLED=false  # Disable deadcode analysis (default: true)
#                                             # Note: deadcode can take 5-10 seconds on large projects

# Don't use set -e - we need to control exit codes carefully
set +e

# Source common helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common-helpers.sh"

# ============================================================================
# PROJECT DETECTION
# ============================================================================

# Add Tilt project detection to the common detect_project_type function
detect_project_type_with_tilt() {
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
    
    # Tilt project
    if [[ -f "Tiltfile" ]] || [[ -n "$(find . -maxdepth 3 -name "Tiltfile" -type f -print -quit 2>/dev/null)" ]] || [[ -n "$(find . -maxdepth 3 -name "*.tiltfile" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("tilt")
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

# Get list of modified files (if available from git)
get_modified_files() {
    if [[ -d .git ]] && command_exists git; then
        # Get files modified in the last commit or currently staged/modified
        git diff --name-only HEAD 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
    fi
}

# ============================================================================
# ERROR TRACKING (extends common-helpers.sh)
# ============================================================================

# Use the CLAUDE_HOOKS_ERRORS array from common-helpers.sh but with a different name for summary
declare -a CLAUDE_HOOKS_SUMMARY=()

# Override add_error to also add to summary
add_error() {
    local message="$1"
    CLAUDE_HOOKS_ERROR_COUNT+=1
    CLAUDE_HOOKS_ERRORS+=("${RED}❌${NC} $message")
    CLAUDE_HOOKS_SUMMARY+=("${RED}❌${NC} $message")
}

print_summary() {
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        # Simple one-line summary when there are errors
        echo -e "\n${RED}❌ Found $CLAUDE_HOOKS_ERROR_COUNT blocking issue(s) - fix all above${NC}" >&2
    fi
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

load_config() {
    # Default configuration
    export CLAUDE_HOOKS_ENABLED="${CLAUDE_HOOKS_ENABLED:-true}"
    export CLAUDE_HOOKS_FAIL_FAST="${CLAUDE_HOOKS_FAIL_FAST:-false}"
    export CLAUDE_HOOKS_SHOW_TIMING="${CLAUDE_HOOKS_SHOW_TIMING:-false}"
    
    # Language enables
    export CLAUDE_HOOKS_GO_ENABLED="${CLAUDE_HOOKS_GO_ENABLED:-true}"
    export CLAUDE_HOOKS_PYTHON_ENABLED="${CLAUDE_HOOKS_PYTHON_ENABLED:-true}"
    export CLAUDE_HOOKS_JS_ENABLED="${CLAUDE_HOOKS_JS_ENABLED:-true}"
    export CLAUDE_HOOKS_RUST_ENABLED="${CLAUDE_HOOKS_RUST_ENABLED:-true}"
    export CLAUDE_HOOKS_NIX_ENABLED="${CLAUDE_HOOKS_NIX_ENABLED:-true}"
    export CLAUDE_HOOKS_TILT_ENABLED="${CLAUDE_HOOKS_TILT_ENABLED:-true}"
    
    # Project-specific overrides
    if [[ -f ".claude-hooks-config.sh" ]]; then
        source ".claude-hooks-config.sh" || {
            log_error "Failed to load .claude-hooks-config.sh"
            exit 2
        }
    fi
    
    # Quick exit if hooks are disabled
    if [[ "$CLAUDE_HOOKS_ENABLED" != "true" ]]; then
        log_info "Claude hooks are disabled"
        exit 0
    fi
}

# ============================================================================
# LANGUAGE-SPECIFIC LINTERS
# ============================================================================

# Source language-specific linting functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Go linting if available
if [[ -f "${SCRIPT_DIR}/lint-go.sh" ]]; then
    source "${SCRIPT_DIR}/lint-go.sh"
fi

# Source Tilt linting if available
if [[ -f "${SCRIPT_DIR}/lint-tilt.sh" ]]; then
    source "${SCRIPT_DIR}/lint-tilt.sh"
fi

lint_python() {
    if [[ "${CLAUDE_HOOKS_PYTHON_ENABLED:-true}" != "true" ]]; then
        log_debug "Python linting disabled"
        return 0
    fi
    
    log_debug "Running Python linters..."
    
    # Find Python files
    local py_files=$(find . -name "*.py" -type f | grep -v -E "(venv/|\.venv/|__pycache__|\.git/)" | head -100)
    
    if [[ -z "$py_files" ]]; then
        log_debug "No Python files found"
        return 0
    fi
    
    # Filter out files that should be skipped
    local filtered_files=""
    for file in $py_files; do
        if ! should_skip_file "$file"; then
            filtered_files="$filtered_files$file "
        fi
    done
    
    if [[ -z "$filtered_files" ]]; then
        log_debug "All Python files were skipped by .claude-hooks-ignore"
        return 0
    fi
    
    # Black formatting
    if command_exists black; then
        local black_output
        if ! black_output=$(echo "$filtered_files" | xargs black --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(echo "$filtered_files" | xargs black 2>&1); then
                add_error "Python formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # Linting
    if command_exists ruff; then
        local ruff_output
        if ! ruff_output=$(echo "$filtered_files" | xargs ruff check --fix 2>&1); then
            add_error "Ruff found issues"
            echo "$ruff_output" >&2
        fi
    elif command_exists flake8; then
        local flake8_output
        if ! flake8_output=$(echo "$filtered_files" | xargs flake8 2>&1); then
            add_error "Flake8 found issues"
            echo "$flake8_output" >&2
        fi
    fi
    
    return 0
}

lint_javascript() {
    if [[ "${CLAUDE_HOOKS_JS_ENABLED:-true}" != "true" ]]; then
        log_debug "JavaScript linting disabled"
        return 0
    fi
    
    log_debug "Running JavaScript/TypeScript linters..."
    
    # Find JS/TS files
    local js_files=$(find . \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -type f | grep -v -E "(node_modules/|dist/|build/|\.git/)" | head -100)
    
    if [[ -z "$js_files" ]]; then
        log_debug "No JavaScript/TypeScript files found"
        return 0
    fi
    
    # Filter out files that should be skipped
    local filtered_files=""
    for file in $js_files; do
        if ! should_skip_file "$file"; then
            filtered_files="$filtered_files$file "
        fi
    done
    
    if [[ -z "$filtered_files" ]]; then
        log_debug "All JavaScript/TypeScript files were skipped by .claude-hooks-ignore"
        return 0
    fi
    
    # Check for ESLint
    if [[ -f "package.json" ]] && grep -q "eslint" package.json 2>/dev/null; then
        if command_exists npm; then
            local eslint_output
            if ! eslint_output=$(npm run lint --if-present 2>&1); then
                add_error "ESLint found issues"
                echo "$eslint_output" >&2
            fi
        fi
    fi
    
    # Prettier
    if [[ -f ".prettierrc" ]] || [[ -f "prettier.config.js" ]] || [[ -f ".prettierrc.json" ]]; then
        if command_exists prettier; then
            local prettier_output
            if ! prettier_output=$(echo "$filtered_files" | xargs prettier --check 2>&1); then
                # Apply formatting and capture any errors
                local format_output
                if ! format_output=$(echo "$filtered_files" | xargs prettier --write 2>&1); then
                    add_error "Prettier formatting failed"
                    echo "$format_output" >&2
                fi
            fi
        elif command_exists npx; then
            local prettier_output
            if ! prettier_output=$(echo "$filtered_files" | xargs npx prettier --check 2>&1); then
                # Apply formatting and capture any errors
                local format_output
                if ! format_output=$(echo "$filtered_files" | xargs npx prettier --write 2>&1); then
                    add_error "Prettier formatting failed"
                    echo "$format_output" >&2
                fi
            fi
        fi
    fi
    
    return 0
}

lint_rust() {
    if [[ "${CLAUDE_HOOKS_RUST_ENABLED:-true}" != "true" ]]; then
        log_debug "Rust linting disabled"
        return 0
    fi
    
    log_debug "Running Rust linters..."
    
    # Find Rust files
    local rust_files=$(find . -name "*.rs" -type f | grep -v -E "(target/|\.git/)" | head -100)
    
    if [[ -z "$rust_files" ]]; then
        log_debug "No Rust files found"
        return 0
    fi
    
    # Filter out files that should be skipped
    local filtered_files=""
    for file in $rust_files; do
        if ! should_skip_file "$file"; then
            filtered_files="$filtered_files$file "
        fi
    done
    
    if [[ -z "$filtered_files" ]]; then
        log_debug "All Rust files were skipped by .claude-hooks-ignore"
        return 0
    fi
    
    if command_exists cargo; then
        local fmt_output
        if ! fmt_output=$(cargo fmt -- --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(cargo fmt 2>&1); then
                add_error "Rust formatting failed"
                echo "$format_output" >&2
            fi
        fi
        
        local clippy_output
        if ! clippy_output=$(cargo clippy --quiet -- -D warnings 2>&1); then
            add_error "Clippy found issues"
            echo "$clippy_output" >&2
        fi
    else
        log_debug "Cargo not found, skipping Rust checks"
    fi
    
    return 0
}

lint_nix() {
    if [[ "${CLAUDE_HOOKS_NIX_ENABLED:-true}" != "true" ]]; then
        log_debug "Nix linting disabled"
        return 0
    fi
    
    log_debug "Running Nix linters..."
    
    # Find all .nix files
    local nix_files=$(find . -name "*.nix" -type f | grep -v -E "(result/|/nix/store/)" | head -20)
    
    if [[ -z "$nix_files" ]]; then
        log_debug "No Nix files found"
        return 0
    fi
    
    # Filter out files that should be skipped
    local filtered_files=""
    for file in $nix_files; do
        if ! should_skip_file "$file"; then
            filtered_files="$filtered_files$file "
        fi
    done
    
    nix_files="$filtered_files"
    if [[ -z "$nix_files" ]]; then
        log_debug "All Nix files were skipped by .claude-hooks-ignore"
        return 0
    fi
    
    # Check formatting with nixpkgs-fmt or alejandra
    if command_exists nixpkgs-fmt; then
        local fmt_output
        if ! fmt_output=$(echo "$nix_files" | xargs nixpkgs-fmt --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(echo "$nix_files" | xargs nixpkgs-fmt 2>&1); then
                add_error "Nix formatting failed"
                echo "$format_output" >&2
            fi
        fi
    elif command_exists alejandra; then
        local fmt_output
        if ! fmt_output=$(echo "$nix_files" | xargs alejandra --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(echo "$nix_files" | xargs alejandra 2>&1); then
                add_error "Nix formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # Static analysis with statix
    if command_exists statix; then
        local statix_output
        if ! statix_output=$(statix check 2>&1); then
            add_error "Statix found issues"
            echo "$statix_output" >&2
        fi
    fi
    
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            export CLAUDE_HOOKS_DEBUG=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Print header only in debug mode
if [[ "${CLAUDE_HOOKS_DEBUG:-0}" == "1" ]]; then
    echo "" >&2
    echo "🔍 Style Check - Validating code formatting..." >&2
    echo "────────────────────────────────────────────" >&2
fi

# Load configuration
load_config

# Start timing
START_TIME=$(time_start)

# Detect project type
PROJECT_TYPE=$(detect_project_type_with_tilt)

# Main execution
main() {
    # Handle mixed project types
    if [[ "$PROJECT_TYPE" == mixed:* ]]; then
        local types="${PROJECT_TYPE#mixed:}"
        IFS=',' read -ra TYPE_ARRAY <<< "$types"
        
        for type in "${TYPE_ARRAY[@]}"; do
            case "$type" in
                "go") lint_go ;;
                "python") lint_python ;;
                "javascript") lint_javascript ;;
                "rust") lint_rust ;;
                "nix") lint_nix ;;
                "tilt") 
                    if type -t lint_tilt &>/dev/null; then
                        lint_tilt
                    else
                        log_debug "Tilt linting function not available"
                    fi
                    ;;
            esac
            
            # Fail fast if configured
            if [[ "$CLAUDE_HOOKS_FAIL_FAST" == "true" && $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
                break
            fi
        done
    else
        # Single project type
        case "$PROJECT_TYPE" in
            "go") lint_go ;;
            "python") lint_python ;;
            "javascript") lint_javascript ;;
            "rust") lint_rust ;;
            "nix") lint_nix ;;
            "tilt") 
                if type -t lint_tilt &>/dev/null; then
                    lint_tilt
                else
                    log_debug "Tilt linting function not available"
                fi
                ;;
            "unknown") 
                log_debug "No recognized project type, skipping checks"
                ;;
        esac
    fi
    
    # Show timing if enabled
    time_end "$START_TIME"
    
    # Print summary
    print_summary
    
    # Return exit code - any issues mean failure
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

# Run main function
main
exit_code=$?

# Final message and exit
if [[ $exit_code -eq 2 ]]; then
    echo -e "${RED}⛔ BLOCKING: Must fix ALL errors above before continuing${NC}" >&2
    exit 2
else
    # Always exit with 2 so Claude sees the continuation message
    echo -e "${YELLOW}👉 Style clean. Continue with your task.${NC}" >&2
    exit 2
fi