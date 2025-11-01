let
  user = "joshsymonds";
in
{ inputs
, outputs
, lib
, config
, pkgs
, ...
}:
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
  environment.systemPackages = with pkgs; [
    coreutils
    git
    docker
    kind
    codex
    claudeCodeCli
    neovim
    glibcLocales
  ];
  environment.variables = {
    EDITOR = "nvim";
    LOCALE_ARCHIVE = lib.mkForce "${pkgs.glibcLocales}/lib/locale/locale-archive";
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
