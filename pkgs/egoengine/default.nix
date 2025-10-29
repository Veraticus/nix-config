{ pkgs
, inputs
, lib ? pkgs.lib
, userName ? "joshsymonds"
, userUid ? 1000
, userGid ? 1000
, homeModule ? ../../home-manager/egoengine/base.nix
, hostname ? "egoengine"
}:

let
  hmPkgs = pkgs.extend (final: prev: {
    mcp-atlassian = prev.callPackage ../../pkgs/mcp-atlassian { };
    starlark-lsp = prev.callPackage ../../pkgs/starlark-lsp { };
    myCaddy = prev.callPackage ../../pkgs/caddy { };
    nuclei = prev.callPackage ../../pkgs/nuclei { };
    claudeCodeCli = prev.callPackage ../../pkgs/claude-code-cli { };
    deadcode = prev.callPackage ../../pkgs/deadcode { };
    golangciLintBin = prev.callPackage ../../pkgs/golangci-lint-bin { };
  });

  hmConfig = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = hmPkgs;
    modules = [ homeModule ];
    extraSpecialArgs = {
      inherit inputs hostname;
    };
  };

  activationPackage = hmConfig.activationPackage;
  homeDir = hmConfig.config.home.homeDirectory;
  homeDirRel = lib.removePrefix "/" homeDir;
  shellPackage =
    let
      maybePackage = lib.attrByPath [ "programs" "zsh" "package" ] null hmConfig.config;
    in
    if maybePackage == null then pkgs.zsh else maybePackage;
  shellPath = "${shellPackage}/bin/zsh";

  homeSkeleton = pkgs.runCommand "egoengine-home" {
    preferLocalBuild = true;
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.gawk
      pkgs.gnutar
      pkgs.gzip
      pkgs.bash
      pkgs.nix
      pkgs.python3
    ];
  } ''
    set -euo pipefail

    export USER=${userName}
    export XDG_RUNTIME_DIR=$TMPDIR/xdg
    export PATH=${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.bash}/bin:${pkgs.nix}/bin:${pkgs.python3}/bin

    umask 077
    mkdir -p "$XDG_RUNTIME_DIR"
    buildHome=$TMPDIR/home
    mkdir -p "$buildHome"
    export HOME="$buildHome"
    export NIX_STATE_DIR="$TMPDIR/nix-state"

    mkdir -p "$NIX_STATE_DIR/gcroots/per-user/${userName}"
    touch "$NIX_STATE_DIR/gcroots/per-user/${userName}/current-home"
    mkdir -p "$NIX_STATE_DIR/profiles/per-user/${userName}"

    install -m 755 ${activationPackage}/activate "$TMPDIR/activate"
    python3 - "$TMPDIR/activate" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
needle = "function checkHomeDirectory"
idx = text.find(needle)
if idx != -1:
    end = text.find("}\n", idx)
    if end != -1:
        end = end + 2
        text = text[:idx] + "checkHomeDirectory() { :; }\n" + text[end:]
text = text.replace("set -eu", "set -eux")
path.write_text(text)
PY
    chmod +x "$TMPDIR/activate"
    "$TMPDIR/activate" || true

    mkdir -p "$out/${homeDirRel}"
    cp -aT "$HOME" "$out/${homeDirRel}"
  '';

  nss = pkgs.dockerTools.fakeNss.override {
    extraPasswdLines = [
      "root:x:0:0::/root:/bin/sh"
      "${userName}:x:${toString userUid}:${toString userGid}:Coder User:${homeDir}:${shellPath}"
    ];
    extraGroupLines = [
      "root:x:0:"
      "${userName}:x:${toString userGid}:${userName}"
    ];
  };

  profileSnippet = pkgs.writeTextDir "etc/profile.d/zz-nix-profile.sh" ''
    if [ -d "$HOME/.nix-profile" ]; then
      export PATH="$HOME/.nix-profile/bin:$HOME/.nix-profile/sbin:$PATH"
      export MANPATH="$HOME/.nix-profile/share/man:$MANPATH"
    fi
  '';

  shells = pkgs.writeTextDir "etc/shells" ''
    ${shellPath}
    ${pkgs.bashInteractive}/bin/bash
    /bin/sh
  '';

  localeConf = pkgs.writeTextDir "etc/locale.conf" ''
    LANG=en_US.UTF-8
    LC_ALL=en_US.UTF-8
  '';

  envFiles = pkgs.buildEnv {
    name = "egoengine-env";
    paths = [
      profileSnippet
      shells
      localeConf
    ];
  };

  image = pkgs.dockerTools.buildLayeredImage {
    name = "egoengine-dev-base";
    maxLayers = 20;
    contents = [
      envFiles
      nss
    ];
    includeNixDB = false;
    extraCommands = ''
      mkdir -p ./home
      cp -a ${homeSkeleton}/${homeDirRel} ./home/
      mkdir -p ./workspace
      mkdir -p ./nix/var/nix/profiles/per-user/${userName}
      mkdir -p ./nix/var/nix/gcroots
    '';
    fakeRootCommands = ''
      chown -R ${toString userUid}:${toString userGid} ./home/${userName}
      chmod 755 ./home
      chmod 700 ./home/${userName}
      chown ${toString userUid}:${toString userGid} ./workspace
      chown -R ${toString userUid}:${toString userGid} ./nix/var/nix/profiles/per-user/${userName}
      chown -R ${toString userUid}:${toString userGid} ./nix/var/nix/gcroots
    '';
    config = {
      User = "${userName}";
      Env = [
        "USER=${userName}"
        "HOME=${homeDir}"
        "LANG=en_US.UTF-8"
        "LC_ALL=en_US.UTF-8"
        "SHELL=${shellPath}"
        "EDITOR=nvim"
        "NIX_CONFIG=experimental-features = nix-command flakes"
        "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/${userName}"
        "NIX_PROFILES=/nix/var/nix/profiles/per-user/${userName}/profile"
      ];
      WorkingDir = homeDir;
      Cmd = [ shellPath "-l" ];
      Labels = {
        "org.opencontainers.image.title" = "egoengine dev base";
        "org.opencontainers.image.description" = "Home Manager baked base image for Coder workspaces";
      };
    };
  };
in
{
  "egoengine-dev-base-oci" = image;
}
