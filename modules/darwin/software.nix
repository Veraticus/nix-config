{ pkgs, ... }: {
  # GUI + CLI apps delivered via nixpkgs (appear in ~/Applications through activation helper)
  environment.systemPackages = with pkgs; [
    aerospace
    eternal-terminal
    firefox
    obsidian
    slack
    slidev
    spotify
  ];

  homebrew = {
    enable = true;
    casks = [
      "1password"
      "1password-cli"
      "readdle-spark"
      "sf-symbols"
    ];
    taps = [
      "FelixKratz/formulae"
      "koekeishiya/formulae"
    ];
    brews = [
      {
        name = "sketchybar";
        restart_service = "changed";
        start_service = true;
        args = [ "HEAD" ];
      }
      "pyenv"
      "borders"
      "qemu"
      "pam-reattach"
      "chruby"
      "ruby-install"
      "xz"
    ];
  };
}
