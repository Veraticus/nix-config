{
  inputs,
  lib,
  config,
  pkgs,
  ...
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

      # IT tool dependencies
      awscli2 # AWS CLI for AWS operations
      kind # Kubernetes in Docker for local K8s clusters
      kubectl # Kubernetes CLI
      ctlptl # Controller for Kind clusters with registry
      postgresql # PostgreSQL client (psql)
      mongosh # MongoDB shell
      tcpdump # Packet capture tool
      lsof # List open files/ports
      inetutils # Network utilities (includes netstat-like tools)
      git # Version control (if not already available)
      kubernetes-helm
      ginkgo
    ];
  };

  programs.zsh.shellAliases.update = "sudo nixos-rebuild switch --flake \".#$(hostname)\"";

  systemd.user.startServices = "sd-switch";
}
