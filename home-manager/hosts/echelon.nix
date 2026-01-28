{pkgs, ...}: {
  imports = [
    ../headless-x86_64-linux.nix
  ];

  home.packages = with pkgs; [
    traceroute
    mtr
    tcpdump
  ];
}
