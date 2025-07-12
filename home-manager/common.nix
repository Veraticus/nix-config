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
    ./kitty
    ./nvim
    ./git
    ./go
    ./k9s
    ./zsh
    ./starship
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = "joshsymonds";

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
      k9s
      starlark-lsp
      autossh
      eternal-terminal
      gnumake
      yq

      # Tilt/Starlark tools
      tilt
      buildifier
      bazel-buildtools # includes buildozer and unused_deps

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
      black
      gofumpt

      # Python testing
      python3Packages.pytest
      python3Packages.pyyaml
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
