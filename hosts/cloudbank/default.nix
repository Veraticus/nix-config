let
  system = "aarch64-darwin";
  user = "joshsymonds";
in
{ inputs, outputs, lib, config, pkgs, ... }: {
  # You can import other NixOS modules here
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./homebrew.nix
  ];

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
    };
  };

  nix = {
    package = pkgs.unstable.nix;

    gc = {
      automatic = true;
      interval = { Weekday = 0; Hour = 0; Minute = 0; };
      options = "--delete-older-than 30d";
    };

    # Configure the nix registry
    registry = {
      nixpkgs.flake = inputs.nixpkgs-unstable;
    };

    # Configure the nixPath
    nixPath = [
      "nixpkgs=${inputs.nixpkgs-unstable}"
    ];

    optimise.automatic = true;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store

      # Caches
      substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };


  networking.hostName = "cloudbank";

  # Time and internationalization
  time.timeZone = "America/Los_Angeles";

  # Users and their homes
  users.users.${user} = {
    shell = pkgs.unstable.zsh;
    home = "/Users/${user}";
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useUserPackages = true;
    useGlobalPkgs = true;
    users = {
      # Import your home-manager configuration
      ${user} = import ../../home-manager/${system}.nix;
    };
  };

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  # Services
  programs.zsh.enable = true; # This is necessary to set zsh paths properly

  # System setup
  system = {
    defaults = {
      dock = {
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
      };
      finder = {
        AppleShowAllExtensions = true;
        CreateDesktop = false;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  # Environment
  environment = {
    pathsToLink = [
      "/bin"
      "/share/locale"
      "/share/terminfo"
      "/share/zsh"
    ];
    variables = {
      EDITOR = "nvim";
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = 4;
}
