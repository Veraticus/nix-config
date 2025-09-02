{ inputs
, lib
, config
, pkgs
, ...
}:
{
  imports = [
    ../common.nix
    ../tmux
    ../devspaces-host
    ../linkpearl
    ../security-tools
    ../gmailctl
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [
      file
      unzip
      dmidecode
      gcc
      # Media server specific tools
      mediainfo
      ffmpeg
      
      # Network debugging tools (useful for media server)
      tcpdump # Packet capture tool
      lsof # List open files/ports
      inetutils # Network utilities (includes netstat-like tools)
    ];
  };

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake \".#$(hostname)\"";
    update-bluedesert = "cd ~/nix-config && sudo nixos-rebuild switch --flake '.#bluedesert' --target-host joshsymonds@172.31.0.201 --use-remote-sudo";
  };

  systemd.user.startServices = "sd-switch";
}
