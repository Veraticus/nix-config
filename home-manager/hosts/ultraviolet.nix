{pkgs, ...}: {
  imports = [
    ../headless-x86_64-linux.nix
  ];

  home.packages = with pkgs; [
    mediainfo
    ffmpeg
    tcpdump
    lsof
    inetutils
  ];

  programs.git.settings.user.signingkey = "0x374165B74CF6A70C";

  programs.zsh.shellAliases.update-bluedesert = "cd ~/nix-config && sudo env NIX_SSHOPTS='-i /home/joshsymonds/.ssh/github' nixos-rebuild switch --flake '.#bluedesert' --target-host joshsymonds@172.31.0.201 --sudo --option warn-dirty false";
}
