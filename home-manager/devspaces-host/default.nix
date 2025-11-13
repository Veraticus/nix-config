_: {
  # Devspace host configuration - for running ON ultraviolet
  programs.zsh.shellAliases = let
    contextAlias = name: icon: "t ${name} ${icon}";
  in {
    # Local tmux session aliases - attach/create via t with explicit icons
    mercury = contextAlias "mercury" "☿";
    venus = contextAlias "venus" "♀";
    earth = contextAlias "earth" "♁";
    mars = contextAlias "mars" "♂";
    jupiter = contextAlias "jupiter" "♃";

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
