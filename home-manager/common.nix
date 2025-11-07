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
    ./k9s
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
        autossh
        bat
        claudeCodeCli
        coder
        codex
        coreutils-full
        curl
        docker
        docker-client
        eza
        eternal-terminal
        fzf
        gh
        git
        inputs.agenix.packages.${pkgs.system}.agenix
        inputs.cc-tools.packages.${pkgs.system}.default
        istioctl
        jq
        just
        k9s
        killall
        kitty.terminfo
        kubectl
        kubernetes-helm
        kustomize
        manix
        ncdu
        parallel
        ranger
        ripgrep
        shellcheck
        shellspec
        socat
        talosctl
        vivid  # For LS_COLORS generation
        wget
        wireguard-tools
        xdg-utils
        yq
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
