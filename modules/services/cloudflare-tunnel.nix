{ config, pkgs, lib, ... }:

let
  cfg = config.services.cloudflareTunnel;
 in
{
  options.services.cloudflareTunnel = {
    enable = lib.mkEnableOption "Cloudflare Tunnel using a token";

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the Cloudflare tunnel token (agenix-managed).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cloudflared;
      description = "cloudflared package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules = [
      "d /var/lib/cloudflared 0700 cloudflared cloudflared -"
    ];

    users.users.cloudflared = {
      isSystemUser = true;
      group = "cloudflared";
      home = "/var/lib/cloudflared";
      createHome = true;
    };

    users.groups.cloudflared = {};

    systemd.services.cloudflare-tunnel = {
      description = "Cloudflare Tunnel";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "cloudflared";
        Group = "cloudflared";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c '${cfg.package}/bin/cloudflared tunnel --no-autoupdate run --token $(cat ${lib.escapeShellArg cfg.tokenFile})'
        '';
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadOnlyPaths = [ cfg.tokenFile ];
      };

      unitConfig.ConditionPathExists = cfg.tokenFile;
    };
  };
}
