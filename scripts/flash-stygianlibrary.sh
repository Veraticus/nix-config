#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: flash-stygianlibrary.sh /dev/<disk> [nixos-install args]

Completely repartitions the target disk as the stygianlibrary USB layout,
formats the partitions, mounts them under /mnt/stygianlibrary, and runs
`nixos-install --flake .#stygianlibrary` to populate the drive. Any existing
data on the device will be destroyed.

Environment overrides:
  BOOT_SIZE    Size of the EFI partition (default: 1G)
  SYSTEM_SIZE  Size of the root partition (default: 64G)
  PERSIST_SIZE Size of the /persist partition (default: 32G)
EOF
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

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

DEVICE="$1"
shift || true

INSTALL_ARGS=("$@")

if [[ $(id -u) -ne 0 ]]; then
  error "run this script as root"
fi

if [[ ! -b "$DEVICE" ]]; then
  error "${DEVICE} is not a block device"
fi

for cmd in sgdisk partprobe mkfs.vfat mkfs.ext4 nixos-install lsblk mountpoint; do
  require_cmd "$cmd"
done

if lsblk -pnro MOUNTPOINT "$DEVICE" | grep -qvE '^\s*$'; then
  error "${DEVICE} or its partitions are currently mounted"
fi

printf 'This will ERASE ALL DATA on %s. Type "stygianlibrary" to continue: ' "$DEVICE"
read -r response
if [[ "$response" != "stygianlibrary" ]]; then
  error "confirmation failed"
fi

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

printf 'Partitioning %s...\n' "$DEVICE"
sgdisk --zap-all "$DEVICE"
sgdisk -n1:1MiB:+"${BOOT_SIZE}" -t1:ef00 -c1:STYGIAN-BOOT "$DEVICE"
sgdisk -n2:0:+"${SYSTEM_SIZE}" -t2:8300 -c2:STYGIAN-SYSTEM "$DEVICE"
sgdisk -n3:0:+"${PERSIST_SIZE}" -t3:8300 -c3:STYGIAN-PERSIST "$DEVICE"
sgdisk -n4:0:0 -t4:8300 -c4:STYGIAN-MODELS "$DEVICE"
partprobe "$DEVICE"
sleep 2

printf 'Formatting partitions...\n'
mkfs.vfat -F 32 -n STYGIAN-BOOT "$BOOT_PART"
mkfs.ext4 -F -L STYGIAN-SYSTEM "$SYSTEM_PART"
mkfs.ext4 -F -L STYGIAN-PERSIST "$PERSIST_PART"
mkfs.ext4 -F -L STYGIAN-MODELS "$MODELS_PART"

TARGET_MOUNT="/mnt/stygianlibrary"
mkdir -p "$TARGET_MOUNT"

declare -a MOUNT_POINTS=()
cleanup() {
  set +e
  sync
  for (( idx=${#MOUNT_POINTS[@]}-1; idx>=0; idx-- )); do
    mountpoint -q "${MOUNT_POINTS[$idx]}" && umount "${MOUNT_POINTS[$idx]}"
  done
  if [[ -d "$TARGET_MOUNT" ]]; then
    rmdir "$TARGET_MOUNT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

printf 'Mounting target filesystem...\n'
mount "$SYSTEM_PART" "$TARGET_MOUNT"
MOUNT_POINTS+=("$TARGET_MOUNT")

mkdir -p "$TARGET_MOUNT"/boot "$TARGET_MOUNT"/persist "$TARGET_MOUNT"/models
mount "$BOOT_PART" "$TARGET_MOUNT/boot"
MOUNT_POINTS+=("$TARGET_MOUNT/boot")
mount "$PERSIST_PART" "$TARGET_MOUNT/persist"
MOUNT_POINTS+=("$TARGET_MOUNT/persist")
mount "$MODELS_PART" "$TARGET_MOUNT/models"
MOUNT_POINTS+=("$TARGET_MOUNT/models")

chown root:root "$TARGET_MOUNT/persist"
chmod 755 "$TARGET_MOUNT/persist"
install -d -m 0755 -o root -g root "$TARGET_MOUNT/persist/ollama"
chown joshsymonds:users "$TARGET_MOUNT/persist/ollama"
chown joshsymonds:users "$TARGET_MOUNT/models"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

printf 'Running nixos-install for stygianlibrary...\n'
nixos-install \
  --flake "$REPO_ROOT#stygianlibrary" \
  --root "$TARGET_MOUNT" \
  --no-root-passwd \
  "${INSTALL_ARGS[@]}"

printf 'Syncing filesystem buffers...\n'
sync

printf '\nUSB install complete. You can now safely remove %s after unmounting.\n' "$DEVICE"
