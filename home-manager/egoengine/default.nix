{
  lib,
  pkgs,
  ...
}: {
  home = {
    file.".local/bin/ee" = {
      source = ./scripts/ee.sh;
      executable = true;
      force = true;
    };

    sessionPath = lib.mkAfter ["$HOME/.local/bin"];

    packages = [
      pkgs._1password-cli
      pkgs.gnutar
      pkgs.gzip
    ];
  };
}
