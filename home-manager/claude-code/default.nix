{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # Get cc-tools binaries from the flake
  cc-tools = inputs.cc-tools.packages.${pkgs.system}.default;

  # Get targetprocess-mcp from the flake
  targetprocess-mcp = inputs.targetprocess-mcp.packages.${pkgs.system}.default;

  # Get mcp-atlassian from our custom packages
  mcp-atlassian = pkgs.mcp-atlassian;
in
{
  # Install Node.js to enable npm
  home.packages =
    with pkgs;
    [
      nodejs_24
      # Dependencies for hooks and wrappers
      yq
      jq
      ripgrep
      # Include cc-tools binaries
      cc-tools
      # Target Process MCP server
      targetprocess-mcp
      # Atlassian MCP server
      mcp-atlassian
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # FHS environment for running Playwright browsers (Linux only)
      steam-run
    ];

  # Add npm global bin to PATH for user-installed packages
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Set npm prefix to user directory and cc-tools socket path
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    CC_TOOLS_SOCKET = "/run/user/\${UID}/cc-tools.sock";
  };

  # Create and manage ~/.claude directory
  home.file =
    let
      # Dynamically read command files
      commandFiles = builtins.readDir ./commands;
      commandEntries = lib.filterAttrs (
        name: type: type == "regular" && lib.hasSuffix ".md" name
      ) commandFiles;
      commandFileAttrs = lib.mapAttrs' (
        name: _: lib.nameValuePair ".claude/commands/${name}" { source = ./commands/${name}; }
      ) commandEntries;
    in
    commandFileAttrs
    // {
      # Static configuration files
      ".claude/settings.json".source = ./settings.json;
      ".claude/CLAUDE.md".source = ./CLAUDE.md;

      # Copy all agent definitions
      ".claude/agents".source = ./agents;

      # Symlinks to cc-tools binaries with cleaner paths
      ".claude/bin/cc-tools-validate".source = "${cc-tools}/bin/cc-tools-validate";
      ".claude/bin/cc-tools-statusline".source = "${cc-tools}/bin/cc-tools-statusline";

      # Symlink to targetprocess-mcp binary
      ".claude/bin/targetprocess-mcp".source = "${targetprocess-mcp}/bin/targetprocess-mcp";

      # Symlink to mcp-atlassian binary
      ".claude/bin/mcp-atlassian".source = "${mcp-atlassian}/bin/mcp-atlassian";

      # Jira MCP wrapper that loads secrets from ~/.config/atlassian
      ".claude/jira-mcp-wrapper.sh" = {
        source = ./jira-mcp-wrapper.sh;
        executable = true;
      };

      # Notification hook (still needed as separate script)
      ".claude/hooks/ntfy-notifier.sh" = {
        source = ./hooks/ntfy-notifier.sh;
        executable = true;
      };

      # Create necessary directories
      ".claude/.keep".text = "";
      ".claude/projects/.keep".text = "";
      ".claude/todos/.keep".text = "";
      ".claude/statsig/.keep".text = "";
      ".claude/commands/.keep".text = "";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      # Playwright MCP wrapper for steam-run (Linux only)
      ".claude/playwright-mcp-wrapper.sh" = {
        source = ./playwright-headless-wrapper.sh;
        executable = true;
      };
    };

  # Install Claude Code on activation
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_24}/bin:$PATH"
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"

    if ! command -v claude >/dev/null 2>&1; then
      echo "Installing Claude Code..."
      npm install -g @anthropic-ai/claude-code
    else
      echo "Claude Code is already installed at $(which claude)"
    fi
  '';
}
