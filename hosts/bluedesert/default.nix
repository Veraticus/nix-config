let
  system = "x86_64-linux";
  user = "joshsymonds";
in
{ inputs, outputs, lib, config, pkgs, ... }: {
  # You can import other NixOS modules here
  imports = [
    # Skip common.nix to avoid NFS mounts and other unnecessary configs
    ./home-automation.nix  # Z-Wave bridge, MQTT, and notifications

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  # Hardware setup (minimal for headless Z-Wave bridge)
  hardware = {
    cpu = {
      intel.updateMicrocode = true;
    };
    # No graphics drivers needed for headless operation
    graphics.enable = false;
    # Only enable specific firmware needed for this hardware
    enableAllFirmware = false;
    enableRedistributableFirmware = true;
  };


  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    optimise.automatic = true;
    
    # Aggressive garbage collection for limited storage
    gc = {
      automatic = true;
      dates = "daily";
      options = lib.mkForce "--delete-older-than 3d";  # Keep only 3 days of history
    };

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      
      # Optimize for slow disk and limited resources
      download-buffer-size = 268435456; # 256MB buffer to avoid "buffer full" warnings
      max-substitution-jobs = 4; # Parallel downloads
      cores = 2; # Limit build parallelism on weak CPU
    };
  };

  networking = {
    useDHCP = false;
    hostName = "bluedesert";
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ ];
      allowedUDPPorts = [ 51820 ];
      allowedTCPPorts = [ 22 80 443 8080 ];
    };
    defaultGateway = "172.31.0.1";
    nameservers = [ "172.31.0.1" ];
    interfaces.enp2s0.ipv4.addresses = [{
      address = "172.31.0.201";
      prefixLength = 24;
    }];
    interfaces.enp1s0.useDHCP = false;
  };

  boot = {
    kernelModules = [ "coretemp" "kvm-intel" ];
    supportedFilesystems = [ "ntfs" ];
    kernelParams = [ ];
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

  # Time and internationalization
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # Users and their homes
  users.defaultUserShell = pkgs.zsh;
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/home/${user}";
    isNormalUser = true;
    extraGroups = [ "wheel" config.users.groups.keys.name ];
  };


  # Security
  security = {
    rtkit.enable = true;
    sudo.extraRules = [
      {
        users = [ "${user}" ];
        commands = [
          {
            command = "ALL";
            options = [ "SETENV" "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  # Services
  services.thermald.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };
  programs.ssh.startAgent = true;

  programs.zsh.enable = true;

  services.rpcbind.enable = true;

  # Environment
  environment = {
    pathsToLink = [ "/share/zsh" ];

    systemPackages = with pkgs; [
      polkit
      pciutils
      hwdata
      cachix
      unar
    ];

    # SSH agent is now managed by systemd user service
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
