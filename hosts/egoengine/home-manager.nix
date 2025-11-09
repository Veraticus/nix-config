# Standalone home-manager configuration for Docker container
# This builds a home-manager activation package without NixOS
{ inputs
, pkgs
, lib
, ...
}:
let
  user = "joshsymonds";
  homeDirectory = "/home/${user}";
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  modules = [
    # Import common home-manager configuration
    ../../home-manager/common.nix

    # Container-specific overrides
    {
      home.username = user;
      home.homeDirectory = homeDirectory;
      home.stateVersion = "25.05";

      # Ensure paths are correct for container environment
      home.sessionPath = [
        "${homeDirectory}/.nix-profile/bin"
        "${homeDirectory}/.local/bin"
      ];

      # Container-specific environment
      home.sessionVariables = {
        EDITOR = "hx";
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
      };

      # Always use HTTPS for GitHub operations inside the container
      programs.git.extraConfig.url = lib.mkForce {
        "https://github.com/".insteadOf = [
          "git@github.com:"
          "ssh://git@github.com/"
        ];
      };

      # Disable atuin daemon in container (no systemd)
      # Use standalone mode instead
      programs.atuin.daemon.enable = lib.mkForce false;
    }
  ];

  extraSpecialArgs = {
    inherit inputs;
    hostname = "egoengine";
    # Provide outputs but keep it minimal
    outputs = {
      overlays = import ../../overlays { inherit inputs; outputs = {}; };
    };
  };
}
