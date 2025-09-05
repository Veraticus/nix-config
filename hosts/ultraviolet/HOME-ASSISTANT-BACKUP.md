# Home Assistant Backup & Restore Documentation

## Overview
Home Assistant configuration is automatically backed up daily to your NAS at 172.31.0.100.
Backups are stored in the `/volume1/backup` share, mounted at `/mnt/backups/home-assistant`.

## Backup System

### Automatic Backups
- **Schedule**: Daily at 3:00 AM (with 10-minute randomization)
- **Retention**: 14 days (older backups are automatically deleted)
- **Location**: `/mnt/backups/home-assistant/backup-YYYYMMDD-HHMMSS`
- **Latest Symlink**: `/mnt/backups/home-assistant/latest` points to newest backup

### What's Backed Up
- All configuration files (*.yaml)
- `.storage/` directory (UI configurations, integrations, auth tokens)
- Custom components and themes
- Blueprints and scripts

### What's NOT Backed Up
- Database WAL/SHM files (temporary)
- Log files
- Cache directories
- Dependencies

### Manual Backup
To create a backup immediately:
```bash
sudo systemctl start home-assistant-backup.service
```

Check backup status:
```bash
systemctl status home-assistant-backup.service
```

## Restore System

### Quick Restore Commands

List available backups:
```bash
ha-restore list
```

Restore from latest backup:
```bash
ha-restore
# or explicitly:
ha-restore latest
```

Restore from specific backup:
```bash
ha-restore backup-20250902-225915
```

### Restore Process Details

The restore script will:
1. Stop Home Assistant if running
2. Create a safety backup of current configuration
3. Restore the selected backup
4. Fix file ownership
5. Provide instructions for restarting

### Manual Restore (if needed)

If the restore command isn't available:
```bash
# Stop Home Assistant
sudo systemctl stop home-assistant.service

# Create safety backup
sudo rsync -rlptD /var/lib/hass/ /var/lib/hass-backup-$(date +%Y%m%d-%H%M%S)/

# Restore from backup (example with latest)
sudo rsync -rlptDv --delete \
  --exclude='*.log' \
  --exclude='*.log.*' \
  /mnt/backups/home-assistant/latest/ /var/lib/hass/

# Fix ownership
sudo chown -R hass:hass /var/lib/hass

# Start Home Assistant
sudo systemctl start home-assistant.service

# Check logs
sudo journalctl -fu home-assistant.service
```

## Disaster Recovery Scenarios

### Scenario 1: Configuration Mistake
You made a configuration change that broke Home Assistant:
```bash
# Restore to previous working state
ha-restore latest
sudo systemctl start home-assistant.service
```

### Scenario 2: Complete System Failure
After rebuilding ultraviolet or migrating to new hardware:

1. Ensure NFS mount is configured:
   ```bash
   ls /mnt/backups/home-assistant/
   ```

2. Run restore:
   ```bash
   ha-restore latest
   ```

3. Start Home Assistant:
   ```bash
   sudo systemctl start home-assistant.service
   ```

4. Re-enter any secrets if needed:
   ```bash
   sudo nano /var/lib/hass/secrets.yaml
   ```

### Scenario 3: Partial Corruption
If only certain files are corrupted:
```bash
# Copy specific files from backup
sudo cp /mnt/backups/home-assistant/latest/.storage/core.config_entries \
        /var/lib/hass/.storage/core.config_entries
sudo chown hass:hass /var/lib/hass/.storage/core.config_entries
```

## Monitoring

Check backup timer status:
```bash
systemctl status home-assistant-backup.timer
systemctl list-timers | grep home-assistant
```

View backup logs:
```bash
journalctl -u home-assistant-backup.service
```

Check backup sizes and dates:
```bash
ls -lah /mnt/backups/home-assistant/
```

## Troubleshooting

### Backup Fails
```bash
# Check service logs
journalctl -xeu home-assistant-backup.service

# Verify NFS mount
mount | grep backups
ls /mnt/backups/

# Test manual backup
sudo /run/current-system/sw/bin/ha-backup
```

### Restore Fails
```bash
# Check permissions
ls -la /var/lib/hass/

# Verify backup exists
ls -la /mnt/backups/home-assistant/

# Check disk space
df -h /var/lib/
```

### NFS Mount Issues
```bash
# Force mount
sudo mount -t nfs 172.31.0.100:/volume1/backup /mnt/backups

# Check NFS server
showmount -e 172.31.0.100
```

## Integration Backup Notes

### Philips Hue
- Bridge authentication stored in `.storage/core.config_entries`
- No need to re-pair after restore

### Z-Wave JS
- Configuration in `.storage/core.config_entries`
- May need to restart Z-Wave JS UI on bluedesert after restore

### Ecobee
- OAuth tokens in `.storage/`
- May need to re-authenticate if tokens expired

## Best Practices

1. **Test Restores**: Periodically test restore process
2. **Monitor Backups**: Check timer and logs weekly
3. **Before Major Changes**: Run manual backup
4. **Document Changes**: Keep notes on custom configurations
5. **Verify After Updates**: Check backups still work after Home Assistant updates

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ha-restore list` | Show all backups |
| `ha-restore` | Restore latest backup |
| `ha-restore backup-20250902-225915` | Restore specific backup |
| `sudo systemctl start home-assistant-backup` | Manual backup |
| `systemctl status home-assistant-backup.timer` | Check timer |
| `journalctl -u home-assistant-backup` | View logs |