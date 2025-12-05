{
  inputs,
  lib,
  pkgs,
  ...
}: let
  tmuxDevspaceHelper =
    pkgs.writeShellScriptBin "tmux-devspace" (builtins.readFile ./tmux/scripts/tmux-devspace.sh);
  firefoxCli = pkgs.writeShellScriptBin "firefox" ''
    open -n -a "${pkgs.firefox-bin-unwrapped}/Applications/Firefox.app" "$@"
  '';
in {
  imports = [
    ./atuin
    ./claude-code
    # ./gemini-cli  # Disabled - overrides don't work properly
    ./mcp
    ./codex
    ./egoengine
    ./helix
    ./kitty
    ./tmux
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

      packages = with pkgs; (
        [
          autossh
          bat
          claudeCodeCli
          coder
          codex
          coreutils-full
          curl
          devenv
          docker
          eza
          eternal-terminal
          fzf
          gh
          git
          gptfdisk
          inputs.agenix.packages.${pkgs.system}.agenix
          inputs.cc-tools.packages.${pkgs.system}.default
          istioctl
          jq
          just
          k9s
          killall
          kitty.terminfo
          tmux
          tmux.terminfo
          kubectl
          kubernetes-helm
          kustomize
          manix
          moar
          ncdu
          parallel
        ]
        ++ lib.optionals (!stdenv.isDarwin) [parted]
        ++ lib.optionals stdenv.isDarwin [firefoxCli]
        ++ [
          ranger
          ripgrep
          shellcheck
          shellspec
          socat
          talosctl
          vivid # For LS_COLORS generation
          wget
          wireguard-tools
          xdg-utils
          yq
          tmuxDevspaceHelper
        ]
      );
    };

    programs = {
      rbenv = {
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

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      htop = {
        enable = true;
        package = pkgs.htop;
        settings.show_program_path = true;
      };
    };

    xdg.enable = true;

    home.stateVersion = "25.05";
  };
}
