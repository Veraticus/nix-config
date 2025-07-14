{ inputs, lib, config, pkgs, ... }:
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
  home.file.".claude/settings.json".source = ./settings.json;
  home.file.".claude/CLAUDE.md".source = ./CLAUDE.md;

  # Copy hook scripts with executable permissions
  home.file.".claude/hooks/common-helpers.sh" = {
    source = ./hooks/common-helpers.sh;
    executable = true;
  };

  home.file.".claude/hooks/smart-lint.sh" = {
    source = ./hooks/smart-lint.sh;
    executable = true;
  };

  home.file.".claude/hooks/smart-test.sh" = {
    source = ./hooks/smart-test.sh;
    executable = true;
  };

  home.file.".claude/hooks/ntfy-notifier.sh" = {
    source = ./hooks/ntfy-notifier.sh;
    executable = true;
  };
  
  home.file.".claude/hooks/ntfy-notifier-debug.sh" = {
    source = ./hooks/ntfy-notifier-debug.sh;
    executable = true;
  };
  
  # Language-specific hook files
  home.file.".claude/hooks/lint-go.sh" = {
    source = ./hooks/lint-go.sh;
    executable = true;
  };
  
  home.file.".claude/hooks/test-go.sh" = {
    source = ./hooks/test-go.sh;
    executable = true;
  };
  
  home.file.".claude/hooks/lint-tilt.sh" = {
    source = ./hooks/lint-tilt.sh;
    executable = true;
  };
  
  home.file.".claude/hooks/test-tilt.sh" = {
    source = ./hooks/test-tilt.sh;
    executable = true;
  };
  
  # Integration helper script
  home.file.".claude/hooks/integrate.sh" = {
    source = ./hooks/integrate.sh;
    executable = true;
  };
  
  # Copy documentation and examples (not executable)
  home.file.".claude/hooks/README.md".source = ./hooks/README.md;
  home.file.".claude/hooks/INTEGRATION.md".source = ./hooks/INTEGRATION.md;
  home.file.".claude/hooks/QUICK_START.md".source = ./hooks/QUICK_START.md;
  home.file.".claude/hooks/example-Makefile".source = ./hooks/example-Makefile;
  home.file.".claude/hooks/example-claude-hooks-config.sh".source = ./hooks/example-claude-hooks-config.sh;
  home.file.".claude/hooks/example-claude-hooks-ignore".source = ./hooks/example-claude-hooks-ignore;

  # Copy command files
  home.file.".claude/commands/check.md".source = ./commands/check.md;
  home.file.".claude/commands/next.md".source = ./commands/next.md;
  home.file.".claude/commands/prompt.md".source = ./commands/prompt.md;

  # Create necessary directories
  home.file.".claude/.keep".text = "";
  home.file.".claude/projects/.keep".text = "";
  home.file.".claude/todos/.keep".text = "";
  home.file.".claude/statsig/.keep".text = "";
  home.file.".claude/commands/.keep".text = "";

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
