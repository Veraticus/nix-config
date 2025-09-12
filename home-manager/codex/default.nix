{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # Install Node.js to enable npm
  home.packages = with pkgs; [
    nodejs_24
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

    if ! npm list -g @openai/codex >/dev/null 2>&1; then
      echo "Installing OpenAI Codex..."
      npm install -g @openai/codex
    else
      echo "OpenAI Codex is already installed"
    fi
  '';
}
