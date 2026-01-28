{pkgs, ...}: {
  imports = [
    ../headless-x86_64-linux.nix
  ];

  home.packages = with pkgs; [
    git-lfs
    jq
    sqlite
  ];

  programs.zsh.shellAliases = {
    infer = "OLLAMA_HOST=127.0.0.1 ollama run";
    models = "OLLAMA_HOST=127.0.0.1 ollama list";
  };
}
