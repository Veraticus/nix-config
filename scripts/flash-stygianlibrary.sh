#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOU'
Usage: flash-stygianlibrary.sh /dev/<usb device>

Re-images the USB stick with the stygianlibrary bootstrap system. It partitions
and formats the device, installs the bootstrap closure onto the stick, and
leaves the filesystems mounted at /mnt/stygianlibrary for inspection.

Environment overrides:
  BOOT_SIZE     Size of the EFI partition (default: 1G)
  SYSTEM_SIZE   Size of the root partition (default: 64G)
  PERSIST_SIZE  Size of the /persist partition (default: 32G)
  SYSTEM_SPEC   Flake reference to build when SYSTEM_PATH is unset
                (default: .#nixosConfigurations.stygianlibrary-bootstrap.config.system.build.toplevel)
  SYSTEM_PATH   Prebuilt bootstrap closure; skips building SYSTEM_SPEC
EOU
}

error() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "missing required command '$1'"
  fi
}

unmount_device_mounts() {
  local device="$1"
  mapfile -t mounted < <(
    lsblk -pnro NAME,MOUNTPOINT "$device" | awk '$2 != "" {print $1"|"$2}'
  )
  for (( idx=${#mounted[@]}-1; idx>=0; idx-- )); do
    IFS='|' read -r part mnt <<<"${mounted[$idx]}"
    if mountpoint -q "$mnt"; then
      umount "$mnt"
    fi
  done
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

DEVICE="$1"

if [[ $(id -u) -ne 0 ]]; then
  error "run this script as root"
fi

for cmd in nix nix-store nix-env sgdisk partprobe mkfs.vfat mkfs.ext4 nixos-install \
  nixos-enter bootctl lsblk mountpoint awk sync; do
  require_cmd "$cmd"
done

if [[ ! -b "$DEVICE" ]]; then
  error "${DEVICE} is not a block device"
fi

printf 'This will ERASE ALL DATA on %s. Type "stygianlibrary" to continue: ' "$DEVICE"
read -r response
if [[ "$response" != "stygianlibrary" ]]; then
  error "confirmation failed"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BOOT_SIZE="${BOOT_SIZE:-1G}"
SYSTEM_SIZE="${SYSTEM_SIZE:-64G}"
PERSIST_SIZE="${PERSIST_SIZE:-32G}"

case "$DEVICE" in
  *[0-9]) part_prefix="${DEVICE}p" ;;
  *) part_prefix="$DEVICE" ;;
    esac

BOOT_PART="${part_prefix}1"
SYSTEM_PART="${part_prefix}2"
PERSIST_PART="${part_prefix}3"
MODELS_PART="${part_prefix}4"

if lsblk -pnro MOUNTPOINT "$DEVICE" | grep -qvE '^\s*$'; then
  printf '%s or its partitions appear mounted; attempting to unmount...\n' "$DEVICE"
  unmount_device_mounts "$DEVICE"
fi

TARGET_MOUNT="/mnt/stygianlibrary"
if mountpoint -q "$TARGET_MOUNT"; then
  umount -R "$TARGET_MOUNT"
fi
mkdir -p "$TARGET_MOUNT"

DEFAULT_SYSTEM_SPEC="${REPO_ROOT}#nixosConfigurations.stygianlibrary-bootstrap.config.system.build.toplevel"
SYSTEM_SPEC="${SYSTEM_SPEC:-$DEFAULT_SYSTEM_SPEC}"

if [[ -n "${SYSTEM_PATH:-}" ]]; then
  if [[ ! -e "$SYSTEM_PATH" ]]; then
    error "SYSTEM_PATH '$SYSTEM_PATH' does not exist"
  fi
else
  if [[ -e "$SYSTEM_SPEC" ]]; then
    SYSTEM_PATH="$SYSTEM_SPEC"
  else
    printf 'Building bootstrap system (%s)...\n' "$SYSTEM_SPEC"
    SYSTEM_PATH=$(nix build "$SYSTEM_SPEC" --no-link --print-out-paths | tail -n1)
  fi
fi

printf 'Using system closure %s\n' "$SYSTEM_PATH"

printf 'Partitioning %s...\n' "$DEVICE"
sgdisk --zap-all "$DEVICE" || true
sgdisk -n1:1MiB:+"${BOOT_SIZE}" -t1:ef00 -c1:STYGIAN-EFI "$DEVICE"
sgdisk -n2:0:+"${SYSTEM_SIZE}" -t2:8300 -c2:STYGIAN-SYSTEM "$DEVICE"
sgdisk -n3:0:+"${PERSIST_SIZE}" -t3:8300 -c3:STYGIAN-PERSIST "$DEVICE"
sgdisk -n4:0:0 -t4:8300 -c4:STYGIAN-MODELS "$DEVICE"
partprobe "$DEVICE"
sleep 2

printf 'Formatting partitions...\n'
mkfs.vfat -F 32 -n STYGIAN-EFI "$BOOT_PART"
mkfs.ext4 -F -L STYGIAN-SYSTEM "$SYSTEM_PART"
mkfs.ext4 -F -L STYGIAN-PERSIST "$PERSIST_PART"
mkfs.ext4 -F -L STYGIAN-MODELS "$MODELS_PART"

printf 'Mounting filesystems at %s...\n' "$TARGET_MOUNT"
mount "$SYSTEM_PART" "$TARGET_MOUNT"
mkdir -p "$TARGET_MOUNT"/boot "$TARGET_MOUNT"/persist "$TARGET_MOUNT"/models
mount "$BOOT_PART" "$TARGET_MOUNT/boot"
mount "$PERSIST_PART" "$TARGET_MOUNT/persist"
mount "$MODELS_PART" "$TARGET_MOUNT/models"

chown root:root "$TARGET_MOUNT/persist"
chmod 755 "$TARGET_MOUNT/persist"
install -d -m 0755 -o root -g root "$TARGET_MOUNT/persist/ollama"

printf 'Initializing target store...\n'
mkdir -p "$TARGET_MOUNT/nix/store"
nix-store --store "$TARGET_MOUNT" --init

printf 'Copying system closure to USB...\n'
STORE_URI="local?root=$TARGET_MOUNT"
nix copy --log-format bar-with-logs --no-check-sigs --to "$STORE_URI" "$SYSTEM_PATH"

printf 'Running nixos-install...\n'
nixos-install \
  --system "$SYSTEM_PATH" \
  --root "$TARGET_MOUNT" \
  --no-channel-copy \
  --no-root-passwd \
  --no-bootloader

if [[ ! -f "$TARGET_MOUNT/etc/os-release" && -f "$SYSTEM_PATH/etc/os-release" ]]; then
  printf 'Populating /etc/os-release...\n'
  install -D -m 0644 "$SYSTEM_PATH/etc/os-release" "$TARGET_MOUNT/etc/os-release"
fi

TARGET_SWITCH_BIN="/nix/var/nix/profiles/system/bin/switch-to-configuration"
TARGET_SWITCH_SW="/nix/var/nix/profiles/system/sw/bin/switch-to-configuration"

find_switch() {
  for candidate in "$TARGET_SWITCH_BIN" "$TARGET_SWITCH_SW"; do
    if [[ -x "$TARGET_MOUNT$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

TARGET_SWITCH_PATH=$(find_switch || true)
if [[ -z "$TARGET_SWITCH_PATH" ]]; then
  printf 'Forcing /nix/var/nix/profiles/system to %s...\n' "$SYSTEM_PATH"
  nix-env --store "$TARGET_MOUNT" -p "$TARGET_MOUNT/nix/var/nix/profiles/system" --set "$SYSTEM_PATH"
  TARGET_SWITCH_PATH=$(find_switch || true)
fi

if [[ -z "$TARGET_SWITCH_PATH" ]]; then
  error "switch-to-configuration not found on target"
fi

printf 'Installing boot loader...\n'
ln -sfn /proc/mounts "$TARGET_MOUNT/etc/mtab"
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root "$TARGET_MOUNT" --command "set -euo pipefail; $TARGET_SWITCH_PATH boot"

printf 'Verifying boot loader...\n'
bootctl --path "$TARGET_MOUNT/boot" status

sync

printf '\nUSB install complete. The filesystems remain mounted at %s.\n' "$TARGET_MOUNT"
printf 'When finished inspecting, run: sudo umount -R %s\n' "$TARGET_MOUNT"
