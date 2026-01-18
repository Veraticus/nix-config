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
    # You can import other NixOS modules here
    imports = [
      ../common.nix

      # You can also split up your configuration and import pieces of it here:
      # ./users.nix

      # SABnzbd with Mullvad VPN (migrated from bluedesert)
      ./sabnzbd-vpn.nix

      # Home Assistant for home automation
      ./home-assistant.nix

      # Wyoming Whisper STT service for Home Assistant voice
      ./wyoming-whisper.nix

      # Cloudflare Tunnel for secure external access
      ./cloudflare-tunnel.nix

      # Service-specific configuration
      ./services/caddy-base.nix
      ./services/homepage.nix
      ./services/jellyfin.nix
      ./services/radarr-sonarr.nix
      ./services/arr-extras.nix
      ./services/jellyseerr.nix
      ./services/bazarr.nix
      ./services/piped.nix
      ./services/redlib.nix
      ./services/redlib-mcp.nix
      ./services/download-proxies.nix
      ./services/flaresolverr.nix

      # Import your generated (nixos-generate-config) hardware configuration
      ./hardware-configuration.nix
    ];

    # Additional NFS mount for Home Assistant backups
    fileSystems."/mnt/backups" = {
      device = "172.31.0.100:/volume1/backup";
      fsType = "nfs";
      options = ["x-systemd.automount" "noauto" "x-systemd.idle-timeout=60"];
    };

    # Hardware setup
    hardware = {
      cpu = {
        intel.updateMicrocode = true;
      };
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-vaapi-driver
          vaapiVdpau
          intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
          vpl-gpu-rt # Modern Intel Media SDK replacement with QSV support
        ];
      };
      enableAllFirmware = true;
    };

    nix = {
      # This will add each flake input as a registry
      # To make nix3 commands consistent with your flake
      registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 3d";
      };
      settings = {
        # Enable flakes and new 'nix' command
        experimental-features = "nix-command flakes";
      };
    };

    networking = {
      useDHCP = false;
      hostName = "ultraviolet";
      firewall = {
        enable = true;
        checkReversePath = "loose";
        trustedInterfaces = [
          "tailscale0"
          "podman0"
        ];
        allowedUDPPorts = [
          51820
          config.services.tailscale.port
          5353 # mDNS/Bonjour for HomeKit discovery
        ];
        allowedTCPPorts = [
          22
          80
          443
          9437
          1400 # Sonos event callbacks (primary)
          10200 # Wyoming Piper TTS server
          8123 # Home Assistant (LAN access for TTS fetch by Sonos)
        ];
      };
      defaultGateway = "172.31.0.1";
      nameservers = ["172.31.0.1"];
      interfaces.enp0s31f6.ipv4.addresses = [
        {
          address = "172.31.0.200";
          prefixLength = 24;
        }
      ];
      interfaces.enp0s20f0u12.useDHCP = false;
    };

    boot = {
      kernelModules = [
        "coretemp"
        "kvm-intel"
        "i915"
      ];
      supportedFilesystems = [
        "ntfs"
        "nfs"
        "nfs4"
      ];
      kernelParams = [
        "intel_pstate=active"
        "i915.enable_fbc=1"
        "i915.enable_psr=2"
      ];
      kernelPackages = pkgs.linuxPackages_latest;
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
    users = {
      defaultUserShell = pkgs.zsh;
      users.${user} = {
        shell = pkgs.zsh;
        home = "/home/${user}";
        isNormalUser = true;
        extraGroups = [
          "wheel"
          config.users.groups.keys.name
          "podman"
        ];
      };
    };

    # Security
    security = {
      rtkit.enable = true;
      sudo.extraRules = [
        {
          users = ["${user}"];
          commands = [
            {
              command = "ALL";
              options = [
                "SETENV"
                "NOPASSWD"
              ];
            }
          ];
        }
      ];
    };

    # Services
    services = {
      thermald.enable = true;

      # Wyoming Piper TTS server for Home Assistant
      wyoming.piper.servers = {
        "amy" = {
          enable = true;
          voice = "en_US-amy-medium";
          uri = "tcp://0.0.0.0:10200";
        };
      };

      openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          # Enable X11 forwarding for GUI applications
          X11Forwarding = true;
          StreamLocalBindUnlink = true;
        };
      };

      tailscale = {
        enable = true;
        package = pkgs.tailscale;
        useRoutingFeatures = "server";
        openFirewall = true; # Open firewall for Tailscale
      };

      # Enable NFS client for better NAS performance
      nfs.server.enable = true;
      rpcbind.enable = true;

      postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        ensureDatabases = ["piped"];
        ensureUsers = [
          {
            name = "piped";
            ensureDBOwnership = true;
          }
        ];
        settings = {
          "listen_addresses" = lib.mkForce "*";
        };
        authentication = ''
          local   all             postgres                                peer
          local   piped           piped                                   trust
          host    piped           piped           127.0.0.1/32            trust
          host    piped           piped           ::1/128                 trust
          host    piped           piped           10.88.0.0/16            trust
          local   all             all                                     peer
          host    all             all             127.0.0.1/32            scram-sha-256
          host    all             all             ::1/128                 scram-sha-256
        '';
      };
    };

    programs.ssh.startAgent = true;
    programs.zsh.enable = true;

    # Configure Radarr with optimal quality settings after it starts
    systemd = {
      services = {
        remote-mounts = {
          description = "Check if remote mounts are available";
          after = [
            "network.target"
            "remote-fs.target"
          ];
          before = ["podman-bazarr.service"];
          wantedBy = [
            "multi-user.target"
            "podman-bazarr.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/test -d /mnt/video'";
          };
        };

        # Clean up Podman and Nix store regularly
        cleanup-podman-and-nix = {
          description = "Clean up Podman and Nix store";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "cleanup-podman-and-nix" ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail

              echo "=== Starting cleanup at $(date) ==="

              # Clean Podman
              if command -v podman &> /dev/null; then
                echo "Cleaning Podman system..."
                ${pkgs.podman}/bin/podman system prune -a --volumes -f || true
                echo "Podman cleanup completed"
              fi

              # Clean old Nix generations (keep last 5)
              echo "Cleaning old Nix generations..."
              ${pkgs.nix}/bin/nix-env --delete-generations +5 || true
              ${pkgs.nix}/bin/nix-collect-garbage || true

              # Clean Nix store of unreferenced packages
              echo "Running Nix garbage collection..."
              ${pkgs.nix}/bin/nix-store --gc || true

              echo "=== Cleanup completed at $(date) ==="
            '';
          };
        };
      };

      timers.cleanup-podman-and-nix = {
        description = "Run Podman and Nix cleanup every hour";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "1h";
          OnUnitActiveSec = "1h";
          Persistent = true;
        };
      };
    };

    age.secrets = {
      "cloudflare-api-token" = {
        file = ../../secrets/hosts/ultraviolet/cloudflare-api-token.age;
        owner = "caddy";
        group = "caddy";
        mode = "0400";
      };

      "cloudflared-token" = {
        file = ../../secrets/hosts/ultraviolet/cloudflared-token.age;
        owner = "cloudflared";
        group = "cloudflared";
        mode = "0400";
      };

      "redlib-collections" = {
        file = ../../secrets/hosts/ultraviolet/redlib-collections.age;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    # Podman for media containers
    virtualisation.podman = {
      enable = true;
      dockerCompat = false;
      defaultNetwork.settings.dns_enabled = true;
      # Enable cgroup v2 for better container resource management
      enableNvidia = false; # Set to true if you have NVIDIA GPU
      extraPackages = [
        pkgs.podman-compose
        pkgs.podman-tui
      ];
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers = {};
    };

    # Environment
    environment = {
      pathsToLink = ["/share/zsh"];

      systemPackages = with pkgs; [
        polkit
        pciutils
        hwdata
        cachix
        tailscale
        unar
        podman-tui
        jellyfin-ffmpeg
        chromium
        signal-cli
      ];

      # SSH agent is now managed by systemd user service
    };

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "25.05";
  }
