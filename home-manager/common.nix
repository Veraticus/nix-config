{ inputs, lib, config, pkgs, ... }:
{
  # You can import other home-manager modules here
  imports = [
    # You can also split up your configuration and import pieces of it here:
    ./atuin
    ./claude-code
    ./kitty
    ./nvim
    ./git
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
      go-tools
      golangci-lint
      socat
      wireguard-tools
      k9s
      starlark-lsp
      autossh
      eternal-terminal
      gnumake
      
      # LSP servers
      lua-language-server
      gopls
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
    ];
  };

  # Programs
  programs.go = {
    enable = true;
    package = pkgs.go_1_23;
  };
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
