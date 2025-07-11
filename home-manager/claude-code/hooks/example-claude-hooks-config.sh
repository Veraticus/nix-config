#!/usr/bin/env bash
# Example .claude-hooks-config.sh - Project-specific Claude hooks configuration
#
# Copy this file to your project root as .claude-hooks-config.sh and uncomment
# the settings you want to override.
#
# This file is sourced by smart-lint.sh, so it can override any setting.

# ============================================================================
# COMMON OVERRIDES
# ============================================================================

# Disable all hooks for this project
# export CLAUDE_HOOKS_ENABLED=false

# Enable debug output for troubleshooting
# export CLAUDE_HOOKS_DEBUG=1

# Stop on first issue instead of running all checks
# export CLAUDE_HOOKS_FAIL_FAST=true

# ============================================================================
# LANGUAGE-SPECIFIC OVERRIDES
# ============================================================================

# Disable checks for specific languages
# export CLAUDE_HOOKS_GO_ENABLED=false
# export CLAUDE_HOOKS_PYTHON_ENABLED=false
# export CLAUDE_HOOKS_JS_ENABLED=false
# export CLAUDE_HOOKS_RUST_ENABLED=false
# export CLAUDE_HOOKS_NIX_ENABLED=false


# ============================================================================
# NOTIFICATION SETTINGS
# ============================================================================

# Disable notifications for this project
# export CLAUDE_HOOKS_NTFY_ENABLED=false

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================

# Limit file checking for very large repos
# export CLAUDE_HOOKS_MAX_FILES=500

# ============================================================================
# TEST EXCLUSIONS
# ============================================================================

# Exclude specific test patterns from smart-test.sh
# Useful for tests that require special context or setup
# Format: comma-separated regex patterns
# export CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS="e2e,integration_test"

# Examples:
# Exclude all E2E tests:
# export CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS="e2e"

# Exclude multiple patterns:
# export CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS="e2e,integration,load_test"

# Exclude tests in specific directories:
# export CLAUDE_HOOKS_GO_TEST_EXCLUDE_PATTERNS="holodeck/e2e,special/context"

# ============================================================================
# PROJECT-SPECIFIC EXAMPLES
# ============================================================================

# Example: Different settings for different environments
# if [[ "$USER" == "ci" ]]; then
#     export CLAUDE_HOOKS_FAIL_FAST=true
#     export CLAUDE_HOOKS_GO_COMPLEXITY_THRESHOLD=15
# fi

# Example: Disable certain checks in test directories
# if [[ "$PWD" =~ /test/ ]]; then
#     export CLAUDE_HOOKS_GO_FORBIDDEN_PATTERNS=false
# fi