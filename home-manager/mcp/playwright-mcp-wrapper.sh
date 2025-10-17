#!/usr/bin/env bash
set -euo pipefail

# Wrapper script to run Playwright MCP server in FHS environment with steam-run
# This allows Playwright's bundled browsers to work on NixOS

# Skip host validation since we're providing the environment via steam-run
export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1

# Set environment variable that we'll check for in a custom patch
export MCP_PLAYWRIGHT_DEFAULT_BROWSER=firefox

# Run the MCP server inside steam-run's FHS environment
exec steam-run npx -y @executeautomation/playwright-mcp-server "$@"
