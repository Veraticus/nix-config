#!/usr/bin/env bash
# Wrapper script to run Playwright MCP server on macOS
# This runs the server directly without steam-run (which is Linux-only)

# Set environment variable to prefer Firefox (though macOS can run all browsers)
export MCP_PLAYWRIGHT_DEFAULT_BROWSER=firefox

# Run the MCP server directly with npx
exec npx -y @executeautomation/playwright-mcp-server "$@"