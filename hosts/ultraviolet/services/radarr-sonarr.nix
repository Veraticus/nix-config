{
  lib,
  pkgs,
  ...
}: let
  configureArrScript = let
    rawScript = builtins.readFile ./configure-arr-optimal.sh;
    placeholders = [
      "@bash@"
      "@sudo@"
      "@gnugrep@"
      "@curl@"
      "@jq@"
      "@coreutils@"
    ];
    values = [
      "${pkgs.bash}"
      "${pkgs.sudo}"
      "${pkgs.gnugrep}"
      "${pkgs.curl}"
      "${pkgs.jq}"
      "${pkgs.coreutils}"
    ];
  in
    pkgs.writeShellScriptBin "configure-arr-optimal"
    (lib.replaceStrings placeholders values rawScript);
in {
  services = {
    sonarr = {
      enable = true;
      package = pkgs.sonarr;
    };

    radarr = {
      enable = true;
      package = pkgs.radarr;
    };

    caddy.virtualHosts = {
      "radarr.home.husbuddies.gay".extraConfig = ''
        reverse_proxy /* localhost:7878
        import cloudflare
      '';
      "sonarr.home.husbuddies.gay".extraConfig = ''
        reverse_proxy /* localhost:8989
        import cloudflare
      '';
    };
  };

  systemd.services."radarr-configure" = {
    description = "Configure Radarr quality profiles for optimal HEVC 4K streaming";
    after = ["radarr.service"];
    wants = ["radarr.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -s http://localhost:7878/api/v3/system/status -H \"X-Api-Key: $(${pkgs.sudo}/bin/sudo cat /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP \"(?<=<ApiKey>)[^<]+\" || echo waiting)\" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q version; do echo \"Waiting for Radarr...\"; sleep 5; done'";
      ExecStart = "${configureArrScript}/bin/configure-arr-optimal";
    };
  };
}
