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
      ../../modules/nix/defaults.nix
      ../../modules/darwin/applications.nix
      ../../modules/darwin/defaults.nix
      ../../modules/darwin/software.nix
    ];

    nix = {
      package = pkgs.nix;

      gc = {
        automatic = true;
        interval = {
          Hour = 3;
          Minute = 30;
        };
        options = "--delete-older-than 3d";
      };

      # Configure the nix registry
      registry = {
        nixpkgs.flake = inputs.nixpkgs;
        devenv.flake = inputs.devenv;
      };

      # Configure the nixPath
      nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];

      settings.trusted-users = ["root" user];
    };

    networking.hostName = "cloudbank";

    # Time and internationalization
    time.timeZone = "America/Los_Angeles";

    # Users and their homes
    users.users.${user} = {
      shell = pkgs.zsh;
      home = "/Users/${user}";
    };

    # Security
    security.pam.services.sudo_local = {
      enable = true;
      text = ''
        auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so
        auth       sufficient     pam_tid.so
      '';
    };

    # Services
    programs.zsh.enable = true; # This is necessary to set zsh paths properly

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

    # System setup
    system = {
      primaryUser = "joshsymonds";
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      stateVersion = 4;
    };
  }
