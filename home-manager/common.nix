{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # You can import other home-manager modules here
  imports = [
    # You can also split up your configuration and import pieces of it here:
    ./atuin
    ./claude-code
    ./codex
    ./kitty
    ./nvim
    ./git
    ./go
    ./k9s
    ./ssh-agent
    ./zsh
    ./starship
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "joshsymonds";

    sessionVariables = {
      COLORTERM = lib.mkDefault "truecolor";
    };

    packages = with pkgs; [
      coreutils-full
      curl
      ripgrep
      ranger
      bat
      jq
      killall
      eza
      xdg-utils
      ncdu
      fzf
      vivid
      manix
      talosctl
      wget
      shellcheck
      shellspec
      socat
      wireguard-tools
      inputs.cc-tools.packages.${pkgs.system}.default
      k9s
      starlark-lsp
      terraform
      autossh
      eternal-terminal
      gnumake
      yq
      gh
      parallel
      just
      kitty.terminfo  # Ensure proper terminal handling for SSH sessions

      # Tilt/Starlark tools
      tilt
      buildifier
      bazel-buildtools # includes buildozer and unused_deps

      # Kubernetes tools
      kubernetes-helm
      kubectl
      kustomize

      # AWS tools
      git-remote-codecommit

      # Python
      (python3.withPackages (ps: with ps; [
        pip
        pytest
        pyyaml
        black
        # Gmail analysis dependencies
        google-api-python-client
        google-auth
        google-auth-oauthlib
        google-auth-httplib2
      ]))

      # LSP servers
      lua-language-server
      pyright
      nil # Nix LSP
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint

      # Formatters
      stylua
      nixpkgs-fmt
      nodePackages.prettier
      gofumpt

      # Python package management
      uv
    ];
  };

  # Programs
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.htop = {
    enable = true;
    package = pkgs.htop;
    settings.show_program_path = true;
  };
  xdg.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.05";
}
