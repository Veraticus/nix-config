{ inputs, darwin, lib, config, pkgs, ... }: {
  imports = [
    ./common.nix
    ./aerospace
    ./devspaces-client
    ./ssh-hosts
    ./ssh-config
    ./linkpearl
  ];

  home.homeDirectory = "/Users/joshsymonds";

  # Fonts managed by Nix
  home.packages = with pkgs; [
    maple-mono.NF-CN-unhinted
  ];

  programs.zsh.shellAliases.update = "sudo darwin-rebuild switch --flake \".#$(hostname -s)\" --option warn-dirty false";
  programs.kitty.font.size = 13;
}
