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
    ../../modules/services/egoengine-coder.nix
    ../../modules/services/cloudflare-tunnel.nix

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
        vpl-gpu-rt # QSV for all Intel GPU generations
      ];
    };
    enableAllFirmware = true;
  };


  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
    optimise.automatic = true;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store

      # Shared nix defaults provide cache settings
    };
  };

  networking = {
    useDHCP = false;
    hostName = "vermissian";
    extraHosts = ''
      172.31.0.200 ultraviolet
      172.31.0.201 bluedesert
      172.31.0.203 echelon
    '';
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
        7080
        9437
      ];
    };
    defaultGateway = "172.31.0.1";
    nameservers = [ "172.31.0.1" ];
    interfaces.enp0s31f6.ipv4.addresses = [
      {
        address = "172.31.0.202";
        prefixLength = 24;
      }
    ];
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
  users.defaultUserShell = pkgs.zsh;
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/home/${user}";
    isNormalUser = true;
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

  # Enable NFS client for better NAS performance
  services.nfs.server.enable = true;
  services.rpcbind.enable = true;

  systemd.services."agenix-import-ssh-${user}" = let
    homeDir = "/home/${user}";
    sshKey = "${homeDir}/.ssh/github";
    sshPubKey = "${sshKey}.pub";
    ageDir = "${homeDir}/.config/agenix";
    privateOut = "${ageDir}/keys.txt";
    publicOut = "${ageDir}/keys.pub";
    defaultSshKey = "${homeDir}/.ssh/id_ed25519";
    defaultSshPub = "${defaultSshKey}.pub";
  in {
    description = "Convert ${user}'s SSH key to an Age identity";
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      ConditionPathExists = [
        sshKey
        sshPubKey
      ];
      StartLimitIntervalSec = 0;
    };
    serviceConfig = {
      Type = "oneshot";
      User = user;
      UMask = "0077";
      ExecStart = pkgs.writeShellScript "agenix-import-ssh-${user}" ''
        set -euo pipefail

        key="${sshKey}"
        pub="${sshPubKey}"
        age_dir="${ageDir}"
        private_out="${privateOut}"
        public_out="${publicOut}"

        mkdir -p "$age_dir"

        tmp_private="$(${pkgs.coreutils}/bin/mktemp "$age_dir/keys.txt.XXXXXX")"
        ${pkgs.ssh-to-age}/bin/ssh-to-age --private-key < "$key" > "$tmp_private"
        mv "$tmp_private" "$private_out"
        chmod 600 "$private_out"

        ${pkgs.ssh-to-age}/bin/ssh-to-age < "$pub" > "$public_out"
        chmod 600 "$public_out"

        if [ ! -e "${defaultSshKey}" ]; then
          ln -sf "$key" "${defaultSshKey}"
          ln -sf "$pub" "${defaultSshPub}"
        fi

        echo "Age identity written to $private_out"
        echo "Age public key:"
        cat "$public_out"
      '';
    };
  };

  # Podman for containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = false; # Disable compat since we have real Docker
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
  };

  age.secrets."cloudflared-token" = {
    file = ../../secrets/hosts/vermissian/cloudflared-token.age;
    owner = "cloudflared";
    group = "cloudflared";
    mode = "0400";
  };

  age.secrets."coder-ghcr-cache-auth" = {
    file = ../../secrets/hosts/vermissian/coder-ghcr-cache-auth.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.cloudflareTunnel = {
    enable = true;
    tokenFile = config.age.secrets."cloudflared-token".path;
  };

  services.egoengine.coder = {
    enable = true;
    accessUrl = "https://coder.husbuddies.gay";
    internalUrl = "https://coder.husbuddies.gay";
    autoRegisterTemplates = false;
  };

  systemd.services."coder-ghcr-cache-config" = {
    description = "Install GHCR cache Docker config for Coder";
    after = [ "run-agenix.d.mount" ];
    before = [ "docker-coder.service" ];
    partOf = [ "docker-coder.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.age.secrets."coder-ghcr-cache-auth".path ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "install-ghcr-cache-config" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g root /var/lib/coder/ghcr-cache
        if ! read -r auth_line <${config.age.secrets."coder-ghcr-cache-auth".path}; then
          echo "Unable to read GHCR auth secret" >&2
          exit 1
        fi
        username="''${auth_line%%=*}"
        token="''${auth_line#*=}"
        if [ -z "$username" ] || [ -z "$token" ] || [ "$username" = "$auth_line" ]; then
          echo "Invalid GHCR auth secret format (expected username=token)" >&2
          exit 1
        fi
        auth=$(${pkgs.coreutils}/bin/printf '%s:%s' "$username" "$token" | ${pkgs.coreutils}/bin/base64 -w0)
        cat >/var/lib/coder/ghcr-cache/config.json <<EOF
{
  "auths": {
    "ghcr.io": {
      "auth": "$auth"
    }
  }
}
EOF
        chmod 600 /var/lib/coder/ghcr-cache/config.json
      '';
    };
  };

  systemd.services."docker-coder".after = lib.mkAfter [ "coder-ghcr-cache-config.service" ];
  systemd.services."docker-coder".requires = lib.mkAfter [ "coder-ghcr-cache-config.service" ];

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

  # Clean up old kind and ctlptl clusters
  systemd.services.cleanup-old-clusters = {
    description = "Clean up kind and ctlptl clusters older than configured timeout";
    after = [ "docker.service" ];
    path = [
      pkgs.kind
      pkgs.ctlptl
    ];
    environment = {
      # Configurable timeout in seconds (default: 1 hour)
      # Can be overridden for testing or different requirements
      CLUSTER_MAX_AGE_SECONDS = "3600"; # 1 hour for production
    };
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = "docker";
      ExecStart = pkgs.writeShellScript "cleanup-old-clusters" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        # Get timeout from environment or use default (1 hour)
        MAX_AGE_SECONDS=${"$"}{CLUSTER_MAX_AGE_SECONDS:-3600}
        echo "Using cluster max age: $MAX_AGE_SECONDS seconds"

        # Function to get cluster age in seconds
        get_cluster_age() {
          local cluster=$1
          local created_time=$(${pkgs.docker}/bin/docker inspect "$cluster-control-plane" 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0].Created // empty')
          
          if [ -z "$created_time" ]; then
            echo "0"
            return
          fi
          
          local created_epoch=$(${pkgs.coreutils}/bin/date -d "$created_time" +%s 2>/dev/null || echo "0")
          local current_epoch=$(${pkgs.coreutils}/bin/date +%s)
          echo $((current_epoch - created_epoch))
        }

        # Clean up kind clusters older than configured timeout
        if ${pkgs.kind}/bin/kind version &> /dev/null; then
          echo "Checking kind clusters..."
          for cluster in $(${pkgs.kind}/bin/kind get clusters 2>/dev/null); do
            age=$(get_cluster_age "$cluster")
            if [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
              echo "Deleting old kind cluster: $cluster (age: $((age/60)) minutes, max: $((MAX_AGE_SECONDS/60)) minutes)"
              ${pkgs.kind}/bin/kind delete cluster --name "$cluster" || true
            else
              echo "Keeping kind cluster: $cluster (age: $((age/60)) minutes, max: $((MAX_AGE_SECONDS/60)) minutes)"
            fi
          done
        else
          echo "Kind not available, skipping kind cluster cleanup"
        fi

        # Clean up ctlptl registries
        if ${pkgs.ctlptl}/bin/ctlptl version &> /dev/null; then
          echo "Checking ctlptl registries..."
          # Get all ctlptl registries and delete those associated with deleted clusters
          for registry in $(${pkgs.ctlptl}/bin/ctlptl get registries -o json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.items[].metadata.name // empty'); do
            # Check if registry starts with "kind-" (associated with a kind cluster)
            if [[ "$registry" == kind-* ]]; then
              cluster_name=${"$"}{registry#kind-}
              # Check if the associated cluster still exists
              if ! ${pkgs.kind}/bin/kind get clusters 2>/dev/null | grep -q "^$cluster_name$"; then
                echo "Removing orphaned ctlptl registry: $registry"
                ${pkgs.ctlptl}/bin/ctlptl delete registry "$registry" || true
              fi
            fi
          done
        else
          echo "Ctlptl not available, skipping registry cleanup"
        fi

        echo "Cluster cleanup completed"
      '';
    };
  };

  systemd.timers.cleanup-old-clusters = {
    description = "Run cluster cleanup every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1h";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  # Clean up Docker and Nix store regularly
  systemd.services.cleanup-docker-and-nix = {
    description = "Clean up Docker and Nix store";
    after = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "cleanup-docker-and-nix" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        echo "=== Starting cleanup at $(date) ==="

        # Clean Docker if it's running
        if systemctl is-active --quiet docker; then
          echo "Cleaning Docker system..."
          ${pkgs.docker}/bin/docker system prune -a --volumes -f || true
          echo "Docker cleanup completed"
        else
          echo "Docker is not running, skipping Docker cleanup"
        fi

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

  systemd.timers.cleanup-docker-and-nix = {
    description = "Run Docker and Nix cleanup every hour";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1h";
      OnUnitActiveSec = "1h";
      Persistent = true;
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
      chromium

      gcc
      gnumake
      grpcurl
      nodejs
      uv
      protobuf
      protoc-gen-go
      protoc-gen-go-grpc
      pkg-config
      openssl
      openssl.dev
    ];

    variables = {
      PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      OPENSSL_DIR = "${pkgs.openssl.out}";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    };

    # SSH agent is now managed by systemd user service
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
