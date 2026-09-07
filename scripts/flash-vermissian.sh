#!/usr/bin/env bash
# flash-vermissian.sh — installs the vermissian NixOS closure onto the
# new 4TB NVMe while booted from vermissian's OLD boot drive.
#
# The MS-A2 has three M.2 slots, so the new drive sits alongside the old
# one and this host installs itself: no USB, no installer ISO, builds
# happen on the fastest box in the fleet, and the old drive stays
# bootable as a fallback until it is deliberately wiped.
#
# What this does, in order (mirrors modules/installer-iso/install.sh,
# minus the kit-partition plumbing):
#   1. Preflight: tools present, target disk exists at the serial-locked
#      by-id path from hosts/vermissian/disko.nix, target is NOT the disk
#      the running system booted from, no leftover cryptroot mapping.
#   2. disko --mode disko: partition, LUKS (passphrase read from
#      /tmp/secret.key, the btrfs-impermanence module's passwordFile),
#      btrfs subvolumes, mount under /mnt.
#   3. @root-blank snapshot (impermanence rollback target; never created
#      by Nix, first boot fails in initrd without it).
#   4. Identity: copy THIS host's SSH host keypair and agekey into
#      /mnt/etc (for the install-time chroot activation) and /mnt/persist
#      (for the running system) so the new install keeps the same agenix
#      identity — no re-keying of any secret.
#   5. sbctl create-keys, staged to BOTH /mnt/var/lib/sbctl (nixos-install
#      signs the first UKI) and /mnt/persist/var/lib/sbctl (survives the
#      first rollback).
#   6. nixos-install --flake .#vermissian --root /mnt --no-root-passwd
#   7. Data copy: /home, /var/lib/docker (nodatacow), the other persisted
#      /var/lib dirs, /root, /etc/machine-id. Docker must be stopped.
#
# Usage (from ~/nix-config on the vermissian-4tb branch, with the by-id
# path filled in and committed — flakes only see tracked files):
#   ./scripts/flash-vermissian.sh              # full run
#   ./scripts/flash-vermissian.sh --dry-run    # preflight + disko dry-run only
#   ./scripts/flash-vermissian.sh --copy-only  # re-run step 7 against a
#                                              # mounted /mnt (e.g. after a
#                                              # second quiesce)
#
# Afterwards: reboot into the new drive, then follow the Secure Boot and
# TPM enrollment steps printed at the end.
set -euo pipefail

DRY_RUN=0
COPY_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --copy-only) COPY_ONLY=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

HOSTNAME_TARGET="vermissian"
FLAKE_REF=".#${HOSTNAME_TARGET}"
DISKO_FILE="hosts/${HOSTNAME_TARGET}/disko.nix"
MNT="/mnt"
CRYPTROOT="/dev/mapper/cryptroot"
PLACEHOLDER="FILL-IN-4TB-SERIAL"
# btrfs-impermanence sets luks.passwordFile to this; disko does NOT prompt.
SECRET_KEY="/tmp/secret.key"
# Everything the persist list in disko.nix needs copied from the running
# system. /var/lib/sbctl is generated fresh (step 5), /var/lib/nixos and
# /var/lib/systemd are copied so uid/gid maps and timer stamps carry over.
PERSIST_DIRS=(
  /var/lib/nixos
  /var/lib/systemd
  /var/lib/tailscale
  /var/lib/cloudflare-warp
  /var/lib/cloudflared
  /var/lib/containers
  /root
)

