{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ./common.nix
    ./tmux
    ./devspaces-host
    ./linkpearl
    ./security-tools
    ./gmailctl
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [
      file
      unzip
      dmidecode
      gcc
    ];
  };

  programs.zsh.initExtra = ''
    # Smart update function that handles remote building for bluedesert
    update() {
      if [ "$(hostname)" = "bluedesert" ]; then
        ssh joshsymonds@172.31.0.200 "cd ~/nix-config && sudo nixos-rebuild switch --flake '.#bluedesert' --target-host joshsymonds@172.31.0.201 --use-remote-sudo"
      else
        sudo nixos-rebuild switch --flake ".#$(hostname)"
      fi
    }
    
    # Function for updating bluedesert from ultraviolet
    update-bluedesert() {
      cd ~/nix-config && sudo nixos-rebuild switch --flake '.#bluedesert' --target-host joshsymonds@172.31.0.201 --use-remote-sudo
    }
  '';

  systemd.user.startServices = "sd-switch";
}
