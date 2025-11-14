{
  config,
  inputs,
  lib,
  pkgs,
  modulesPath,
  outputs,
  ...
}: let
  targetSystem = outputs.nixosConfigurations.stygianlibrary-bootstrap.config.system.build.toplevel;
  inherit (pkgs) util-linux jq gptfdisk e2fsprogs dosfstools;
in {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.config.allowUnfree = true;
  hardware.enableAllFirmware = true;

  services.openssh.enable = true;

  environment.systemPackages = [ util-linux jq gptfdisk e2fsprogs dosfstools ];

  services.getty.helpLine = ''
    ███████╗████████╗██╗   ██╗ ██████╗ ██╗ █████╗ ███╗   ██╗██╗      ██╗██╗   ██╗
    ██╔════╝╚══██╔══╝██║   ██║██╔════╝ ██║██╔══██╗████╗  ██║██║  ██╗██╔╝██║   ██║
    ███████╗   ██║   ██║   ██║██║  ███╗██║███████║██╔██╗ ██║╚██╗ ██╔╝██║ ██║   ██║
    ╚════██║   ██║   ██║   ██║██║   ██║██║██╔══██║██║╚██╗██║ ╚████╔╝ ██║ ██║   ██║
    ███████║   ██║   ╚██████╔╝╚██████╔╝██║██║  ██║██║ ╚████║  ╚██╔╝  ██║ ╚██████╔╝
    ╚══════╝   ╚═╝    ╚═════╝  ╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═════╝

    Stygianlibrary auto installer running. All data on the target disk will be erased.
    Progress logs appear here; system powers off when complete.
  '';

  systemd.services.stygian-auto-install = {
    description = "Partition disk and install stygianlibrary bootstrap";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];
    path = [ util-linux jq gptfdisk e2fsprogs dosfstools pkgs.coreutils pkgs.mount pkgs.systemd ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
    script = ''
      set -euxo pipefail

      wait_for() {
        local tries=0
        until "$@"; do
          tries=$((tries + 1))
          if [[ $tries -ge 10 ]]; then
            return 1
          fi
          sleep 1
        done
      }

      echo "Selecting installation disk..."
      disk="''${INSTALL_DISK:-}"
      if [[ -z "$disk" ]]; then
        disk=$(${util-linux}/bin/lsblk --json --bytes --output NAME,SIZE,TYPE,RM | ${jq}/bin/jq -r '.blockdevices | map(select(.type == "disk" and (.rm == 0 or .rm == "0"))) | sort_by(.size) | reverse | .[0].name // empty')
        if [[ -n "$disk" ]]; then
          disk="/dev/$disk"
        fi
      fi

      if [[ -z "$disk" || ! -b "$disk" ]]; then
        echo "Could not determine install disk" >&2
        exit 1
      fi

      echo "Installing to $disk"

      ${gptfdisk}/bin/sgdisk --zap-all "$disk"
      ${gptfdisk}/bin/sgdisk -n1:1MiB:+1G -t1:ef00 -c1:STYGIAN-EFI "$disk"
      ${gptfdisk}/bin/sgdisk -n2:0:+64G -t2:8300 -c2:STYGIAN-SYSTEM "$disk"
      ${gptfdisk}/bin/sgdisk -n3:0:+32G -t3:8300 -c3:STYGIAN-PERSIST "$disk"
      ${gptfdisk}/bin/sgdisk -n4:0:0 -t4:8300 -c4:STYGIAN-MODELS "$disk"
      ${util-linux}/bin/partprobe "$disk"
      sleep 2

      wait_for [ -b /dev/disk/by-partlabel/STYGIAN-EFI ]
      wait_for [ -b /dev/disk/by-partlabel/STYGIAN-SYSTEM ]
      wait_for [ -b /dev/disk/by-partlabel/STYGIAN-PERSIST ]
      wait_for [ -b /dev/disk/by-partlabel/STYGIAN-MODELS ]

      echo "Formatting partitions..."
      ${dosfstools}/bin/mkfs.vfat -F32 -n STYGIAN-EFI /dev/disk/by-partlabel/STYGIAN-EFI
      ${e2fsprogs}/bin/mkfs.ext4 -F -L STYGIAN-SYSTEM /dev/disk/by-partlabel/STYGIAN-SYSTEM
      ${e2fsprogs}/bin/mkfs.ext4 -F -L STYGIAN-PERSIST /dev/disk/by-partlabel/STYGIAN-PERSIST
      ${e2fsprogs}/bin/mkfs.ext4 -F -L STYGIAN-MODELS /dev/disk/by-partlabel/STYGIAN-MODELS

      echo "Mounting target..."
      mount /dev/disk/by-partlabel/STYGIAN-SYSTEM /mnt
      mkdir -p /mnt/boot /mnt/persist /mnt/models
      mount /dev/disk/by-partlabel/STYGIAN-EFI /mnt/boot
      mount /dev/disk/by-partlabel/STYGIAN-PERSIST /mnt/persist
      mount /dev/disk/by-partlabel/STYGIAN-MODELS /mnt/models

      chmod 755 /mnt/persist
      install -d -m 0755 -o root -g root /mnt/persist/ollama

      echo "Running nixos-install with prebuilt system..."
      ${config.system.build.nixos-install}/bin/nixos-install \
        --system ${targetSystem} \
        --root /mnt \
        --no-root-passwd \
        --no-channel-copy \
        --cores 0

      echo "Syncing and powering off..."
      sync
      umount -R /mnt || true
      ${pkgs.systemd}/bin/systemctl poweroff
    '';
  };
}
