_: {
  services.caddy.virtualHosts = {
    "transmission.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* 172.31.0.201:9091
      import cloudflare
    '';
    "sabnzbd.home.husbuddies.gay".extraConfig = ''
      reverse_proxy /* localhost:8080
      import cloudflare
    '';
  };
}
