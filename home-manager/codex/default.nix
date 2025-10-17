{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  notifierPath = "${homeDir}/.codex/hooks/ntfy-notifier.sh";
  projectPath = "${homeDir}/nix-config";
  mcpDir = "${homeDir}/.mcp";
  codexConfig = ''
model = "gpt-5-codex"
model_reasoning_effort = "high"

notify = ["${notifierPath}"]

${lib.optionalString pkgs.stdenv.isLinux ''
[mcp_servers.playwright]
command = "${mcpDir}/playwright-mcp-wrapper.sh"

''}[mcp_servers.targetprocess]
command = "${mcpDir}/bin/targetprocess-mcp"

[mcp_servers.jira]
command = "${mcpDir}/jira-mcp-wrapper.sh"

[projects."${projectPath}"]
trust_level = "trusted"

[tui]
notifications = true
'';
in
{
  # Install dependencies required by Codex and the notifier
  home.packages = with pkgs; [
    codex
    jq
    curl
  ];

  # Deploy Codex configuration and ntfy notifier
  home.file = {
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
}
