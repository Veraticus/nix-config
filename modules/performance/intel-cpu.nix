# Intel CPU and I/O scheduler tuning based on performance profile
#
# Configures:
#   - intel_pstate driver mode
#   - CPU scaling governor (schedutil/powersave)
#   - Energy Performance Preference (EPP) via HWP
#   - NVMe and SSD I/O scheduler (none - best for parallel queues)
#
# Intel-specific: the systemd service detects Intel CPUs at runtime
# and skips gracefully on AMD or other architectures.
#
# All values use lib.mkDefault so hosts can override.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.performance;

  cpuSettings = {
    dev = {
      governor = "schedutil";
      epp = "balance_performance";
    };
    server = {
      governor = "schedutil";
      epp = "balance_performance";
    };
    workstation = {
      governor = "performance";
      epp = "performance";
    };
    constrained = {
      governor = "powersave";
      epp = "power";
    };
    router = {
      governor = "schedutil";
      epp = "balance_power";
    };
    none = {
      governor = null;
      epp = null;
    };
  };

  cpu = cpuSettings.${cfg.profile};
in {
  config = lib.mkIf (cfg.cpuVendor == "intel" && cfg.profile != "none" && cpu.governor != null) {
    # Ensure intel_pstate is active (HWP-aware mode)
    # No mkDefault here -- kernelParams is a list that merges via concatenation,
    # and mkDefault would cause the entire list to be discarded if the host
    # defines any kernelParams explicitly.
    boot.kernelParams = ["intel_pstate=active"];

    # Set governor and EPP at boot
    # Detects Intel CPU at runtime - exits cleanly on AMD
    systemd.services.cpu-performance-setup = {
      description = "Configure CPU governor and EPP for ${cfg.profile} profile";
      wantedBy = ["multi-user.target"];
      after = ["systemd-modules-load.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "cpu-performance-setup" ''
          set -euo pipefail

          # Check if intel_pstate is available
          if [ ! -d /sys/devices/system/cpu/intel_pstate ]; then
            echo "intel_pstate not available (AMD CPU or different driver) - skipping"
            exit 0
          fi

          # Set scaling governor on all CPUs
          for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            if [ -w "$gov" ]; then
              echo "${cpu.governor}" > "$gov"
            fi
          done
          echo "Set CPU governor to ${cpu.governor}"

          # Set Energy Performance Preference (requires HWP support)
          for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
            if [ -w "$epp" ]; then
              echo "${cpu.epp}" > "$epp"
            fi
          done
          echo "Set EPP to ${cpu.epp}"
        '';
      };
    };

    # I/O scheduler: 'none' is optimal for NVMe (parallel queue hardware)
    # and SSDs (no rotational latency to optimize for)
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    '';
  };
}
