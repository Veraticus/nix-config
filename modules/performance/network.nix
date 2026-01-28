# Network performance tuning based on performance profile
#
# Configures:
#   - TCP buffer sizes for high-bandwidth (10Gbit+) networks and NFS
#   - BBR congestion control (better than CUBIC for variable loss)
#   - Backlog and buffer autotuning
#
# Enabled for: dev, server, workstation, router profiles
# All values use lib.mkDefault so hosts can override.
{
  config,
  lib,
  ...
}: let
  cfg = config.performance;
  enableNetTuning = builtins.elem cfg.profile ["dev" "server" "workstation" "router"];
in {
  config = lib.mkIf enableNetTuning {
    boot.kernel.sysctl = {
      # TCP buffer sizes - large enough for 10Gbit with reasonable RTT
      "net.core.rmem_max" = lib.mkDefault 67108864;
      "net.core.wmem_max" = lib.mkDefault 67108864;
      "net.ipv4.tcp_rmem" = lib.mkDefault "4096 87380 33554432";
      "net.ipv4.tcp_wmem" = lib.mkDefault "4096 65536 33554432";

      # BBR congestion control - requires fq qdisc
      "net.core.default_qdisc" = lib.mkDefault "fq";
      "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";

      # Allow larger packet backlog for bursty traffic
      "net.core.netdev_max_backlog" = lib.mkDefault 300000;

      # Auto-tune receive buffers, don't cache route metrics between connections
      "net.ipv4.tcp_moderate_rcvbuf" = lib.mkDefault 1;
      "net.ipv4.tcp_no_metrics_save" = lib.mkDefault 1;
    };
  };
}
