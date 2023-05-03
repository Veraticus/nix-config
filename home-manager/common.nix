{ inputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    # You can also split up your configuration and import pieces of it here:
    ./nvim
    ./git
    ./kitty
    ./k9s
    ./zsh
    ./starship
    ./${pkgs.system}.nix
  ];

  # TODO: Set your username
  home = {
    username = "joshsymonds";
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [ 
      coreutils
      curl
      ripgrep
      ranger
      bat
      exa
      jq
      catppuccin-cursors.mochaLavender
      xdg-utils
      spotify
      unstable.firefox
      unstable.signal-desktop-beta
      unstable.slack
      unstable.vivid
      fzf
    ];

    pointerCursor = {
      name = "Catppuccin-Mocha-Lavender-Cursors";
      package = pkgs.catppuccin-cursors.mochaLavender;
      gtk.enable = true;
      size = 20;
    };
  };

  # Programs
  programs.go.enable = true;
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.htop.enable = true;
  programs.htop.settings.show_program_path = true;

  xdg.enable = true;

  home.file."Backgrounds" = {
    source = ./Backgrounds;
    recursive = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";
}