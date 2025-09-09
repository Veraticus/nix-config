{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ../minimal.nix  # Use minimal config for this resource-constrained box
  ];

  # Override any specific settings for bluedesert if needed
  programs.zsh.shellAliases = lib.mkForce {
    # Remote build through ultraviolet
    update = "ssh -i ~/.ssh/github joshsymonds@172.31.0.200 'cd ~/nix-config && sudo env NIX_SSHOPTS=\"-i /home/joshsymonds/.ssh/github\" nixos-rebuild switch --flake .#bluedesert --target-host joshsymonds@172.31.0.201 --sudo'";
    ll = "ls -la";
    l = "ls -l";
    # Monitoring aliases specific to this box
    diskspace = "df -h / && du -sh /nix/store";
    zwave-logs = "sudo podman logs zwave-js-ui 2>/dev/null || echo 'Z-Wave container not running'";
    zwave-ui = "echo 'Z-Wave JS UI: http://bluedesert:8091'";
    ntfy-status = "systemctl status ntfy-sh";
    ntfy-test = "curl -d 'Test notification from bluedesert' localhost:8093/test";
  };
}
