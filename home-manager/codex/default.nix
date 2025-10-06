{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  notifierPath = "${config.home.homeDirectory}/.codex/hooks/ntfy-notifier.sh";
  projectPath = "${config.home.homeDirectory}/nix-config";
  codexConfig = ''
model = "gpt-5-codex"
model_reasoning_effort = "high"

notify = ["${notifierPath}"]

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
