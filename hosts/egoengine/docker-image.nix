# Clean Nix-based Docker image for development environments
# Uses dockerTools.buildLayeredImage (not NixOS) for proper FHS compatibility
{ inputs
, outputs
, lib
, pkgs
, ...
}:
let
  user = "joshsymonds";
  uid = "1000";
  gid = "1000";
  homeDirectory = "/home/${user}";

  # Minimal locale configuration
  minimalLocales = pkgs.glibcLocales.override {
    locales = [
      "en_US.UTF-8/UTF-8"
      "C.UTF-8/UTF-8"
    ];
  };

  # Build home-manager activation package standalone
  homeConfig = import ./home-manager.nix {
    inherit inputs pkgs;
  };

  # Pre-build home directory structure from home-manager configuration
  # This extracts dotfiles and configurations without running activation
  prebuiltHome = pkgs.runCommand "egoengine-home" {
    nativeBuildInputs = [ pkgs.rsync ];
  } ''
    set -euo pipefail

    # Create home directory structure
    mkdir -p $out

    # Extract home-files from home-manager build
    # Home-manager stores dotfiles in the activation package
    if [ -d "${homeConfig.activationPackage}/home-files" ]; then
      echo "Copying home-files from activation package..."
      rsync -a "${homeConfig.activationPackage}/home-files/" "$out/"
    fi

    # Ensure standard directories exist
    mkdir -p $out/.config
    mkdir -p $out/.local/bin
    mkdir -p $out/.local/share
    mkdir -p $out/.cache

    # Set proper permissions
    chmod -R u+w $out
  '';

  # Core system packages needed in container
  # This mirrors the packages from the NixOS configuration
  systemPackages = with pkgs; [
    # Core utilities
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    gnutar
    gzip
    which

    # Development tools
    git
    curl
    docker-client
    kubectl
    neovim

    # Custom packages
    codex
    claudeCodeCli
    _1password-cli

    # Shell
    zsh
    bashInteractive

    # Nix tools
    nix

    # Locales
    minimalLocales

    # SSL certificates
    cacert
  ];

  # Build a combined environment with all packages
  # This makes PATH construction easier
  combinedEnv = pkgs.buildEnv {
    name = "egoengine-env";
    paths = systemPackages;
    pathsToLink = [ "/bin" "/share" "/lib" ];
  };

  # Create FHS-compatible directory structure
  # This is needed because Coder agent init script expects /usr/bin/env, grep, tar, etc.
  fhsSetup = pkgs.runCommand "egoengine-fhs-setup" {} ''
    set -euo pipefail

    # Create directory structure
    mkdir -p $out/usr/bin $out/bin $out/etc $out/home/${user}

    # /usr/bin symlinks (for Coder agent compatibility)
    # The Coder agent init script needs these tools in /usr/bin
    ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
    ln -s ${pkgs.gnugrep}/bin/grep $out/usr/bin/grep
    ln -s ${pkgs.gnutar}/bin/tar $out/usr/bin/tar
    ln -s ${pkgs.gzip}/bin/gzip $out/usr/bin/gzip
    ln -s ${pkgs.coreutils}/bin/head $out/usr/bin/head
    ln -s ${pkgs.which}/bin/which $out/usr/bin/which
    ln -s ${pkgs.zsh}/bin/zsh $out/usr/bin/zsh
    ln -s ${pkgs.bashInteractive}/bin/bash $out/usr/bin/bash

    # /bin symlinks (common FHS locations)
    ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
    ln -s ${pkgs.coreutils}/bin/env $out/bin/env

    # Create user account files
    cat > $out/etc/passwd <<EOF
root:x:0:0::/root:/bin/sh
${user}:x:${uid}:${gid}::${homeDirectory}:${pkgs.zsh}/bin/zsh
EOF

    cat > $out/etc/group <<EOF
root:x:0:
${user}:x:${gid}:${user}
docker:x:998:${user}
EOF

    cat > $out/etc/shadow <<EOF
