{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
    imports = [
      inputs.hardware.nixosModules.common-pc
      ./hardware-configuration.nix
    ];

    # Performance tuning
    performance.profile = "workstation";
    performance.cpuVendor = "amd";

    # Host-specific: use all cores and add CUDA binary cache (common.nix provides defaults)
    nix.settings = {
      cores = 0;
      max-jobs = "auto";
      extra-substituters = [
        "https://cuda-maintainers.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };

    networking = {
      hostName = "stygianlibrary";
      useDHCP = false;
      networkmanager.enable = true;
      firewall = {
        enable = true;
        checkReversePath = "loose";
        trustedInterfaces = ["tailscale0"];
        allowedTCPPorts = [22 2022 8080 8188 8888 11434];
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

    # Deploy ComfyUI pre-start script (installs SageAttention, FlashAttention, etc.)
    system.activationScripts.comfyui-config = ''
      mkdir -p /var/lib/comfyui/storage/user-scripts
      cp ${./comfyui/pre-start.sh} /var/lib/comfyui/storage/user-scripts/pre-start.sh
      chmod +x /var/lib/comfyui/storage/user-scripts/pre-start.sh
    '';

    services = {
      xserver.videoDrivers = ["nvidia"];
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
      hardware.bolt.enable = true;
      caddy = {
        enable = true;
        virtualHosts.":8888".extraConfig = ''
          handle /output/* {
            root * /var/lib/comfyui
            file_server browse
          }
          handle {
            reverse_proxy localhost:8188
          }
        '';
      };
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
    '';

    systemd.services.open-webui.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "open-webui";
      Group = "open-webui";
    };

    programs.nm-applet.enable = true;

    users.users.joshsymonds.extraGroups = ["video" "render" "docker"];

    users.users.open-webui = {
      isSystemUser = true;
      group = "open-webui";
      home = "/var/lib/open-webui";
    };

    users.groups.open-webui = {};

    programs.nix-ld.enable = true;

    environment = {
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
