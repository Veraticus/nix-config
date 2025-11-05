{ inputs, lib, config, pkgs, ... }:
let
  lazySources = import ./lazy-plugins.nix { inherit (pkgs) fetchFromGitHub; };
  lazyPluginCache = pkgs.runCommand "lazyvim-plugins-cache" {} ''
    set -euo pipefail
    mkdir -p $out/share/nvim/lazy
${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
    ${pkgs.coreutils}/bin/cp -a ${src} $out/share/nvim/lazy/${name}
'') lazySources)}
  '';
in {
  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    package = pkgs.neovim;

    extraPackages = with pkgs; [ git ];
    withNodeJs = false;
    withPython3 = true;

    extraConfig = ''
      let $PATH = $PATH . ':${pkgs.git}/bin'
    '';
  };

  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
    force = true;
  };

  home.file = {
    ".local/share/nvim/lazy" = {
      source = lazyPluginCache + "/share/nvim/lazy";
      recursive = true;
      force = true;
    };
  };
}
