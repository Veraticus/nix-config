{pkgs, ...}: {
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
}
