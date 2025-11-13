_: {
  systemd.tmpfiles.rules = [
    "d /etc/bazarr/config 0644 root root -"
  ];

  virtualisation.oci-containers.containers.bazarr = {
    image = "linuxserver/bazarr:1.5.1";
    ports = [
      "6767:6767"
    ];
    volumes = [
      "/etc/bazarr/config:/config"
      "/mnt/video/:/mnt/video"
    ];
    environment = {
      PUID = "0";
      PGID = "0";
    };
    autoStart = true;
    extraOptions = [
      "--network=host"
    ];
  };

  services.caddy.virtualHosts."bazarr.home.husbuddies.gay".extraConfig = ''
    reverse_proxy /* localhost:6767
    import cloudflare
  '';
}
