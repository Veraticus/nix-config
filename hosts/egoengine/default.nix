# Egoengine Docker container configuration
# Simplified entry point that builds Docker image using dockerTools
{
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: {
  # Import common NixOS configuration
  # This provides basic system settings but we don't use the full NixOS container build
  imports = [../common.nix];

  # Basic system configuration
  networking.hostName = "egoengine";
  system.stateVersion = "25.05";
  boot = {
    loader = {
      grub.enable = false;
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = false;
    };
  };

  fileSystems = lib.mkForce {
    "/" = {
      device = "nodev";
      fsType = "tmpfs";
    };
  };

  users.users.joshsymonds = lib.mkForce {
    isSystemUser = true;
    shell = pkgs.bash;
    group = "joshsymonds";
  };
  users.groups.joshsymonds = lib.mkForce {};

  # Enable experimental features for nix commands
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Build the Docker image using clean dockerTools approach
  # This replaces the old NixOS container build
  system.build.egoengineDockerImage = import ./docker-image.nix {
    inherit inputs outputs lib pkgs;
  };
}
