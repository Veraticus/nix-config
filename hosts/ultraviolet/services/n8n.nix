{
  pkgs,
  config,
  lib,
  ...
}: {
  # n8n workflow automation
  # Access via Cloudflare Tunnel at n8n.husbuddies.gay
  # Configure route in Cloudflare dashboard: n8n.husbuddies.gay -> http://localhost:5678

  services.n8n = {
    enable = true;
    environment = {
      # Port (default 5678)
      N8N_PORT = 5678;
      # Public URL for webhooks and OAuth callbacks
      N8N_PROTOCOL = "https";
      N8N_HOST = "n8n.husbuddies.gay";
      # Webhook URL (same as host since we're behind CF tunnel)
      WEBHOOK_URL = "https://n8n.husbuddies.gay/";
      # Bypass n8n's built-in auth - Cloudflare Access handles authentication
      N8N_AUTH_EXCLUDE_ENDPOINTS = "*";
      # Trust proxy headers from Cloudflare
      N8N_TRUST_PROXY = "true";
    };
  };

  # Backup service for n8n database
  systemd.services.n8n-backup = {
    description = "Backup n8n database to NAS";
    after = [
      "n8n.service"
      "mnt-backups.mount"
    ];
    requires = ["mnt-backups.mount"];

    path = with pkgs; [
      coreutils
      rsync
      util-linux
      gzip
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = pkgs.writeShellScript "backup-n8n" ''
        set -euo pipefail

        BACKUP_DIR="/mnt/backups/n8n"
        SOURCE_DIR="/var/lib/n8n"
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        BACKUP_NAME="backup-$TIMESTAMP"

        # Ensure backup directory exists
        mkdir -p "$BACKUP_DIR"

        # Check if source exists
        if [ ! -d "$SOURCE_DIR" ]; then
          echo "n8n data directory not found at $SOURCE_DIR"
          exit 1
        fi

        # Create timestamped backup
        echo "Creating n8n backup: $BACKUP_NAME"
        ${pkgs.rsync}/bin/rsync -rlptD --delete \
          "$SOURCE_DIR/" \
          "$BACKUP_DIR/$BACKUP_NAME/"

        # Update latest symlink
        ln -sfn "$BACKUP_NAME" "$BACKUP_DIR/latest"

        # Prune old backups (keep last 7)
        echo "Pruning old backups..."
        ls -1dt "$BACKUP_DIR"/backup-* 2>/dev/null | tail -n +8 | while read -r old_backup; do
          echo "Removing old backup: $old_backup"
          rm -rf "$old_backup"
        done

        echo "n8n backup completed: $BACKUP_NAME"
      '';
    };
  };

  # Timer to run backup daily at 3:30 AM (offset from HA backup at 3:00)
  systemd.timers.n8n-backup = {
    description = "Daily n8n backup timer";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };

  # Restore helper script
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "n8n-restore" ''
      set -e

      BACKUP_DIR="/mnt/backups/n8n"
      RESTORE_DIR="/var/lib/n8n"

      case "''${1:-latest}" in
        list|--list|-l)
          echo "Available n8n backups:"
          echo ""
          if [ -L "$BACKUP_DIR/latest" ]; then
            echo "  latest -> $(basename "$(readlink -f "$BACKUP_DIR/latest")")"
            echo ""
          fi
          ls -1dt "$BACKUP_DIR"/backup-* 2>/dev/null | while read -r backup; do
            size=$(du -sh "$backup" | cut -f1)
            echo "  $(basename "$backup") ($size)"
          done || echo "No backups found"
          ;;
        *)
          BACKUP_NAME="''${1:-latest}"

          if [ "$BACKUP_NAME" = "latest" ]; then
            if [ -L "$BACKUP_DIR/latest" ]; then
              BACKUP_PATH="$BACKUP_DIR/latest"
              echo "Restoring from latest backup: $(readlink -f "$BACKUP_PATH")"
            else
              echo "Error: No 'latest' symlink found."
              exit 1
            fi
          elif [ -d "$BACKUP_DIR/$BACKUP_NAME" ]; then
            BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
            echo "Restoring from backup: $BACKUP_NAME"
          else
            echo "Error: Backup '$BACKUP_NAME' not found"
            exit 1
          fi

          # Stop n8n if running
          if systemctl is-active --quiet n8n.service; then
            echo "Stopping n8n..."
            sudo systemctl stop n8n.service
          fi

          # Restore
          echo "Restoring n8n data..."
          sudo ${pkgs.rsync}/bin/rsync -rlptD --delete "$BACKUP_PATH/" "$RESTORE_DIR/"

          echo ""
          echo "Restore complete. Start n8n with: sudo systemctl start n8n"
          ;;
      esac
    '')
  ];
}
