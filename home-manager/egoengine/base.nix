{ inputs, lib, config, pkgs, ... }:
{
  imports = [
    ../common.nix
    ../tmux
    ../linkpearl
    ../security-tools
    ../gmailctl
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [
      _1password-cli
      file
      unzip
      dmidecode
      gcc
      jq
      httpie
      websocat
      awscli2
      kind
      kubectl
      ctlptl
      nix
      postgresql
      mongosh
      tcpdump
      lsof
      inetutils
      kubernetes-helm
      ginkgo
      prisma
      prisma-engines
      nodePackages.prisma
      rustup
      (pkgs.callPackage ../../pkgs/mcp-atlassian { })
    ];
  };
}
