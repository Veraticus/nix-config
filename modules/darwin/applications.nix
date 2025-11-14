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

        firefoxApp="$targetFolder/Firefox.app"
        firefoxWrapper="$firefoxApp/Contents/MacOS/firefox"
        if [ -f "$firefoxWrapper" ]; then
          FIREFOX_WRAPPER="$firefoxWrapper" /usr/bin/python3 <<'PY'
    import os
    import pathlib
    import re

    path = pathlib.Path(os.environ["FIREFOX_WRAPPER"])
    text = path.read_text()
    pattern = r'exec "/nix/store/[^"]+/Applications/Firefox\.app/Contents/MacOS/.firefox-old"  "\$@"'
    replacement = 'firefox_dir="$(cd "$(dirname "$0")" && pwd)"\nexec "$firefox_dir/.firefox-old"  "$@"'
    new_text, subs = re.subn(pattern, replacement, text)
    if subs:
        path.write_text(new_text)
    PY
          chmod +x "$firefoxWrapper"
          /usr/bin/codesign --force --deep --sign - "$firefoxApp" 2>/dev/null || true
        fi

        ${optionalString (config.system.primaryUser != null) ''
      userHome=~${config.system.primaryUser}
      userApplications="$userHome/Applications"
      userLink="$userApplications/Nix Apps"

      if [ -d "$userHome" ]; then
        mkdir -p "$userApplications"
        chown ${config.system.primaryUser}: "$userApplications"
        rm -rf "$userLink"
        ln -sfn "$targetFolder" "$userLink"
        chown -h ${config.system.primaryUser}: "$userLink"
      fi
    ''}
  '';
}
