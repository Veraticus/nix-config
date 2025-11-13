_: {
  # Devspace client configuration
  programs.zsh.shellAliases = let
    devspaceAlias = name: icon: "et vermissian:2022 -c \"tmux-devspace attach --icon '${icon}' ${name}\"";
  in {
    # Direct connection aliases - ensure TMUX_DEVSPACE/DEV_CONTEXT metadata is set
    mercury = devspaceAlias "mercury" "☿";
    venus = devspaceAlias "venus" "♀";
    earth = devspaceAlias "earth" "♁";
    mars = devspaceAlias "mars" "♂";
    jupiter = devspaceAlias "jupiter" "♃";

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