root:!:1::::::
${user}:!:1::::::
EOF

    cat > $out/etc/gshadow <<EOF
root:!::
${user}:!::
docker:!::${user}
EOF

    # Set proper permissions on home directory
    chmod 0700 $out/home/${user}
  '';

  # Construct PATH for container
  # Priority: home-manager profile > nix profiles > FHS locations
  containerPath = lib.concatStringsSep ":" [
    "${homeDirectory}/.nix-profile/bin"
    "${homeDirectory}/.local/bin"
    "/nix/var/nix/profiles/per-user/${user}/profile/bin"
    "${combinedEnv}/bin"
    "/usr/bin"
    "/bin"
  ];


in
pkgs.dockerTools.buildLayeredImage {
  name = "egoengine";
  tag = "latest";

  # Enable Nix database for nix commands to work
  enableFakechroot = true;
  fakeRootCommands = ''
    set -euo pipefail

    # Create necessary directories with proper ownership
    mkdir -p ./home/${user}
    mkdir -p ./workspace
    mkdir -p ./tmp
    mkdir -p ./nix/var/nix/profiles/per-user/${user}
    mkdir -p ./root

    # Copy pre-built home directory structure
    # This contains dotfiles, configs, etc. from home-manager
    # Using cp instead of rsync for better compatibility in fakechroot
    echo "Installing home directory structure..."
    cp -r ${prebuiltHome}/. ./home/${user}/

    # Create profile symlink for home-manager
    ln -sf ${homeConfig.activationPackage} ./nix/var/nix/profiles/per-user/${user}/profile

    # Link .nix-profile to the actual profile
    rm -f ./home/${user}/.nix-profile
    ln -sf /nix/var/nix/profiles/per-user/${user}/profile ./home/${user}/.nix-profile

    # Set ownership
    chown -R ${uid}:${gid} ./home/${user}
    chmod 0700 ./home/${user}

    chown ${uid}:${gid} ./workspace
    chmod 0755 ./workspace

    chmod 1777 ./tmp

    chown ${uid}:${gid} ./nix/var/nix/profiles/per-user/${user}
  '';

  # Contents to copy into the image
  contents = [
    # FHS compatibility layer (user accounts, symlinks)
    fhsSetup

    # Official dockerTools helpers
    pkgs.dockerTools.usrBinEnv    # Provides /usr/bin/env
    pkgs.dockerTools.binSh        # Provides /bin/sh
    pkgs.dockerTools.caCertificates # SSL certificates
    pkgs.dockerTools.fakeNss      # NSS configuration

    # Combined environment with all packages
    combinedEnv

    # Home-manager activation package (for the profile)
    homeConfig.activationPackage
  ];

  # Container configuration
  config = {
    # Run as non-root user
    User = user;
    WorkingDir = homeDirectory;

    # Default command: login shell
    Cmd = [ "${pkgs.zsh}/bin/zsh" "-l" ];

    # Environment variables
    Env = [
      "USER=${user}"
      "HOME=${homeDirectory}"
      "SHELL=${pkgs.zsh}/bin/zsh"
      "LANG=en_US.UTF-8"
      "LC_ALL=en_US.UTF-8"
      "EDITOR=nvim"
      "PATH=${containerPath}"

      # Nix configuration
      "NIX_CONFIG=experimental-features = nix-command flakes"
      "NIX_USER_PROFILE_DIR=/nix/var/nix/profiles/per-user/${user}"
      "NIX_PROFILES=/nix/var/nix/profiles/per-user/${user}/profile"
      "LOCALE_ARCHIVE=${minimalLocales}/lib/locale/locale-archive"

      # Prevent warnings
      "NO_COLOR=1"
    ];

    # OCI labels
    Labels = {
      "org.opencontainers.image.title" = "egoengine";
      "org.opencontainers.image.description" = "Nix-based development environment";
      "org.opencontainers.image.source" = "https://github.com/Veraticus/nix-config";
      "org.opencontainers.image.licenses" = "MIT";
    };
  };
}
