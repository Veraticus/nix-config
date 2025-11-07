{ inputs, lib, config, pkgs, ... }:
{
  imports = [
    ./atuin
    ./claude-code
    ./mcp
    ./codex
    ./egoengine
    ./kitty
    ./nvim
    ./git
    ./ssh-agent
    ./zsh
    ./starship
  ];

  config = {
    home = {
      enableNixpkgsReleaseCheck = false;
      username = "joshsymonds";

      sessionVariables = {
        COLORTERM = lib.mkDefault "truecolor";
      };

      packages = with pkgs; [
        coreutils
        git
        curl
        ripgrep
        jq
        eza
        fzf
        yq
        gh
        bat
        shellcheck
        neovim
        codex
        claudeCodeCli
        docker-client
        kubectl
        coder
        vivid  # For LS_COLORS generation
        inputs.agenix.packages.${pkgs.system}.agenix
      ];
    };

    programs.rbenv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      plugins = [
        {
          name = "ruby-build";
          src = pkgs.fetchFromGitHub {
            owner = "rbenv";
            repo = "ruby-build";
            rev = "v20251008";
            hash = "sha256-FZRp7O4YjDV+EOvwuaqWaQ6LfzL9vENBaIPot5G89Z0=";
          };
        }
      ];
    };

    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;

    programs.htop = {
      enable = true;
      package = pkgs.htop;
      settings.show_program_path = true;
    };

    xdg.enable = true;

    home.stateVersion = "25.05";
  };
}
