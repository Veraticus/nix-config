# This file defines overlays
{inputs, ...}: let
  moarRev = "25be66bf628ad02e807ca929b5e7a1128511d255";
  moarVersion = "unstable-2025-11-09";
  moarVersionString = "${moarVersion}+g${builtins.substring 0 7 moarRev}";
in {
  default = final: prev: let
    codexTui = inputs.codex-src.packages.${final.system}.codex-tui;
    codexCli = inputs.codex-src.packages.${final.system}.codex-cli;
    codexWrapper = final.writeShellScriptBin "codex" ''
      exec ${codexCli}/bin/codex "$@"
    '';
  in {
    myCaddy = final.callPackage ../pkgs/caddy {};
    starlark-lsp = final.callPackage ../pkgs/starlark-lsp {};
    nuclei = final.callPackage ../pkgs/nuclei {};
    mcp-atlassian = final.callPackage ../pkgs/mcp-atlassian {};
    claudeCodeCli = final.callPackage ../pkgs/claude-code-cli {};
    deadcode = final.callPackage ../pkgs/deadcode {};
    golangciLintBin = final.callPackage ../pkgs/golangci-lint-bin {};
    heretic = final.callPackage ../pkgs/heretic {};
    coder = final.callPackage ../pkgs/coder-cli {inherit (final) unzip;};
    slidev = final.callPackage ../pkgs/slidev {};
    redlib-veraticus = final.callPackage ../pkgs/redlib-veraticus {
      inherit (inputs) crane;
      redlibSrc = inputs.redlib-fork.sourceInfo.outPath;
      redlibRev = inputs.redlib-fork.sourceInfo.rev;
      rustOverlay = inputs.rust-overlay;
    };

    # Codex packages from local checkout
    codex-tui = codexTui;
    codex-cli = codexCli;
    codex = codexWrapper;

    # gocover-cobertura 1.3.0 fails to build with Go 1.24; rebuild with Go 1.23
    gocover-cobertura =
      final.callPackage
      (inputs.nixpkgs + "/pkgs/by-name/go/gocover-cobertura/package.nix")
      {
        buildGoModule = final.buildGo123Module;
      };

    # Package modifications
    waybar = prev.waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
      version = "0.9.21";
    });

    catppuccin-gtk = prev.catppuccin-gtk.override {
      accents = ["lavender"];
      size = "compact";
      tweaks = ["rimless" "black"];
      variant = "mocha";
    };

    catppuccin-plymouth = prev.catppuccin-plymouth.override {
      variant = "mocha";
    };

    moar = prev.moar.overrideAttrs (_: {
      version = moarVersion;
      src = final.fetchFromGitHub {
        owner = "walles";
        repo = "moar";
        rev = moarRev;
        hash = "sha256-c2ypM5xglQbvgvU2Eq7sgMpNHSAsKEBDwQZC/Sf4GPU=";
      };
      vendorHash = "sha256-ve8QT2dIUZGTFYESt9vIllGTan22ciZr8SQzfqtqQfw=";
      ldflags = [
        "-s"
        "-w"
        "-X"
        "main.versionString=${moarVersionString}"
      ];
      postInstall = ''
        if [ -x "$out/bin/moor" ] && [ ! -e "$out/bin/moar" ]; then
          mv "$out/bin/moor" "$out/bin/moar"
        fi
        if [ -x "$out/bin/moar" ] && [ ! -e "$out/bin/moor" ]; then
          ln -s moar "$out/bin/moor"
        fi
        if [ -f ./moor.1 ]; then
          installManPage ./moor.1
        elif [ -f ./moar.1 ]; then
          installManPage ./moar.1
        fi
      '';
    });

    # XIVLauncher customizations
    xivlauncher =
      prev.xivlauncher.override {
        steam = prev.steam.override {
          extraLibraries = _: [prev.gamemode.lib];
        };
      }
      // {
        desktopItems = [];
      };

    vaapiIntel = prev.vaapiIntel.override {
      enableHybridCodec = true;
    };

    # Stable packages available under pkgs.stable (if needed)
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };

  additions = _: _: {};
  modifications = _: _: {};
  unstable-packages = _: _: {};
  darwin = import ./darwin.nix;
}
