let
  system = "x86_64-linux";
  user = "joshsymonds";
in
{ inputs, outputs, lib, config, pkgs, ... }: {
  # You can import other NixOS modules here
  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.agenix.nixosModules.default
    # inputs.agenix-rekey.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
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
    opengl = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
      ];
      driSupport = true;
      driSupport32Bit = true;
    };
    enableAllFirmware = true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      inputs.nixneovim.overlays.default
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
      auto-optimise-store = true;

      # Caches
      substituters = [
        "https://hyprland.cachix.org"
        "https://cache.nixos.org"
        "https://nixpkgs-wayland.cachix.org"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      ];
    };
  };

  networking = {
    hostName = "ultraviolet";
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ 51820 config.services.tailscale.port ];
      allowedTCPPorts = [ 22 80 443 ];
    };
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.1" ];
    interfaces.enp0s31f6.ipv4.addresses = [{
      address = "192.168.1.200";
      prefixLength = 24;
    }];
    interfaces.enp0s20f0u12.useDHCP = false;
  };

  boot = {
    kernelModules = [ "coretemp" "kvm-intel" ];
    supportedFilesystems = [ "ntfs" ];
    kernelParams = [ ];
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
    shell = pkgs.unstable.zsh;
    home = "/home/${user}";
    initialPassword = "correcthorsebatterystaple";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ4hwNjF4SMCeYcqm3tzUxZWadcv7ZLJbCa/mLHzsvw josh+cloudbank@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTWmaNJwRqzDMdfVOXbX6FNjcJ94VRK+aKLI2NqrcWV josh+morningstar@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0OvTKlW2Vk5WA11YOQ6SNDS4KsT9I1ffVGomswscZA josh+ultraviolet@joshsymonds.com"
    ];
    extraGroups = [ "wheel" config.users.groups.keys.name ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useUserPackages = true;
    useGlobalPkgs = true;
    users = {
      # Import your home-manager configuration
      ${user} = import ../../home-manager/headless-${system}.nix;
    };
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
    };
  };
  programs.ssh.startAgent = true;

  services.tailscale = {
    enable = true;
    package = pkgs.unstable.tailscale;
    useRoutingFeatures = "server";
  };

  programs.zsh.enable = true;

  services.jellyfin = {
    enable = true;
    package = pkgs.unstable.jellyfin;
  };

  services.sonarr = {
    enable = true;
    package = pkgs.unstable.sonarr;
  };

  services.radarr = {
    enable = true;
    package = pkgs.unstable.radarr;
  };

  services.readarr = {
    enable = true;
    package = pkgs.unstable.readarr;
  };

  services.prowlarr = {
    enable = true;
  };

  services.caddy = {
    acmeCA = null;
    enable = true;
    package = pkgs.myCaddy;
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
        reverse_proxy /* 192.168.1.201:9091
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
    text = ''
      - Social:
          - lib.lgbt:
              - icon: https://lib.lgbt/pictrs/image/cc8bb351-0cc5-4c89-8f7f-21649c286e98.webp
                href: https://lib.lgbt
    '';
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
              url: http://192.168.1.201:9091
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

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      flaresolverr = {
        image = "flaresolverr/flaresolverr:v3.3.13";
        ports = [
          "8191:8191"
        ];
        extraOptions = [ "--network=host" ];
      };
      jellyseerr = {
        image = "fallenbagel/jellyseerr:1.7.0";
        ports = [
          "5055:5055"
        ];
        extraOptions = [ "--network=host" ];
        volumes = [
          "/etc/jellyseerr/config:/app/config"
        ];
      };
      bazarr = {
        image = "linuxserver/bazarr:1.4.1";
        ports = [
          "6767:6767"
        ];
        extraOptions = [ "--network=host" ];
        volumes = [
          "/etc/bazarr/config:/config"
          "/mnt/video/:/mnt/video"
        ];
        environment = {
          PUID = "0";
          PGID = "0";
        };
      };
      homepage = {
        image = "ghcr.io/gethomepage/homepage:v0.8.8";
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
        };
        extraOptions = [ "--network=host" ];
      };
    };
  };

  services.rpcbind.enable = true;

  # Environment
  environment = {
    pathsToLink = [ "/share/zsh" ];

    systemPackages = with pkgs.unstable; [
      polkit
      pciutils
      hwdata
      cachix
      tailscale
      unar
    ];

    loginShellInit = ''
      eval $(ssh-agent)
    '';
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