red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
log()    { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
abort()  { red "ABORT: $1"; red "No destructive operations performed."; exit 1; }

# ── Tooling: re-exec under nix shell if anything is missing ─────────────
# None of these are installed on vermissian's running system.
NEEDED=(disko sbctl btrfs cryptsetup rsync nixos-install)
missing=()
for t in "${NEEDED[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [ "${#missing[@]}" -gt 0 ] && [ -z "${FLASH_VERMISSIAN_IN_SHELL:-}" ]; then
  yellow "Missing in PATH: ${missing[*]} — re-running under nix shell"
  exec env FLASH_VERMISSIAN_IN_SHELL=1 nix shell \
    nixpkgs#disko nixpkgs#sbctl nixpkgs#btrfs-progs nixpkgs#cryptsetup \
    nixpkgs#rsync nixpkgs#nixos-install-tools \
    --command "$0" "$@"
fi
for t in "${NEEDED[@]}"; do
  command -v "$t" >/dev/null 2>&1 || abort "$t still missing after nix shell"
done

# ── Preflight ───────────────────────────────────────────────────────────
bold "vermissian 4TB flash — preflight"
echo

[ -f flake.nix ] || abort "run from the nix-config checkout root"
[ "$(hostname)" = "$HOSTNAME_TARGET" ] || abort "this script runs ON vermissian (hostname is $(hostname))"
[ -f "$DISKO_FILE" ] || abort "$DISKO_FILE not found"

if grep -q "$PLACEHOLDER" "$DISKO_FILE"; then
  abort "$DISKO_FILE still has the $PLACEHOLDER placeholder. Seat the drive, then:
    ls -l /dev/disk/by-id/ | grep nvme
  and put the new drive's nvme-<MODEL>_<SERIAL> path in $DISKO_FILE, commit, re-run."
fi

EXPECTED_DISK="$(sed -n 's/.*device = "\(\/dev\/disk\/by-id\/[^"]*\)".*/\1/p' "$DISKO_FILE" | head -1)"
[ -n "$EXPECTED_DISK" ] || abort "could not read device path from $DISKO_FILE"
[ -e "$EXPECTED_DISK" ] || abort "$EXPECTED_DISK does not exist. Wrong serial, or drive not seated / not detected."
ACTUAL_DEV="$(readlink -f "$EXPECTED_DISK")"

# git must see the disko.nix edit, or the flake evaluates the placeholder.
# -c safe.directory: this runs under sudo in a checkout owned by joshsymonds.
if ! git -c safe.directory='*' diff --quiet -- "$DISKO_FILE" \
   || ! git -c safe.directory='*' diff --cached --quiet -- "$DISKO_FILE"; then
  abort "$DISKO_FILE has uncommitted changes; flakes only see committed/staged files. Commit it first."
fi

# The running system's root device must never be the target.
ROOT_SRC="$(findmnt -no SOURCE /)"
ROOT_DISK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -1)"
[ -n "$ROOT_DISK" ] || abort "could not determine the running root's parent disk"
[ "/dev/$ROOT_DISK" != "$ACTUAL_DEV" ] || abort "target $ACTUAL_DEV IS the running system's boot disk"
if lsblk -no MOUNTPOINTS "$ACTUAL_DEV" | grep -q .; then
  abort "$ACTUAL_DEV has mounted partitions; it is in use"
fi

if [ "$COPY_ONLY" = 0 ] && [ -e "$CRYPTROOT" ]; then
  abort "$CRYPTROOT already exists (partial earlier run?). Inspect, then: sudo cryptsetup close cryptroot"
fi

if [ "$COPY_ONLY" = 0 ] && [ "$DRY_RUN" = 0 ]; then
  [ "$(id -u)" = 0 ] || abort "run with sudo (preserving env): sudo -E $0"
  [ -s "$SECRET_KEY" ] || abort "$SECRET_KEY is missing or empty. disko reads the LUKS passphrase from it (no prompt). Create it first:
    (umask 077; read -rs 'PW?LUKS passphrase: '; printf '%s' \"\$PW\" > $SECRET_KEY; unset PW)"
fi

echo "Target:  $EXPECTED_DISK"
echo "         -> $ACTUAL_DEV  $(lsblk -dno SIZE,MODEL,SERIAL "$ACTUAL_DEV")"
echo "Running: $ROOT_SRC on /dev/$ROOT_DISK (will NOT be touched)"
echo
bold "Disk inventory:"
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,MOUNTPOINTS
echo

# ── Data copy (step 7), factored so --copy-only can re-run it ───────────
copy_data() {
  log "Checking the copy preconditions"
  mountpoint -q "$MNT" || abort "$MNT is not mounted"
  mountpoint -q "$MNT/persist" || abort "$MNT/persist is not mounted (disko layout not up?)"
  mountpoint -q "$MNT/home" || abort "$MNT/home is not mounted"
  if systemctl is-active --quiet docker; then
    abort "docker.service is running. Stop it (and anything else writing to /home) first:
    sudo systemctl stop docker.socket docker.service"
  fi

  log "Persist backing for Docker: nodatacow"
  mkdir -p "$MNT/persist/var/lib/docker"
  chattr +C "$MNT/persist/var/lib/docker"

  log "rsync /home -> $MNT/home (this is the long one)"
  rsync -aHAX --numeric-ids --info=progress2 /home/ "$MNT/home/"

  log "rsync /var/lib/docker -> $MNT/persist/var/lib/docker"
  rsync -aHAX --numeric-ids --info=progress2 /var/lib/docker/ "$MNT/persist/var/lib/docker/"

  for d in "${PERSIST_DIRS[@]}"; do
    [ -d "$d" ] || { yellow "skip $d (absent on source)"; continue; }
    log "rsync $d -> $MNT/persist$d"
    mkdir -p "$MNT/persist$d"
    rsync -aHAX --numeric-ids "$d/" "$MNT/persist$d/"
  done

  log "machine-id"
  mkdir -p "$MNT/persist/etc"
  install -m 444 /etc/machine-id "$MNT/persist/etc/machine-id"
}

if [ "$COPY_ONLY" = 1 ]; then
  [ "$(id -u)" = 0 ] || abort "run with sudo"
  copy_data
  green "Copy complete."
  exit 0
fi

# ── Dry run: show disko's plan and stop ─────────────────────────────────
if [ "$DRY_RUN" = 1 ]; then
  log "disko --dry-run (prints the partitioning script, executes nothing)"
  disko --mode disko --dry-run --flake "$FLAKE_REF"
  echo
  green "Dry run complete. Preflight passed for $EXPECTED_DISK."
  exit 0
fi

# ── Confirmation ────────────────────────────────────────────────────────
bold "About to ERASE $EXPECTED_DISK and install $HOSTNAME_TARGET onto it."
yellow "The running system on /dev/$ROOT_DISK is not touched."
echo
read -rp "Type '$HOSTNAME_TARGET' to proceed: " CONFIRM
[ "$CONFIRM" = "$HOSTNAME_TARGET" ] || abort "not confirmed (got '$CONFIRM')"

# ── 2. disko ────────────────────────────────────────────────────────────
log "disko (LUKS passphrase from $SECRET_KEY)"
disko --mode disko --flake "$FLAKE_REF"
mountpoint -q "$MNT" || abort "disko finished but $MNT is not mounted"
rm -f "$SECRET_KEY"

# ── 3. @root-blank ──────────────────────────────────────────────────────
log "@root-blank snapshot"
TOP="$(mktemp -d /tmp/btrfs-top.XXXXXX)"
mount -t btrfs -o subvol=/ "$CRYPTROOT" "$TOP"
btrfs subvolume snapshot -r "$TOP/@root" "$TOP/@root-blank"
umount "$TOP"; rmdir "$TOP"

# ── 4. Identity: same host keys, same agekey, no re-keying ─────────────
# Staged to BOTH $MNT/etc and $MNT/persist/etc (the stygianlibrary
# pattern): nixos-install activates the system inside a chroot where the
# impermanence binds do not exist yet, and activation needs the host key
# and agekey at /etc/ssh and /etc/age to decrypt agenix secrets. Without
# the /etc copies activation aborts and the boot loader never gets
# installed. The @root copies are discarded by the first rollback; the
# /persist copies are what the running system sees.
log "Identity -> $MNT/etc and $MNT/persist/etc"
for base in "$MNT" "$MNT/persist"; do
  install -d -m 755 "$base/etc/ssh" "$base/etc/age"
  install -m 600 -o 0 -g 0 /etc/ssh/ssh_host_ed25519_key     "$base/etc/ssh/"
  install -m 644 -o 0 -g 0 /etc/ssh/ssh_host_ed25519_key.pub "$base/etc/ssh/"
  install -m 600 -o 0 -g 0 "/etc/age/${HOSTNAME_TARGET}.agekey" "$base/etc/age/"
done

# ── 5. Secure Boot signing keys ────────────────────────────────────────
log "sbctl create-keys -> staged to $MNT/var/lib/sbctl and $MNT/persist/var/lib/sbctl"
SBTMP="$(mktemp -d /tmp/sbctl-stage.XXXXXX)"
# sbctl writes to /var/lib/sbctl unconditionally; this running system has
# none, so generate here and move them off the old root afterwards.
[ -e /var/lib/sbctl/keys ] && abort "/var/lib/sbctl/keys already exists on the running system; refusing to overwrite"
sbctl create-keys
mkdir -p "$MNT/var/lib/sbctl" "$MNT/persist/var/lib/sbctl"
cp -a /var/lib/sbctl/. "$MNT/var/lib/sbctl/"
cp -a /var/lib/sbctl/. "$MNT/persist/var/lib/sbctl/"
mv /var/lib/sbctl "$SBTMP/sbctl-generated-for-new-install"
yellow "sbctl keys moved off the running system to $SBTMP (copies are on the target)"

# ── 6. nixos-install ───────────────────────────────────────────────────
log "nixos-install $FLAKE_REF -> $MNT"
nixos-install --flake "$FLAKE_REF" --root "$MNT" --no-root-passwd

# ── 7. Data ────────────────────────────────────────────────────────────
copy_data

green "
═══════════════════════════════════════════════════════════════════════
  Install complete: $HOSTNAME_TARGET on $EXPECTED_DISK
═══════════════════════════════════════════════════════════════════════

Next:
  1. Reboot; pick the new drive's 'Linux Boot Manager' entry (or set it
     first in BIOS). Enter the LUKS passphrase at the prompt.
  2. Check identity survived: tailscale status, warp-cli status,
     systemctl status cloudflared-tunnel docker; docker images | head.
  3. Merge the vermissian-4tb branch to main and run 'update' once —
     proves the persisted sbctl keys sign a new generation.
  4. Secure Boot:  sudo sbctl enroll-keys --microsoft ; sudo sbctl status
     Then in BIOS enable Secure Boot. Confirm: bootctl status.
  5. TPM auto-unlock (ONLY after Secure Boot is on — PCR 7 changes):
       sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \\
         /dev/disk/by-uuid/<luks-partition-uuid>
     (uuid: lsblk -o NAME,UUID,FSTYPE | grep crypto_LUKS). Reboot: unattended.
  6. Once, when calm: clear the TPM in BIOS, reboot, confirm the passphrase
     fallback works, re-enroll.
  7. After a week on the new drive: efibootmgr -B the old entry, wipe the
     old disk, pull it.
"
