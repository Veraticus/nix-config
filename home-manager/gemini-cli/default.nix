{
  pkgs,
  lib,
  ...
}: {
  home = {
    packages = [
      pkgs.geminiCli
      pkgs.jq # Required for the hook script
    ];

    # Create and manage ~/.gemini directory
    file = {
      ".gemini/settings.json".source = ./settings.json;
      ".gemini/hooks/ntfy-notifier.sh" = {
        source = ./hooks/ntfy-notifier.sh;
        executable = true;
      };
    };

    activation.geminiDirectoryPermissions = lib.hm.dag.entryAfter ["writeBoundary"] ''
      set -euo pipefail
      if [ -d "$HOME/.gemini" ]; then
        chmod 755 "$HOME/.gemini"
      fi
      if [ -d "$HOME/.gemini/hooks" ]; then
        chmod 755 "$HOME/.gemini/hooks"
      fi
    '';
  };
}
