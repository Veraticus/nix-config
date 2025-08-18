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
    nodejs_20
    # Dependencies for hooks
    yq
    ripgrep
  ];

  # Add npm global bin to PATH for user-installed packages
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Set npm prefix to user directory
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  # Create and manage ~/.claude directory
  home.file = let
    # Dynamically read command files
    commandFiles = builtins.readDir ./commands;
    commandEntries = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) commandFiles;
    commandFileAttrs = lib.mapAttrs' (name: _: 
      lib.nameValuePair ".claude/commands/${name}" { source = ./commands/${name}; }
    ) commandEntries;
  in commandFileAttrs // {
    # Static files
    ".claude/settings.json".source = ./settings.json;
    ".claude/CLAUDE.md".source = ./CLAUDE.md;

    # Copy hook scripts with executable permissions
    ".claude/hooks/common-helpers.sh" = {
      source = ./hooks/common-helpers.sh;
      executable = true;
    };

    ".claude/hooks/smart-lint.sh" = {
      source = ./hooks/smart-lint.sh;
      executable = true;
    };

    ".claude/hooks/smart-test.sh" = {
      source = ./hooks/smart-test.sh;
      executable = true;
    };

    ".claude/hooks/ntfy-notifier.sh" = {
      source = ./hooks/ntfy-notifier.sh;
      executable = true;
    };

    # Integration helper script
    ".claude/hooks/integrate.sh" = {
      source = ./hooks/integrate.sh;
      executable = true;
    };

    # Status line script
    ".claude/hooks/statusline.sh" = {
      source = ./hooks/statusline.sh;
      executable = true;
    };
    
    # Copy documentation and examples (not executable)
    ".claude/hooks/README.md".source = ./hooks/README.md;
    ".claude/hooks/INTEGRATION.md".source = ./hooks/INTEGRATION.md;
    ".claude/hooks/QUICK_START.md".source = ./hooks/QUICK_START.md;
    ".claude/hooks/example-Makefile".source = ./hooks/example-Makefile;
    ".claude/hooks/example-claude-hooks-config.sh".source =
      ./hooks/example-claude-hooks-config.sh;
    ".claude/hooks/example-claude-hooks-ignore".source = ./hooks/example-claude-hooks-ignore;

    # Create necessary directories
    ".claude/.keep".text = "";
    ".claude/projects/.keep".text = "";
    ".claude/todos/.keep".text = "";
    ".claude/statsig/.keep".text = "";
    ".claude/commands/.keep".text = "";
  };

  # Install Claude Code on activation
  home.activation.installClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.nodejs_20}/bin:$PATH"
    export NPM_CONFIG_PREFIX="$HOME/.npm-global"

    if ! command -v claude >/dev/null 2>&1; then
      echo "Installing Claude Code..."
      npm install -g @anthropic-ai/claude-code
    else
      echo "Claude Code is already installed at $(which claude)"
    fi
  '';

}
