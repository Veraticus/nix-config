#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOU'
Usage: flash-stygianlibrary.sh /dev/<usb device>

Re-images the USB stick with the full stygianlibrary system. It partitions and
formats the device, installs the full closure onto the stick, and leaves the
filesystems mounted at /mnt/stygianlibrary for inspection.

Environment overrides:
  BOOT_SIZE     Size of the EFI partition (default: 1G)
  SYSTEM_SPEC   Flake reference to build when SYSTEM_PATH is unset
                (default: .#nixosConfigurations.stygianlibrary.config.system.build.toplevel)
  SYSTEM_PATH   Prebuilt system closure; skips building SYSTEM_SPEC
  REPO_URL      Git URL to clone into /persist/nix-config
                (default: https://github.com/Veraticus/nix-config)
  CRYPT_NAME    Mapper name for the unlocked LUKS device (default: stygiancrypt)
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

prompt_luks_passphrase() {
  local pass1 pass2
  while true; do
    read -rsp "Enter LUKS passphrase: " pass1
    printf '\n'
    read -rsp "Confirm LUKS passphrase: " pass2
    printf '\n'
    if [[ -z "$pass1" ]]; then
      printf 'Passphrase cannot be empty.\n' >&2
      continue
    fi
    if [[ "$pass1" != "$pass2" ]]; then
      printf 'Passphrases do not match; try again.\n' >&2
      continue
    fi
    LUKS_PASSPHRASE="$pass1"
    break
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

for cmd in cryptsetup git nix nix-store nix-env sgdisk partprobe mkfs.vfat mkfs.ext4 nixos-install \
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
CRYPT_NAME="${CRYPT_NAME:-stygiancrypt}"

case "$DEVICE" in
  *[0-9]) part_prefix="${DEVICE}p" ;;
  *) part_prefix="$DEVICE" ;;
    esac

BOOT_PART="${part_prefix}1"
LUKS_PART="${part_prefix}2"
MAPPER_PATH="/dev/mapper/$CRYPT_NAME"

if lsblk -pnro MOUNTPOINT "$DEVICE" | grep -qvE '^\s*$'; then
  printf '%s or its partitions appear mounted; attempting to unmount...\n' "$DEVICE"
  unmount_device_mounts "$DEVICE"
fi

TARGET_MOUNT="/mnt/stygianlibrary"
if mountpoint -q "$TARGET_MOUNT"; then
  umount -R "$TARGET_MOUNT"
fi
mkdir -p "$TARGET_MOUNT"

DEFAULT_SYSTEM_SPEC="${REPO_ROOT}#nixosConfigurations.stygianlibrary.config.system.build.toplevel"
SYSTEM_SPEC="${SYSTEM_SPEC:-$DEFAULT_SYSTEM_SPEC}"

if [[ -n "${SYSTEM_PATH:-}" ]]; then
  if [[ ! -e "$SYSTEM_PATH" ]]; then
    error "SYSTEM_PATH '$SYSTEM_PATH' does not exist"
  fi
else
  if [[ -e "$SYSTEM_SPEC" ]]; then
    SYSTEM_PATH="$SYSTEM_SPEC"
  else
    printf 'Building stygianlibrary system (%s)...\n' "$SYSTEM_SPEC"
    SYSTEM_PATH=$(nix build "$SYSTEM_SPEC" --no-link --print-out-paths | tail -n1)
  fi
fi

printf 'Using system closure %s\n' "$SYSTEM_PATH"

printf 'Partitioning %s...\n' "$DEVICE"
sgdisk --zap-all "$DEVICE" || true
sgdisk -n1:1MiB:+"${BOOT_SIZE}" -t1:ef00 -c1:STYGIAN-EFI "$DEVICE"
sgdisk -n2:0:0 -t2:8300 -c2:STYGIAN-LUKS "$DEVICE"
partprobe "$DEVICE"
sleep 2

prompt_luks_passphrase

printf 'Formatting partitions and creating LUKS container...\n'
mkfs.vfat -F 32 -n STYGIAN-EFI "$BOOT_PART"
if [[ -e "$MAPPER_PATH" ]]; then
  error "$MAPPER_PATH already exists; close it before continuing"
fi
printf '%s' "$LUKS_PASSPHRASE" | cryptsetup luksFormat --type luks2 --batch-mode "$LUKS_PART" -
printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$LUKS_PART" "$CRYPT_NAME" --key-file - --allow-discards
unset LUKS_PASSPHRASE
mkfs.ext4 -F -L STYGIAN-SYSTEM "$MAPPER_PATH"

printf 'Mounting filesystems at %s...\n' "$TARGET_MOUNT"
mount "$MAPPER_PATH" "$TARGET_MOUNT"
mkdir -p "$TARGET_MOUNT"/boot "$TARGET_MOUNT"/persist "$TARGET_MOUNT"/models
mount "$BOOT_PART" "$TARGET_MOUNT/boot"

chown root:root "$TARGET_MOUNT/persist"
chmod 755 "$TARGET_MOUNT/persist"
chmod 755 "$TARGET_MOUNT/models"
install -d -m 0755 -o root -g root "$TARGET_MOUNT/persist/ollama"

REPO_URL="${REPO_URL:-https://github.com/Veraticus/nix-config}"
TARGET_REPO_PATH="$TARGET_MOUNT/persist/nix-config"
printf 'Syncing nix-config repo into %s...\n' "$TARGET_REPO_PATH"
if [[ -d "$TARGET_REPO_PATH/.git" ]]; then
  git -C "$TARGET_REPO_PATH" fetch origin
  git -C "$TARGET_REPO_PATH" reset --hard origin/main
else
  rm -rf "$TARGET_REPO_PATH"
  git clone "$REPO_URL" "$TARGET_REPO_PATH"
fi

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
printf 'When finished inspecting, run:\n'
printf '  sudo umount -R %s\n' "$TARGET_MOUNT"
printf '  sudo cryptsetup close %s\n' "$CRYPT_NAME"
