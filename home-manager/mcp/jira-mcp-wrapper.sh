#!/usr/bin/env bash
set -euo pipefail

# Load Jira configuration from ~/.config/atlassian/config.json
CONFIG_FILE="$HOME/.config/atlassian/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Jira configuration not found at $CONFIG_FILE" >&2
  echo "Please create the file with the following structure:" >&2
  cat >&2 <<'EOF'
{
  "JIRA_URL": "https://your-company.atlassian.net",
  "JIRA_USERNAME": "your.email@company.com",
  "JIRA_API_TOKEN": "your_jira_api_token"
}
EOF
  exit 1
fi

# Parse the JSON config file and export as environment variables
JIRA_URL=$(jq -r '.JIRA_URL // empty' "$CONFIG_FILE")
JIRA_USERNAME=$(jq -r '.JIRA_USERNAME // empty' "$CONFIG_FILE")
JIRA_API_TOKEN=$(jq -r '.JIRA_API_TOKEN // empty' "$CONFIG_FILE")
export JIRA_URL JIRA_USERNAME JIRA_API_TOKEN

# Optional Confluence configuration - only export if values are present
CONFLUENCE_URL=$(jq -r '.CONFLUENCE_URL // empty' "$CONFIG_FILE")
CONFLUENCE_USERNAME=$(jq -r '.CONFLUENCE_USERNAME // empty' "$CONFIG_FILE")
CONFLUENCE_API_TOKEN=$(jq -r '.CONFLUENCE_API_TOKEN // empty' "$CONFIG_FILE")

if [ -n "$CONFLUENCE_URL" ]; then
  export CONFLUENCE_URL
fi
if [ -n "$CONFLUENCE_USERNAME" ]; then
  export CONFLUENCE_USERNAME
fi
if [ -n "$CONFLUENCE_API_TOKEN" ]; then
  export CONFLUENCE_API_TOKEN
fi

# Check required Jira variables
if [ -z "$JIRA_URL" ] || [ -z "$JIRA_USERNAME" ] || [ -z "$JIRA_API_TOKEN" ]; then
  echo "Error: Missing required Jira configuration in $CONFIG_FILE" >&2
  echo "Required fields: JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN" >&2
  exit 1
fi

# Run the mcp-atlassian server
exec "$HOME/.mcp/bin/mcp-atlassian" "$@"
