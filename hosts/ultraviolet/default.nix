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
    
    # SABnzbd with Mullvad VPN (migrated from bluedesert)
    ./sabnzbd-vpn.nix
    
    # Home Assistant for home automation
    ./home-assistant.nix
    
    # Wyoming Whisper STT service for Home Assistant voice
    ./wyoming-whisper.nix

    # Cloudflare Tunnel for secure external access
    ./cloudflare-tunnel.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  # Additional NFS mount for Home Assistant backups
  fileSystems."/mnt/backups" = {
    device = "172.31.0.100:/volume1/backup";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.idle-timeout=60" ];
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

  nixpkgs = {
    # You can add overlays here
    overlays = [
      outputs.overlays.default
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

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };
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
        5353  # mDNS/Bonjour for HomeKit discovery
      ];
      allowedTCPPorts = [
        22
        80
        443
        9437
        1400  # Sonos event callbacks (primary)
        10200 # Wyoming Piper TTS server
        8123  # Home Assistant (LAN access for TTS fetch by Sonos)
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
    initialPassword = "correcthorsebatterystaple";
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQ4hwNjF4SMCeYcqm3tzUxZWadcv7ZLJbCa/mLHzsvw josh+cloudbank@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTWmaNJwRqzDMdfVOXbX6FNjcJ94VRK+aKLI2NqrcWV josh+morningstar@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0OvTKlW2Vk5WA11YOQ6SNDS4KsT9I1ffVGomswscZA josh+ultraviolet@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEhL0xP1eFVuYEPAvO6t+Mb9ragHnk4dxeBd/1Tmka41 josh+phone@joshsymonds.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIORmNHlIFi2MWPh9H0olD2VBvPNK7+wJkA+A/3wCOtZN josh+vermissian@joshsymonds.com"
    ];
    extraGroups = [
      "wheel"
      config.users.groups.keys.name
      "podman"
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
  
  # Wyoming Piper TTS server for Home Assistant
  services.wyoming.piper.servers = {
    "amy" = {
      enable = true;
      voice = "en_US-amy-medium";
      uri = "tcp://0.0.0.0:10200";
    };
  };

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
  
  # Add jellyfin user to video and render groups for GPU hardware acceleration
  users.users.jellyfin.extraGroups = [ "video" "render" ];
  
  # Configure Jellyfin user policies to disable transcoding for direct play
  systemd.services.jellyfin-user-policy = {
    description = "Configure Jellyfin user policies for direct play";
    after = [ "jellyfin.service" ];
    wants = [ "jellyfin.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'sleep 30'"; # Wait for Jellyfin to fully start
      ExecStart = let
        configureScript = pkgs.writeScriptBin "configure-jellyfin-users" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          
          echo "Configuring Jellyfin user policies for direct play..."
          
          # Wait for Jellyfin API to be ready
          until ${pkgs.curl}/bin/curl -s http://localhost:8096/System/Info >/dev/null 2>&1; do
            echo "Waiting for Jellyfin API..."
            sleep 5
          done
          
          # Check if API key file exists
          if [ ! -f /etc/homepage/keys/jellyfin-api-key ]; then
            echo "⚠ Jellyfin API key file not found at /etc/homepage/keys/jellyfin-api-key"
            echo "  Skipping user policy configuration - will retry on next boot"
            exit 0
          fi
          
          # Get API key from secure location
          API_KEY=$(cat /etc/homepage/keys/jellyfin-api-key | tr -d '\n')
          
          if [ -z "$API_KEY" ]; then
            echo "⚠ Jellyfin API key is empty"
            echo "  Skipping user policy configuration - will retry on next boot"
            exit 0
          fi
          
          # Function to update user policy
          update_user_policy() {
            local username="$1"
            
            # Get user ID
            USER_ID=$(${pkgs.curl}/bin/curl -s "http://localhost:8096/Users" \
              -H "X-Emby-Token: $API_KEY" 2>/dev/null | \
              ${pkgs.jq}/bin/jq -r --arg name "$username" '.[] | select(.Name == $name) | .Id' 2>/dev/null)
            
            if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
              echo "Updating policy for user: $username (ID: $USER_ID)"
              
              # Disable video transcoding to force direct play
              ${pkgs.curl}/bin/curl -X POST "http://localhost:8096/Users/$USER_ID/Policy" \
                -H "X-Emby-Token: $API_KEY" \
                -H "Content-Type: application/json" \
                -d '{
                  "EnableVideoPlaybackTranscoding": false,
                  "EnablePlaybackRemuxing": false
                }' >/dev/null 2>&1
              
              echo "  ✓ Disabled transcoding for $username"
            else
              echo "  ⚠ User $username not found (may not be created yet)"
            fi
          }
          
          # Get all users and check if we have any
          ALL_USERS=$(${pkgs.curl}/bin/curl -s "http://localhost:8096/Users" \
            -H "X-Emby-Token: $API_KEY" 2>/dev/null | \
            ${pkgs.jq}/bin/jq -r '.[].Name' 2>/dev/null)
          
          if [ -z "$ALL_USERS" ]; then
            echo "ℹ No users found in Jellyfin yet"
            echo "  This is normal for a fresh installation"
            echo "  User policies will be configured when users are created"
            exit 0
          fi
          
          echo "Found users: $(echo $ALL_USERS | tr '\n' ', ')"
          
          # Update policies for known users if they exist
          update_user_policy "jellyfin"
          update_user_policy "josh"
          
          # Also update any other users to use the same policy
          echo "$ALL_USERS" | while read -r username; do
            if [ "$username" != "jellyfin" ] && [ "$username" != "josh" ] && [ -n "$username" ]; then
              echo "Found additional user: $username"
              update_user_policy "$username"
            fi
          done
          
          echo "Jellyfin user policy configuration complete"
        '';
      in "${configureScript}/bin/configure-jellyfin-users";
      StandardOutput = "journal";
      StandardError = "journal";
      User = "root";
    };
    
    startLimitIntervalSec = 60;
    startLimitBurst = 3;
  };

  # Jellyfin encoding configuration for better performance with large files
  systemd.services.jellyfin.preStart = ''
    mkdir -p /var/lib/jellyfin/config
    cat > /var/lib/jellyfin/config/encoding.xml <<'EOF'
    <?xml version="1.0" encoding="utf-8"?>
    <EncodingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <EncodingThreadCount>-1</EncodingThreadCount>
      <TranscodingTempPath>/var/cache/jellyfin/transcodes</TranscodingTempPath>
      <FallbackFontPath />
      <EnableFallbackFont>false</EnableFallbackFont>
      <EnableAudioVbr>false</EnableAudioVbr>
      <DownMixAudioBoost>2</DownMixAudioBoost>
      <DownMixStereoAlgorithm>None</DownMixStereoAlgorithm>
      <MaxMuxingQueueSize>2048</MaxMuxingQueueSize>
      <EnableThrottling>false</EnableThrottling>
      <ThrottleDelaySeconds>180</ThrottleDelaySeconds>
      <EnableSegmentDeletion>true</EnableSegmentDeletion>
      <SegmentKeepSeconds>720</SegmentKeepSeconds>
      <HardwareAccelerationType>vaapi</HardwareAccelerationType>
      <EncoderAppPathDisplay>/nix/store/fvr78yr36anl4h054ph6nz3jpsdm7ank-jellyfin-ffmpeg-7.1.1-6-bin/bin/ffmpeg</EncoderAppPathDisplay>
      <VaapiDevice>/dev/dri/renderD128</VaapiDevice>
      <QsvDevice />
      <EnableTonemapping>false</EnableTonemapping>
      <EnableVppTonemapping>false</EnableVppTonemapping>
      <EnableVideoToolboxTonemapping>false</EnableVideoToolboxTonemapping>
      <TonemappingAlgorithm>bt2390</TonemappingAlgorithm>
      <TonemappingMode>auto</TonemappingMode>
      <TonemappingRange>auto</TonemappingRange>
      <TonemappingDesat>0</TonemappingDesat>
      <TonemappingPeak>100</TonemappingPeak>
      <TonemappingParam>0</TonemappingParam>
      <VppTonemappingBrightness>16</VppTonemappingBrightness>
      <VppTonemappingContrast>1</VppTonemappingContrast>
      <H264Crf>23</H264Crf>
      <H265Crf>28</H265Crf>
      <EncoderPreset>auto</EncoderPreset>
      <DeinterlaceDoubleRate>false</DeinterlaceDoubleRate>
      <DeinterlaceMethod>yadif</DeinterlaceMethod>
      <EnableDecodingColorDepth10Hevc>true</EnableDecodingColorDepth10Hevc>
      <EnableDecodingColorDepth10Vp9>true</EnableDecodingColorDepth10Vp9>
      <EnableDecodingColorDepth10HevcRext>true</EnableDecodingColorDepth10HevcRext>
      <EnableDecodingColorDepth12HevcRext>false</EnableDecodingColorDepth12HevcRext>
      <EnableEnhancedNvdecDecoder>true</EnableEnhancedNvdecDecoder>
      <PreferSystemNativeHwDecoder>true</PreferSystemNativeHwDecoder>
      <EnableIntelLowPowerH264HwEncoder>false</EnableIntelLowPowerH264HwEncoder>
      <EnableIntelLowPowerHevcHwEncoder>false</EnableIntelLowPowerHevcHwEncoder>
      <EnableHardwareEncoding>true</EnableHardwareEncoding>
      <AllowHevcEncoding>true</AllowHevcEncoding>
      <AllowAv1Encoding>false</AllowAv1Encoding>
      <EnableSubtitleExtraction>true</EnableSubtitleExtraction>
      <HardwareDecodingCodecs>
        <string>h264</string>
        <string>hevc</string>
        <string>mpeg2video</string>
        <string>mpeg4</string>
        <string>vc1</string>
        <string>vp8</string>
        <string>vp9</string>
      </HardwareDecodingCodecs>
      <AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
        <string>mkv</string>
      </AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
    </EncodingOptions>
    EOF
  '';

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
  
  # Configure Radarr with optimal quality settings after it starts
  systemd.services.radarr-configure = {
    description = "Configure Radarr quality profiles for optimal HEVC 4K streaming";
    after = [ "radarr.service" ];
    wants = [ "radarr.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Wait for Radarr to be fully ready
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -s http://localhost:7878/api/v3/system/status -H \"X-Api-Key: $(${pkgs.sudo}/bin/sudo cat /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP \"(?<=<ApiKey>)[^<]+\" || echo waiting)\" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q version; do echo \"Waiting for Radarr...\"; sleep 5; done'";
      ExecStart = let
        configureScript = pkgs.writeScriptBin "configure-arr-optimal" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          # Configure Radarr and Sonarr for optimal quality on ultraviolet
          # Optimized for Intel i5-10500TE with UHD 630 (supports 4K HEVC hardware decode)

          # Get API keys from filesystem
          RADARR_API_KEY=$(${pkgs.sudo}/bin/sudo cat /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
          RADARR_URL="http://localhost:7878"

          SONARR_API_KEY=$(${pkgs.sudo}/bin/sudo cat /var/lib/sonarr/.config/NzbDrone/config.xml 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
          SONARR_URL="http://localhost:8989"

          if [ -z "$RADARR_API_KEY" ]; then
              echo "⚠ Could not find Radarr API key in /var/lib/radarr/.config/Radarr/config.xml"
              echo "  This is normal on fresh installations - Radarr needs to start first"
              echo "  Configuration will be applied on next boot after Radarr generates its config"
              
              # Still try to configure Sonarr if it's available
              if [ -n "$SONARR_API_KEY" ]; then
                  echo "  Found Sonarr API key, will configure Sonarr only"
              else
                  echo "  No Sonarr API key found either - exiting"
                  exit 0
              fi
          fi

          # Only configure Radarr if we have an API key
          if [ -n "$RADARR_API_KEY" ]; then
              echo "=== Configuring Radarr for optimal quality ==="
              echo "Target: 4K HEVC when available, 1080p HEVC fallback"
              echo ""

              # Clean up duplicate custom formats first
              cleanup_duplicate_formats() {
              echo "Cleaning up duplicate custom formats..."
              
              # Get all custom formats
              formats=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY")
              
              # Delete old duplicates (keep the newer ones with better names)
              # Delete "x264" if "x264/H.264" exists
              x264_old_id=$(echo "$formats" | ${pkgs.jq}/bin/jq '.[] | select(.name == "x264") | .id')
              x264_new_id=$(echo "$formats" | ${pkgs.jq}/bin/jq '.[] | select(.name == "x264/H.264") | .id')
              
              if [ -n "$x264_old_id" ] && [ -n "$x264_new_id" ] && [ "$x264_old_id" != "null" ] && [ "$x264_new_id" != "null" ]; then
                  echo "  Removing duplicate: x264 (keeping x264/H.264)"
                  ${pkgs.curl}/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$x264_old_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
              fi
              
              # Delete "Large File Size" as we're using bitrate limits instead
              large_id=$(echo "$formats" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Large File Size") | .id')
              if [ -n "$large_id" ] && [ "$large_id" != "null" ]; then
                  echo "  Removing obsolete: Large File Size (using bitrate limits instead)"
                  ${pkgs.curl}/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$large_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
              fi
              
              echo "  Cleanup complete"
          }

          # Function to create or update custom format
          create_or_update_format() {
              local name="$1"
              local spec_json="$2"
              
              # Check if format exists
              existing_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq --arg name "$name" '.[] | select(.name == $name) | .id')
              
              if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
                  echo "  Updating existing format: $name (ID: $existing_id)"
                  ${pkgs.curl}/bin/curl -X PUT "$RADARR_URL/api/v3/customformat/$existing_id" \
                      -H "X-Api-Key: $RADARR_API_KEY" \
                      -H "Content-Type: application/json" \
                      -d "$spec_json" > /dev/null 2>&1
              else
                  echo "  Creating new format: $name"
                  ${pkgs.curl}/bin/curl -X POST "$RADARR_URL/api/v3/customformat" \
                      -H "X-Api-Key: $RADARR_API_KEY" \
                      -H "Content-Type: application/json" \
                      -d "$spec_json" > /dev/null 2>&1
              fi
          }

          # Clean up duplicates first
          cleanup_duplicate_formats

          # Create custom formats
          echo "Creating/updating custom formats..."

          # HEVC/x265 format (strongly preferred for 4K)
          create_or_update_format "x265/HEVC" '{
              "name": "x265/HEVC",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "x265/HEVC",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(x265|h265|hevc)\\b"
                          }
                      ]
                  }
              ]
          }'

          # Bad release groups to avoid
          create_or_update_format "Bad Release Groups" '{
              "name": "Bad Release Groups",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "Bad Release Groups",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(YIFY|YTS|RARBG.*REENC|TERRiBLE|LiGaS|BRrip|CHD|RM|mSD|HDTime|SiC)\\b"
                          }
                      ]
                  }
              ]
          }'

          # Trusted HEVC encoders
          create_or_update_format "Trusted HEVC Groups" '{
              "name": "Trusted HEVC Groups",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "Trusted HEVC Groups",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(QxR|UTR|TOMMY|FLUX|NTb|CtrlHD|TERMINAL|TIGERS|HONE|MONOLITH|PSA|MZABI|TAoE|SEV|CMRG)\\b"
                          }
                      ]
                  }
              ]
          }'

          # Re-encoded content warning
          create_or_update_format "Re-Encoded" '{
              "name": "Re-Encoded",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "Re-Encoded",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(REENC|ReEnc|Re-Enc|Reencoded)\\b"
                          }
                      ]
                  }
              ]
          }'

          # x264 format (okay for 1080p, bad for 4K)
          create_or_update_format "x264/H.264" '{
              "name": "x264/H.264",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "x264/H.264",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(x264|h264|avc)\\b"
                          }
                      ]
                  }
              ]
          }'

          # 4K resolution format (bonus points when HEVC)
          create_or_update_format "4K/2160p" '{
              "name": "4K/2160p",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "4K Resolution",
                      "implementation": "ResolutionSpecification",
                      "implementationName": "Resolution",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": 2160
                          }
                      ]
                  }
              ]
          }'

          # Remove the old absolute size format if it exists
          echo "  Removing old Excessive Size format (replacing with bitrate-based)..."
          old_excessive_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Excessive Size") | .id')
          if [ -n "$old_excessive_id" ] && [ "$old_excessive_id" != "null" ]; then
              ${pkgs.curl}/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$old_excessive_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
          fi

          # Remux format (these are unnecessarily large)
          create_or_update_format "Remux" '{
              "name": "Remux",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "Remux",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(remux)\\b"
                          }
                      ]
                  }
              ]
          }'

          # Foreign Film format
          create_or_update_format "Foreign Film" '{
              "name": "Foreign Film",
              "includeCustomFormatWhenRenaming": false,
              "specifications": [
                  {
                      "name": "Foreign Indicators",
                      "implementation": "ReleaseTitleSpecification",
                      "implementationName": "Release Title",
                      "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
                      "negate": false,
                      "required": false,
                      "fields": [
                          {
                              "name": "value",
                              "value": "\\b(japanese|korean|chinese|french|german|italian|spanish|russian|swedish|danish|norwegian|finnish|polish|hindi|thai)\\b"
                          }
                      ]
                  }
              ]
          }'

          echo ""
          echo "Configuring quality definitions (bitrate limits)..."

          # Configure quality definitions with sensible bitrate limits (MB/minute)
          # These ensure TV episodes don't grab unnecessarily large files
          ${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/qualitydefinition" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r def; do
              quality_name=$(echo "$def" | ${pkgs.jq}/bin/jq -r '.quality.name')
              def_id=$(echo "$def" | ${pkgs.jq}/bin/jq '.id')
              
              case "$quality_name" in
                  "HDTV-720p"|"WEBDL-720p"|"Bluray-720p")
                      # 720p: Target ~3-5 Mbps (22-38 MB/min)
                      updated=$(echo "$def" | ${pkgs.jq}/bin/jq '.minSize = 15 | .maxSize = 45 | .preferredSize = 30')
                      ;;
                  "HDTV-1080p"|"WEBDL-1080p"|"Bluray-1080p")
                      # 1080p: Target ~8-12 Mbps (60-90 MB/min)
                      updated=$(echo "$def" | ${pkgs.jq}/bin/jq '.minSize = 40 | .maxSize = 100 | .preferredSize = 70')
                      ;;
                  "HDTV-2160p"|"WEBDL-2160p"|"Bluray-2160p")
                      # 4K: Target ~20-35 Mbps HEVC (150-260 MB/min)
                      updated=$(echo "$def" | ${pkgs.jq}/bin/jq '.minSize = 100 | .maxSize = 300 | .preferredSize = 200')
                      ;;
                  "Remux-1080p")
                      # 1080p Remux: ~25-35 Mbps (190-260 MB/min) - discouraged
                      updated=$(echo "$def" | ${pkgs.jq}/bin/jq '.minSize = 150 | .maxSize = 300 | .preferredSize = 200')
                      ;;
                  "Remux-2160p")
                      # 4K Remux: ~50-80 Mbps (375-600 MB/min) - strongly discouraged
                      updated=$(echo "$def" | ${pkgs.jq}/bin/jq '.minSize = 300 | .maxSize = 700 | .preferredSize = 400')
                      ;;
                  *)
                      # Keep existing for others
                      continue
                      ;;
              esac
              
              echo "  Setting $quality_name bitrate limits..."
              ${pkgs.curl}/bin/curl -X PUT "$RADARR_URL/api/v3/qualitydefinition/$def_id" \
                  -H "X-Api-Key: $RADARR_API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$updated" > /dev/null 2>&1
          done

          echo ""
          echo "Getting custom format IDs..."

          # Get all format IDs
          hevc_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "x265/HEVC") | .id')
          x264_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "x264/H.264") | .id')
          fourk_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "4K/2160p") | .id')
          remux_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Remux") | .id')
          foreign_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Foreign Film") | .id')
          bad_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Bad Release Groups") | .id')
          trusted_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Trusted HEVC Groups") | .id')
          reenc_id=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Re-Encoded") | .id')

          echo "Updating quality profiles with optimal scoring..."

          # Update all quality profiles with the new scoring
          ${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/qualityprofile" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r profile; do
              profile_id=$(echo "$profile" | ${pkgs.jq}/bin/jq '.id')
              profile_name=$(echo "$profile" | ${pkgs.jq}/bin/jq -r '.name')
              
              echo "  Updating profile: $profile_name"
              
              # Build format items with scores optimized for 4K HEVC
              format_items="["
              [ -n "$hevc_id" ] && [ "$hevc_id" != "null" ] && format_items+="{\"format\": $hevc_id, \"name\": \"x265/HEVC\", \"score\": 150},"
              [ -n "$trusted_id" ] && [ "$trusted_id" != "null" ] && format_items+="{\"format\": $trusted_id, \"name\": \"Trusted HEVC Groups\", \"score\": 100},"
              [ -n "$fourk_id" ] && [ "$fourk_id" != "null" ] && format_items+="{\"format\": $fourk_id, \"name\": \"4K/2160p\", \"score\": 50},"
              [ -n "$foreign_id" ] && [ "$foreign_id" != "null" ] && format_items+="{\"format\": $foreign_id, \"name\": \"Foreign Film\", \"score\": 30},"
              [ -n "$x264_id" ] && [ "$x264_id" != "null" ] && format_items+="{\"format\": $x264_id, \"name\": \"x264/H.264\", \"score\": -30},"
              [ -n "$reenc_id" ] && [ "$reenc_id" != "null" ] && format_items+="{\"format\": $reenc_id, \"name\": \"Re-Encoded\", \"score\": -100},"
              [ -n "$remux_id" ] && [ "$remux_id" != "null" ] && format_items+="{\"format\": $remux_id, \"name\": \"Remux\", \"score\": -200},"
              [ -n "$bad_id" ] && [ "$bad_id" != "null" ] && format_items+="{\"format\": $bad_id, \"name\": \"Bad Release Groups\", \"score\": -1000},"
              format_items="''${format_items%,}]"
              
              # Update profile with new scoring and settings
              updated_profile=$(echo "$profile" | ${pkgs.jq}/bin/jq \
                  --argjson items "$format_items" \
                  '.formatItems = $items |
                   .minFormatScore = -150 |
                   .cutoffFormatScore = 100 |
                   .upgradeAllowed = true |
                   .cutoff = 9 |
                   (.items[]? | select(.quality.name? and (.quality.name | test("2160p")))).allowed = true |
                   (.items[]? | select(.quality.name? and (.quality.name | test("1080p")))).allowed = true |
                   (.items[]? | select(.quality.name? and (.quality.name | test("720p")))).allowed = true |
                   (.items[]? | select(.quality.name? and (.quality.name | test("Remux")))).allowed = false |
                   (.items[]? | select(.quality.name? and ((.quality.name | test("480p")) or (.quality.name | test("DVD")) or (.quality.name | test("SDTV"))))).allowed = false'
              )
              
              ${pkgs.curl}/bin/curl -X PUT "$RADARR_URL/api/v3/qualityprofile/$profile_id" \
                  -H "X-Api-Key: $RADARR_API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$updated_profile" > /dev/null 2>&1
          done

          echo ""
          echo "Setting HD - 720p/1080p as default profile for all movies..."

          # Set profile 6 (HD - 720p/1080p) as default for all movies
          movie_ids=$(${pkgs.curl}/bin/curl -s "$RADARR_URL/api/v3/movie" -H "X-Api-Key: $RADARR_API_KEY" | ${pkgs.jq}/bin/jq -r '[.[].id] | @csv' | tr -d '"')
          movie_count=$(echo "$movie_ids" | tr ',' '\n' | ${pkgs.coreutils}/bin/wc -l)

          if [ -n "$movie_ids" ]; then
              bulk_edit="{\"movieIds\": [$movie_ids], \"qualityProfileId\": 6, \"moveFiles\": false}"
              
              ${pkgs.curl}/bin/curl -X PUT "$RADARR_URL/api/v3/movie/editor" \
                  -H "X-Api-Key: $RADARR_API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$bulk_edit" > /dev/null 2>&1
              
              echo "  Updated $movie_count movies to use optimized profile"
          fi
          fi  # End of Radarr configuration block

          # Configure Sonarr if available (v4 uses Custom Formats like Radarr)
          if [ -n "$SONARR_API_KEY" ]; then
              echo ""
              echo "=== Configuring Sonarr ==="
              
              # Sonarr v4 uses Custom Formats similar to Radarr
              echo "Creating custom formats for Sonarr..."
              
              # Function to create or update Sonarr custom format
              create_or_update_sonarr_format() {
                  local name="$1"
                  local json="$2"
                  
                  # Check if format exists
                  local existing_id=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | \
                      ${pkgs.jq}/bin/jq --arg name "$name" '.[] | select(.name == $name) | .id')
                  
                  if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
                      # Update existing format
                      ${pkgs.curl}/bin/curl -X PUT "$SONARR_URL/api/v3/customformat/$existing_id" \
                          -H "X-Api-Key: $SONARR_API_KEY" \
                          -H "Content-Type: application/json" \
                          -d "$(echo "$json" | ${pkgs.jq}/bin/jq --argjson id "$existing_id" '. + {id: $id}')" > /dev/null 2>&1
                      echo "  Updated custom format: $name"
                  else
                      # Create new format
                      ${pkgs.curl}/bin/curl -X POST "$SONARR_URL/api/v3/customformat" \
                          -H "X-Api-Key: $SONARR_API_KEY" \
                          -H "Content-Type: application/json" \
                          -d "$json" > /dev/null 2>&1
                      echo "  Created custom format: $name"
                  fi
              }
              
              # Create HEVC format
              create_or_update_sonarr_format "x265/HEVC" '{
                  "name": "x265/HEVC",
                  "includeCustomFormatWhenRenaming": false,
                  "specifications": [
                      {
                          "name": "x265/HEVC",
                          "implementation": "ReleaseTitleSpecification",
                          "implementationName": "Release Title",
                          "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                          "negate": false,
                          "required": false,
                          "fields": [
                              {
                                  "name": "value",
                                  "value": "\\b(x265|h265|hevc)\\b"
                              }
                          ]
                      }
                  ]
              }'
              
              # Create bad release groups format
              create_or_update_sonarr_format "Bad Release Groups" '{
                  "name": "Bad Release Groups",
                  "includeCustomFormatWhenRenaming": false,
                  "specifications": [
                      {
                          "name": "Bad Release Groups",
                          "implementation": "ReleaseTitleSpecification",
                          "implementationName": "Release Title",
                          "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                          "negate": false,
                          "required": false,
                          "fields": [
                              {
                                  "name": "value",
                                  "value": "\\b(YIFY|YTS|RARBG.*REENC|TERRiBLE|LiGaS|BRrip|CHD|RM|mSD|HDTime|SiC)\\b"
                              }
                          ]
                      }
                  ]
              }'
              
              # Create trusted HEVC groups format
              create_or_update_sonarr_format "Trusted HEVC Groups" '{
                  "name": "Trusted HEVC Groups",
                  "includeCustomFormatWhenRenaming": false,
                  "specifications": [
                      {
                          "name": "Trusted HEVC Groups",
                          "implementation": "ReleaseTitleSpecification",
                          "implementationName": "Release Title",
                          "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                          "negate": false,
                          "required": false,
                          "fields": [
                              {
                                  "name": "value",
                                  "value": "\\b(QxR|UTR|TOMMY|FLUX|NTb|CtrlHD|TERMINAL|TIGERS|HONE|MONOLITH|PSA|MZABI|TAoE|SEV|CMRG)\\b"
                              }
                          ]
                      }
                  ]
              }'
              
              # Create re-encoded format
              create_or_update_sonarr_format "Re-Encoded" '{
                  "name": "Re-Encoded",
                  "includeCustomFormatWhenRenaming": false,
                  "specifications": [
                      {
                          "name": "Re-Encoded",
                          "implementation": "ReleaseTitleSpecification",
                          "implementationName": "Release Title",
                          "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                          "negate": false,
                          "required": false,
                          "fields": [
                              {
                                  "name": "value",
                                  "value": "\\b(REENC|ReEnc|Re-Enc|Reencoded)\\b"
                              }
                          ]
                      }
                  ]
              }'
              
              # Also keep the release profile for blocking (it still works for must not contain)
              bad_existing=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/releaseprofile" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Block Bad Encoders")')
              
              if [ -z "$bad_existing" ]; then
                  echo "  Creating bad encoder blocking profile..."
                  ${pkgs.curl}/bin/curl -X POST "$SONARR_URL/api/v3/releaseprofile" \
                      -H "X-Api-Key: $SONARR_API_KEY" \
                      -H "Content-Type: application/json" \
                      -d '{
                          "name": "Block Bad Encoders",
                          "enabled": true,
                          "required": [],
                          "ignored": [
                              "YIFY",
                              "YTS",
                              "RARBG.*REENC",
                              "TERRiBLE",
                              "LiGaS",
                              "BRrip",
                              "CHD",
                              "RM",
                              "mSD",
                              "HDTime",
                              "SiC",
                              "REENC",
                              "ReEnc",
                              "Re-Enc",
                              "Reencoded"
                          ],
                          "indexerId": 0,
                          "tags": []
                      }' > /dev/null 2>&1
                  echo "  Bad encoder blocking profile created"
              else
                  echo "  Bad encoder blocking profile already exists"
              fi
              
              # Now update quality profiles with custom format scores
              echo "Updating Sonarr quality profiles with custom format scoring..."
              
              # Get format IDs
              hevc_id=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "x265/HEVC") | .id')
              bad_id=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Bad Release Groups") | .id')
              trusted_id=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Trusted HEVC Groups") | .id')
              reenc_id=$(${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq '.[] | select(.name == "Re-Encoded") | .id')
              
              # Update quality profiles
              ${pkgs.curl}/bin/curl -s "$SONARR_URL/api/v3/qualityprofile" -H "X-Api-Key: $SONARR_API_KEY" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r profile; do
                  profile_id=$(echo "$profile" | ${pkgs.jq}/bin/jq '.id')
                  profile_name=$(echo "$profile" | ${pkgs.jq}/bin/jq -r '.name')
                  
                  echo "  Updating profile: $profile_name"
                  
                  # Build format items with scores
                  format_items="["
                  [ -n "$hevc_id" ] && [ "$hevc_id" != "null" ] && format_items+="{\"format\": $hevc_id, \"name\": \"x265/HEVC\", \"score\": 100},"
                  [ -n "$trusted_id" ] && [ "$trusted_id" != "null" ] && format_items+="{\"format\": $trusted_id, \"name\": \"Trusted HEVC Groups\", \"score\": 50},"
                  [ -n "$reenc_id" ] && [ "$reenc_id" != "null" ] && format_items+="{\"format\": $reenc_id, \"name\": \"Re-Encoded\", \"score\": -100},"
                  [ -n "$bad_id" ] && [ "$bad_id" != "null" ] && format_items+="{\"format\": $bad_id, \"name\": \"Bad Release Groups\", \"score\": -1000},"
                  format_items="''${format_items%,}]"
                  
                  # Update profile
                  updated_profile=$(echo "$profile" | ${pkgs.jq}/bin/jq \
                      --argjson items "$format_items" \
                      '.formatItems = $items | .minFormatScore = -1000 | .cutoffFormatScore = 10000'
                  )
                  
                  ${pkgs.curl}/bin/curl -X PUT "$SONARR_URL/api/v3/qualityprofile/$profile_id" \
                      -H "X-Api-Key: $SONARR_API_KEY" \
                      -H "Content-Type: application/json" \
                      -d "$updated_profile" > /dev/null 2>&1
              done
              
              echo "  Sonarr configuration complete"
          fi

          echo ""
          echo "✅ Configuration complete!"
          echo ""
          echo "Optimized for Intel UHD 630 with 4K HEVC hardware decode:"
          echo ""
          echo "Format scoring:"
          echo "  • x265/HEVC: +150 points (essential for 4K content)"
          echo "  • Trusted HEVC Groups: +100 points (quality encoders)"
          echo "  • 4K/2160p: +50 points (your hardware handles this well with HEVC)"
          echo "  • Foreign films: +30 points (for international content)"
          echo "  • x264/H.264: -30 points (mild penalty, still grabbable)"
          echo "  • Re-Encoded: -100 points (avoid poor re-encodes)"
          echo "  • Remux: -200 points (unnecessarily large, uncompressed)"
          echo "  • Bad Release Groups: -1000 points (blocks known bad encoders)"
          echo ""
          echo "Bitrate limits (prevents oversized TV episodes):"
          echo "  • 720p: 3-5 Mbps (2-4 GB per movie, 200-400 MB per TV episode)"
          echo "  • 1080p: 8-12 Mbps (5-9 GB per movie, 500-900 MB per TV episode)"
          echo "  • 4K HEVC: 20-35 Mbps (15-26 GB per movie, 1.5-2.6 GB per TV episode)"
          echo ""
          echo "Your system can easily handle 4K HEVC at these bitrates!"
          echo "TV episodes won't exceed reasonable sizes for their runtime."
        '';
      in "${configureScript}/bin/configure-arr-optimal";
      StandardOutput = "journal";
      StandardError = "journal";
      User = "root";  # Needs sudo to read API keys
    };
    
    # Run 30 seconds after Radarr starts to ensure it's fully initialized
    startLimitIntervalSec = 60;
    startLimitBurst = 3;
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
        reverse_proxy /* localhost:8080
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
      - Home Automation:
        - Home Assistant:
            icon: home-assistant.png
            href: https://homeassistant.home.husbuddies.gay
            description: Home automation hub
            widget:
              type: homeassistant
              url: http://127.0.0.1:8123
              key: {{HOMEPAGE_FILE_HOMEASSISTANT_API_KEY}}
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
              url: http://127.0.0.1:8080
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
    containers = {
      flaresolverr = {
        image = "flaresolverr/flaresolverr:v3.3.18";
        ports = [
          "8191:8191"
        ];
        extraOptions = [ "--network=host" ];
      };
      jellyseerr = {
        image = "fallenbagel/jellyseerr:2.7.3";
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
          HOMEPAGE_FILE_HOMEASSISTANT_API_KEY = "/app/keys/homeassistant-api-key";
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

  # Clean up Podman and Nix store regularly
  systemd.services.cleanup-podman-and-nix = {
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

  systemd.timers.cleanup-podman-and-nix = {
    description = "Run Podman and Nix cleanup every hour";
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
      jellyfin-ffmpeg
      chromium
      signal-cli
    ];

    # SSH agent is now managed by systemd user service
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.05";
}
