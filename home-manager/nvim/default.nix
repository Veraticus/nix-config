{
  lib,
  config,
  pkgs,
  ...
}: let
  lazySources = import ./lazy-plugins.nix {inherit (pkgs) fetchFromGitHub;};
  lazyPluginCache = pkgs.runCommand "lazyvim-plugins-cache" {} ''
        set -euo pipefail
        mkdir -p $out/share/nvim/lazy
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: src: ''
        ${pkgs.coreutils}/bin/cp -a ${src} $out/share/nvim/lazy/${name}
      '')
      lazySources)}
  '';
  lazyDataDir = "${config.home.homeDirectory}/.local/share/nvim/lazy";
in {
  home.packages = with pkgs; [
    ripgrep
    fd
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = false;
    viAlias = true;
    vimAlias = true;
    package = pkgs.neovim;

    extraPackages = with pkgs; [git];
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
  home.activation.syncLazyPlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
    lazy_dir=${lib.escapeShellArg lazyDataDir}
    cache_dir=${lib.escapeShellArg (lazyPluginCache + "/share/nvim/lazy")}
    $DRY_RUN_CMD rm -rf "$lazy_dir"
    $DRY_RUN_CMD mkdir -p "$(dirname "$lazy_dir")"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/cp -a "$cache_dir" "$lazy_dir"
  '';
}
