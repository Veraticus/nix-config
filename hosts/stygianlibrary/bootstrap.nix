{
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: let
  repoDir = "/persist/nix-config";
in {
  imports = [
    ../../modules/nix/defaults.nix
    ../../modules/services/age-identity.nix
    ../../modules/services/cleanup-stale-processes.nix
    ./disko.nix
    inputs.hardware.nixosModules.common-pc
    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "stygianlibrary";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [22];
  };

  boot = {
    supportedFilesystems = ["ntfs" "vfat"];
    kernelModules = ["coretemp" "kvm-intel"];
    kernelParams = ["kernel.unprivileged_userns_clone=1"];
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 8;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  hardware.enableAllFirmware = true;

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };

    tailscale = {
      enable = true;
      package = pkgs.tailscale;
      useRoutingFeatures = "client";
      openFirewall = true;
    };
  };

  environment.systemPackages = [pkgs.git];

  users.users.joshsymonds = {
    isNormalUser = true;
    createHome = true;
    extraGroups = ["wheel"];
    shell = pkgs.zsh;
    initialPassword = lib.mkDefault "bootstrap";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ4hwNjF4SMCeYcqm3tzUxZWadcv7ZLJbCa/mLHzsvw josh+cloudbank@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTWmaNJwRqzDMdfVOXbX6FNjcJ94VRK+aKLI2NqrcWV josh+morningstar@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0OvTKlW2Vk5WA11YOQ6SNDS4KsT9I1ffVGomswscZA josh+ultraviolet@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEhL0xP1eFVuYEPAvO6t+Mb9ragHnk4dxeBd/1Tmka41 josh+phone@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIORmNHlIFi2MWPh9H0olD2VBvPNK7+wJkA+A/3wCOtZN josh+vermissian@joshsymonds.com"
    ];
  };

  users.groups.joshsymonds = {};

  programs.zsh.enable = true;

  systemd.tmpfiles.rules = ["d /persist 0755 root root -"];

  systemd.services.stygian-bootstrap-rebuild = {
    description = "Clone nix-config and rebuild stygianlibrary";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = 30;
    };
    script = ''
      set -euo pipefail
      trap 'rm -f /run/bootstrap-git-askpass' EXIT

      repoDir=${lib.escapeShellArg repoDir}
      mkdir -p /persist

       tokenFile=/persist/github-token
       if [ -f "$tokenFile" ]; then
         chmod 600 "$tokenFile"
         cat > /run/bootstrap-git-askpass <<'EOF'
#!/usr/bin/env bash
TOKEN="$(cat /persist/github-token)"
case "$1" in
  *Username*) echo "oauth2" ;;
  *Password*) echo "$TOKEN" ;;
  *) echo "" ;;
esac
EOF
         chmod 700 /run/bootstrap-git-askpass
         export GIT_ASKPASS=/run/bootstrap-git-askpass
         export GIT_TERMINAL_PROMPT=0
       fi

      repoUrl="https://github.com/Veraticus/nix-config"
      if [ -d "$repoDir/.git" ]; then
        cd "$repoDir"
        ${pkgs.git}/bin/git fetch origin
        ${pkgs.git}/bin/git reset --hard origin/main
      else
        rm -rf "$repoDir"
        ${pkgs.git}/bin/git clone "$repoUrl" "$repoDir"
      fi
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "$repoDir#stygianlibrary"
    '';
  };

  system.stateVersion = "25.05";
}
