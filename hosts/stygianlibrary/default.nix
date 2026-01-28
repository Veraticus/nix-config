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
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://neovim-nightly.cachix.org"
          "https://joshsymonds.cachix.org"
          "https://cuda-maintainers.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "neovim-nightly.cachix.org-1:fLrV5fy41LFKwyLAxJ0H13o6FOVGc4k6gXB5Y1dqtWw="
          "joshsymonds.cachix.org-1:DajO7Bjk/Q8eQVZQZC/AWOzdUst2TGp8fHS/B1pua2c="
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        ];
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
        allowedTCPPorts = [22 2022 8080 8188 11434];
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

          # Poll for devices for up to 15 seconds
          for i in $(seq 1 15); do
            echo "Thunderbolt scan attempt $i..."

            # Check for the bus
            if [ -d /sys/bus/thunderbolt/devices ]; then
              # Authorize everything we see
              for dev in /sys/bus/thunderbolt/devices/*; do
                if [ -f "$dev/authorized" ]; then
                  current=$(cat "$dev/authorized" 2>/dev/null)
                  if [ "$current" != "1" ]; then
                    echo "Authorizing $dev..."
                    echo 1 > "$dev/authorized" 2>/dev/null || echo "Failed to authorize $dev"
                  fi
                fi
              done
            fi

            # Force udev to process events (critical for the next device in chain to appear)
            udevadm trigger --subsystem-match=thunderbolt
            udevadm settle --timeout=1

            sleep 1
          done

          # Final broad trigger
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
          libva-vdpau-driver
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

    hardware.nvidia-container-toolkit.enable = true;

    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker";
      containers.comfyui = {
        image = "yanwk/comfyui-boot:cu128-slim";
        ports = ["8188:8188"];
        volumes = [
          "/var/lib/comfyui/storage:/root"
          "/var/lib/comfyui/output:/root/ComfyUI/output"
        ];
        extraOptions = [
          "--device=nvidia.com/gpu=all"
        ];
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
        package = pkgs.ollama-cuda;
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
        "docker"
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
        hwdata
        nvtopPackages.full
        ollama
        python312
        python312Packages.pip
        tmux
        vulkan-tools
      ];
    };

    system.stateVersion = "25.05";
  }
