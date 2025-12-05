{
  inputs,
  outputs,
  lib,
  ...
}: {
  nixpkgs = {
    overlays = [
      inputs.neovim-nightly.overlays.default
      outputs.overlays.default
      outputs.overlays.darwin
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config.allowUnfree = lib.mkDefault true;
  };

  nix = {
    optimise.automatic = lib.mkDefault true;
    settings = {
      experimental-features = lib.mkDefault "nix-command flakes";
      extra-substituters = lib.mkDefault [
        "https://nix-community.cachix.org"
        "https://neovim-nightly.cachix.org"
        "https://joshsymonds.cachix.org"
        "https://devenv.cachix.org"
      ];
      extra-trusted-public-keys = lib.mkDefault [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "neovim-nightly.cachix.org-1:fLrV5fy41LFKwyLAxJ0H13o6FOVGc4k6gXB5Y1dqtWw="
        "joshsymonds.cachix.org-1:DajO7Bjk/Q8eQVZQZC/AWOzdUst2TGp8fHS/B1pua2c="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
      trusted-users = ["root" "joshsymonds"];
    };
  };
}
