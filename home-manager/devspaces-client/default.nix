{ lib, config, pkgs, ... }:

{
  # Devspace client configuration
  programs.zsh.shellAliases = let
    devspaceAlias = name:
      "et vermissian:2022 -c \"if tmux has-session -t ${name} >/dev/null 2>&1; then tmux set-environment -t ${name} -g TMUX_DEVSPACE ${name}; else tmux new-session -d -s ${name} -e TMUX_DEVSPACE=${name}; fi; exec tmux attach-session -t ${name}\"";
  in {
    # Direct connection aliases - ensure TMUX_DEVSPACE is always set
    mercury = devspaceAlias "mercury";
    venus = devspaceAlias "venus";
    earth = devspaceAlias "earth";
    mars = devspaceAlias "mars";
    jupiter = devspaceAlias "jupiter";

    # Status command to see what's running
    devspace-status = "ssh vermissian 'tmux list-sessions 2>/dev/null || echo \"No active sessions\"'";

    # Quick aliases for common operations
    ds = "devspace-status";
    dsl = "ssh vermissian 'tmux list-sessions -F \"#{session_name}: #{session_windows} windows, created #{session_created_string}\" 2>/dev/null || echo \"No sessions\"'";
  };

  # Helper function for devspace information
  programs.zsh.initContent = ''
    devspaces() {
      echo "🌌 Development Spaces"
      echo "━━━━━━━━━━━━━━━━━━━"
      echo
      echo "Available commands:"
      echo "  mercury  - Quick experiments and prototypes"
      echo "  venus    - Personal creative projects"
      echo "  earth    - Primary work project"
      echo "  mars     - Secondary work project"
      echo "  jupiter  - Large personal project"
      echo
      echo "  ds       - Quick status check"
      echo "  dsl      - Detailed session list"
      echo
      echo "Just type the planet name to connect!"
    }
  '';
}
