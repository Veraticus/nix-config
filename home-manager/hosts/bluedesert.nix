{ inputs, lib, config, pkgs, ... }: {
  imports = [
    ../minimal.nix  # Use minimal config for this resource-constrained box
  ];

  # Override any specific settings for bluedesert if needed
  programs.zsh.shellAliases = {
    update = "sudo nixos-rebuild switch --flake \".#$(hostname)\"";
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
