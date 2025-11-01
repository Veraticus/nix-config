# This file defines overlays
{ inputs, ... }:
{
  default = final: prev:
    let
      codexTui = inputs.codex-src.packages.${final.system}.codex-tui;
      codexCli = inputs.codex-src.packages.${final.system}.codex-cli;
      codexWrapper = final.writeShellScriptBin "codex" ''
        exec ${codexCli}/bin/codex "$@"
      '';
    in {
      myCaddy = final.callPackage ../pkgs/caddy { };
      starlark-lsp = final.callPackage ../pkgs/starlark-lsp { };
      nuclei = final.callPackage ../pkgs/nuclei { };
      mcp-atlassian = final.callPackage ../pkgs/mcp-atlassian { };
      claudeCodeCli = final.callPackage ../pkgs/claude-code-cli { };
      deadcode = final.callPackage ../pkgs/deadcode { };
      golangciLintBin = final.callPackage ../pkgs/golangci-lint-bin { };
      coder = final.callPackage ../pkgs/coder-cli { unzip = final.unzip; };

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
        desktopItems = [];
      };
      
      # Stable packages available under pkgs.stable (if needed)
      stable = import inputs.nixpkgs-stable {
        system = final.system;
        config.allowUnfree = true;
      };
    };

  additions = final: _prev: { };
  modifications = final: prev: { };
  unstable-packages = final: prev: { };
}
