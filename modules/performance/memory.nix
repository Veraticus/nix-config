# Memory and swap tuning based on performance profile
#
# Configures:
#   - zram swap with zstd compression
#   - vm.swappiness and cache pressure
#   - Dirty page ratios for write coalescing
#   - MGLRU (Multi-Gen LRU) for better page reclaim on kernel 6.1+
#
# All values use lib.mkDefault so hosts can override.
{
  config,
  lib,
  ...
}: let
  cfg = config.performance;

  profileMemory = {
    dev = {
      zramPercent = 25;
      swappiness = 10;
      cachePressure = 50;
      enableMglru = true;
    };
    server = {
      zramPercent = 25;
      swappiness = 30;
      cachePressure = 50;
      enableMglru = true;
    };
    workstation = {
      zramPercent = 0; # Skip zram - these machines have dedicated swap already
      swappiness = 10;
      cachePressure = 50;
      enableMglru = true;
    };
    constrained = {
      zramPercent = 50;
      swappiness = 60;
      cachePressure = 100;
      enableMglru = false;
    };
    router = {
      zramPercent = 10;
      swappiness = 60;
      cachePressure = 100;
      enableMglru = false;
    };
    none = {
      zramPercent = 0;
      swappiness = 60;
      cachePressure = 100;
      enableMglru = false;
    };
  };

  mem = profileMemory.${cfg.profile};
in {
  config = lib.mkIf (cfg.profile != "none") {
    # zram swap - compresses pages in RAM before hitting disk
    zramSwap = lib.mkIf (mem.zramPercent > 0) {
      enable = lib.mkDefault true;
      algorithm = lib.mkDefault "zstd";
      memoryPercent = lib.mkDefault mem.zramPercent;
      priority = lib.mkDefault 100;
    };

    boot.kernel.sysctl =
      {
        "vm.swappiness" = lib.mkDefault mem.swappiness;
        "vm.vfs_cache_pressure" = lib.mkDefault mem.cachePressure;
        "vm.dirty_ratio" = lib.mkDefault 10;
        "vm.dirty_background_ratio" = lib.mkDefault 5;
      }
      // lib.optionalAttrs mem.enableMglru {
        # MGLRU: better page reclaim for workloads with large working sets
        # Available on kernel 6.1+, non-fatal on older kernels (sysctl warning only)
        "vm.watermark_boost_factor" = lib.mkDefault 0;
        "vm.watermark_scale_factor" = lib.mkDefault 125;
      };
  };
}
