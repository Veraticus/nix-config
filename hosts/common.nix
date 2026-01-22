{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [
    ../modules/nix/defaults.nix
    ../modules/services/age-identity.nix
    ../modules/services/cleanup-stale-processes.nix
  ];

  nix = {
    # Use latest Nix version available in nixpkgs
    package = pkgs.nixVersions.latest;

    settings = {
      # Trigger GC when disk space is low
      min-free = "${toString (10 * 1024 * 1024 * 1024)}"; # 10GB free space minimum
      max-free = "${toString (50 * 1024 * 1024 * 1024)}"; # Clean up to 50GB when triggered
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "daily"; # Run every night
      options = "--delete-older-than 3d"; # Keep derivations for 3 days
    };

    # Automatic store optimization (hard-linking identical files)
    optimise.automatic = true;
  };

  # Common packages for all headless Linux hosts
  environment.systemPackages = with pkgs; [
    yamllint # YAML linter, useful for Home Assistant configurations
    inputs.agenix.packages.${pkgs.system}.agenix
    ssh-to-age
  ];

  fileSystems = lib.mkIf (config.networking.hostName != "stygianlibrary") {
    "/mnt/video" = {
      device = "172.31.0.100:/volume1/video";
      fsType = "nfs";
    };
    "/mnt/music" = {
      device = "172.31.0.100:/volume1/music";
      fsType = "nfs";
    };
    "/mnt/books" = {
      device = "172.31.0.100:/volume1/books";
      fsType = "nfs";
    };
  };

  services.eternal-terminal = {
    enable = true;
    port = 2022;
  };

  services.openssh.settings.AcceptEnv = lib.mkBefore [ "TERM" "COLORTERM" "TERM_PROGRAM" "TERM_PROGRAM_VERSION" ];

  # Open firewall for ET
  networking.firewall.allowedTCPPorts = [2022];

  users.users.joshsymonds = {
    hashedPassword = lib.mkDefault "";
    group = "joshsymonds";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ4hwNjF4SMCeYcqm3tzUxZWadcv7ZLJbCa/mLHzsvw josh+cloudbank@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTWmaNJwRqzDMdfVOXbX6FNjcJ94VRK+aKLI2NqrcWV josh+morningstar@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0OvTKlW2Vk5WA11YOQ6SNDS4KsT9I1ffVGomswscZA josh+ultraviolet@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEhL0xP1eFVuYEPAvO6t+Mb9ragHnk4dxeBd/1Tmka41 josh+phone@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIORmNHlIFi2MWPh9H0olD2VBvPNK7+wJkA+A/3wCOtZN josh+vermissian@joshsymonds.com"
    ];
  };

  users.groups.joshsymonds = {};
}
