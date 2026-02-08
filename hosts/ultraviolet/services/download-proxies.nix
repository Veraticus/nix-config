_: {
  services.caddy.virtualHosts = {
    "sabnzbd.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* localhost:8080
      import cloudflare
    '';
  };
}
