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
  home.packages =
    (with pkgs; [
      nodejs_24
      # Dependencies for hooks and wrappers
      yq
      jq
      ripgrep
      # Include cc-tools binaries
      cc-tools
    ])
    ++ [ pkgs.claudeCodeCli ];

  # Add npm global bin to PATH for user-installed packages
  home.sessionPath = lib.mkAfter [
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
    lib.mkMerge [
      commandFileAttrs
      {
        ".claude/settings.json".source = ./settings.json;
        ".claude/CLAUDE.md".source = ./CLAUDE.md;
        ".claude/agents".source = ./agents;
        ".claude/bin/cc-tools-validate".source = "${cc-tools}/bin/cc-tools-validate";
        ".claude/bin/cc-tools-statusline".source = "${cc-tools}/bin/cc-tools-statusline";
        ".claude/hooks/ntfy-notifier.sh" = {
          source = ./hooks/ntfy-notifier.sh;
          executable = true;
        };
        ".claude/.keep".text = "";
        ".claude/projects/.keep".text = "";
        ".claude/todos/.keep".text = "";
        ".claude/statsig/.keep".text = "";
        ".claude/commands/.keep".text = "";
      }
    ];

  # Install Claude Code on activation
  # CLI is provided via pkgs.claudeCodeCli.
  home.activation.claudeDirectoryPermissions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail
    for dir in ".claude" ".claude/bin" ".claude/commands" ".claude/hooks" ".claude/projects" ".claude/statsig" ".claude/todos"; do
      if [ -d "$HOME/$dir" ]; then
        chmod 755 "$HOME/$dir"
      fi
    done
    if [ ! -d "$HOME/.claude/debug" ]; then
      mkdir -p "$HOME/.claude/debug"
      chmod 755 "$HOME/.claude/debug"
    fi
  '';
}
