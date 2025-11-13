{
  lib,
  config,
  pkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  notifierPath = "${homeDir}/.codex/hooks/ntfy-notifier.sh";
  projectPath = "${homeDir}/nix-config";
  mcpDir = "${homeDir}/.mcp";
  codexConfig = ''
    model = "gpt-5-codex"
    model_reasoning_effort = "high"

    notify = ["${notifierPath}"]

    ${lib.optionalString pkgs.stdenv.isLinux ''
      ''}[mcp_servers.targetprocess]
    command = "${mcpDir}/bin/targetprocess-mcp"

    [mcp_servers.jira]
    command = "${mcpDir}/jira-mcp-wrapper.sh"

    [projects."${projectPath}"]
    trust_level = "trusted"

    [tui]
    notifications = true
  '';
in {
  home = {
    # Install dependencies required by Codex and the notifier
    packages = with pkgs; [
      codex
      jq
      curl
    ];

    # Deploy Codex configuration and ntfy notifier
    file = {
      ".codex/hooks/ntfy-notifier.sh" = {
        source = ./hooks/ntfy-notifier.sh;
        executable = true;
        force = true;
      };

      ".codex/config.toml" = {
        text = codexConfig;
        force = true;
      };
    };

    activation.codexDirectoryPermissions = lib.hm.dag.entryAfter ["writeBoundary"] ''
      set -euo pipefail
      if [ -d "$HOME/.codex" ]; then
        chmod 755 "$HOME/.codex"
        if [ -d "$HOME/.codex/hooks" ]; then
          chmod 755 "$HOME/.codex/hooks"
        fi
      fi
    '';
  };
}
