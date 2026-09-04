# vermissian disk layout — single 4TB NVMe, LUKS-encrypted btrfs with
# impermanence. Same module and subvolume layout as gnomon.
#
# The `device` path is serial-locked, the stygianlibrary pattern rather
# than gnomon's REPLACE-AT-INSTALL sentinel: this host is installed from
# its own running system (scripts/flash-vermissian.sh) with the old boot
# drive still present in another M.2 slot, so the config itself must be
# incapable of naming the wrong disk. disko fails with "device not found"
# rather than touching anything else. Fill in the real by-id path once
# the drive is seated; the flash script refuses to run while the
# placeholder below is still here.
{...}: {
  imports = [
    ../../modules/disko/btrfs-impermanence.nix
  ];

  btrfs-impermanence = {
    enable = true;
    device = "/dev/disk/by-id/nvme-FILL-IN-4TB-SERIAL";
    luks.enable = true;
    # Matches the 32G VM-SWAP partition the ext4 install had. zram from
    # the dev performance profile sits in front of it.
    swapSizeGiB = 32;

    # /etc/ssh is NOT a directory-bind (see hosts/gnomon/disko.nix for
    # why); only the host keypair is persisted via persistFiles below.
    # /var/lib/sbctl must survive rollback or every rebuild after the
    # first fails to sign its UKI.
    persistDirectories = [
      "/etc/age"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/sbctl"
      "/var/lib/tailscale"
      # WARP enrollment is interactive and headless-painful; keep it.
      "/var/lib/cloudflare-warp"
      # cloudflared tunnel state (tmpfiles creates it cloudflared:cloudflared).
      "/var/lib/cloudflared"
      # Docker is the biggest stateful thing on this host: ~110G of images,
      # volumes (marvin-blackbox-nix-store among them) and build cache that
      # the marvin-blackbox reaper's warm-cache design depends on. Root-owned
      # so a plain entry works. The flash script runs `chattr +C` on the
      # persist backing before the copy so overlay2 layers are nodatacow —
      # CoW + zstd under kind/containerd churn is the wrong default, and
      # btrfs skips compression on nodatacow files anyway.
      "/var/lib/docker"
      # System podman storage (rootless podman lives under ~/.local/share
      # and rides along with @home).
      "/var/lib/containers"
      # root's ~/.docker (registry logins incl. the ghcr cache auth) and
      # ~/.ssh. Small, and losing the registry login every boot is the
      # kind of silent breakage impermanence is supposed to make explicit.
      "/root"
    ];

    persistFiles = [
      "/etc/machine-id"
      "/etc/adjtime"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };
}
