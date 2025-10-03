{ lib, config, pkgs, ... }:

{
  # Devspace host configuration - for running ON ultraviolet
  programs.zsh.shellAliases = let
    attachDevspace = name:
      "if tmux has-session -t ${name} >/dev/null 2>&1; then tmux set-environment -t ${name} -g TMUX_DEVSPACE ${name}; else tmux new-session -d -s ${name} -e TMUX_DEVSPACE=${name}; fi; exec tmux attach-session -t ${name}";
  in {
    # Local tmux session aliases - attach or create with TMUX_DEVSPACE set
    mercury = attachDevspace "mercury";
    venus = attachDevspace "venus";
    earth = attachDevspace "earth";
    mars = attachDevspace "mars";
    jupiter = attachDevspace "jupiter";

    # Status command to see what's running locally
    devspace-status = "tmux list-sessions 2>/dev/null || echo \"No active sessions\"";

    # Quick aliases for common operations
    ds = "devspace-status";
    dsl = "tmux list-sessions -F \"#{session_name}: #{session_windows} windows, created #{session_created_string}\" 2>/dev/null || echo \"No sessions\"";
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
