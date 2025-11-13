{pkgs, ...}: {
  programs.atuin = {
    enable = true;
    package = pkgs.atuin;

    enableZshIntegration = true;
    daemon.enable = true;
  };
}
