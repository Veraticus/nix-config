{pkgs, ...}: {
  imports = [
    ../common.nix
    ../devspaces-host
    ../linkpearl
    ../security-tools
    ../gmailctl
  ];

  home = {
    homeDirectory = "/home/joshsymonds";

    packages = with pkgs; [
      git-lfs
      jq
      sqlite
    ];
  };

  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake \".#$(hostname)\" --option warn-dirty false --accept-flake-config";
    infer = "OLLAMA_HOST=127.0.0.1 ollama run";
    models = "OLLAMA_HOST=127.0.0.1 ollama list";
  };

  systemd.user.startServices = "sd-switch";
}
