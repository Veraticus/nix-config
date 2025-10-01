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

[projects."${projectPath}"]
trust_level = "trusted"

notify = ["${notifierPath}"]

[tui]
notifications = true
'';
in
{
  # Install dependencies required by Codex and the notifier
  home.packages = with pkgs; [
    nodejs_24
    jq
    curl
  ];

  # Add npm global bin to PATH for user-installed packages
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Set npm prefix to user directory
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  # Install Codex on activation
  home.activation.installCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_24}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:$PATH"
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"

    if ! command -v codex >/dev/null 2>&1; then
      echo "Installing Codex CLI..."
      npm install -g @openai/codex
    else
      echo "Codex CLI is already installed at $(which codex)"
    fi
  '';

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
