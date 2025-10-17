{ lib, pkgs, ... }:
let
  mountPoint = "/mnt/obsidian";
  listenPort = 4646;
  listenAddr = "127.0.0.1";
  serviceUser = "joshsymonds";
  cacheDir = "/var/cache/obsidian-webdav";
in
{
  fileSystems."${mountPoint}" = {
    device = "172.31.0.100:/volume1/obsidian";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "nofail"
    ];
  };

  systemd.tmpfiles.rules = lib.mkAfter [
    "d ${mountPoint} 0755 ${serviceUser} users -"
    "d ${cacheDir} 0755 ${serviceUser} users -"
  ];

  systemd.services.obsidian-webdav = {
    description = "Local WebDAV endpoint for Obsidian vault";
    after = [
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    unitConfig = {
      RequiresMountsFor = [ mountPoint ];
    };
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = serviceUser;
      Group = "users";
      WorkingDirectory = mountPoint;
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone serve webdav ${mountPoint} \
          --addr ${listenAddr}:${toString listenPort} \
          --cache-dir ${cacheDir} \
          --vfs-cache-mode writes \
          --dir-cache-time 60m \
          --poll-interval 2m
      '';
      Restart = "on-failure";
      RestartSec = 5;
      AmbientCapabilities = "";
      NoNewPrivileges = true;
    };
  };
}
