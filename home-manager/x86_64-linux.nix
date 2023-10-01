{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ./common.nix

    ./eww
    ./kitty
    ./wofi
    ./hyprland
    ./wlogout
    ./swaync
    ./xiv
    ./firefox
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs.unstable; [
      appimage-run
      spotifywm
      (pkgs.makeDesktopItem {
        name = "Spotify";
        exec = "spotifywm";
        desktopName = "Spotify";
      })
      google-chrome
      inputs.hyprland-contrib.packages.${pkgs.system}.grimblast
      polkit-kde-agent
      file
      steam
      unzip
      cliphist
      wl-clip-persist
      pavucontrol
      (pkgs.writeShellApplication {
        name = "discord";
        text = "${pkgs.unstable.discord}/bin/discord --use-gl=desktop";
      })
      (pkgs.makeDesktopItem {
        name = "discord";
        exec = "discord";
        desktopName = "Discord";
      })
      nvtop
      qbittorrent
      inputs.nixpkgs-wayland.packages.${system}.wl-clipboard
      hyprpicker
      swaylock-effects
      swayidle
      swww
      psensor
      piper
      catppuccin-cursors.mochaLavender
      signal-desktop-beta
      slack
      xclip
      inputs.nix-gaming.packages.${system}.wine-ge
    ];

    pointerCursor = {
      name = "Catppuccin-Mocha-Lavender-Cursors";
      package = pkgs.catppuccin-cursors.mochaLavender;
      gtk.enable = true;
      size = 20;
    };
  };

  programs.zsh.shellAliases.update = "sudo nixos-rebuild switch --flake \".#$(hostname)\"";
  programs.kitty.font.size = 10;
  programs.kitty.settings."kitty_mod" = "alt";

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
