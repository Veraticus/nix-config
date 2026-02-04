{
  pkgs,
  config,
  lib,
  ...
}: let
  # Git-tracked workflows directory - Claude creates these, sync to n8n on rebuild
  workflowsDir = ../../../n8n/workflows;
in {
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

  # Override n8n service to add workflow import on startup
  systemd.services.n8n = {
    # Import git-tracked workflows before starting n8n
    preStart = let
      importScript = pkgs.writeShellScript "n8n-import-workflows" ''
        set -euo pipefail

        WORKFLOWS_DIR="${workflowsDir}"

        # Check if workflows directory has any JSON files
        if compgen -G "$WORKFLOWS_DIR/*.json" > /dev/null 2>&1; then
          echo "Importing workflows from $WORKFLOWS_DIR..."
          ${pkgs.n8n}/bin/n8n import:workflow --separate --input="$WORKFLOWS_DIR" || {
            echo "Warning: Workflow import failed (may be first run before DB init)"
          }
          echo "Workflow import complete"
        else
          echo "No workflow files found in $WORKFLOWS_DIR"
        fi
      '';
    in
      lib.mkAfter ''
        ${importScript}
      '';
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

  # Helper scripts
  environment.systemPackages = [
    # Restore from backup
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

    # Export workflow(s) from n8n for reconciliation with git
    (pkgs.writeShellScriptBin "n8n-export" ''
      set -e

      OUTPUT_DIR="''${2:-/tmp/n8n-export}"
      mkdir -p "$OUTPUT_DIR"

      case "''${1:-help}" in
        all|--all|-a)
          echo "Exporting all workflows to $OUTPUT_DIR..."
          sudo -u n8n ${pkgs.n8n}/bin/n8n export:workflow --all --separate --output="$OUTPUT_DIR"
          echo ""
          echo "Exported workflows:"
          ls -la "$OUTPUT_DIR"/*.json 2>/dev/null || echo "No workflows found"
          echo ""
          echo "Copy desired files to nix-config/n8n/workflows/ and commit"
          ;;
        help|--help|-h|"")
          echo "n8n-export - Export workflows for git reconciliation"
          echo ""
          echo "Usage:"
          echo "  n8n-export all [output-dir]     Export all workflows"
          echo "  n8n-export <id> [output-dir]    Export specific workflow by ID"
          echo ""
          echo "Default output: /tmp/n8n-export"
          echo ""
          echo "After exporting, copy files to nix-config/n8n/workflows/"
          ;;
        *)
          WORKFLOW_ID="$1"
          echo "Exporting workflow $WORKFLOW_ID to $OUTPUT_DIR..."
          sudo -u n8n ${pkgs.n8n}/bin/n8n export:workflow --id="$WORKFLOW_ID" --output="$OUTPUT_DIR/$WORKFLOW_ID.json"
          echo "Exported: $OUTPUT_DIR/$WORKFLOW_ID.json"
          echo ""
          echo "Copy to nix-config/n8n/workflows/ and commit"
          ;;
      esac
    '')
  ];
}
