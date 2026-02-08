# Daily backups of media service configs to NAS.
# The *arr apps maintain their own backup directories with DB snapshots;
# we ship those plus other service configs to /mnt/backups nightly.
{pkgs, ...}: let
  backupScript = pkgs.writeShellScript "media-backup" ''
    #!${pkgs.bash}/bin/bash
    set -uo pipefail

    BACKUP_ROOT="/mnt/backups/media-services"
    DATE=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
    KEEP_DAYS=7

    echo "=== Media service backup starting at $(${pkgs.coreutils}/bin/date) ==="

    # Ensure NAS is mounted
    if ! ${pkgs.coreutils}/bin/mountpoint -q /mnt/backups 2>/dev/null; then
      echo "Mounting /mnt/backups..."
      ${pkgs.systemd}/bin/systemctl start mnt-backups.automount || {
        echo "ERROR: Failed to mount /mnt/backups"
        exit 1
      }
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$BACKUP_ROOT"

    backup_dir() {
      local name="$1" src="$2"
      local dest="$BACKUP_ROOT/$name"

      if [ ! -d "$src" ]; then
        echo "$name: source $src not found, skipping"
        return
      fi

      ${pkgs.coreutils}/bin/mkdir -p "$dest"
      echo "$name: backing up $src"
      ${pkgs.gnutar}/bin/tar czf "$dest/$name-$DATE.tar.gz" \
        -C "$(${pkgs.coreutils}/bin/dirname "$src")" \
        "$(${pkgs.coreutils}/bin/basename "$src")" 2>/dev/null || {
        echo "$name: WARNING - backup had errors (may be partial)"
      }
      echo "$name: done"
    }

    # *arr services - back up their built-in backup dirs (contain DB snapshots)
    # plus the config.xml for each
    backup_dir "sonarr" "/var/lib/sonarr/.config/NzbDrone/Backups"
    backup_dir "radarr" "/var/lib/radarr/.config/Radarr/Backups"
    backup_dir "readarr" "/var/lib/readarr/.config/Readarr/Backups"
    backup_dir "prowlarr" "/var/lib/prowlarr/Backups"

    # Jellyfin - config and data (excludes transcodes/cache)
    backup_dir "jellyfin" "/var/lib/jellyfin/config"

    # Jellyseerr - full config
    backup_dir "jellyseerr" "/etc/jellyseerr/config"

    # Bazarr - full config
    backup_dir "bazarr" "/etc/bazarr/config"

    # SABnzbd - config (excludes downloads/cache)
    backup_dir "sabnzbd" "/var/lib/sabnzbd"

    # Prune old backups
    echo "Pruning backups older than $KEEP_DAYS days..."
    ${pkgs.findutils}/bin/find "$BACKUP_ROOT" -name "*.tar.gz" -mtime +$KEEP_DAYS -delete 2>/dev/null || true

    echo "=== Backup complete at $(${pkgs.coreutils}/bin/date) ==="
  '';
in {
  systemd.services.media-backup = {
    description = "Backup media service configs to NAS";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = backupScript;
    };
  };

  systemd.timers.media-backup = {
    description = "Daily media service backup at 4:00 AM";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
