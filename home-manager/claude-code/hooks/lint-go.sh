#!/usr/bin/env bash
# lint-go.sh - Go-specific linting functions for Claude Code smart-lint
#
# This file is sourced by smart-lint.sh to provide Go linting capabilities.
# It follows the same pattern as other language-specific linters.

# ============================================================================
# GO LINTING
# ============================================================================

lint_go() {
    if [[ "${CLAUDE_HOOKS_GO_ENABLED:-true}" != "true" ]]; then
        log_debug "Go linting disabled"
        return 0
    fi
    
    log_debug "Running Go formatting and linting..."
    
    # Check if Makefile exists with fmt and lint targets
    if [[ -f "Makefile" ]]; then
        local has_fmt=$(grep -E "^fmt:" Makefile 2>/dev/null || echo "")
        local has_lint=$(grep -E "^lint:" Makefile 2>/dev/null || echo "")
        
        if [[ -n "$has_fmt" && -n "$has_lint" ]]; then
            log_debug "Using Makefile targets"
            
            local fmt_output
            # Suppress output unless there's an error
            if ! fmt_output=$(make fmt 2>&1); then
                add_error "Go formatting failed (make fmt)"
                # Only show output on failure
                echo "$fmt_output" >&2
            fi
            
            local lint_output
            if ! lint_output=$(make lint 2>&1); then
                add_error "Go linting failed (make lint)"
                echo "$lint_output" >&2
            fi
        else
            # Fallback to direct commands
            run_go_direct_lint
        fi
    else
        # No Makefile, use direct commands
        run_go_direct_lint
    fi
}

# Run Go linting tools directly (when no Makefile targets)
run_go_direct_lint() {
    log_debug "Using direct Go tools"
    
    # Format check - filter files through should_skip_file
    local unformatted_files=$(gofmt -l . 2>/dev/null | grep -v vendor/ | while read -r file; do
        if ! should_skip_file "$file"; then
            echo "$file"
        fi
    done || true)
    
    if [[ -n "$unformatted_files" ]]; then
        local fmt_output
        if ! fmt_output=$(gofmt -w . 2>&1); then
            add_error "Go formatting failed"
            echo "$fmt_output" >&2
        fi
    fi
    
    # Linting - build exclude args from .claude-hooks-ignore
    if command_exists golangci-lint; then
        local exclude_args=""
        if [[ -f ".claude-hooks-ignore" ]]; then
            # Convert ignore patterns to golangci-lint skip-files patterns
            while IFS= read -r pattern; do
                [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
                # Remove quotes and adjust pattern for golangci-lint
                pattern="${pattern//\'/}"
                pattern="${pattern//\"/}"
                exclude_args="${exclude_args} --skip-files=${pattern}"
            done < ".claude-hooks-ignore"
        fi
        
        local lint_output
        local lint_cmd="golangci-lint run --timeout=2m${exclude_args}"
        log_debug "Running: $lint_cmd"
        if ! lint_output=$($lint_cmd 2>&1); then
            add_error "golangci-lint found issues"
            echo "$lint_output" >&2
        fi
    elif command_exists go; then
        local vet_output
        if ! vet_output=$(go vet ./... 2>&1); then
            add_error "go vet found issues"
            echo "$vet_output" >&2
        fi
    else
        log_error "No Go linting tools available - install golangci-lint or go"
    fi
}

