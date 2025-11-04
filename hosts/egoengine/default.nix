{ inputs
, outputs
, lib
, config
, pkgs
, ...
}:
let
  user = "joshsymonds";
  minimalLocales = pkgs.glibcLocales.override {
    locales = [
      "en_US.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  };
in
{
  imports = [
    ../common.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  boot.isContainer = true;

  networking.hostName = "egoengine";
  networking.useDHCP = true;
  networking.firewall.enable = lib.mkForce false;

  nixpkgs = {
    overlays = [
      inputs.neovim-nightly.overlays.default
      outputs.overlays.default
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config.allowUnfree = true;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    homeMode = "700";
    createHome = true;
    shell = pkgs.zsh;
    uid = 1000;
    group = user;
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  users.groups.${user}.gid = 1000;
  users.groups.docker = { members = [ user ]; };

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  environment.etc."passwd".text = ''
root:x:0:0::/root:/bin/sh
${user}:x:${toString config.users.users.${user}.uid}:${toString config.users.groups.${user}.gid}::${config.users.users.${user}.home}:${pkgs.zsh}/bin/zsh
'';

  environment.etc."group".text = ''
root:x:0:
${user}:x:${toString config.users.groups.${user}.gid}:${user}
docker:x:998:${user}
'';

  programs.zsh.enable = true;

  environment.shells = [ pkgs.zsh pkgs.bashInteractive ];
  environment.systemPackages = (with pkgs; [
    coreutils
    git
    docker-client
    gnutar
    gzip
    gnugrep
    codex
    claudeCodeCli
    neovim
    kubectl
    _1password-cli
  ]) ++ [ minimalLocales ];
  environment.variables = {
    EDITOR = "nvim";
    LOCALE_ARCHIVE = lib.mkForce "${minimalLocales}/lib/locale/locale-archive";
  };

  systemd.tmpfiles.rules = [
    "d /usr/bin 0755 root root - -"
    "L+ /usr/bin/env - - - - ${pkgs.coreutils}/bin/env"
    "L+ /usr/bin/zsh - - - - ${pkgs.zsh}/bin/zsh"
    "L+ /usr/bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /usr/bin/head - - - - ${pkgs.coreutils}/bin/head"
    "L+ /usr/bin/which - - - - ${pkgs.coreutils}/bin/which"
  ];

  services = {
    eternal-terminal.enable = lib.mkForce false;
    openssh.enable = false;
  };

  systemd.services.cleanup-stale-processes.enable = lib.mkForce false;
  systemd.timers.cleanup-stale-processes.enable = lib.mkForce false;

  system.build.egoenginePathOverlay = pkgs.runCommand "egoengine-path-overlay" { } ''
    set -euo pipefail
    mkdir -p $out/bin $out/usr/bin
    ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
    ln -s ${pkgs.coreutils}/bin/head $out/usr/bin/head
    ln -s ${pkgs.which}/bin/which $out/usr/bin/which
    ln -s ${config.users.users.${user}.shell}/bin/zsh $out/usr/bin/zsh
    ln -s ${pkgs.bashInteractive}/bin/bash $out/usr/bin/bash
    ln -s ${pkgs.gnutar}/bin/tar $out/usr/bin/tar
    ln -s ${pkgs.gzip}/bin/gzip $out/usr/bin/gzip
    ln -s ${pkgs.gnugrep}/bin/grep $out/usr/bin/grep
    ln -s ${pkgs._1password-cli}/bin/op $out/usr/bin/op

    ln -s ${pkgs.coreutils}/bin/env $out/bin/env
    ln -s ${pkgs.coreutils}/bin/head $out/bin/head
    ln -s ${pkgs.which}/bin/which $out/bin/which
    ln -s ${config.users.users.${user}.shell}/bin/zsh $out/bin/zsh
    ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
    ln -s ${pkgs.git}/bin/git $out/bin/git
    ln -s ${pkgs.docker-client}/bin/docker $out/bin/docker
    ln -s ${pkgs.kind}/bin/kind $out/bin/kind
    ln -s ${pkgs.codex}/bin/codex $out/bin/codex
    ln -s ${pkgs.claudeCodeCli}/bin/claude $out/bin/claude
    ln -s ${pkgs.neovim}/bin/nvim $out/bin/nvim
    ln -s ${pkgs.gnutar}/bin/tar $out/bin/tar
    ln -s ${pkgs.gzip}/bin/gzip $out/bin/gzip
    ln -s ${pkgs.gnugrep}/bin/grep $out/bin/grep
    ln -s ${pkgs._1password-cli}/bin/op $out/bin/op
  '';

  system.build.egoengineDockerImage =
    let
      homeDir = config.users.users.${user}.home;
      shellPath = config.users.users.${user}.shell;
      uid = config.users.users.${user}.uid;
      gid = config.users.groups.${user}.gid;
      localeArchive = config.environment.variables.LOCALE_ARCHIVE;
      nsswitchSource = lib.attrByPath [ "environment" "etc" "nsswitch.conf" "source" ] null config;
    in
    pkgs.dockerTools.buildImageWithNixDb {
      name = "egoengine";
      copyToRoot = [
        config.system.build.toplevel
        config.system.build.egoenginePathOverlay
      ];
      keepContentsDirlinks = true;
      runAsRoot = ''
        set -euo pipefail
        if [ -L /etc ]; then
          target="$(readlink -f /etc)"
          rm /etc
          mkdir -p /etc
          cp -a ${config.system.build.etc}/etc/. /etc/
        fi
        ${lib.optionalString (nsswitchSource != null) ''
          install -m 0644 ${nsswitchSource} /etc/nsswitch.conf
        ''}
        mkdir -p /home/${user} /workspace
        chmod 1777 /tmp
        chown ${toString uid}:${toString gid} /home/${user}
        chmod 700 /home/${user}
        chown ${toString uid}:${toString gid} /workspace
      '';
      config = {
        User = user;
        WorkingDir = homeDir;
        Cmd = [ "${shellPath}/bin/zsh" "-l" ];
        Env = [
          "USER=${user}"
          "HOME=${homeDir}"
          "LANG=en_US.UTF-8"
          "LC_ALL=en_US.UTF-8"
          "SHELL=${shellPath}/bin/zsh"
          "EDITOR=nvim"
          "NIX_CONFIG=experimental-features = nix-command flakes"
          "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/${user}"
          "NIX_PROFILES=/nix/var/nix/profiles/per-user/${user}/profile"
          "LOCALE_ARCHIVE=${localeArchive}"
          "PATH=/etc/profiles/per-user/${user}/bin:${pkgs.coreutils}/bin:${homeDir}/.nix-profile/bin:${homeDir}/.nix-profile/sbin:/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/bin"
        ];
        Labels = {
          "org.opencontainers.image.title" = "egoengine";
          "org.opencontainers.image.description" = "NixOS-based workspace image for egoengine";
        };
      };
    };

  fileSystems = lib.mkForce {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${user} = import ../../home-manager/common.nix;
    extraSpecialArgs = {
      inherit inputs outputs;
      hostname = "egoengine";
    };
    sharedModules = [ inputs.agenix.homeManagerModules.default ];
  };

  system.stateVersion = "25.05";
}
