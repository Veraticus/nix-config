{ lib, config, pkgs, ... }:

{
  # Devspace client configuration
  programs.zsh.shellAliases = {
    # Direct connection aliases - ensure TMUX_DEVSPACE is always set
    mercury = "et vermissian:2022 -c '(tmux set-environment -t mercury -g TMUX_DEVSPACE mercury 2>/dev/null || true) && (tmux attach-session -t mercury || tmux new-session -s mercury -e TMUX_DEVSPACE=mercury)'";
    venus = "et vermissian:2022 -c '(tmux set-environment -t venus -g TMUX_DEVSPACE venus 2>/dev/null || true) && (tmux attach-session -t venus || tmux new-session -s venus -e TMUX_DEVSPACE=venus)'";
    earth = "et vermissian:2022 -c '(tmux set-environment -t earth -g TMUX_DEVSPACE earth 2>/dev/null || true) && (tmux attach-session -t earth || tmux new-session -s earth -e TMUX_DEVSPACE=earth)'";
    mars = "et vermissian:2022 -c '(tmux set-environment -t mars -g TMUX_DEVSPACE mars 2>/dev/null || true) && (tmux attach-session -t mars || tmux new-session -s mars -e TMUX_DEVSPACE=mars)'";
    jupiter = "et vermissian:2022 -c '(tmux set-environment -t jupiter -g TMUX_DEVSPACE jupiter 2>/dev/null || true) && (tmux attach-session -t jupiter || tmux new-session -s jupiter -e TMUX_DEVSPACE=jupiter)'";

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
