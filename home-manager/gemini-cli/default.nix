{
  pkgs,
  lib,
  config,
  ...
}: {
  home = {
    packages = [
      pkgs.geminiCli
      pkgs.jq # Required for the hook script and settings merging
    ];

    # Create and manage ~/.gemini directory
    file = {
      ".gemini/hooks/ntfy-notifier.sh" = {
        source = ./hooks/ntfy-notifier.sh;
        executable = true;
      };
    };

    activation.geminiSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      set -euo pipefail
      
      GEMINI_DIR="$HOME/.gemini"
      SETTINGS_FILE="$GEMINI_DIR/settings.json"
      
      if [ ! -d "$GEMINI_DIR" ]; then
        mkdir -p "$GEMINI_DIR"
        chmod 755 "$GEMINI_DIR"
      fi
      
      # Define the Nix-managed settings
      NIX_SETTINGS='${builtins.toJSON {
        tools = {
          enableHooks = true;
        };
        hooks = {
          AfterModel = [
            {
              hooks = [
                {
                  type = "command";
                  command = "${config.home.homeDirectory}/.gemini/hooks/ntfy-notifier.sh";
                }
              ];
            }
          ];
        };
      }}'
      
      if [ -f "$SETTINGS_FILE" ]; then
        # If file exists, merge Nix settings into it
        # We use a temporary file to avoid issues with reading/writing the same file
        TMP_SETTINGS=$(mktemp)
        # Merge: Existing settings + Nix settings (Nix wins for these keys)
        # Actually, let's make Nix wins for these specific keys, but keep others.
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$NIX_SETTINGS") > "$TMP_SETTINGS"
        cat "$TMP_SETTINGS" > "$SETTINGS_FILE"
        rm "$TMP_SETTINGS"
      else
        # If file doesn't exist, just write Nix settings
        echo "$NIX_SETTINGS" > "$SETTINGS_FILE"
      fi
      
      # Ensure the settings file is writable
      chmod 644 "$SETTINGS_FILE"
      
      if [ -d "$HOME/.gemini/hooks" ]; then
        chmod 755 "$HOME/.gemini/hooks"
      fi
    '';
  };
}
