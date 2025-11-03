{ inputs, lib, config, pkgs, ... }:
{
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
  };
}
