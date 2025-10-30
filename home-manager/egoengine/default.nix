{ lib, pkgs, ... }:
{
  home.file.".local/bin/ee" = {
    source = ./scripts/ee.sh;
    executable = true;
    force = true;
  };

  home.sessionPath = lib.mkAfter [ "$HOME/.local/bin" ];

  home.packages = [
    pkgs._1password-cli
  ];
}
