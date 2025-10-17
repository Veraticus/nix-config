# This file defines overlays
{ inputs, ... }:
{
  # Single default overlay that combines everything
  default = final: prev:
    let
      codexTui = inputs.codex-src.packages.${final.system}.codex-tui;
      codexCli = inputs.codex-src.packages.${final.system}.codex-cli;
      codexWrapper = final.writeShellScriptBin "codex" ''
        exec ${codexCli}/bin/codex "$@"
      '';
    in {
    # Import custom packages from the 'pkgs' directory
    inherit (import ../pkgs { pkgs = final; })
      myCaddy
      starlark-lsp
      nuclei;

    # Codex packages from local checkout
    codex-tui = codexTui;
    codex-cli = codexCli;
    codex = codexWrapper;

    # gocover-cobertura 1.3.0 fails to build with Go 1.24; rebuild with Go 1.23
    gocover-cobertura = final.callPackage
      (inputs.nixpkgs + "/pkgs/by-name/go/gocover-cobertura/package.nix")
      {
        buildGoModule = final.buildGo123Module;
      };

    home-assistant-tailwind = prev.home-assistant.overrideAttrs (old: {
      version = "${old.version}-tailwindfix";
      __intentionallyOverridingVersion = true;
      patches = (old.patches or []) ++ [
        (final.fetchpatch {
          url = "https://github.com/Veraticus/core/commit/02e91c66498ef8756e11cb121ffa12bfbe0c4f5c.patch";
          hash = "sha256-9B7VpKT3FCRqz6OFDlLCX3vfc9GyRqIhUYXW+XPZ8Pg=";
        })
      ];
    });
    
    # Package modifications
    waybar = prev.waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
      version = "0.9.21";
    });
    
    catppuccin-gtk = prev.catppuccin-gtk.override {
      accents = [ "lavender" ];
      size = "compact";
      tweaks = [ "rimless" "black" ];
      variant = "mocha";
    };
    
    catppuccin-plymouth = prev.catppuccin-plymouth.override {
      variant = "mocha";
    };
    
    # XIVLauncher customizations
    xivlauncher = prev.xivlauncher.override {
      steam = prev.steam.override {
        extraLibraries = pkgs: [ prev.gamemode.lib ];
      };
    } // {
      # Remove desktop items as we're setting them ourselves
      desktopItems = [];
    };
    
    # Stable packages available under pkgs.stable (if needed)
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
  
  # Legacy overlay references for backwards compatibility
  additions = final: _prev:
    let
      codexTui = inputs.codex-src.packages.${final.system}.codex-tui;
      codexCli = inputs.codex-src.packages.${final.system}.codex-cli;
      codexWrapper = final.writeShellScriptBin "codex" ''
        exec ${codexCli}/bin/codex "$@"
      '';
    in
      (import ../pkgs { pkgs = final; })
      // {
        codex-tui = codexTui;
        codex-cli = codexCli;
        codex = codexWrapper;
      };
  modifications = final: prev: { };  # Empty, kept for compatibility
  unstable-packages = final: prev: { };  # Empty, no longer needed since we use unstable as primary
}
