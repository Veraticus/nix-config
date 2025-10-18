{ inputs, outputs, lib, config, pkgs, ... }: {
  # Common packages for all headless Linux hosts
  environment.systemPackages = with pkgs; [
    yamllint  # YAML linter, useful for Home Assistant configurations
  ];

  # Nix store management - prevent disk space issues
  nix = {
    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "daily";  # Run every night
      options = "--delete-older-than 3d";  # Keep derivations for 3 days
    };
    
    # Automatic store optimization (hard-linking identical files)
    optimise.automatic = true;
    
    settings = {
      # Trigger GC when disk space is low
      min-free = "${toString (10 * 1024 * 1024 * 1024)}"; # 10GB free space minimum
      max-free = "${toString (50 * 1024 * 1024 * 1024)}"; # Clean up to 50GB when triggered
    };
  };

  fileSystems = {
    "/mnt/video" = {
      device = "172.31.0.100:/volume1/video";
      fsType = "nfs";
    };
    "/mnt/music" = {
      device = "172.31.0.100:/volume1/music";
      fsType = "nfs";
    };
    "/mnt/books" = {
      device = "172.31.0.100:/volume1/books";
      fsType = "nfs";
    };
  };

  # Enable Eternal Terminal for low-latency persistent connections
  services.eternal-terminal = {
    enable = true;
    port = 2022;
  };

  # Open firewall for ET
  networking.firewall.allowedTCPPorts = [ 2022 ];

  services.openssh.settings.AcceptEnv = lib.mkBefore "TERM COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION";

  # Automatic cleanup of stale browser/Playwright processes
  systemd.services.cleanup-stale-processes = {
    description = "Clean up stale browser and Playwright processes";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "cleanup-stale-processes" ''
        #!/usr/bin/env bash
        
        # Kill Firefox processes older than 24 hours
        for pid in $(${pkgs.procps}/bin/pgrep -f firefox); do
          # Get process start time in seconds since epoch
          start_time=$(${pkgs.coreutils}/bin/stat -c %Y /proc/$pid 2>/dev/null || echo 0)
          current_time=$(${pkgs.coreutils}/bin/date +%s)
          age=$((current_time - start_time))
          
          # If older than 24 hours (86400 seconds), kill it
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
