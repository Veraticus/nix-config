{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce optionalString getExe;
in {
  assertions = [
    {
      assertion = config.system.primaryUser != null;
      message = "modules/darwin/applications.nix requires system.primaryUser to be set";
    }
  ];

  # Nix-darwin does not link installed applications to the user environment. This means apps will not show up
  # in spotlight, and when launched through the dock they come with a terminal window. This is a workaround.
  # Upstream issue: https://github.com/LnL7/nix-darwin/issues/214
  system.activationScripts.applications.text = mkForce ''
    echo "setting up /Applications/Nix Apps..." >&2

    ourLink () {
      local link
      link=$(readlink "$1")
      [ -L "$1" ] && [ "''${link#*-}" = 'system-applications/Applications' ]
    }

    ${optionalString (config.system.primaryUser != null) ''
      if ourLink ~${config.system.primaryUser}/Applications; then
        rm ~${config.system.primaryUser}/Applications
      elif ourLink ~${config.system.primaryUser}/Applications/'Nix Apps'; then
        rm ~${config.system.primaryUser}/Applications/'Nix Apps'
      fi
    ''}

    targetFolder='/Applications/Nix Apps'

    if [ -e "$targetFolder" ] && ourLink "$targetFolder"; then
      rm "$targetFolder"
    fi

    mkdir -p "$targetFolder"

    rsyncFlags=(
      --checksum
      --copy-unsafe-links
      --archive
      --delete
      --chmod=-w
      --no-group
      --no-owner
    )

    ${getExe pkgs.rsync} "''${rsyncFlags[@]}" ${config.system.build.applications}/Applications/ "$targetFolder"
  '';
}
