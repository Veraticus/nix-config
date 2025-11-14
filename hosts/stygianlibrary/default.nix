let
  user = "joshsymonds";
in
  {
    inputs,
    lib,
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../common.nix
      ./disko.nix
      inputs.hardware.nixosModules.common-pc
      ./hardware-configuration.nix
    ];

    nix = {
      registry = lib.mapAttrs (_: value: {flake = value;}) inputs;
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 3d";
      };
      settings = {
        experimental-features = "nix-command flakes";
        cores = 0;
        max-jobs = "auto";
      };
    };

    networking = {
      hostName = "stygianlibrary";
      useDHCP = false;
      networkmanager.enable = true;
      firewall = {
        enable = true;
        checkReversePath = "loose";
        trustedInterfaces = ["tailscale0"];
        allowedTCPPorts = [22 2022 8080 11434];
        allowedUDPPorts = [config.services.tailscale.port];
      };
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

    hardware = {
      cpu = {
        intel.updateMicrocode = lib.mkDefault true;
        amd.updateMicrocode = lib.mkDefault true;
      };
      enableAllFirmware = true;
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          libvdpau-va-gl
          vaapiVdpau
        ];
      };
      nvidia = {
        open = false;
        nvidiaSettings = true;
        powerManagement.enable = lib.mkDefault true;
        package = config.boot.kernelPackages.nvidiaPackages.production;
        modesetting.enable = true;
      };
    };

    services = {
      xserver.videoDrivers = ["nvidia"];
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
      ollama = {
        enable = true;
        acceleration = "cuda";
        package = pkgs.ollama;
        environmentVariables = {
          OLLAMA_HOST = "0.0.0.0";
          OLLAMA_MODELS = "/persist/ollama";
        };
      };
      open-webui = {
        enable = true;
        host = "0.0.0.0";
        port = 8080;
        environment = {
          OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        };
      };
      thermald.enable = true;
      fstrim.enable = true;
    };

    systemd.tmpfiles.rules = [
      "d /persist 0755 root root -"
      "d /persist/ollama 0755 ${user} users -"
      "L /var/lib/ollama - - - - /persist/ollama"
    ];

    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";

    users.defaultUserShell = pkgs.zsh;
    users.users.${user} = {
      shell = pkgs.zsh;
      home = "/home/${user}";
      isNormalUser = true;
      createHome = true;
      extraGroups = [
        "wheel"
        config.users.groups.keys.name
        "video"
        "render"
        "docker"
      ];
    };

    security = {
      rtkit.enable = true;
      sudo.extraRules = [
        {
          users = [user];
          commands = [
            {
              command = "ALL";
              options = ["SETENV" "NOPASSWD"];
            }
          ];
        }
      ];
    };

    programs = {
      ssh.startAgent = true;
      zsh.enable = true;
      nix-ld.enable = true;
    };

    environment = {
      pathsToLink = ["/share/zsh"];
      systemPackages = with pkgs; [
        cachix
        git
        hwdata
        nvtopPackages.full
        ollama
        python312
        python312Packages.pip
        python312Packages.transformers
        tmux
        vulkan-tools
        cudaPackages.cudnn
      ];
    };

    system.stateVersion = "25.05";
  }
