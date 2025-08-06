let
  system = "x86_64-linux";
  user = "joshsymonds";
in
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # You can import other NixOS modules here
  imports = [
    ../common.nix

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

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
        vpl-gpu-rt # QSV on 11th gen or newer
        intel-media-sdk # QSV up to 11th gen
      ];
    };
    enableAllFirmware = true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      };
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store

      # Caches
      substituters = [
        # "https://hyprland.cachix.org"
        "https://cache.nixos.org"
        # "https://nixpkgs-wayland.cachix.org"
      ];
      trusted-public-keys = [
        # "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        # "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      ];
    };
  };

  networking = {
    useDHCP = false;
    hostName = "ultraviolet";
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [
        51820
        config.services.tailscale.port
      ];
      allowedTCPPorts = [
        22
        80
        443
        9437
      ];
    };
    defaultGateway = "172.31.0.1";
    nameservers = [ "172.31.0.1" ];
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
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
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
    initialPassword = "correcthorsebatterystaple";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ4hwNjF4SMCeYcqm3tzUxZWadcv7ZLJbCa/mLHzsvw josh+cloudbank@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTWmaNJwRqzDMdfVOXbX6FNjcJ94VRK+aKLI2NqrcWV josh+morningstar@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0OvTKlW2Vk5WA11YOQ6SNDS4KsT9I1ffVGomswscZA josh+ultraviolet@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEhL0xP1eFVuYEPAvO6t+Mb9ragHnk4dxeBd/1Tmka41 josh+phone@joshsymonds.com"
    ];
    extraGroups = [
      "wheel"
      config.users.groups.keys.name
      "podman"
      "docker"
    ];
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
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
        ];
      }
    ];
  };

  # Directories
  systemd.tmpfiles.rules = [
    "d /etc/jellyseerr/config 0644 root root -"
    "d /etc/bazarr/config 0644 root root -"
  ];

  # Services
  services.thermald.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      # Enable X11 forwarding for GUI applications
      X11Forwarding = true;
      StreamLocalBindUnlink = true;
    };
  };
  programs.ssh.startAgent = true;

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
    useRoutingFeatures = "server";
    openFirewall = true; # Open firewall for Tailscale
  };

  programs.zsh.enable = true;

  services.jellyfin = {
    enable = true;
    package = pkgs.jellyfin;
    group = "users";
    openFirewall = true;
    user = "jellyfin";
  };

  # Enable NFS client for better NAS performance
  services.nfs.server.enable = true;
  services.rpcbind.enable = true;

  services.sonarr = {
    enable = true;
    package = pkgs.sonarr;
  };

  services.radarr = {
    enable = true;
    package = pkgs.radarr;
  };

  services.readarr = {
    enable = true;
    package = pkgs.readarr;
  };

  services.prowlarr = {
    enable = true;
  };

  services.caddy = {
    acmeCA = null;
    enable = true;
    package = pkgs.myCaddy.overrideAttrs (old: {
      meta = old.meta // {
        mainProgram = "caddy";
      };
    });
    globalConfig = ''
      storage file_system {
        root /var/lib/caddy
      }
    '';
    extraConfig = ''
      (cloudflare) {
        tls {
          dns cloudflare {env.CF_API_TOKEN}
          resolvers 1.1.1.1
        }
      }
    '';
    virtualHosts."home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:3000
        import cloudflare
      '';
    };
    virtualHosts."transmission.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* 172.31.0.201:9091
        import cloudflare
      '';
    };
    virtualHosts."sabnzbd.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* 172.31.0.201:8080
        import cloudflare
      '';
    };
    virtualHosts."jellyseerr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:5055
        import cloudflare
      '';
    };
    virtualHosts."jellyfin.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:8096
        import cloudflare
      '';
    };
    virtualHosts."radarr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:7878
        import cloudflare
      '';
    };
    virtualHosts."sonarr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:8989
        import cloudflare
      '';
    };
    virtualHosts."readarr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:8787
        import cloudflare
      '';
    };
    virtualHosts."prowlarr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:9696
        import cloudflare
      '';
    };
    virtualHosts."bazarr.home.husbuddies.gay" = {
      extraConfig = ''
        reverse_proxy /* localhost:6767
        import cloudflare
      '';
    };
  };

  environment.etc."homepage/config/settings.yaml" = {
    mode = "0644";
    text = ''
      providers:
        openweathermap: openweathermapapikey
        weatherapi: weatherapiapikey
    '';
  };
  environment.etc."homepage/config/bookmarks.yaml" = {
    mode = "0644";
    text = '''';
  };
  environment.etc."homepage/config/widgets.yaml" = {
    mode = "0644";
    text = ''
      - openmeteo:
          label: "Santa Barbara, CA"
          latitude: 34.4208
          longitude: 119.6982
          units: imperial
          cache: 5 # Time in minutes to cache API responses, to stay within limits
      - resources:
          cpu: true
          memory: true
          disk: /
      - datetime:
          format:
            dateStyle: long
            timeStyle: short
            hourCycle: h23
    '';
  };
  environment.etc."homepage/config/services.yaml" = {
    mode = "0644";
    text = ''
      - Media Management:
        - Jellyseerr:
            icon: jellyseerr.png
            href: https://jellyseerr.home.husbuddies.gay
            description: Media discovery
            widget:
              type: jellyseerr
              url: http://127.0.0.1:5055
              key: {{HOMEPAGE_FILE_JELLYSEERR_API_KEY}}
        - Sonarr:
            icon: sonarr.png
            href: https://sonarr.home.husbuddies.gay
            description: Series management
            widget:
              type: sonarr
              url: http://127.0.0.1:8989
              key: {{HOMEPAGE_FILE_SONARR_API_KEY}}
        - Radarr:
            icon: radarr.png
            href: https://radarr.home.husbuddies.gay
            description: Movie management
            widget:
              type: radarr
              url: http://127.0.0.1:7878
              key: {{HOMEPAGE_FILE_RADARR_API_KEY}}
        - Readarr:
            icon: readarr.png
            href: https://readarr.home.husbuddies.gay
            description: Book management
            widget:
              type: readarr
              url: http://127.0.0.1:8787
              key: {{HOMEPAGE_FILE_READARR_API_KEY}}
        - Bazarr:
            icon: bazarr.png
            href: https://bazarr.home.husbuddies.gay
            description: Subtitle Management
            widget:
              type: bazarr
              url: http://127.0.0.1:6767
              key: {{HOMEPAGE_FILE_BAZARR_API_KEY}}
      - Media:
        - Jellyfin:
            icon: jellyfin.png
            href: https://jellyfin.home.husbuddies.gay
            description: Movie management
            widget:
              type: jellyfin
              url: http://127.0.0.1:8096
              key: {{HOMEPAGE_FILE_JELLYFIN_API_KEY}}
        - Transmission:
            icon: transmission.png
            href: https://transmission.home.husbuddies.gay
            description: Torrent management
            widget:
              type: transmission
              url: http://172.31.0.201:9091
        - SABnzbd:
            icon: sabnzbd.png
            href: https://sabnzbd.home.husbuddies.gay
            description: Usenet client
            widget:
              type: sabnzbd
              url: http://172.31.0.201:8080
              key: {{HOMEPAGE_FILE_SABNZBD_API_KEY}}
      - Network:
        - NextDNS:
            icon: nextdns.png
            href: https://my.nextdns.io
            description: DNS Resolution
            widget:
              type: nextdns
              profile: 381116
              key: {{HOMEPAGE_FILE_NEXTDNS_API_KEY}}
    '';
  };

  # Podman for existing media containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;  # Disable compat since we have real Docker
    defaultNetwork.settings.dns_enabled = true;
    # Enable cgroup v2 for better container resource management
    enableNvidia = false; # Set to true if you have NVIDIA GPU
    extraPackages = [
      pkgs.podman-compose
      pkgs.podman-tui
    ];
  };
  
  # Docker for development tools (Kind, ctlptl, etc)
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    # Use a separate storage driver to avoid conflicts
    storageDriver = "overlay2";
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      flaresolverr = {
        image = "flaresolverr/flaresolverr:v3.3.18";
        ports = [
          "8191:8191"
        ];
        extraOptions = [ "--network=host" ];
      };
      jellyseerr = {
        image = "fallenbagel/jellyseerr:2.5.2";
        ports = [
          "5055:5055"
        ];
        extraOptions = [
          "--network=host"
          "--cpu-shares=512"
          "--memory=2g"
          "--security-opt=no-new-privileges"
        ];
        volumes = [
          "/etc/jellyseerr/config:/app/config"
        ];
      };
      bazarr = {
        image = "linuxserver/bazarr:1.5.1";
        ports = [
          "6767:6767"
        ];
        volumes = [
          "/etc/bazarr/config:/config"
          "/mnt/video/:/mnt/video"
        ];
        environment = {
          PUID = "0";
          PGID = "0";
        };
        autoStart = true;
        extraOptions = [
          "--network=host"
        ];
      };
      homepage = {
        image = "ghcr.io/gethomepage/homepage:v0.10.9";
        ports = [
          "3000:3000"
        ];
        volumes = [
          "/etc/homepage/config:/app/config"
          "/etc/homepage/keys:/app/keys"
        ];
        environment = {
          HOMEPAGE_FILE_SONARR_API_KEY = "/app/keys/sonarr-api-key";
          HOMEPAGE_FILE_BAZARR_API_KEY = "/app/keys/bazarr-api-key";
          HOMEPAGE_FILE_RADARR_API_KEY = "/app/keys/radarr-api-key";
          HOMEPAGE_FILE_READARR_API_KEY = "/app/keys/readarr-api-key";
          HOMEPAGE_FILE_JELLYFIN_API_KEY = "/app/keys/jellyfin-api-key";
          HOMEPAGE_FILE_NEXTDNS_API_KEY = "/app/keys/nextdns-api-key";
          HOMEPAGE_FILE_JELLYSEERR_API_KEY = "/app/keys/jellyseerr-api-key";
          HOMEPAGE_FILE_SABNZBD_API_KEY = "/app/keys/sabnzbd-api-key";
        };
        extraOptions = [ "--network=host" ];
      };
    };
  };

  # Remote mounts check service
  systemd.services.remote-mounts = {
    description = "Check if remote mounts are available";
    after = [
      "network.target"
      "remote-fs.target"
    ];
    before = [ "podman-bazarr.service" ];
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

  # Environment
  environment = {
    pathsToLink = [ "/share/zsh" ];

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
