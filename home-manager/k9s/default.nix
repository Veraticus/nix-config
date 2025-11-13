{pkgs, ...}: {
  home.packages = [pkgs.k9s];

  xdg.configFile."k9s" = {
    source = ./k9s;
    recursive = true;
  };
}
