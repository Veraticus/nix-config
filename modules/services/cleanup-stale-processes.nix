{ pkgs, lib, ... }:
let
  cleanupScript = pkgs.writeShellScript "cleanup-stale-processes" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Kill Firefox processes older than 24 hours
    for pid in $(${pkgs.procps}/bin/pgrep -f firefox); do
      start_time=$(${pkgs.coreutils}/bin/stat -c %Y /proc/$pid 2>/dev/null || echo 0)
      current_time=$(${pkgs.coreutils}/bin/date +%s)
      age=$((current_time - start_time))

      if [ $age -gt 86400 ]; then
        echo "Killing stale Firefox process $pid (age: $((age/3600)) hours)"
        ${pkgs.util-linux}/bin/kill -TERM $pid 2>/dev/null || true
        sleep 2
        ${pkgs.util-linux}/bin/kill -KILL $pid 2>/dev/null || true
      fi
    done

    # Kill Playwright server processes older than 24 hours
    for pid in $(${pkgs.procps}/bin/pgrep -f playwright-mcp-server); do
      start_time=$(${pkgs.coreutils}/bin/stat -c %Y /proc/$pid 2>/dev/null || echo 0)
      current_time=$(${pkgs.coreutils}/bin/date +%s)
      age=$((current_time - start_time))

      if [ $age -gt 86400 ]; then
        echo "Killing stale Playwright server $pid (age: $((age/3600)) hours)"
        ${pkgs.util-linux}/bin/kill -TERM $pid 2>/dev/null || true
        sleep 2
        ${pkgs.util-linux}/bin/kill -KILL $pid 2>/dev/null || true
      fi
    done

    # Clean up temporary Playwright profiles
    ${pkgs.findutils}/bin/find /tmp -maxdepth 1 -type d -name "playwright_*" -mtime +1 -exec rm -rf {} + 2>/dev/null || true

    echo "Cleanup completed at $(${pkgs.coreutils}/bin/date)"
  '';
in {
  systemd.services.cleanup-stale-processes = {
    description = "Clean up stale browser and Playwright processes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = cleanupScript;
    };
  };

  systemd.timers.cleanup-stale-processes = {
    description = "Timer for cleaning up stale processes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      OnBootSec = "30min";
      Persistent = true;
    };
  };
}
