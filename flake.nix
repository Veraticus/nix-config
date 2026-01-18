{
  description = "Josh Symonds' nix config";

  inputs = {
    # Nixpkgs - using unstable as primary
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11"; # Keep stable available if needed

    # Darwin
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware-specific optimizations
    hardware.url = "github:nixos/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Linkpearl - clipboard sync
    linkpearl.url = "github:Veraticus/linkpearl";

    # CC-Tools - Claude Code smart hooks
    cc-tools.url = "github:Veraticus/cc-tools";

    # Target Process MCP - Target Process API integration
    targetprocess-mcp.url = "github:Veraticus/targetprocess-mcp";

    # Redlib MCP - Reddit API via Redlib for Claude
    redlib-mcp.url = "github:Veraticus/redlib-mcp";

    # Codex checkout (Rust implementation) - track GitHub fork
    codex-src.url = "github:Veraticus/codex";

    # Redlib fork for customizations
    redlib-fork = {
      url = "github:Veraticus/redlib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://neovim-nightly.cachix.org"
      "https://joshsymonds.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "neovim-nightly.cachix.org-1:fLrV5fy41LFKwyLAxJ0H13o6FOVGc4k6gXB5Y1dqtWw="
      "joshsymonds.cachix.org-1:DajO7Bjk/Q8eQVZQZC/AWOzdUst2TGp8fHS/B1pua2c="
    ];
  };

  outputs = {
    nixpkgs,
    darwin,
    home-manager,
    self,
    ...
  } @ inputs: let
    inherit (self) outputs;
    inherit (nixpkgs) lib;

    # Only the systems we actually use
    systems = ["x86_64-linux" "aarch64-darwin"];
    forAllSystems = f: lib.genAttrs systems f;

    # Common special arguments for all configurations
    mkSpecialArgs = _: {
      inherit inputs outputs;
    };

    mkHomeManagerModules = {
      hostname,
      system,
      module,
    }: [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          users.joshsymonds = import module;
          extraSpecialArgs =
            mkSpecialArgs system
            // {
              inherit hostname;
            };
          sharedModules = [inputs.agenix.homeManagerModules.default];
        };
      }
    ];

    mkNixosHost = hostname: cfg:
      lib.nixosSystem {
        inherit (cfg) system;
        specialArgs = mkSpecialArgs cfg.system;
        modules =
          cfg.modules
          ++ lib.optionals (cfg ? homeModule)
          (mkHomeManagerModules {
            inherit hostname;
            inherit (cfg) system;
            module = cfg.homeModule;
          });
      };

    nixosHostDefinitions = {
      egoengine = {
        system = "x86_64-linux";
        modules = [
          ./hosts/egoengine
          inputs.agenix.nixosModules.default
        ];
      };

      ultraviolet = {
        system = "x86_64-linux";
        modules = [
          ./hosts/ultraviolet
          ./hosts/common.nix
          inputs.agenix.nixosModules.default
        ];
        homeModule = ./home-manager/hosts/ultraviolet.nix;
      };

      bluedesert = {
        system = "x86_64-linux";
        modules = [
          ./hosts/bluedesert
          ./hosts/common.nix
          inputs.agenix.nixosModules.default
        ];
        homeModule = ./home-manager/hosts/bluedesert.nix;
      };

      echelon = {
        system = "x86_64-linux";
        modules = [
          ./hosts/echelon
          ./hosts/common.nix
          inputs.agenix.nixosModules.default
        ];
        homeModule = ./home-manager/hosts/echelon.nix;
      };

      vermissian = {
        system = "x86_64-linux";
        modules = [
          ./hosts/vermissian
          ./hosts/common.nix
          inputs.agenix.nixosModules.default
        ];
        homeModule = ./home-manager/hosts/vermissian.nix;
      };

      stygianlibrary = {
        system = "x86_64-linux";
        modules = [
          ./hosts/stygianlibrary
          ./hosts/common.nix
          inputs.agenix.nixosModules.default
        ];
        homeModule = ./home-manager/hosts/stygianlibrary.nix;
      };

      stygianlibrary-installer = {
        system = "x86_64-linux";
        modules = [
          ./hosts/stygianlibrary/installer.nix
        ];
      };
    };
  in {
    packages = let
      base = forAllSystems (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [inputs.neovim-nightly.overlays.default];
          };
        in
          import ./pkgs {
            inherit pkgs;
          }
      );
    in
      base
      // {
        x86_64-linux =
          base.x86_64-linux
          // {
            egoengine = self.nixosConfigurations.egoengine.config.system.build.egoengineDockerImage;
            stygianlibraryInstallerIso = self.nixosConfigurations.stygianlibrary-installer.config.system.build.isoImage;
          };
      };

    overlays = import ./overlays {inherit inputs outputs;};

    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        default = pkgs.mkShell {
          name = "nix-config-dev";
          packages = with pkgs; [
            alejandra
            nixpkgs-fmt
            statix
            deadnix
            shellcheck
            git
          ];
        };
      }
    );

    # NixOS configurations - inlined for clarity
    nixosConfigurations =
      lib.mapAttrs mkNixosHost nixosHostDefinitions;

    # Darwin configuration - inlined for clarity
    darwinConfigurations = {
      cloudbank = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkSpecialArgs "aarch64-darwin";
        modules = [
          ./hosts/cloudbank
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users.joshsymonds = import ./home-manager/aarch64-darwin.nix;
              extraSpecialArgs =
                mkSpecialArgs "aarch64-darwin"
                // {
                  hostname = "cloudbank";
                };
              sharedModules = [inputs.agenix.homeManagerModules.default];
            };
          }
        ];
      };
    };

    # Simplified home configurations - generated programmatically
    homeConfigurations = let
      mkHome = {
        system,
        module,
        hostname,
      }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              inputs.neovim-nightly.overlays.default
              outputs.overlays.default
              outputs.overlays.darwin
            ];
            config.allowUnfree = true;
          };
          extraSpecialArgs = mkSpecialArgs system // {inherit hostname;};
          modules = [inputs.agenix.homeManagerModules.default module];
        };

      linuxHosts = builtins.attrNames (lib.filterAttrs (_: cfg: cfg ? homeModule) nixosHostDefinitions);
      darwinHosts = ["cloudbank"];
    in
      (
        lib.genAttrs
        (map (h: "joshsymonds@${h}") linuxHosts)
        (h: let
          hostname = lib.removePrefix "joshsymonds@" h;
        in
          mkHome {
            system = "x86_64-linux";
            module = ./home-manager/hosts/${hostname}.nix;
            inherit hostname;
          })
      )
      // (
        lib.genAttrs
        (map (h: "joshsymonds@${h}") darwinHosts)
        (h: let
          hostname = lib.removePrefix "joshsymonds@" h;
        in
          mkHome {
            system = "aarch64-darwin";
            module = ./home-manager/aarch64-darwin.nix;
            inherit hostname;
          })
      );

    inherit (self.packages.x86_64-linux) egoengine;
  };
}
