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
    initrd = {
      luks.devices.stygianlibrary = {
        device = "/dev/disk/by-partlabel/STYGIAN-LUKS";
        allowDiscards = true;
      };
      kernelModules = ["thunderbolt" "vmd" "xhci_pci"];
      preDeviceCommands = ''
        echo "Activating Thunderbolt..."
        
        # Wait for bus
        for i in $(seq 1 20); do
          [ -d /sys/bus/thunderbolt/devices ] && break
          sleep 0.5
        done

        # Try to authorize devices. Retry on failure.
        for dev in /sys/bus/thunderbolt/devices/*; do
          if [ -f "$dev/authorized" ]; then
            for attempt in $(seq 1 10); do
              current=$(cat "$dev/authorized" 2>/dev/null)
              if [ "$current" = "1" ]; then
                echo "$dev already authorized"
                break
              fi
              
              # Try to authorize
              if echo 1 > "$dev/authorized" 2>/dev/null; then
                echo "Successfully authorized $dev"
                break
              fi
              
              echo "Authorization failed for $dev (attempt $attempt)... retrying"
              sleep 1
            done
          fi
        done
        
        udevadm trigger
        udevadm settle
      '';
    };
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
        open = true;
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
      ollama = {
        enable = true;
        acceleration = "cuda";
        package = pkgs.ollama;
        host = "0.0.0.0";
        user = "ollama";
        group = "ollama";
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
      hardware.bolt.enable = true;
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';

    systemd.tmpfiles.rules = [
      "d /var/lib/private 0755 root root -"
    ];

    systemd.services.open-webui.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = "open-webui";
    };

    time.timeZone = "America/Los_Angeles";
    i18n.defaultLocale = "en_US.UTF-8";

    users.defaultUserShell = pkgs.zsh;
    programs.nm-applet.enable = true;

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
      ];
    };

    users.users.open-webui = {
      isSystemUser = true;
      group = "open-webui";
      home = "/var/lib/open-webui";
    };

    users.groups.open-webui = {};

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
        heretic
        hwdata
        nvtopPackages.full
        ollama
        python312
        python312Packages.pip
        python312Packages.huggingface-hub
        python312Packages.transformers
        tmux
        vulkan-tools
        cudaPackages.cudnn
      ];
    };

    system.stateVersion = "25.05";
  }
