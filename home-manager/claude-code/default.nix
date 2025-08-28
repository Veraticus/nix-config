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
in
{
  # Install Node.js to enable npm
  home.packages = with pkgs; [
    nodejs_24
    # Dependencies for hooks
    yq
    ripgrep
    # FHS environment for running Playwright browsers
    steam-run
    # Include cc-tools binaries
    cc-tools
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

      # Symlinks to cc-tools binaries with cleaner paths
      ".claude/bin/cc-tools-lint".source = "${cc-tools}/bin/cc-tools-lint";
      ".claude/bin/cc-tools-test".source = "${cc-tools}/bin/cc-tools-test";
      ".claude/bin/cc-tools-statusline".source = "${cc-tools}/bin/cc-tools-statusline";

      # Notification hook (still needed as separate script)
      ".claude/hooks/ntfy-notifier.sh" = {
        source = ./hooks/ntfy-notifier.sh;
        executable = true;
      };

      # Playwright MCP wrapper for steam-run
      ".claude/playwright-mcp-wrapper.sh" = {
        source = ./playwright-headless-wrapper.sh;
        executable = true;
      };

      # Create necessary directories
      ".claude/.keep".text = "";
      ".claude/projects/.keep".text = "";
      ".claude/todos/.keep".text = "";
      ".claude/statsig/.keep".text = "";
      ".claude/commands/.keep".text = "";
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

  # Disable cc-tools server (cc-tools doesn't have a serve command)
  # services.cc-tools = {
  #   enable = true;
  #   package = cc-tools;
  # };

  # Enable the service to start on switch
  systemd.user.startServices = "sd-switch";

}
