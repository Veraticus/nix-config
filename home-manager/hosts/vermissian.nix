{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ../common.nix
    ../tmux
    ../devspaces-host
    ../linkpearl
    ../security-tools
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [
      file
      unzip
      dmidecode
      gcc
      # Integration/automation specific tools
      jq
      httpie
      websocat # WebSocket client
      
      # Development tools
      awscli2 # AWS CLI for AWS operations
      kind # Kubernetes in Docker for local K8s clusters
      kubectl # Kubernetes CLI
      ctlptl # Controller for Kind clusters with registry
      postgresql # PostgreSQL client (psql)
      mongosh # MongoDB shell
      tcpdump # Packet capture tool
      lsof # List open files/ports
      inetutils # Network utilities (includes netstat-like tools)
      kubernetes-helm
      ginkgo
      prisma
      prisma-engines
      nodePackages.prisma
    ];
  };

  programs.zsh.shellAliases.update = "sudo nixos-rebuild switch --flake \".#$(hostname)\"";

  systemd.user.startServices = "sd-switch";
}
