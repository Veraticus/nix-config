{pkgs, ...}: {
  services = {
    readarr = {
      enable = true;
      package = pkgs.readarr;
    };

    prowlarr = {
      enable = true;
    };

    caddy.virtualHosts = {
      "readarr.home.husbuddies.gay".extraConfig = ''
        reverse_proxy /* localhost:8787
        import cloudflare
      '';
      "prowlarr.home.husbuddies.gay".extraConfig = ''
        reverse_proxy /* localhost:9696
        import cloudflare
      '';
    };
  };
}
